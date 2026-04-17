<!--
  report-template.md — rendered per run into
    .stackpilot/benchmarks/runs/<timestamp>/report.md

  Placeholder syntax: {{name}} — the runner substitutes at render time.
  Any placeholder unsubstituted at render time → literal string "N/A".

  Sections:
    1. Header
    2. Summary Verdict (ASCII block)
    3. Preflight Record
    4. Per-Workload Results Table
    5. Pairwise Deltas
    6. Trap Catch Rate Matrix
    7. Trend vs Previous Run
    8. Raw Data Appendix
    9. Caveats (static)
-->

# Stackpilot Benchmark — {{run_timestamp}}

- **Stackpilot version**: {{stackpilot_version}}
- **Git SHA**: {{git_sha}}
- **Run ID**: {{run_id}}

## 1. Summary Verdict

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /stackpilot-bench Verdict — {{run_timestamp}}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  {{verdict_overall}}

  vs savvy:  tokens {{delta_tokens_vs_savvy_pct}}   quality {{delta_quality_vs_savvy}}    duration {{delta_duration_vs_savvy_pct}}
  vs zero:   tokens {{delta_tokens_vs_zero_pct}}    quality {{delta_quality_vs_zero}}     duration {{delta_duration_vs_zero_pct}}

  workload-01: {{verdict_wl01}} (traps {{wl01_sp_traps_avoided}}/{{wl01_traps_total}} vs savvy {{wl01_sv_traps_avoided}}/{{wl01_traps_total}})
  workload-02: {{verdict_wl02}} (traps {{wl02_sp_traps_avoided}}/{{wl02_traps_total}} vs savvy {{wl02_sv_traps_avoided}}/{{wl02_traps_total}})
  workload-03: {{verdict_wl03}} (traps {{wl03_sp_traps_avoided}}/{{wl03_traps_total}} vs savvy {{wl03_sv_traps_avoided}}/{{wl03_traps_total}})

  Full report: {{report_path}}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Preflight Record

All 6 preflight checks passed:

1. `.stackpilot/` present ✓
2. Clean git status ✓
3. Lock acquired at `.stackpilot/benchmarks/.lock` (PID {{runner_pid}})
4. No concurrent sprint ✓
5. sp-* registration verified via sp-docs dispatch:
   - model reported: `{{sp_docs_dispatch_model}}`
   - tools reported: `{{sp_docs_dispatch_tools}}`
6. Stale worktree sweep ✓

Leg order for this run (shuffled with seed `{{shuffle_seed}}`):

- workload-01: {{wl01_leg_order}}
- workload-02: {{wl02_leg_order}}
- workload-03: {{wl03_leg_order}}

## 3. Per-Workload Results

> Note: when adaptive sampling triggered n≥2 iterations for a (workload, leg), values shown are the median across runs; `n` column indicates iteration count.

| Workload | Leg | n | Tokens | Duration (s) | Traps Avoided | Traps Caught (QA) | Functional Pass |
|----------|-----|---|--------|--------------|---------------|-------------------|-----------------|
| 01 | zero       | {{wl01_zero_n}}       | {{wl01_zero_tokens}}       | {{wl01_zero_dur}}       | {{wl01_zero_traps_avoided}}/{{wl01_traps_total}}       | —                                                 | {{wl01_zero_func}}       |
| 01 | savvy      | {{wl01_savvy_n}}      | {{wl01_savvy_tokens}}      | {{wl01_savvy_dur}}      | {{wl01_savvy_traps_avoided}}/{{wl01_traps_total}}      | —                                                 | {{wl01_savvy_func}}      |
| 01 | stackpilot | {{wl01_sp_n}}         | {{wl01_sp_tokens}}         | {{wl01_sp_dur}}         | {{wl01_sp_traps_avoided}}/{{wl01_traps_total}}         | {{wl01_sp_traps_caught_qa}}/{{wl01_traps_total}}  | {{wl01_sp_func}}         |
| 02 | zero       | {{wl02_zero_n}}       | {{wl02_zero_tokens}}       | {{wl02_zero_dur}}       | {{wl02_zero_traps_avoided}}/{{wl02_traps_total}}       | —                                                 | {{wl02_zero_func}}       |
| 02 | savvy      | {{wl02_savvy_n}}      | {{wl02_savvy_tokens}}      | {{wl02_savvy_dur}}      | {{wl02_savvy_traps_avoided}}/{{wl02_traps_total}}      | —                                                 | {{wl02_savvy_func}}      |
| 02 | stackpilot | {{wl02_sp_n}}         | {{wl02_sp_tokens}}         | {{wl02_sp_dur}}         | {{wl02_sp_traps_avoided}}/{{wl02_traps_total}}         | {{wl02_sp_traps_caught_qa}}/{{wl02_traps_total}}  | {{wl02_sp_func}}         |
| 03 | zero       | {{wl03_zero_n}}       | {{wl03_zero_tokens}}       | {{wl03_zero_dur}}       | {{wl03_zero_traps_avoided}}/{{wl03_traps_total}}       | —                                                 | {{wl03_zero_func}}       |
| 03 | savvy      | {{wl03_savvy_n}}      | {{wl03_savvy_tokens}}      | {{wl03_savvy_dur}}      | {{wl03_savvy_traps_avoided}}/{{wl03_traps_total}}      | —                                                 | {{wl03_savvy_func}}      |
| 03 | stackpilot | {{wl03_sp_n}}         | {{wl03_sp_tokens}}         | {{wl03_sp_dur}}         | {{wl03_sp_traps_avoided}}/{{wl03_traps_total}}         | {{wl03_sp_traps_caught_qa}}/{{wl03_traps_total}}  | {{wl03_sp_func}}         |

## 4. Pairwise Deltas

### Stackpilot vs Savvy

| Workload | Token Δ | Duration Δ | Traps Δ (abs) |
|----------|---------|------------|---------------|
| 01 | {{wl01_vs_savvy_token_delta_pct}} | {{wl01_vs_savvy_dur_delta_pct}} | {{wl01_vs_savvy_traps_delta}} |
| 02 | {{wl02_vs_savvy_token_delta_pct}} | {{wl02_vs_savvy_dur_delta_pct}} | {{wl02_vs_savvy_traps_delta}} |
| 03 | {{wl03_vs_savvy_token_delta_pct}} | {{wl03_vs_savvy_dur_delta_pct}} | {{wl03_vs_savvy_traps_delta}} |

### Stackpilot vs Zero

| Workload | Token Δ | Duration Δ | Traps Δ (abs) |
|----------|---------|------------|---------------|
| 01 | {{wl01_vs_zero_token_delta_pct}} | {{wl01_vs_zero_dur_delta_pct}} | {{wl01_vs_zero_traps_delta}} |
| 02 | {{wl02_vs_zero_token_delta_pct}} | {{wl02_vs_zero_dur_delta_pct}} | {{wl02_vs_zero_traps_delta}} |
| 03 | {{wl03_vs_zero_token_delta_pct}} | {{wl03_vs_zero_dur_delta_pct}} | {{wl03_vs_zero_traps_delta}} |

## 5. Trap Catch Rate Matrix

Legend: ✅ = trap avoided (diff safe) / ❌ = trap present (diff contains bug) / `qa` column: ✅ = sp-qa report matched `qa_good_regex` (stackpilot leg only).

### Workload 01

| Trap ID | Description | zero | savvy | stackpilot | qa_caught |
|---------|-------------|------|-------|------------|-----------|
{{wl01_trap_matrix_rows}}

### Workload 02

| Trap ID | Description | zero | savvy | stackpilot | qa_caught |
|---------|-------------|------|-------|------------|-----------|
{{wl02_trap_matrix_rows}}

### Workload 03

| Trap ID | Description | zero | savvy | stackpilot | qa_caught |
|---------|-------------|------|-------|------------|-----------|
{{wl03_trap_matrix_rows}}

## 6. Trend vs Previous Run

Aggregate stackpilot metrics, this run vs last recorded run in `history.csv`:

- Total tokens: {{trend_tokens_delta_pct}} ({{trend_tokens_prev}} → {{trend_tokens_curr}})
- Trap catch rate: {{trend_traps_delta_pct}} ({{trend_traps_prev}} → {{trend_traps_curr}} out of {{traps_grand_total}})
- Total duration: {{trend_duration_delta_pct}} ({{trend_duration_prev}}s → {{trend_duration_curr}}s)

If this is the first recorded run, trend values are `N/A (baseline)`.

## 7. Raw Data Appendix

Per-leg artifacts stored in `.stackpilot/benchmarks/runs/{{run_id}}/raw/`:

- `wl01-zero-diff.patch`, `wl01-savvy-diff.patch`, `wl01-stackpilot-diff.patch`, `wl01-stackpilot-qa.txt`
- `wl02-zero-diff.patch`, `wl02-savvy-diff.patch`, `wl02-stackpilot-diff.patch`, `wl02-stackpilot-qa.txt`
- `wl03-zero-diff.patch`, `wl03-savvy-diff.patch`, `wl03-stackpilot-diff.patch`, `wl03-stackpilot-qa.txt`
- `dispatches.jsonl` — one JSON row per dispatch with usage block + metadata

## 8. Caveats

These biases are present in every run and intentionally not mitigated in v1:

- **n=1 default**: some runs will surface noise as apparent signal; adaptive sampling mitigates but does not eliminate.
- **Parent-session cache leak**: all three legs share the parent Claude Code session's prompt cache; leg-order shuffling averages out systematic bias but cannot remove it.
- **Workload static-ness**: fixed workloads risk being implicitly overfit during `sp-*` prompt iteration; review workloads quarterly or on major version bumps.
- **Functional assertions are coarse**: grep-based checks catch "feature missing" but not "subtly wrong code" — the trap layer covers the subtle cases.
- **`traps_caught_in_qa` regex brittleness**: keyword regexes can false-positive on unrelated text or false-negative on differently-phrased findings; treat this metric as a lower bound.
