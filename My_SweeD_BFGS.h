#ifndef SWEED_BFGS_H
#define SWEED_BFGS_H

// These three parameters affect the precision of optimization.
// m is not recommended to be higher than 20
// decreasing factr, pgtol will increase precision
#define MVAL 12
#define FACTR 1.0e6
#define PGTOL 1.0e-3

// Main optimization function wrapping NLopt
double findmax_bfgs(int numpars, double *invec, double (*fun)(const double x[]),
		    void (*dfun)(const double x[], double y[]),
		    double *lowbound, double *upbound,
		    int *nbd, int noisy);

// Numerical gradient calculator (Required by SweeD_SFS.c)
void getgradient(int npar, const double invec[], const int need_gradient[], 
		 double outvec[], double(*func)(const double []), 
		 const double* lowbound, const double* upbound);

#endif