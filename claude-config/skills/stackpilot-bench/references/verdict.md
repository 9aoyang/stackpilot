# Verdict Rules & Computation

Reference: `.stackpilot/specs/2026-04-17-stackpilot-bench-design.md` (Verdict Rules and Adaptive Sampling sections).

Used by `compute-verdict.sh` to evaluate each run and produce the final verdict block printed to stdout.

---

## Threshold Configuration

All verdict thresholds defined in one place for easy tuning:

```
SAVVY_COST_MULT = 3              # stackpilot cost ≤ 3× savvy cost
ZERO_COST_MULT = 5               # stackpilot cost ≤ 5× zero cost
POSITIVE_REGRESSION_THRESHOLD = 0.20   # >20% token growth vs history = regression
MARGINAL_DEGRADATION_BAND = 0.05..0.20  # 5–20% = marginal
```

---

## Per-Workload Pairwise Verdicts

For each workload, two separate verdicts are computed:

### pipeline_PASS_vs_savvy(workload)

Verdict is **PASS** iff ALL three conditions hold:

```
stackpilot.traps_avoided_in_diff + 0.5 * stackpilot.traps_caught_in_qa
  >= savvy.traps_avoided_in_diff
  AND
stackpilot.functional_pass == true
  AND
stackpilot.total_tokens <= SAVVY_COST_MULT * savvy.total_tokens
```

The quality term counts bugs sp-qa catches even when the dev diff already
contains them: a catch is worth half an avoidance (caught-after-the-fact is
still a win, but strictly less valuable than never writing the bug). Savvy/zero
legs have no QA phase so their quality term is just `traps_avoided_in_diff`.

**Rationale**: the pipeline must not cost >3× the savvy baseline while
delivering at least equal effective quality and complete functional correctness.
Without the `traps_caught_in_qa` term, sp-qa improvements produced no verdict
signal — catching a bug looked identical to never catching it.

### pipeline_PASS_vs_zero(workload)

Verdict is **PASS** iff ALL three conditions hold:

```
stackpilot.traps_avoided_in_diff + 0.5 * stackpilot.traps_caught_in_qa
  >= zero.traps_avoided_in_diff
  AND
stackpilot.functional_pass == true
  AND
stackpilot.total_tokens <= ZERO_COST_MULT * zero.total_tokens
```

**Rationale**: A more lenient bar (5× cost) to confirm the pipeline provides value over raw unassisted Claude, even if it underperforms vs a prompt-savvy user.

---

## Overall Run Verdict

Computed after all per-workload verdicts are ready. Three states:

### POSITIVE OPTIMIZATION

All three conditions:

```
1. All 3 workloads pass pipeline_PASS_vs_savvy
2. Aggregate stackpilot total_tokens <= (1 + POSITIVE_REGRESSION_THRESHOLD) * previous_run_median_tokens
3. Aggregate traps_caught did not shrink vs previous run
```

Interpretation: stackpilot improved or held steady on all dimensions.

### MARGINAL

Pairwise rules satisfied (all workloads PASS vs savvy), but:

```
Token growth or trap catch reduction between MARGINAL_DEGRADATION_BAND[0] and [1]
(i.e., 5–20% worse than previous run on either metric)
```

Interpretation: acceptable degradation; iterate if possible but not a blocker for release.

### NEGATIVE OPTIMIZATION

Any of:

```
1. At least one workload fails pipeline_PASS_vs_savvy
2. Aggregate token growth > 20% vs previous run
3. Aggregate trap catch rate dropped > 20% vs previous run
```

Interpretation: regression detected; investigate before release.

---

## First Run (No History)

When `.stackpilot/benchmarks/history.csv` is empty or does not exist:

- **Per-workload verdicts**: compute and display normally (only using the current run's three legs).
- **Overall run verdict**: output **"BASELINE ESTABLISHED"** instead of POSITIVE / MARGINAL / NEGATIVE.
- **Regression comparison**: skip (no prior run to compare against).

---

## Worked Example

### Input: Three-Workload Run with Made-Up Numbers

Run timestamp: `2026-04-17-1430`  
Fixture SHAs: `abc1234` (all workloads)

History median (prior 3 runs):
- All workloads, stackpilot leg, total_tokens: 8500
- Aggregate traps_caught: 13/15 (86.7%)

Current run raw results:

| Workload | Leg | traps_total | traps_avoided | traps_caught_in_qa | functional_pass | total_tokens | duration_sec |
|----------|-----|-------------|---------------|-------------------|-----------------|--------------|--------------|
| 01-trap-heavy-bash | zero | 5 | 1 | N/A | true | 2400 | 45 |
| 01-trap-heavy-bash | savvy | 5 | 3 | N/A | true | 5800 | 120 |
| 01-trap-heavy-bash | stackpilot | 5 | 4 | 4 | true | 9200 | 180 |
| 02-doc-consistency | zero | 4 | 0 | N/A | false | 1800 | 35 |
| 02-doc-consistency | savvy | 4 | 4 | N/A | true | 4200 | 95 |
| 02-doc-consistency | stackpilot | 4 | 4 | 4 | true | 9800 | 165 |
| 03-cross-file-refactor | zero | 4 | 1 | N/A | false | 2100 | 42 |
| 03-cross-file-refactor | savvy | 4 | 3 | N/A | true | 6500 | 140 |
| 03-cross-file-refactor | stackpilot | 4 | 4 | 3 | true | 10200 | 175 |

**Aggregate for current run stackpilot leg**: 28200 tokens, 12/15 traps caught.

### Pairwise Verdict Computation

#### Workload 01: trap-heavy-bash

```
pipeline_PASS_vs_savvy:
  stackpilot.traps_avoided (4) >= savvy.traps_avoided (3)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (9200) <= 3 * savvy.total_tokens (5800 * 3 = 17400)  ✓
  → PASS
```

```
pipeline_PASS_vs_zero:
  stackpilot.traps_avoided (4) >= zero.traps_avoided (1)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (9200) <= 5 * zero.total_tokens (2400 * 5 = 12000)  ✓
  → PASS
```

#### Workload 02: doc-consistency

```
pipeline_PASS_vs_savvy:
  stackpilot.traps_avoided (4) >= savvy.traps_avoided (4)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (9800) <= 3 * savvy.total_tokens (4200 * 3 = 12600)  ✓
  → PASS
```

```
pipeline_PASS_vs_zero:
  stackpilot.traps_avoided (4) >= zero.traps_avoided (0)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (9800) <= 5 * zero.total_tokens (1800 * 5 = 9000)  ✗
  → FAIL (overspends vs zero baseline)
```

#### Workload 03: cross-file-refactor

```
pipeline_PASS_vs_savvy:
  stackpilot.traps_avoided (4) >= savvy.traps_avoided (3)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (10200) <= 3 * savvy.total_tokens (6500 * 3 = 19500)  ✓
  → PASS
```

```
pipeline_PASS_vs_zero:
  stackpilot.traps_avoided (4) >= zero.traps_avoided (1)  ✓
  stackpilot.functional_pass (true) == true  ✓
  stackpilot.total_tokens (10200) <= 5 * zero.total_tokens (2100 * 5 = 10500)  ✓
  → PASS
```

### Overall Verdict Computation

Check conditions for **POSITIVE OPTIMIZATION**:

```
1. All 3 workloads PASS vs savvy:  01=PASS, 02=PASS, 03=PASS  ✓
2. Aggregate token growth check:
   Current: 28200 tokens
   History median: 8500 tokens × 3 workloads = 25500 tokens
   Growth: (28200 - 25500) / 25500 = 10.6%
   Is 10.6% <= 20% ?  ✓
3. Aggregate traps_caught:
   Current: 12/15 (80%)
   History: 13/15 (86.7%)
   Shrink: 86.7% - 80% = 6.7% drop
   Did not shrink vs previous ?  ✗ (it did shrink)
```

Condition 1 passes, condition 2 passes, condition 3 **fails**.

Check **MARGINAL**:

```
Pairwise rules satisfied?  YES (all workloads PASS vs savvy)
Token or trap degradation in 5–20% band?
  Token growth: 10.6% (within 5–20%)  ✓
  Trap drop: 6.7% (within 5–20%)  ✓
  → MARGINAL
```

### Final Verdict Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /stackpilot-bench Verdict — 2026-04-17 14:30
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  MARGINAL ⚠️

  vs savvy:  tokens +7.8%   quality +0    duration -15%
  vs zero:   tokens +2.7x   quality +3    duration +1.5x

  workload-01: PASS (traps 4/5 vs savvy 3/5)
  workload-02: PASS (traps 4/4 vs savvy 4/4)
  workload-03: PASS (traps 4/4 vs savvy 3/4)

  Full report: .stackpilot/benchmarks/runs/2026-04-17-1430/report.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Why MARGINAL and not NEGATIVE?** Trap catch rate shrank by 6.7% (within the 5–20% marginal band) and all pairwise verdicts passed vs savvy. No workload failed the quality gate.

---

## Output Format

The verdict block is printed to stdout at the end of a successful run. Format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /stackpilot-bench Verdict — <ISO date> <HH:MM>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  <VERDICT_STATE> <EMOJI>

  vs savvy:  tokens <±percent>   quality <+/- count>    duration <±percent>
  vs zero:   tokens <multiplier>x   quality <+/- count>    duration <±multiplier>x

  workload-01: <PASS|FAIL> (traps <stackpilot_count>/<total> vs savvy <savvy_count>/<total>)
  workload-02: <PASS|FAIL> (traps <stackpilot_count>/<total> vs savvy <savvy_count>/<total>)
  workload-03: <PASS|FAIL> (traps <stackpilot_count>/<total> vs savvy <savvy_count>/<total>)

  Full report: <path to runs/<timestamp>/report.md>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Fields**:

- `<VERDICT_STATE>`: one of `POSITIVE OPTIMIZATION` / `MARGINAL` / `NEGATIVE OPTIMIZATION` / `BASELINE ESTABLISHED`.
- `<EMOJI>`: `✅` for POSITIVE, `⚠️` for MARGINAL, `❌` for NEGATIVE, `🎯` for BASELINE.
- `vs savvy / vs zero`: computed as `(stackpilot - baseline) / baseline * 100%` for percentage deltas; as `stackpilot / baseline` for cost multipliers.
- `quality` field: change in `traps_avoided_in_diff` count, not percentage.
- Workload line: shows per-workload verdict and trap counts. `<total>` is `traps_total` for that workload.
