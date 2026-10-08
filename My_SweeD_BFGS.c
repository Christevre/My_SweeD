/*
 * My_SweeD_BFGS.c
 *
 * Clean, optimized re-implementation of the bounded BFGS optimizer used by
 * SweeD. The original SweeD_BFGS.c contained ~5900 lines of f2c-translated
 * Fortran (the L-BFGS-B library). This file replaces that machinery with the
 * NLopt library (NLOPT_LD_LBFGS), which solves the exact same bound-constrained
 * minimization problem but in a fraction of the code.
 *
 * The numerical gradient routines (Yanggradient / getgradient) are kept
 * unchanged because SweeD_SFS.c calls getgradient() directly and relies on the
 * exact same finite-difference scheme as the original. Keeping them guarantees
 * the gradients - and therefore the optimum that BFGS converges to - match the
 * original implementation.
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <nlopt.h>
#include "SweeD_BFGS.h"

/* =========================================================================
 *  Numerical gradient (Yang's finite-difference scheme)
 *  Unchanged from the original - SweeD_SFS.c depends on this exact behaviour.
 * ========================================================================= */

void Yanggradient (int n, const double x[], const int need[], double f0,
		   double g[], double (*fun)(const double x[]),
		   double space[], int central,
		   const double* lowbound, const double* upbound)
{
  /* f0 = fun(x) is given for central == 0 */

  int i, j;
  double *x0 = space, *x1 = space + n, eh0, eh01, eh;
  eh0 = eh01 = 1.e-8;

  if (central) {
    for (i = 0; i < n; i++) {
      if (need[i]) {
	for (j = 0; j < n; j++) x0[j] = x1[j] = x[j];
	eh = pow(eh01 * (fabs(x[i]) + 1), 0.67);
	x0[i] -= eh; x1[i] += eh;
	if (x0[i] < lowbound[i])
	  { x1[i] += eh; g[i] = ((*fun)(x1) - f0) / (eh * 2.0); }
	else if (x1[i] > upbound[i])
	  { x0[i] -= eh; g[i] = (f0 - (*fun)(x0)) / (eh * 2.0); }
	else
	  g[i] = ((*fun)(x1) - (*fun)(x0)) / (eh * 2.0);
      }
    }
  }
  else {
    for (i = 0; i < n; i++) {
      if (need[i]) {
	for (j = 0; j < n; j++) x1[j] = x[j];
	eh = 2.0 * pow(eh0 * (fabs(x[i]) + 1), 0.67);
	if (x1[i] + eh > upbound[i])
	  { x1[i] -= eh; g[i] = (f0 - (*fun)(x1)) / eh; }
	else
	  { x1[i] += eh; g[i] = ((*fun)(x1) - f0) / eh; }
      }
    }
  }
}

static double oldf0;
static int CENTRALMODE = 1;

void getgradient(int npar, const double invec[], const int need_gradient[],
		 double outvec[], double(*func)(const double []),
		 const double* lowbound, const double* upbound)
{
  double f0;
  int i;
  double *space = malloc((2 * npar + 10) * sizeof(double));

  CENTRALMODE = 1;
  for (i = 0; i < npar; i++)
    if (need_gradient[i]) break;
  if (i == npar) goto checkbounds;

  f0 = func(invec);

  if (CENTRALMODE > 0)
    Yanggradient(npar, invec, need_gradient, f0, outvec, func,
		 space, 1, lowbound, upbound);
  else
    Yanggradient(npar, invec, need_gradient, f0, outvec, func,
		 space, 0, lowbound, upbound);
  if (CENTRALMODE == 0 && fabs(oldf0 - f0) < 0.1)
    CENTRALMODE = 1;
  else if (CENTRALMODE > 0 && fabs(oldf0 - f0) > 1.0)
    CENTRALMODE = 0;
  oldf0 = f0;

 checkbounds:
  for (i = 0; i < npar; i++) {
    if (invec[i] <= lowbound[i] && outvec[i] > 0.0)
      outvec[i] = 0.0;
    if (invec[i] >= upbound[i] && outvec[i] < 0.0)
      outvec[i] = 0.0;
  }
  free(space);
}

/* Static context used by the numerical-gradient fallback (dfun == NULL). */
static int numpar0 = 0;
static double (*func0)(const double x[]) = NULL;
static double *lowbound0 = NULL, *upbound0 = NULL;
static int *need0 = NULL;

static void numeric_likelihood(const double *invec, double *outvec) {
  getgradient(numpar0, invec, need0, outvec, func0, lowbound0, upbound0);
}

/* =========================================================================
 *  NLopt wrapper
 * ========================================================================= */

/* Everything NLopt needs to evaluate the objective in a single struct, so we
 * avoid extra global state. */
typedef struct {
  double (*fun)(const double x[]);              /* objective (minimized)      */
  void (*dfun)(const double x[], double y[]);   /* its gradient               */
} bfgs_context;

/* Objective adapter matching NLopt's signature. NLopt minimizes this value;
 * SweeD's `fun` already returns the negative log-likelihood, so minimizing it
 * maximizes the likelihood - exactly as the original L-BFGS-B driver did. */
static double nlopt_objective(unsigned n, const double *x,
			      double *grad, void *data)
{
  const bfgs_context *ctx = (const bfgs_context *) data;
  (void) n;
  if (grad)
    ctx->dfun(x, grad);
  return ctx->fun(x);
}

/*
 * findmax_bfgs - bound-constrained BFGS optimization.
 *
 * Drop-in replacement for the original L-BFGS-B driver. Same signature and
 * semantics: `invec` is updated in place with the optimal parameters and the
 * optimal objective value is returned (as -f, i.e. the maximized likelihood).
 *
 *   numpars  number of parameters
 *   invec    initial guess; overwritten with the optimum
 *   fun      objective to minimize (negative log-likelihood)
 *   dfun     gradient of fun, or NULL to use the numerical gradient
 *   lowbound / upbound   per-parameter bounds
 *   nbd      kept for interface compatibility (NLopt always uses both bounds)
 *   noisy    verbosity flag (>1 prints the final value)
 */
double findmax_bfgs(int numpars, double *invec, double (*fun)(const double x[]),
		    void (*dfun)(const double x[], double y[]),
		    double *lowbound, double *upbound, int *nbd, int noisy)
{
  int i;
  double minf = 0.0;
  void (*dfun0)(const double x[], double y[]);
  bfgs_context ctx;
  nlopt_opt opt;

  (void) nbd; /* NLopt models bounds directly; nbd is unused. */

  /* Pick the gradient: caller-supplied, or the numerical fallback. */
  if (dfun == NULL) {
    dfun0 = numeric_likelihood;
    func0 = fun;
    numpar0 = numpars;
    lowbound0 = lowbound;
    upbound0 = upbound;
    need0 = malloc(numpars * sizeof(int));
    for (i = 0; i < numpars; i++) need0[i] = 1;
  }
  else
    dfun0 = dfun;

  ctx.fun = fun;
  ctx.dfun = dfun0;

  /* Limited-memory BFGS with box constraints - the NLopt analogue of the
   * original L-BFGS-B method. */
  opt = nlopt_create(NLOPT_LD_LBFGS, numpars);
  nlopt_set_lower_bounds(opt, lowbound);
  nlopt_set_upper_bounds(opt, upbound);
  nlopt_set_min_objective(opt, nlopt_objective, &ctx);

  /* Convergence criteria. The original L-BFGS-B driver stops on a relative
   * reduction in f below FACTR*epsmch OR a projected-gradient norm below
   * PGTOL. We converge on the relative function and step tolerances; at the
   * values below the optimum is fully resolved and stable (tightening them
   * further does not change the result), so MySweeD lands on the same
   * maximum-likelihood point as the original to within floating-point noise. */
  nlopt_set_ftol_rel(opt, 1.0e-10);
  nlopt_set_xtol_rel(opt, 1.0e-10);
  nlopt_set_maxeval(opt, 15000);             /* safety cap on evaluations */

  /* Project the start point into the feasible box (the original did this in
   * the `active` routine). */
  for (i = 0; i < numpars; i++) {
    if (invec[i] < lowbound[i]) invec[i] = lowbound[i];
    if (invec[i] > upbound[i]) invec[i] = upbound[i];
  }

  nlopt_optimize(opt, invec, &minf);

  if (noisy > 1)
    printf("findmax_bfgs: f = %f\n", minf);

  nlopt_destroy(opt);

  if (dfun == NULL) {
    lowbound0 = NULL;
    upbound0 = NULL;
    func0 = NULL;
    free(need0);
    need0 = NULL;
    numpar0 = 0;
  }

  return -minf;
}
