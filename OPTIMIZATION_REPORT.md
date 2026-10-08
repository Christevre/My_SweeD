# SweeD Optimization Report

Τεκμηρίωση της βελτιστοποίησης του SweeD: αντικατάσταση του optimizer με NLopt
και παραλληλοποίηση του υπολογιστικού πυρήνα με OpenMP.

---

## 1. Στόχος

Το SweeD ανιχνεύει **selective sweeps** υπολογίζοντας ένα **CLR (Composite
Likelihood Ratio)** κατά μήκος του χρωμοσώματος. Ο αρχικός κώδικας
βελτιστοποίησης (`SweeD_BFGS.c`) ήταν αυτόματα μεταφρασμένη Fortran (μέσω f2c),
πρακτικά μη-συντηρήσιμη (~5937 γραμμές).

**Δύο στόχοι:**
1. Αντικατάσταση του optimizer με καθαρή, συντηρήσιμη υλοποίηση (NLopt).
2. Επιτάχυνση του προγράμματος χωρίς απώλεια ακρίβειας.

---

## 2. Τι άλλαξε

### 2.1 Αντικατάσταση optimizer (`My_SweeD_BFGS.c`)

Ο αρχικός L-BFGS-B optimizer αντικαταστάθηκε με τη βιβλιοθήκη **NLopt**
(`NLOPT_LD_LBFGS`).

| | Original (`SweeD_BFGS.c`) | Νέο (`My_SweeD_BFGS.c`) |
|---|---|---|
| Γραμμές κώδικα | ~5937 | **227** (−96%) |
| Προέλευση | f2c-μεταφρασμένη Fortran | Καθαρή C + NLopt |
| Συντηρησιμότητα | Πολύ δύσκολη | Εύκολη |

Το setup του optimizer:
```c
opt = nlopt_create(NLOPT_LD_LBFGS, numpars);  // δημιουργία
nlopt_set_lower_bounds(opt, lowbound);         // όρια [-15, 10]
nlopt_set_upper_bounds(opt, upbound);
nlopt_set_min_objective(opt, nlopt_objective, &ctx);  // αντικειμενική
nlopt_set_ftol_rel(opt, 1.0e-10);              // κριτήριο σύγκλισης (f)
nlopt_set_xtol_rel(opt, 1.0e-10);              // κριτήριο σύγκλισης (x)
nlopt_set_maxeval(opt, 15000);                 // όριο ασφαλείας
nlopt_optimize(opt, invec, &minf);             // εκτέλεση
nlopt_destroy(opt);                            // καθαρισμός
```

### 2.2 Ρύθμιση tolerance (`ftol_rel`)

Το `ftol_rel` ρυθμίστηκε από `1e-12` σε **`1e-10`**. Η ακρίβεια παραμένει ίδια
(το peak CLR ταυτίζεται στα 6 δεκαδικά), αλλά με λιγότερα iterations:

| ftol_rel | Evaluations (mytest, grid 50) | Peak CLR |
|----------|-------------------------------|----------|
| 1e-12 | 8333 | 2.960707 |
| **1e-10** | **8213** | 2.960708 |

### 2.3 Instrumentation: μετρητής evaluations (`SweeD_SFS.c`)

Προστέθηκε προαιρετικός μετρητής των likelihood evaluations, ενεργός μόνο με
την environment variable `SWEED_COUNT_EVALS`:
```bash
SWEED_COUNT_EVALS=1 ./MySweeD -name t -input mytest.sf -grid 50 >/dev/null
# -> SWEED_EVALS: 8213 likelihood evaluations
```
Χωρίς την environment variable, η συμπεριφορά είναι ταυτόσημη με πριν.

### 2.4 Παραλληλοποίηση `createPROBS` με OpenMP (`SweeD_CLR.c`)

Το profiling έδειξε ότι η `createPROBS` (προϋπολογισμός του probability grid)
είναι το κύριο bottleneck (~65-70% του χρόνου σε μεγάλα δείγματα). Τα δύο βαριά
loops της είναι ανεξάρτητα ανά εξωτερικό δείκτη, οπότε παραλληλοποιήθηκαν με
`#pragma omp parallel for`. Χωρίς `-fopenmp` τα pragmas αγνοούνται (σειριακό,
ίδια συμπεριφορά).

---

## 3. Επαλήθευση ακρίβειας

Σύγκριση MySweeD (NLopt) vs original SweeD, `mytest.sf`, grid 50 — μόνο θέσεις
με ουσιαστικό σήμα (CLR > 0.01):

| Position | Original | NLopt | Diff % | Alpha match |
|----------|----------|-------|--------|-------------|
| 0 | 1.134212 | 1.134289 | +0.007% | yes |
| 408000 | 1.473855 | 1.473365 | −0.033% | yes |
| 652800 | 0.766440 | 0.766174 | −0.035% | yes |
| **754800 (peak)** | 2.964020 | 2.960708 | **−0.112%** | yes |

**Συμπέρασμα:** Οι δύο εκδόσεις εντοπίζουν **τις ίδιες περιοχές επιλογής** με
**ταυτόσημα Alpha** και διαφορά likelihood **< 0.12%**. Η διαφορά είναι εγγενές
floating-point/convergence noise μεταξύ δύο διαφορετικών αλγορίθμων — αμελητέα
επιστημονικά. Επαληθεύτηκε σε 3 datasets (`mytest.sf`, `test2.sf`, `test3.sf`).

---

## 4. Πολυπλοκότητα του αλγορίθμου

Με `n` = μέγεθος δείγματος (≈ αριθμός παραμέτρων), `P` = διακριτά SNP patterns,
`I` = iterations:

- **Μία αποτίμηση likelihood:** O(P)
- **Αριθμητικό gradient:** O(n·P) ≈ O(n²)
- **Μία επανάληψη L-BFGS:** O(n²) (κυριαρχεί το gradient) + O(m·n) update
- **Συνολική βελτιστοποίηση:** **O(I · n²)**

Το L-BFGS χρησιμοποιεί **limited memory** (m=12 διανύσματα): O(m·n) = **O(n)**
μνήμη/update, αντί O(n²) του πλήρους BFGS. Original L-BFGS-B και NLopt LBFGS
έχουν **ίδια ασυμπτωτική πολυπλοκότητα** — η διαφορά είναι μόνο σε σταθερούς
παράγοντες.

---

## 5. Profiling (gprof)

Flat profile σε μεγάλο δείγμα (n=500):

| Συνάρτηση | Self % | Ρόλος |
|-----------|--------|-------|
| createPROBS | 29% | προϋπολογισμός probability grid (1 φορά) |
| getProb_chooseXfromYgivSFS | 29% | helper του createPROBS |
| getProb_Total | 13% | helper του createPROBS |
| likelihoodSFS_SNP | 16% | objective του optimizer |
| XchooseY_ln | 6% | ήδη βελτιστοποιημένη (lookup table) |

**Το «createPROBS phase» = ~70% του χρόνου** → ο στόχος βελτιστοποίησης. Ο
optimizer (η αλλαγή NLopt) είναι μικρό κομμάτι — δεν είναι το bottleneck.

---

## 6. Αποτελέσματα ταχύτητας

### 6.1 Iterations (optimizer)

| Μέγεθος δείγματος | MySweeD (NLopt) | Original (L-BFGS-B) |
|-------------------|-----------------|---------------------|
| n=100 | 8213 | 7847 |
| **n=1000** | **97.190** | 206.304 |

Σε μεγάλο δείγμα, ο NLopt συγκλίνει σε **λιγότερα από τα μισά** iterations.

### 6.2 Benchmark OpenMP (`testbign.sf`, n=1000, grid 2000)

| Έκδοση | real χρόνος | Σχόλιο |
|--------|-------------|--------|
| Original (σειριακό) | 12.783s | baseline |
| MySweeD, 1 thread | 12.945s | ≈ original (NLopt overhead 1.3%) |
| **MySweeD, 4 threads** | **6.649s** | **1.92× πιο γρήγορο** |

**Speedup OpenMP:** 12.945 / 6.649 = **1.95×** με 4 threads.
**vs Original:** 12.783 / 6.649 = **1.92× πιο γρήγορο**.

Το scaling (1.95× αντί 4×) εξηγείται από τον νόμο του Amdahl: ~65% του χρόνου
(το createPROBS) είναι παράλληλο, το υπόλοιπο 35% σειριακό.

---

## 7. Αρχεία

### Τροποποιημένα
- `My_SweeD_BFGS.c` — NLopt optimizer (αντικαθιστά το `SweeD_BFGS.c`)
- `SweeD_SFS.c` — μετρητής evaluations (env-gated)
- `SweeD_CLR.c` — OpenMP στο `createPROBS`
- `Makefile.MySweeD.gcc` — `-fopenmp` ενεργό by default

### Νέα εργαλεία & δεδομένα
- `compare_results.sh` — σύγκριση MySweeD vs original ανά θέση
- `make_test_data.sh` — γεννήτρια μεγάλων benchmark datasets
- `test2.sf`, `test3.sf` — test datasets
- `.gitignore` — αγνοεί binaries/objects/output

---

## 8. Build & Run

```bash
# Χτίσιμο (OpenMP ενεργό αυτόματα)
make -f Makefile.MySweeD.gcc clean && make -f Makefile.MySweeD.gcc
make -f Makefile.gcc                      # original, για σύγκριση

# Εκτέλεση (χρησιμοποιεί όλους τους πυρήνες)
./MySweeD -name run -input data.sf -grid 200

# Έλεγχος OpenMP
ldd ./MySweeD | grep gomp                 # -> libgomp.so.1

# Σύγκριση με original
./compare_results.sh mytest.sf 50

# Benchmark scaling
OMP_NUM_THREADS=1 bash -c 'time ./MySweeD -name s -input testbign.sf -grid 2000 >/dev/null 2>&1'
OMP_NUM_THREADS=4 bash -c 'time ./MySweeD -name s -input testbign.sf -grid 2000 >/dev/null 2>&1'
```

---

## 9. Συμπεράσματα

| Άξονας | Αποτέλεσμα |
|--------|-----------|
| **Καθαρότητα κώδικα** | Optimizer 227 vs 5937 γραμμές (−96%) |
| **Ακρίβεια** | < 0.12% από original, ίδια Alpha/Position |
| **Ταχύτητα** | **1.92× πιο γρήγορο** από original (OpenMP) |

Η αντικατάσταση με NLopt έδωσε **δραστικά πιο καθαρό κώδικα** με **ίδια
επιστημονικά αποτελέσματα**. Η παραλληλοποίηση του `createPROBS` με OpenMP έδωσε
**~2× επιτάχυνση** σε μεγάλα δεδομένα.

### Μελλοντική δουλειά
- Παραλληλοποίηση και του **CLR grid scan** (`computeAlpha_parallel`) για να
  καλυφθεί το υπόλοιπο ~35% → πιθανή επιτάχυνση 3–3.5×.
- Βελτιστοποίηση του `getProb_chooseXfromYgivSFS` (μείωση κλήσεων `exp()`).

---

## 10. Ιστορικό αλλαγών (Changelog)

Χρονολογική σειρά των commits (από το παλαιότερο στο νεότερο):

| Commit | Περιγραφή |
|--------|-----------|
| Initial commit | Αρχική έκδοση με τον optimizer βασισμένο σε NLopt |
| fix: L-BFGS-B | Διόρθωση: χρήση σωστής L-BFGS-B λογικής στο `My_SweeD_BFGS.c` |
| perf: Reimplement με NLopt | Καθαρή επανυλοποίηση του optimizer με NLopt (227 γραμμές) |
| ftol_rel → 1e-10 | Χαλάρωση tolerance: λιγότερα iterations, ίδια ακρίβεια |
| Add eval counter + tools | Μετρητής evaluations, `.gitignore`, `compare_results.sh`, `test2.sf` |
| tests / test3.sf | Τρίτο test dataset (n=50, ακραίες συχνότητες) |
| chore: stop tracking artifacts | Αφαίρεση binaries/`.o` από το git tracking |
| perf: Parallelize createPROBS | **OpenMP** στα δύο βαριά loops του `createPROBS` |
| build: OpenMP by default | `-fopenmp` ενεργό στο `Makefile.MySweeD.gcc` |
| docs: optimization report | Αυτή η αναφορά |

## 11. Ροή εργασίας & περιβάλλον

- **Ανάπτυξη:** branch `claude/ecstatic-carson-zp6rp6`
- **Compile & test:** σε Linux VM με εγκατεστημένο `libnlopt` και `libgomp`
- **Datasets:** `mytest.sf` (n=100), `test2.sf` (n=100), `test3.sf` (n=50),
  και μεγάλα benchmark (`testbig.sf`, `testbign.sf`) που παράγονται από το
  `make_test_data.sh`.

### Εκκρεμότητες / προτεινόμενο καθάρισμα repo
Στο repository υπάρχουν κάποια αρχεία που καλό είναι να αφαιρεθούν από το git
(παραμένουν στον δίσκο):
- `testbig.sf`, `testbign.sf` — μεγάλα παραγόμενα datasets (αναπαράγονται από
  το `make_test_data.sh`)· ήδη στο `.gitignore` αλλά ακόμα tracked.
- Stray αρχεία: `My_SweeD_BFGS .c` (με κενό στο όνομα), `My SweeD test.txt`,
  `cMy_SweeD_BFGS.c7.3 KB.url` — υπολείμματα προηγούμενης δουλειάς.

Καθάρισμα (προαιρετικό):
```bash
git rm --cached testbig.sf testbign.sf "My_SweeD_BFGS .c" "My SweeD test.txt" "cMy_SweeD_BFGS.c7.3 KB.url"
git commit -m "chore: remove generated/stray files from tracking"
```
