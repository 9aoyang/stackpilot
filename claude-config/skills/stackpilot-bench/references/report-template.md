# Bench Run Report

Generated: {{RUN_TS}}  
Git SHA: {{GIT_SHA}}  
Stackpilot version: {{STACKPILOT_VERSION}}  
Verdict: **{{VERDICT}}**

## 1. Preflight

- sp-docs probe: model={{PREFLIGHT_SP_DOCS_MODEL}}, tools={{PREFLIGHT_SP_DOCS_TOOLS}}
- Leg order per workload: {{LEG_ORDER_WL01}} / {{LEG_ORDER_WL02}} / {{LEG_ORDER_WL03}}
- Three-leg config:
  - `zero`: native one-shot
  - `stackpilot-serial`: max_parallel=1 + criteria gate disabled + state.json disabled
  - `stackpilot`: v1.11.0 defaults

## 2. Per-Workload Scores (composite)

| Workload | zero | stackpilot-serial | stackpilot | Verdict |
|----------|------|-------------------|------------|---------|
| 01 regional-billing | {{wl01_zero_composite}} | {{wl01_sps_composite}} | {{wl01_sp_composite}} | {{wl01_verdict}} |
| 02 parallel-features | {{wl02_zero_composite}} | {{wl02_sps_composite}} | {{wl02_sp_composite}} | {{wl02_verdict}} |
| 03 adversarial-gates | {{wl03_zero_composite}} | {{wl03_sps_composite}} | {{wl03_sp_composite}} | {{wl03_verdict}} |

## 3. Per-Dimension Breakdown (stackpilot leg)

| Dim | 01 | 02 | 03 |
|-----|-----|-----|-----|
| Correctness | {{wl01_sp_correctness}} | {{wl02_sp_correctness}} | {{wl03_sp_correctness}} |
| Over-eng resistance | {{wl01_sp_overeng}} | {{wl02_sp_overeng}} | {{wl03_sp_overeng}} |
| Bug catch rate | {{wl01_sp_bugcatch}} | {{wl02_sp_bugcatch}} | {{wl03_sp_bugcatch}} |
| Token efficiency | {{wl01_sp_tokeneff}} | {{wl02_sp_tokeneff}} | {{wl03_sp_tokeneff}} |
| Wall-clock speed | {{wl01_sp_speed}} | {{wl02_sp_speed}} | {{wl03_sp_speed}} |
| Parallel speedup | {{wl01_parallel_speedup_pct}} | {{wl02_parallel_speedup_pct}} | {{wl03_parallel_speedup_pct}} |
| Gate correctness | {{wl01_sp_gate_correctness}} | {{wl02_sp_gate_correctness}} | {{wl03_sp_gate_correctness}} |
| Recovery success | {{wl01_sp_recovery_success}} | {{wl02_sp_recovery_success}} | {{wl03_sp_recovery_success}} |
| Criteria coverage | {{wl01_sp_criteria_coverage_pct}} | {{wl02_sp_criteria_coverage_pct}} | {{wl03_sp_criteria_coverage_pct}} |

## 4. Pairwise Deltas

```
{{PAIRWISE_DELTAS_BLOCK}}
```

## 5. Sprint Lifecycle Metrics

| Workload | tasks | waves | gate_correctness | criteria_coverage_pct | recovery_success |
|----------|-------|-------|------------------|----------------------|------------------|
| 01 | {{wl01_sprint_total_tasks}} | {{wl01_sprint_waves}} | {{wl01_sp_gate_correctness}} | {{wl01_sp_criteria_coverage_pct}} | {{wl01_sp_recovery_success}} |
| 02 | {{wl02_sprint_total_tasks}} | {{wl02_sprint_waves}} | {{wl02_sp_gate_correctness}} | {{wl02_sp_criteria_coverage_pct}} | {{wl02_sp_recovery_success}} |
| 03 | {{wl03_sprint_total_tasks}} | {{wl03_sprint_waves}} | {{wl03_sp_gate_correctness}} | {{wl03_sp_criteria_coverage_pct}} | {{wl03_sp_recovery_success}} |

## 6. Parallel Speedup

| Workload | serial_duration | parallel_duration | speedup_pct | verdict |
|----------|-----------------|-------------------|-------------|---------|
| 01 | {{wl01_sps_duration}} | {{wl01_sp_duration}} | {{wl01_parallel_speedup_pct}} | {{wl01_parallel_verdict}} |
| 02 | {{wl02_sps_duration}} | {{wl02_sp_duration}} | {{wl02_parallel_speedup_pct}} | {{wl02_parallel_verdict}} |
| 03 | {{wl03_sps_duration}} | {{wl03_sp_duration}} | {{wl03_parallel_speedup_pct}} | {{wl03_parallel_verdict}} |

## 7. Rows

Full per-leg data: [{{ROWS_CSV_PATH}}]({{ROWS_CSV_PATH}})

---

> Placeholder convention: `{{wl<NN>_<short-leg>_<metric>}}` where short-leg ∈ `{zero, sps, sp}`. Workload-level placeholders use `{{wl<NN>_<metric>}}`. Any unsubstituted `{{placeholder}}` renders as literal `N/A`.
