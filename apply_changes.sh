#!/bin/bash
# apply_changes.sh - Εφαρμόζει ΟΛΕΣ τις αλλαγές του sandbox σε ένα βήμα.
# Τρέξε το μέσα στον φάκελο του project, μετά: git add -A && git commit && git push
set -e

echo " .gitignore"
cat > .gitignore << 'EOF'
# Compiled object files
*.o

# Compiled binaries
SweeD
MySweeD

# SweeD runtime output files
SweeD_Report.*
SweeD_Info.*
SweeD_Warnings.*
EOF

echo "==> 2/4  creation of test2.sf"
cat > test2.sf << 'EOF'
position	x	n	folded
0	2	100	0
500	15	100	0
1000	3	100	0
1500	42	100	0
2000	1	100	0
2500	28	100	0
3000	7	100	0
3500	19	100	0
4000	35	100	0
4500	5	100	0
5000	22	100	0
5500	11	100	0
6000	47	100	0
6500	8	100	0
7000	31	100	0
7500	4	100	0
8000	26	100	0
8500	18	100	0
9000	39	100	0
9500	6	100	0
10000	24	100	0
10500	13	100	0
11000	44	100	0
11500	9	100	0
12000	29	100	0
12500	2	100	0
13000	37	100	0
13500	14	100	0
14000	21	100	0
14500	7	100	0
15000	43	100	0
15500	10	100	0
16000	25	100	0
16500	5	100	0
17000	32	100	0
17500	17	100	0
18000	40	100	0
18500	11	100	0
19000	27	100	0
19500	6	100	0
20000	38	100	0
EOF

echo "==> 3/4  compare  compare_results.sh"
cat > compare_results.sh << 'EOF'
#!/bin/bash
# Compare MySweeD (NLopt) vs SweeD (original)
# Use: ./compare_results.sh <input.sf> <grid>
INPUT=${1:-mytest.sf}
GRID=${2:-50}
echo "Execute original SweeD..."
./SweeD   -name _orig  -input "$INPUT" -grid "$GRID" >/dev/null 2>&1
echo "Execute MySweeD (NLopt)..."
./MySweeD -name _nlopt -input "$INPUT" -grid "$GRID" >/dev/null 2>&1
echo ""
echo "Position      | Original     | NLopt        | Diff %   | Alpha match"
echo "--------------|--------------|--------------|----------|------------"
awk '
  NR==FNR { if($1 ~ /^[0-9]/) { lo[$1]=$2; ao[$1]=$3 } next }
  $1 ~ /^[0-9]/ {
    pos=$1; ln=$2; an=$3
    if (pos in lo) {
      d = ln - lo[pos]
      pct = (lo[pos]!=0) ? 100*d/lo[pos] : 0
      amatch = (sprintf("%.4g",an)==sprintf("%.4g",ao[pos])) ? "yes" : "NO"
      if (ln > 0.01 || lo[pos] > 0.01)
        printf "%-13s | %.6e | %.6e | %+7.3f%% | %s\n", pos, lo[pos], ln, pct, amatch
    }
  }
' SweeD_Report._orig SweeD_Report._nlopt
echo ""
echo "Amount of evaluations (iterations):"
SWEED_COUNT_EVALS=1 ./SweeD   -name _c -input "$INPUT" -grid "$GRID" >/dev/null 2>_o.txt
SWEED_COUNT_EVALS=1 ./MySweeD -name _c -input "$INPUT" -grid "$GRID" >/dev/null 2>_n.txt
echo "  Original: $(grep -o '[0-9]* likelihood' _o.txt)"
echo "  NLopt:    $(grep -o '[0-9]* likelihood' _n.txt)"
rm -f _o.txt _n.txt SweeD_Report._orig SweeD_Report._nlopt SweeD_Report._c SweeD_Info._* SweeD_Warnings._*
EOF
chmod +x compare_results.sh

echo "==> 4/4  Επεξεργασία SweeD_SFS.c (προσθήκη eval counter)"
python3 - << 'PYEOF'
f = "SweeD_SFS.c"
s = open(f).read()
if "sweed_eval_count" in s:
    print("    (ο counter υπάρχει ήδη - skip)")
else:
    old = """t_sfs p_likelihood_freq(const t_sfs * logSFS)
{
\tt_sfs likelihood;
  
\tgetSFSfromLogSFS (logSFS, alignment->tmpSFS);

\tlikelihood = getLikelihoodSFS(alignment->tmpSFS);

 \treturn -likelihood;
}"""
    new = """/* Diagnostic counter: total number of likelihood evaluations across the whole
 * run. Both optimizers (original L-BFGS-B and NLopt) call this same function,
 * so the count is a fair "iterations" comparison. Printed at program exit only
 * when the environment variable SWEED_COUNT_EVALS is set, so normal runs are
 * unaffected. */
unsigned long sweed_eval_count = 0;

static void __attribute__((destructor)) sweed_print_eval_count(void)
{
\tif (getenv("SWEED_COUNT_EVALS"))
\t\tfprintf(stderr, "SWEED_EVALS: %lu likelihood evaluations\\n",
\t\t\tsweed_eval_count);
}

t_sfs p_likelihood_freq(const t_sfs * logSFS)
{
\tt_sfs likelihood;

\tsweed_eval_count++;

\tgetSFSfromLogSFS (logSFS, alignment->tmpSFS);

\tlikelihood = getLikelihoodSFS(alignment->tmpSFS);

 \treturn -likelihood;
}"""
    if old not in s:
        print(" error no p_likelihood_freq has been found")
        raise SystemExit(1)
    open(f, "w").write(s.replace(old, new))
    print("  ok counter has been added")
PYEOF

echo ""
echo "==> Done! Now:"
echo "    make -f Makefile.gcc clean && make -f Makefile.gcc"
echo "    make -f Makefile.MySweeD.gcc clean && make -f Makefile.MySweeD.gcc"
echo "    ./compare_results.sh mytest.sf 50"
echo ""
echo "    git add -A"
echo "    git commit -m 'Add eval counter, comparison script, test2, gitignore'"
echo "    git push -u origin claude/ecstatic-carson-zp6rp6"
