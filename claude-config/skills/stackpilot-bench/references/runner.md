# Runner Protocol — v2

> Operational protocol for `compute-scorecard.sh`, `compute-verdict.sh`, `run-codex-bench.sh`, `run-leg-codex.sh`. Describes three-leg main execution loop, user-response injection, gate-trap evaluation, and CSV row construction. SKILL.md is the high-level entrypoint; this file has the exact algorithm.

## Three legs

| Leg | Dispatch | Config override in `<worktree>/stackpilot.config.yml` |
|-----|----------|-------------------------------------------------------|
| `zero` | `Agent(general-purpose, PREAMBLE + prose-from-plan)` | none |
| `stackpilot-serial` | Main agent drives `/stackpilot` | `qa.max_parallel: 1`, `qa.disable_criteria_gate: true`, `qa.disable_state_json: true` |
| `stackpilot` | Main agent drives `/stackpilot` | defaults (v1.11.0) |

## Leg order shuffle

Deterministic 3-leg permutation seeded from `md5(RUN_TS)`. 6 possible permutations.

## Per-leg flow

For each `leg` in shuffled order:

1. **Config write** (stackpilot-serial only): write the 3 override keys; capture original first.
2. **Reset worktree to sandbox fixture** via `reset-worktree.sh`.
3. **Record LEG_START** wall-clock.
4. **Dispatch leg**:
   - `zero`: Agent call with general-purpose
   - `stackpilot-serial` / `stackpilot`: main agent drives full `/stackpilot` against `plan.yml` with PREAMBLE pointing to bench-sandbox/
5. **Inject user responses** (stackpilot legs): scan `user-responses.yml` `responses[]` in declaration order; first-match-wins by `prompt_contains` substring; submit `answer`. 60s no-match timeout → `status=gate_timeout`.
6. **Compute LEG_DUR**.
7. **Capture scoped diff** from `LEG_START_SHA`, restricted to `bench-sandbox/`.
8. **Run trap assertions** against the diff.
9. **Run gate-trap evaluation** (stackpilot only): parse Sprint Finish output; for each `gate_traps[]`, check `expected_signal_regex` against output; count `triggered / expected` → `gate_correctness`.
10. **Run functional assertions and verification commands** from `traps.yml`.
11. **Recovery measurement** (opt-in workloads): SIGKILL leg at mid-sprint checkpoint, restart, measure state.json resume accuracy.
12. **Config restore** (stackpilot-serial): restore original `stackpilot.config.yml`.
13. **Accumulate row in memory** with 26 CSV columns.

## CSV row construction

26 columns (20 v1 + 6 v2). v2 column order appended after v1:

```
... 20 v1 columns ..., leg_config, sprint_total_tasks, sprint_waves, gate_correctness, parallel_speedup_pct, criteria_coverage_pct
```

`leg_config` literal values: `zero`, `serial`, `parallel`.

Null fields written as literal `null`.

## User response matching

- Substring containment (`prompt.contains(pattern)`), case-sensitive
- Declaration order traversal — first match wins
- 60s timeout → `status=gate_timeout`
- Authors put more-specific patterns earlier

## Config-file cleanup discipline

CRITICAL: when running `stackpilot-serial`, MUST restore `<worktree>/stackpilot.config.yml` at leg end (success / error / timeout). Otherwise next leg inherits `qa.max_parallel: 1` and parallel speedup is nonsense.

```bash
ORIG_CONFIG=$(cat <worktree>/stackpilot.config.yml)
# ... overrides, dispatch ...
echo "$ORIG_CONFIG" > <worktree>/stackpilot.config.yml
```

## Caveats

- **Cache contamination**: 3 legs share parent session cache. Leg shuffle mitigates but doesn't eliminate.
- **n=1 default**: noisy. Adaptive sampling (inherited) mitigates near-threshold pairs.
- **`<usage>` parsing fragility**: same as v1.
