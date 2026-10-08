#!/bin/bash
# Compares MySweeD (NLopt) vs SweeD (original)
# How to use: ./compare_results.sh <input.sf> <grid>
INPUT=${1:-mytest.sf}
GRID=${2:-50}
echo "Executing original SweeD..."
./SweeD   -name _orig  -input "$INPUT" -grid "$GRID" >/dev/null 2>&1
echo "Executing MySweeD (NLopt)..."
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
echo "Count of evaluations (iterations):"
SWEED_COUNT_EVALS=1 ./SweeD   -name _c -input "$INPUT" -grid "$GRID" >/dev/null 2>_o.txt
SWEED_COUNT_EVALS=1 ./MySweeD -name _c -input "$INPUT" -grid "$GRID" >/dev/null 2>_n.txt
echo "  Original: $(grep -o '[0-9]* likelihood' _o.txt)"
echo "  NLopt:    $(grep -o '[0-9]* likelihood' _n.txt)"
rm -f _o.txt _n.txt SweeD_Report._orig SweeD_Report._nlopt SweeD_Report._c SweeD_Info._* SweeD_Warnings._*
