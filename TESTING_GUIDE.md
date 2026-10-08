# SweeD BFGS Testing Guide

## Quick Start

### Step 1: Compile the Original Version (with L-BFGS-B)

```bash
# Make a backup of your optimized version
cp My_SweeD_BFGS.c My_SweeD_BFGS.c.backup

# Compile with original BFGS implementation
make -f Makefile.gcc clean
make -f Makefile.gcc

# This creates: ./SweeD (original version)
```

### Step 2: Run Original Version and Save Results

```bash
# Run with test data
./SweeD -input mytest.sf > original_results.txt

# Save the output
cp original_results.txt original_results_backup.txt
```

### Step 3: Switch to Optimized Version

**IMPORTANT:** Your optimized version requires NLopt library!

```bash
# Install NLopt if not already installed
# On Ubuntu/Debian:
sudo apt-get install libnlopt-dev

# Or compile from source if needed:
# https://nlopt.readthedocs.io/en/latest/

# Verify NLopt is installed:
pkg-config --cflags --libs nlopt
```

### Step 4: Create Makefile for Optimized Version

Create a new Makefile (e.g., `Makefile.nlopt.gcc`):

```makefile
# Makefile for the NLopt-based sequential version

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
	rm -f $(EXECNAME)
	rm -f $(OBJS)
```

### Step 5: Compile Optimized Version

```bash
# Compile with optimized NLopt version
make -f Makefile.nlopt.gcc clean
make -f Makefile.nlopt.gcc

# This creates: ./SweeD_nlopt (optimized version)
```

### Step 6: Run Optimized Version and Save Results

```bash
# Run with same test data
./SweeD_nlopt -input mytest.sf > optimized_results.txt

# Compare results
diff original_results.txt optimized_results.txt
```

## Comparing Results

### Check Likelihood Values

```bash
# Extract likelihood values from both outputs
echo "=== Original Version ==="
head -20 original_results.txt | grep -E "Likelihood|Position"

echo ""
echo "=== Optimized Version ==="
head -20 optimized_results.txt | grep -E "Likelihood|Position"
```

### Full Diff Report

```bash
# See all differences
diff -u original_results.txt optimized_results.txt

# Line-by-line comparison with line numbers
diff -u original_results.txt optimized_results.txt | less
```

### Check Specific Values

```bash
# Extract just the numbers for easier comparison
echo "Original first result:"
head -5 original_results.txt | tail -1

echo "Optimized first result:"
head -5 optimized_results.txt | tail -1
```

## Expected Results

✅ **After the fix, you should see:**
- **Same likelihood values** (or differences < 1e-10, which is numerical precision)
- **Same alpha values** (selection coefficient)
- **Same start/end positions** for detected regions
- **Similar number of iterations** to convergence

❌ **Before the fix, you would see:**
- Completely different likelihood values
- Different alpha values
- Different position ranges
- Early stopping (fewer iterations)

## Troubleshooting

### Issue: "No such file or directory: nlopt.h"
**Solution:** Install NLopt development files
```bash
sudo apt-get install libnlopt-dev
# Or on other systems:
sudo yum install NLopt-devel        # Fedora/RHEL
brew install nlopt                   # macOS
```

### Issue: "undefined reference to `nlopt_*`"
**Solution:** Make sure NLopt libraries are linked
```bash
# Verify NLopt is installed
pkg-config --list-all | grep nlopt

# If not found, install it or check your Makefile has NLOPT_LIBS
```

### Issue: Results still don't match
**Possible causes:**
1. Different initial parameters - verify using same `-input` file
2. Different random seed - check if applicable
3. Numerical precision differences - these are acceptable
4. CENTRALMODE static variable state - ensure fresh run

## Test Data Format

The `mytest.sf` file should be in the SweeD input format. 
To see expected output format:
```bash
cat SweeD_Report.test
```

This shows the expected output format with columns:
- Position (genomic location)
- Likelihood (CLR value)
- Alpha (selection coefficient)
- StartPos (region start)
- EndPos (region end)
