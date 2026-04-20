# Stackpilot Bench

Run: `2026-04-20-1329`  |  n=1 per leg  |  workloads: 0 target / 1 total
Native-enough workloads excluded from target summary: 1

## Headline

这次结果不可作为 Stackpilot 价值判断：所有 workload 都属于 native-enough，原生 zero-shot 已经接近满分。
下一步应该换更复杂的 workload，而不是调 agent prompt。

## Overall

Native Zero
质量：★★★★★ 97/100
耗时：4m21s（速度 ★★★★★）

Stackpilot
质量：★★★★★ 91/100
耗时：5m01s（速度 ★★★★☆）

质量图
Native Zero   ██████████ 97/100
Stackpilot    █████████░ 91/100

## Per Workload

01-regional-billing-ledger-cutover (native enough)
Native Zero：★★★★★ 97/100 / 4m21s
Stackpilot： ★★★★★ 91/100 / 5m01s
差异：-6 分，耗时 +40s（+15%）
建议：不用 Stackpilot

## Diagnostics

- Target workloads: 0
- Native-enough workloads: 1
- Raw rows: `.stackpilot/benchmarks/runs/2026-04-20-1329/rows.csv`
- Full history source: `.stackpilot/benchmarks/history.csv`
────────────────────────────────────────────────────────────────────────
