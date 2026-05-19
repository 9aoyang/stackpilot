# Scoring Model — v2

> Authoritative weight table consumed by `compute-scorecard.sh`. The scorecard answers: **is stackpilot worth using over native zero-shot?** Verdict (`compute-verdict.sh`) is a complementary regression-tracking view.

## 9 dimensions

| # | Dimension | Weight | Direction | Formula | Legs eligible |
|---|-----------|--------|-----------|---------|---------------|
| 1 | Correctness | 0.20 | higher | `functional_pass + diff_quality_score / 2` | all three |
| 2 | Over-engineering resistance | 0.10 | higher | `traps_avoided_in_diff / traps_total` | all three |
| 3 | Bug catch rate | 0.15 | higher | `traps_caught_in_qa / traps_total` | stackpilot, stackpilot-serial |
| 4 | Token efficiency | 0.10 | higher | `1 - leg.tokens / median(zero.tokens)` | all three |
| 5 | Wall-clock speed | 0.10 | higher | `1 - leg.duration / median(zero.duration)` | all three |
| 6 | **Parallel speedup** (NEW) | 0.10 | higher | `(stackpilot-serial.duration - stackpilot.duration) / stackpilot-serial.duration` | stackpilot vs stackpilot-serial |
| 7 | **Gate correctness** (NEW) | 0.10 | higher | `triggered_gates / expected_gates` from `gate_traps[]` | stackpilot only |
| 8 | **Recovery success** (NEW) | 0.05 | higher | mid-sprint SIGKILL → restart → state.json resume accuracy | stackpilot only |
| 9 | **Criteria coverage** (NEW) | 0.10 | higher | `criteria_marked_green / criteria_total` from `<feature>-criteria.md` | stackpilot only |

**Weights sum:** 0.20 + 0.10 + 0.15 + 0.10 + 0.10 + 0.10 + 0.10 + 0.05 + 0.10 = **1.000** (exact).

## N/A handling

Dimension N/A rules — when a dimension is not measurable for a row, it is excluded from that leg's composite and remaining dimension weights are re-normalized proportionally.

| Dimension | N/A condition |
|-----------|---------------|
| 6 Parallel speedup | Only valid when both `stackpilot-serial` AND `stackpilot` rows present, both `status=ok`, AND `sprint_waves >= 2`. Otherwise `N/A — single-wave workload` or `N/A — comparison leg incomplete`. |
| 7 Gate correctness | N/A for `zero` and `stackpilot-serial` legs by construction (no Sprint Finish gates). N/A for workloads with no `gate_traps[]` declared. |
| 8 Recovery success | N/A unless workload declares `recovery_test: true`. Stackpilot-leg only. |
| 9 Criteria coverage | N/A for `zero` leg. N/A for `stackpilot-serial` leg (criteria gate disabled by config). |

## CSV column names

The 6 new columns appended to v1's 20-column schema (total 26):

- `leg_config` — literal string `zero` / `serial` / `parallel`
- `sprint_total_tasks` — count of tasks in workload's `plan.yml`
- `sprint_waves` — count of dependency waves
- `gate_correctness` — fraction (0.0 to 1.0)
- `parallel_speedup_pct` — percentage as float (can be negative)
- `criteria_coverage_pct` — percentage (0 to 100)

**CSV header has 26 columns total** (20 v1 + 6 v2). The spec section 3 mistakenly says 27; v1 header is 20 (not 21). Sprint Finish will fix the spec at completion.

## Discrimination check

Inherited from v1: any workload where `zero` leg's composite > 90 is marked `🚫 NON-DISCRIMINATIVE` and excluded from overall composite. If all workloads are non-discriminative, headline reads `INCONCLUSIVE`. Threshold tunable via `DISCRIMINATION_THRESHOLD` env var (default 90).

## Single-wave edge case

When `sprint_waves=1` for a workload, parallel and serial legs run the same code path. Parallel speedup is reported as `N/A — single-wave workload` and excluded from that workload's composite.

## Leg-agnostic formula design

Formulas are over rows, not legs. The leg is a row-filter. e.g. `parallel_speedup_pct` joins two rows (stackpilot-serial + stackpilot) for the same workload; the formula doesn't branch on "if leg == X".
