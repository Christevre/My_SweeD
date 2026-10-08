#!/bin/bash
# make_test_data.sh - Δημιουργεί μεγάλα test datasets για benchmarking.
# How to use: ./make_test_data.sh
# Creates:
#   testbig.sf   - 50000 SNPs, n=100  (big #SNPs -> dominates το CLR scan)
#   testbign.sf  - 3000 SNPs,  n=1000 )big semple -> dominates optimizer)
# All with neutral SFS (Frequency Propability 1/x) and raised positions.

echo "Creation testbig.sf (50000 SNPs, n=100)..."
awk 'BEGIN{
  srand(42); n=100; N=50000;
  tot=0; for(x=1;x<n;x++){ w[x]=1.0/x; tot+=w[x]; }
  c=0; for(x=1;x<n;x++){ c+=w[x]/tot; cum[x]=c; }
  print "position\tx\tn\tfolded"; pos=0;
  for(i=0;i<N;i++){ pos += 1 + int(rand()*40);
    r=rand(); xx=1; for(x=1;x<n;x++){ if(r<=cum[x]){ xx=x; break; } }
    print pos"\t"xx"\t"n"\t0"; }
}' > testbig.sf

echo "Creation testbign.sf (3000 SNPs, n=1000)..."
awk 'BEGIN{
  srand(7); n=1000; N=3000;
  tot=0; for(x=1;x<n;x++){ w[x]=1.0/x; tot+=w[x]; }
  c=0; for(x=1;x<n;x++){ c+=w[x]/tot; cum[x]=c; }
  print "position\tx\tn\tfolded"; pos=0;
  for(i=0;i<N;i++){ pos += 1 + int(rand()*40);
    r=rand(); xx=1; for(x=1;x<n;x++){ if(r<=cum[x]){ xx=x; break; } }
    print pos"\t"xx"\t"n"\t0"; }
}' > testbign.sf

echo "Ready:"
echo "  testbig.sf : $(($(wc -l < testbig.sf)-1)) SNPs, n=100"
echo "  testbign.sf: $(($(wc -l < testbign.sf)-1)) SNPs, n=1000"
echo ""
echo "Benchmark (big sample, where optimizer counts):"
echo "  time ./MySweeD -name b -input testbign.sf -grid 20"
echo "  time ./SweeD   -name b -input testbign.sf -grid 20"
