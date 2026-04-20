# Stackpilot Bench Scorecard Template

The primary scorecard is designed for a human who will ask AI for the
interpretation later. It should read like a short decision memo, not like a
CSV export.

## Required Shape

```md
# Stackpilot Bench

Run: `<RUN_TS>` | n=<N> per leg | workloads: <target>/<total>

## Headline

复杂任务建议使用 Stackpilot：质量 +14 分，额外耗时 +45m00s（+54%）。
换算下来，每提升 1 分大约多花 3.2 分钟。

## Overall

Native Zero
质量：★★★☆☆ 51/100
耗时：37m15s（速度 ★★★★★）

Native Savvy
质量：★★★★☆ 77/100
耗时：84m00s（速度 ★★★★☆）

Stackpilot
质量：★★★★★ 91/100
耗时：129m00s（速度 ★★★☆☆）

质量图
Native Savvy  ████████░░ 77/100
Stackpilot    █████████░ 91/100

## Per Workload

W01-subscription-ambiguity (target)
Native Savvy：★★★★☆ 76/100 / 24m20s
Stackpilot： ★★★★★ 91/100 / 39m05s
差异：+15 分，耗时 +14m45s（+61%）
建议：用 Stackpilot

## Diagnostics

- Target workloads: 3
- Native-enough workloads: 1
- Raw rows: `.stackpilot/benchmarks/runs/<RUN_TS>/rows.csv`
- Full history source: `.stackpilot/benchmarks/history.csv`
```

## Formatting Rules

- Start with the decision, not the data table.
- Score means quality only: correctness, trap avoidance, and QA catch signal.
- Always show both score and elapsed time; do not blend time/token cost into
  the displayed score.
- Use five-star quality/velocity summaries for quick reading.
- Use dense tables only in detailed reports, not the first screen.
- Mark native-enough workloads explicitly so Stackpilot is not rewarded on
  simple tasks.

## Data Source

`compute-scorecard.sh` renders the current concrete format directly from
`history.csv`. This template documents the intended report shape and should be
kept aligned with that script.
