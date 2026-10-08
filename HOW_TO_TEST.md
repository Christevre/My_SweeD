# SweeD Test Execution Guide - REAL Instructions

## Your Actual Test Setup

You already have **pre-compiled binaries**:
- **`SweeD`** - Original version (using L-BFGS-B in SweeD_BFGS.c)
- **`MySweeD`** - Your version (using My_SweeD_BFGS.c - which you just fixed!)

## Test Files

### Input Data
- **`mytest.sf`** - Test dataset (position, mutations, sample size, folded status)

### Expected Reference Output  
- **`SweeD_Report.test`** - Original SweeD results (baseline)
- **`SweeD_Report.MyTest`** - Your MySweeD results (before fix - DIFFERENT!)

## IMPORTANT: The Problem Shown in Output Files

Your existing output files **PROVE the bug existed**:

**Original (`SweeD_Report.test`):**
```
Position      Likelihood      Alpha           StartPos  EndPos
0.0000        1.134223e+00    5.963891e-02    0.0000    100.0000
499800.0000   1.769154e-01    3.902013e+01    499800.0000 499900.0000
999600.0000   0.000000e+00    1.200000e+03    999600.0000 999600.0000
```

**Your Old Version (`SweeD_Report.MyTest`) - WRONG!:**
```
Position      Likelihood      Alpha           StartPos  EndPos
0.0000        1.160631e+05    2.241024e-06    0.0000    999600.0000
499800.0000   1.142656e+05    4.945023e-06    0.0000    999600.0000
999600.0000   1.144950e+05    2.307607e-06    0.0000    999600.0000
```

**Difference:** Likelihood is 100,000x different! 

## How to Test the FIX

### Step 1: Recompile MySweeD with the FIXED code

```bash
cd /home/user/SweeD_optimization

# Clean old object files
make -f Makefile.gcc clean

# Rebuild using your FIXED My_SweeD_BFGS.c
# Replace the line in Makefile.gcc to use My_SweeD_BFGS.o instead:
# Edit: Change "SweeD_BFGS.o" to "My_SweeD_BFGS.o" in OBJS
# Or create a new Makefile

# Quick way - create Makefile for your fixed version:
cat > Makefile.MySweeD.gcc << 'EOF'
CC = gcc
CFLAGS = -Wall -g -O3 -fcommon -Wno-implicit-function-declaration -Wno-int-conversion -std=gnu89
LIBRARIES = -lm -lblas

EXECNAME = MySweeD
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

# Compile your FIXED version
make -f Makefile.MySweeD.gcc clean
make -f Makefile.MySweeD.gcc

# Verify it compiled
ls -la MySweeD
```

### Step 2: Run Both Versions on Test Data

```bash
# Run ORIGINAL version
./SweeD -name test -input mytest.sf -grid 3

# Run YOUR FIXED version  
./MySweeD -name MyTest -input mytest.sf -grid 3
```

This creates:
- `SweeD_Report.test` - Original results
- `SweeD_Report.MyTest` - Your FIXED results

### Step 3: Compare the Results

```bash
# View original
echo "=== ORIGINAL (SweeD_BFGS.c) ==="
cat SweeD_Report.test

echo ""
echo "=== YOUR FIXED VERSION (My_SweeD_BFGS.c) ==="
cat SweeD_Report.MyTest

echo ""
echo "=== DIFFERENCE ==="
diff SweeD_Report.test SweeD_Report.MyTest
```

## Expected Results After Fix

✅ **AFTER your fix (commit 9d923b0):**
- `SweeD_Report.test` and `SweeD_Report.MyTest` should be **IDENTICAL** (or nearly identical)
- Same likelihood values
- Same alpha values
- Same position ranges
- `diff` shows **NO DIFFERENCES** (or only < 1e-10 numerical precision)

❌ **BEFORE your fix:**
- Results were completely different (100,000x different likelihood!)
- This proved the convergence tolerance bug

## The Fix You Applied

In `My_SweeD_BFGS.c` (lines 144-148), you now:

```c
// OLD (WRONG):
nlopt_set_ftol_rel(opt, 1e-4);  // Fixed tolerance

// NEW (CORRECT - matches original):
double like = (*fun)(invec);
double factr = like * 1.0e4;
double ftol = factr * epsmch;
nlopt_set_ftol_rel(opt, ftol);  // Scaled like original
```

This ensures NLopt uses **the same convergence criterion** as L-BFGS-B.

## Simple Test Commands

```bash
# 1. Build fixed version
make -f Makefile.MySweeD.gcc

# 2. Run both
./SweeD -name test -input mytest.sf -grid 3
./MySweeD -name MyTest -input mytest.sf -grid 3

# 3. Compare
diff SweeD_Report.test SweeD_Report.MyTest

# Success = NO OUTPUT from diff command!
```
