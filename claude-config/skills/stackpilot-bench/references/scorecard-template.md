<!--
  scorecard-template.md — rendered per run into
    .stackpilot/benchmarks/runs/<timestamp>/scorecard.md

  Placeholder syntax: {{name}} — the runner substitutes at render time.
  Any placeholder unsubstituted at render time → literal string "N/A".

  Sections:
    1. Header
    2. ASCII scorecard block (from compute-scorecard.sh stdout)
    3. Per-workload decision guide
    4. Raw-data appendix
    5. Caveats
-->

# Stackpilot vs Native Claude Code — Scorecard ({{run_timestamp}})

- **Stackpilot version**: {{stackpilot_version}}
- **Git SHA**: {{git_sha}}
- **Run ID**: {{run_id}}
- **Sample size**: n={{sample_n}} per (workload, leg)

## 1. Scorecard

```
{{scorecard_block}}
```

## 2. How to read this

The question this scorecard answers is "should I use stackpilot for my
work, or is native Claude Code enough?" The answer is generally not "yes"
or "no" uniformly — it depends on the workload.

- **Quality dimensions** (correctness, over-engineering resistance, bug
  catch rate) drive 75% of the composite. Stackpilot's thesis is that the
  orchestration overhead buys more quality than it costs.
- **Cost dimensions** (token efficiency, wall-clock speed) drive 25% of
  the composite and are scored *relatively* within each workload — the
  cheapest leg scores 100.
- **Per-workload breakdown** (§3) is where the nuance lives. A positive
  overall score masks workloads where native wins. Those are the cases
  where you should skip stackpilot.

## 3. Per-workload decision guide

| Workload | Complexity | Savvy | Stackpilot | Recommendation |
|---|---|---:|---:|---|
| {{wl01_id}} | {{wl01_complexity}} | {{wl01_savvy_score}} | {{wl01_stackpilot_score}} | {{wl01_recommendation}} |
| {{wl02_id}} | {{wl02_complexity}} | {{wl02_savvy_score}} | {{wl02_stackpilot_score}} | {{wl02_recommendation}} |
| {{wl03_id}} | {{wl03_complexity}} | {{wl03_savvy_score}} | {{wl03_stackpilot_score}} | {{wl03_recommendation}} |

**Recommendation values**:
- `use-stackpilot` — stackpilot wins by >5 composite points; overhead pays off
- `either-works` — within ±5 points; choose by personal preference / cost sensitivity
- `skip-stackpilot` — native savvy wins by >5 points; orchestration overhead not worth it

## 4. Raw data

Per-leg artefacts stored in `.stackpilot/benchmarks/runs/{{run_id}}/raw/`:

- `wl*-zero-diff.patch`, `wl*-savvy-diff.patch`, `wl*-stackpilot-diff.patch`
- `wl*-stackpilot-qa.txt` (sp-qa report per workload)
- `rows.csv` (this run's CSV rows only)

Full history: `.stackpilot/benchmarks/history.csv`.

## 5. Caveats

Scores in this scorecard inherit the biases documented in
`references/scoring.md § Known Biases`:

- n=1 default + adaptive n=3 on near-boundary pairs — not a full statistical
  sample
- Parent-session cache leak leaks between legs (pre-M4)
- Trap regexes are conservative lower bounds, not precise measurements
- Workload static-ness risks prompt overfit over time — rotate workloads
  quarterly

**Single-run scores are directional, not authoritative.** Trend across
multiple runs (via `history.csv`) is the more reliable signal.
