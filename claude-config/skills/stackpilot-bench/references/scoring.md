# Scorecard Scoring Model

How `compute-scorecard.sh` turns CSV rows into a stackpilot-vs-native
performance scorecard. The scorecard answers **"is stackpilot worth using
over native Claude Code?"**, which is a different question from the verdict
block's "did the last change regress?".

If you only want to understand the final numbers, read §Dimensions and
§Composite Score. §Rationale and §Known Biases are for anyone tuning the
model or debating the weights.

---

## Output shape

```
STACKPILOT vs NATIVE Claude Code — Performance Scorecard
════════════════════════════════════════════════════════
run: <ts>  |  n=<sample> per leg  |  workloads: <count>

OVERALL SCORE       Native Savvy  Stackpilot    Δ
                         62            87      +25 (stackpilot +40%)

DIMENSIONS (0-100)  Native Savvy  Stackpilot    Δ
  Correctness           75             95      +20
  Over-eng resist       45             92      +47  ★★
  Bug catch rate        N/A            88       —
  Token efficiency      95             55      -40  ★
  Wall-clock speed      90             62      -28

PER-WORKLOAD (stackpilot vs savvy)
  W01 simple           savvy 85 | stackpilot 78   -7   ⚠️ 开销不回本
  W02 medium           savvy 50 | stackpilot 91  +41   ✓
  W03 complex          savvy 42 | stackpilot 93  +51   ✓✓

FLOOR BASELINE (native zero-shot prompt): 35  (unassisted Claude)
HEADLINE: ✅ stackpilot 显著领先
```

---

## Dimensions

Each leg gets 0-100 scores on 5 dimensions:

### 1. Correctness
```
score = 100 if functional_pass else 0
```
Averaged across workloads. This is the stop-the-world dimension: a leg that
doesn't actually produce working code gets 0, dragging the overall down.

### 2. Over-engineering resistance
```
score = 100 * traps_avoided_in_diff / traps_total
```
Fraction of workload traps that were *not* tripped in the final diff. Traps in
M3 workloads are deliberately designed around the over-engineering behaviours
Anthropic has publicly acknowledged in Claude Opus 4.5/4.6 — unrequested retry
logic, extra abstraction layers, prophylactic try/catch, unprompted
comments, scope-creep refactoring. A high score here means the leg stayed
within the task's scope.

Future: when `traps.yml` carries `category: over-engineering | correctness |
security`, this score narrows to the over-engineering subset and the
correctness traps feed a separate dimension. Until then, treat this as a
unified "stayed in scope" score.

### 3. Bug catch rate (stackpilot-only)
```
score = 100 * traps_caught_in_qa / traps_total
```
Only defined for the stackpilot leg because savvy/zero legs have no QA phase.
This dimension exposes sp-qa's value: catching bugs that would have shipped.
Since v1 bench entirely ignored this, any improvement to sp-qa used to be
invisible — the scorecard now makes the signal first-class.

### 4. Token efficiency
```
score = 100 * min_tokens_in_workload / this_leg_tokens
```
Relative within the same workload. The cheapest leg scores 100, others scale
down proportionally. This is NOT an absolute cost score — comparing raw token
counts across wildly different workloads is meaningless. Averaging the
per-workload relative scores gives a cost dimension that's invariant to
workload size.

### 5. Wall-clock speed
Same relative-scoring formula as token efficiency, but on `duration_sec`.

Bound to end-to-end dispatch time. In headless mode (M4) this becomes
subprocess wall-clock; currently it's the main-agent observation of the
`Agent()` call.

---

## Composite score

```
overall = Σ (dimension_score × weight) / Σ weight_of_available_dimensions
```

Default weights:

| Dimension | Weight | Rationale |
|-----------|-------:|-----------|
| Correctness       | 0.30 | Incorrect code is worthless regardless of speed |
| Over-eng resist   | 0.30 | stackpilot's core claim; must be measurable |
| Bug catch rate    | 0.15 | Unique to stackpilot; N/A for native legs auto-reweights |
| Token efficiency  | 0.15 | Real cost, but not the primary question users are asking |
| Wall-clock speed  | 0.10 | Matters but generally less than cost |

**Quality dimensions = 0.75 of total**, cost dimensions = 0.25. This encodes
the prior that a typical user considering stackpilot is asking "does it make
my outputs better" more than "does it save me money".

To tune: edit `WEIGHTS` in `compute-scorecard.sh` until a config-file loader
lands. Changes should be committed so history stays interpretable.

**N/A handling**: the savvy and zero legs have no `bug_catch` dimension. The
formula above automatically reweights — their overall is computed across the
4 defined dimensions only. This avoids penalising native legs for a
capability they structurally lack.

---

## Per-workload composite

Same weighted formula applied per workload. The per-workload table in the
scorecard shows:
- ⚠️ "开销不回本" when stackpilot scores >5 points below savvy
- ✓ when stackpilot wins by 5-15
- ✓✓ when stackpilot wins by >15

These thresholds surface the "stackpilot is worth it for complex work but
overkill for simple changes" pattern that normally hides in averages.

---

## Rationale — why this shape and not something else

**Why not a single number?** Because stackpilot's value profile is
non-uniform: it wins on quality, loses on cost. Collapsing that to a single
score hides the decision criterion (use it when? skip it when?). The
scorecard deliberately keeps quality/cost split so the tradeoff is visible.

**Why relative normalisation for cost?** Comparing absolute tokens across
workloads conflates "stackpilot is 3× more expensive" with "workload 3 is
3× bigger than workload 1". Relative scoring removes the workload-size
confounding, at the cost of losing absolute magnitude information (available
in the raw CSV).

**Why equal weight between over-eng and correctness?** Anthropic officially
acknowledges Claude Opus 4.5/4.6 over-engineers by default; FeatBench 2025
showed 73.6% of coding-agent failures are scope creep / regressive
implementation. Giving over-engineering resistance the same weight as
functional correctness matches the empirical bug distribution, rather than
optimistically assuming correctness is the only failure mode.

**Why 0.5 weight for bug_catch vs 1.0 for over-eng_resist?** Catching a bug
in review is less valuable than never writing it (fix cost, churn, cognitive
load, etc.). The verdict formula uses the same 0.5 multiplier for the same
reason.

---

## Discrimination check

A workload is **NON-DISCRIMINATIVE** when native-zero composite scores above
`DISCRIMINATION_THRESHOLD` (default 90). Meaning: Claude 4.7 handles the
task zero-shot well enough that the stackpilot pipeline has no headroom
to earn back its overhead. Including such workloads in the overall
composite is selection-bias — real users do not invoke `/stackpilot` for
tasks this simple, so scoring the tool on those tasks answers the wrong
question.

Behaviour:

- Per-workload: flagged with `🚫 NON-DISCRIMINATIVE` in the per-workload
  table. Data is kept in the CSV and the table so the bias is visible.
- Overall composite: computed over the discriminative subset only.
- If ALL workloads are non-discriminative: the overall falls back to
  all-workload aggregates, and the headline reads `INCONCLUSIVE — all
  workloads are NON-DISCRIMINATIVE` with a recommendation to design
  harder workloads.

This check is the mechanical version of the 2026-04-20 lesson recorded
in `docs/bench-implementation.md § Workload selection error`: small
well-specified tasks don't discriminate, because Claude 4.7 does them
correctly on a one-line prompt. Testing `/stackpilot` on those tasks
benchmarks it at a job it's not designed for.

## Known biases (same as verdict — scorecard inherits all of them)

- **n=1 default** — single-run numbers fluctuate; adaptive sampling gives
  n=3 near-boundary pairs. The scorecard shows `n=<sample>` in its header.
- **Parent-session cache leak** — in v1 all legs share the main Claude Code
  session's prompt cache; leg-order shuffling mitigates but doesn't
  eliminate. Fixed in M4 (headless subprocess mode).
- **Workload design bias** — the trap set is finite and known; iterative
  stackpilot tuning can overfit to it. Rotate workloads quarterly.
- **Regex trap brittleness** — `diff_bad_regex` can false-positive on
  benign mentions or false-negative on differently-phrased problems. Treat
  any single trap signal as a lower bound, not a measurement.

The scorecard amplifies these biases because its per-dimension presentation
looks authoritative. The `n=<sample>` header is the least you should read
before citing a score.
