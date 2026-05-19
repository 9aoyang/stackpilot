# Stackpilot Bench Scorecard

**Date:** {{RUN_TS}}  
**Stackpilot version:** {{STACKPILOT_VERSION}}  
**Verdict:** {{VERDICT}}

## Headline

{{HEADLINE_LINE}}

> Three-way comparison: `zero` (native one-shot) vs `stackpilot-serial` (v1.10.0 equivalent) vs `stackpilot` (v1.11.0 with parallel waves + criteria gate + state.json).

## Per-Workload Decision Guide

### Workload 01 — regional-billing-ledger-cutover

| Leg | Composite | Quality | Tokens | Duration |
|-----|-----------|---------|--------|----------|
| Native zero | {{wl01_zero_composite}} | {{wl01_zero_quality}} | {{wl01_zero_tokens}} | {{wl01_zero_duration}} |
| Stackpilot serial | {{wl01_sps_composite}} | {{wl01_sps_quality}} | {{wl01_sps_tokens}} | {{wl01_sps_duration}} |
| Stackpilot parallel | {{wl01_sp_composite}} | {{wl01_sp_quality}} | {{wl01_sp_tokens}} | {{wl01_sp_duration}} |

- Parallel speedup: {{wl01_parallel_speedup_pct}} ({{wl01_parallel_verdict}})
- Verdict: {{wl01_verdict}}

### Workload 02 — sprint-parallel-features

| Leg | Composite | Quality | Tokens | Duration |
|-----|-----------|---------|--------|----------|
| Native zero | {{wl02_zero_composite}} | {{wl02_zero_quality}} | {{wl02_zero_tokens}} | {{wl02_zero_duration}} |
| Stackpilot serial | {{wl02_sps_composite}} | {{wl02_sps_quality}} | {{wl02_sps_tokens}} | {{wl02_sps_duration}} |
| Stackpilot parallel | {{wl02_sp_composite}} | {{wl02_sp_quality}} | {{wl02_sp_tokens}} | {{wl02_sp_duration}} |

- Parallel speedup: {{wl02_parallel_speedup_pct}} ({{wl02_parallel_verdict}})
- Verdict: {{wl02_verdict}}

### Workload 03 — adversarial-gates

| Leg | Composite | Quality | Tokens | Duration |
|-----|-----------|---------|--------|----------|
| Native zero | {{wl03_zero_composite}} | {{wl03_zero_quality}} | {{wl03_zero_tokens}} | {{wl03_zero_duration}} |
| Stackpilot serial | {{wl03_sps_composite}} | {{wl03_sps_quality}} | {{wl03_sps_tokens}} | {{wl03_sps_duration}} |
| Stackpilot parallel | {{wl03_sp_composite}} | {{wl03_sp_quality}} | {{wl03_sp_tokens}} | {{wl03_sp_duration}} |

- Gate correctness: {{wl03_sp_gate_correctness}} (expected: 3/3 for stackpilot, 0/3 for stackpilot-serial)
- Verdict: {{wl03_verdict}}

## Lifecycle Gates (workloads with gate_traps)

| Workload | Gate 1 (criteria) | Gate 2 (CHANGELOG) | Gate 3 (Pattern Candidates) |
|----------|-------------------|--------------------|-----------------------------|
| 03 | {{wl03_gate1}} | {{wl03_gate2}} | {{wl03_gate3}} |

## Final Composite

Overall stackpilot composite: **{{OVERALL_SP_COMPOSITE}}**  
Overall stackpilot-serial composite: **{{OVERALL_SPS_COMPOSITE}}**  
Overall zero composite: **{{OVERALL_ZERO_COMPOSITE}}**

Lift of stackpilot vs zero: **{{LIFT_VS_ZERO}}**  
Lift of stackpilot vs stackpilot-serial: **{{LIFT_VS_SERIAL}}**
