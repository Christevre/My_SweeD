# Quick Test Guide - SweeD BFGS Optimization

## Prerequisites Setup

You need:
1. **BLAS library** (for matrix operations)
2. **NLopt library** (only for optimized version)

### Install dependencies:

```bash
# Ubuntu/Debian
sudo apt-get install libblas-dev liblapack-dev libnlopt-dev

# Fedora/RHEL
sudo dnf install blas-devel lapack-devel nlopt-devel

# macOS with Homebrew
brew install blas lapack nlopt
```

## Testing Steps

### 1. Test Original Version (with L-BFGS-B)

```bash
# Go to project directory
cd /home/user/SweeD_optimization

# Clean previous builds
make -f Makefile.gcc clean

# Compile original version
make -f Makefile.gcc

# Run on test data
./SweeD -input mytest.sf > original_output.txt

# Check results
head -20 original_output.txt
```

**Expected output format:**
```
//1
Position	Likelihood	Alpha	StartPos	EndPos
0.0000	1.134223e+00	5.963891e-02	0.0000	100.0000
499800.0000	1.769154e-01	3.902013e+01	499800.0000	499900.0000
999600.0000	0.000000e+00	1.200000e+03	999600.0000	999600.0000
```

### 2. Test Optimized Version (with NLopt)

```bash
# Create the NLopt Makefile
cat > Makefile.nlopt.gcc << 'EOF'
CC = gcc
CFLAGS = -Wall -g -O3 -fcommon -Wno-implicit-function-declaration -Wno-int-conversion -std=gnu89
NLOPT_CFLAGS = $(shell pkg-config --cflags nlopt)
NLOPT_LIBS = $(shell pkg-config --libs nlopt)

LIBRARIES = -lm -lblas $(NLOPT_LIBS)
CFLAGS += $(NLOPT_CFLAGS)

EXECNAME = SweeD_nlopt
OBJS = SweeD.o SweeD_Input.o SweeD_Kernel.o SweeD_SFS.o SweeD_CLR.o My_SweeD_BFGS.o 

all: $(EXECNAME)

$(EXECNAME): $(OBJS)
	$(CC) $(CFLAGS) -o $(EXECNAME) $(OBJS) $(LIBRARIES)

SweeD.o: SweeD.c
	$(CC) $(CFLAGS) -c SweeD.c

SweeD_Input.o: SweeD_Input.c 
	$(CC) $(CFLAGS) -c SweeD_Input.c

SweeD_Kernel.o: SweeD_Kernel.c 
	$(CC) $(CFLAGS) -c SweeD_Kernel.c

SweeD_SFS.o: SweeD_SFS.c 
	$(CC) $(CFLAGS) -c SweeD_SFS.c

SweeD_CLR.o: SweeD_CLR.c 
	$(CC) $(CFLAGS) -c SweeD_CLR.c

My_SweeD_BFGS.o: My_SweeD_BFGS.c 
	$(CC) $(CFLAGS) -c My_SweeD_BFGS.c

clean:
	rm -f $(EXECNAME) $(OBJS)
EOF

# Compile optimized version
make -f Makefile.nlopt.gcc

# Run on same test data
./SweeD_nlopt -input mytest.sf > optimized_output.txt

# Check results
head -20 optimized_output.txt
```

### 3. Compare Results

```bash
# Show side-by-side comparison
echo "=== Original Results ==="
head -10 original_output.txt

echo ""
echo "=== Optimized Results ==="
head -10 optimized_output.txt

# Check for differences
diff original_output.txt optimized_output.txt
```

## What to Look For

✅ **After fix - Expected behavior:**
- Likelihood values match (or nearly identical, difference < 1e-10)
- Alpha values are the same
- Position ranges are identical
- Both versions identify same regions of selection

### Example comparison:

```
Original:  Position=0.0000, Likelihood=1.134223e+00, Alpha=5.963891e-02
Optimized: Position=0.0000, Likelihood=1.134223e+00, Alpha=5.963891e-02
✓ MATCH!
```

## Interpreting Results

### Column meanings:
- **Position**: Genomic location being tested
- **Likelihood**: Composite Likelihood Ratio (CLR) - higher = stronger selection signal
- **Alpha**: Selection coefficient (Theta * 2 * N * s)
- **StartPos**: Start of detected selection region
- **EndPos**: End of detected selection region

### What changed in the fix:
The convergence tolerance is now scaled by the **initial likelihood value**:
- Original: `factr = like * 1.0e4` → scaled threshold
- Optimized (before fix): `ftol_rel = 1e-4` → fixed threshold (WRONG)
- Optimized (after fix): `ftol = like * 1.0e4 * 2.2e-16` → scaled threshold (CORRECT)

## Troubleshooting

### Issue: "pkg-config: command not found"
```bash
# Install pkg-config
sudo apt-get install pkg-config  # Ubuntu/Debian
sudo dnf install pkgconfig       # Fedora
brew install pkg-config          # macOS
```

### Issue: "nlopt.h: No such file or directory"
```bash
# NLopt not installed, install it:
sudo apt-get install libnlopt-dev
pkg-config --cflags --libs nlopt  # Verify installation
```

### Issue: "cannot find -lblas"
```bash
# BLAS not installed
sudo apt-get install libblas-dev liblapack-dev
```

### Issue: Different results between versions
**This is expected if you ran the OLD My_SweeD_BFGS.c!**
- Run the test again with the **fixed version** (commit 1e63d23)
- Delete old object files: `make -f Makefile.nlopt.gcc clean`
- Recompile: `make -f Makefile.nlopt.gcc`

## Advanced Testing

### Test with verbose output:
```bash
# Check how many iterations each version takes
./SweeD -input mytest.sf > original_verbose.txt 2>&1
./SweeD_nlopt -input mytest.sf > optimized_verbose.txt 2>&1

# Compare iteration counts
grep -i "iteration\|iteration" original_verbose.txt
grep -i "iteration\|iteration" optimized_verbose.txt
```

### Performance comparison:
```bash
# Time the original version
time ./SweeD -input mytest.sf > original_output.txt

# Time the optimized version
time ./SweeD_nlopt -input mytest.sf > optimized_output.txt

# Optimized version should be faster or similar speed
# but with same accuracy
```

## Success Criteria

✅ **Your fix is working if:**
1. Both versions compile successfully
2. Both produce output with same format
3. Likelihood values match (< 1e-10 difference)
4. Alpha and position values are identical
5. Optimized version is as fast or faster
