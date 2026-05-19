# Workload 02 — Sprint Parallel Features

**Purpose:** Stress-test parallel wave dispatch. 4 tasks, 2 waves, wave 1 has 3 fully-independent tasks with disjoint `relevant_files`.

**Expected outcome:** the `stackpilot` leg completes wave 1 in roughly one-third the time of `stackpilot-serial`. The Parallel speedup dimension scores high.

## Topology

```
TASK-001 (wave 1, no deps) → pricingQuote endpoint
TASK-002 (wave 1, no deps) → shippingEstimate endpoint
TASK-003 (wave 1, no deps) → inventoryCheck endpoint
TASK-004 (wave 2, deps 1+2+3) → integration test that calls all three
```

## Design properties

- Wave 1 `relevant_files` are **disjoint** — no shared barrel file or shared types module. Worktree merges trivially.
- Each wave-1 task is structurally identical (implement a pure function reading a local table) so wall-clock per task is approximately equal — keeps the parallel-speedup measurement statistically valid.
- Sandbox is hermetic per ARCHITECTURE.md (no references to real repo files).
- Workload is not adversarial — no `gate_traps`. Diff-traps are minimal (only catch obvious anti-patterns like console.log left in).

## Verdict input

- `parallel_speedup_pct` = `(stackpilot-serial.duration_sec - stackpilot.duration_sec) / stackpilot-serial.duration_sec * 100`
- `sprint_waves` = 2
- `sprint_total_tasks` = 4
- evaluator runs after each leg to confirm all 4 endpoints respond and the integration test passes.
