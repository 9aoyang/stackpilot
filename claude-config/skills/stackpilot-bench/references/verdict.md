# Verdict Model — v2

> Regression-tracking verdict computed by `compute-verdict.sh`. POSITIVE / MARGINAL / NEGATIVE call used during iterative tuning.

## Three legs

v1 had `zero` vs `stackpilot` (and historically `savvy`). v2 has three legs:

- `zero` — native one-shot baseline
- `stackpilot-serial` — equivalent to v1.10.0 (max_parallel=1, criteria gate disabled, state.json disabled)
- `stackpilot` — v1.11.0 with all mechanisms enabled

The savvy leg is dropped. The `stackpilot-serial` leg semantically replaces it as "the prior version of the same pipeline."

## Pairwise checks

For each workload:

1. **`pipeline_PASS_vs_zero(stackpilot)`** — same semantics as v1: stackpilot quality ≥ zero quality AND stackpilot cost ≤ 5× zero cost.
2. **`pipeline_PASS_vs_zero(stackpilot-serial)`** — same formula on stackpilot-serial leg.
3. **`parallel_vs_serial(workload)`** — NEW per-workload check:
   - `stackpilot.duration_sec ≤ stackpilot-serial.duration_sec × 0.9` (parallel must be ≥ 10% faster)
   - AND `stackpilot.quality ≥ stackpilot-serial.quality` (no quality regression)
   - PASS = parallel speedup observed without quality loss.

## Quality term

```
quality = traps_avoided_in_diff + 0.5 × traps_caught_in_qa
```

## Overall verdict

- **POSITIVE** — all workloads PASS vs zero AND all `parallel_vs_serial` PASS AND token regression within band (< 5%).
- **MARGINAL** — pairwise rules satisfied but parallel speedup < 10% OR token drift 5-20% OR any INCOMPLETE workload.
- **NEGATIVE** — any workload fails vs zero OR parallel speedup negative OR token regression > 20%.

## INCOMPLETE workload override

A workload with any leg `status=timed_out` / `error` / `orchestration_invalid` is marked INCOMPLETE. If all complete workloads would be POSITIVE, overall collapses to MARGINAL.

## Gate correctness as auxiliary signal

`gate_correctness` is surfaced in the verdict block but NOT a gate condition itself. Stackpilot-leg only, fixture-specific. Render as `gate-fire: 3/3` info, not PASS/FAIL.

## Worked example

```
Workload: 02-sprint-parallel-features
  zero leg:               duration=180s  quality=12.0  status=ok
  stackpilot-serial leg:  duration=240s  quality=14.5  status=ok
  stackpilot leg:         duration=85s   quality=14.0  status=ok

Pairwise:
  pipeline_PASS_vs_zero(stackpilot):        14.0 >= 12.0 ✓; cost 85s vs 180s OK ✓ → PASS
  pipeline_PASS_vs_zero(stackpilot-serial): 14.5 >= 12.0 ✓; cost 240s vs 180s OK ✓ → PASS
  parallel_vs_serial:                       85s ≤ 240s × 0.9 (216s) ✓; 14.0 ≥ 14.5? NO → MARGINAL

Workload verdict: MARGINAL — parallel-speedup ok, but small quality regression in parallel mode
```

## Removed from v1

- All `savvy` leg comparisons (no `savvy` leg in v2)
- `pipeline_PASS_vs_savvy` term
