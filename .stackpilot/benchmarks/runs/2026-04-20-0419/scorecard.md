════════════════════════════════════════════════════════════════
  STACKPILOT vs NATIVE Claude Code — Performance Scorecard
════════════════════════════════════════════════════════════════
  run: 2026-04-20 04:19  |  n=1 per leg  |  workloads: 0/3 (3 NON-DISCRIMINATIVE excluded)

  OVERALL SCORE       Native Savvy  Stackpilot    Δ
                            98             82   -16  (stackpilot -16%)

  DIMENSIONS (0-100)  Native Savvy  Stackpilot    Δ
    Correctness            100            100       +0  
    Over-eng resist         98             98       +0  
    Bug catch rate         N/A             78      N/A  
    Token efficiency        96             53      -43  ★★
    Wall-clock speed        94             34      -61  ★★

  PER-WORKLOAD (stackpilot vs savvy)
    01-stripe-invoice-api     savvy  97  |  stackpilot  80      -16  🚫 NON-DISCRIMINATIVE (zero >90, excluded)
    02-rate-limit-middleware  savvy 100  |  stackpilot  86      -14  🚫 NON-DISCRIMINATIVE (zero >90, excluded)
    03-moment-to-datefns-refactor  savvy  97  |  stackpilot  81      -17  🚫 NON-DISCRIMINATIVE (zero >90, excluded)

  FLOOR BASELINE (native zero-shot prompt):    97  (unassisted Claude)

  HEADLINE: ⚠️  INCONCLUSIVE — all workloads are NON-DISCRIMINATIVE.
            Native zero scored >90 on every workload, meaning the
            tasks are too simple for /stackpilot to have a reason to
            run. Design harder workloads and re-bench before drawing
            conclusions from this report.

  RAW DATA: .stackpilot/benchmarks/runs/2026-04-20-0419/rows.csv
════════════════════════════════════════════════════════════════
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /stackpilot-bench Verdict — 2026-04-20 04:19
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  BASELINE ESTABLISHED 🎯

  vs savvy:  tokens +86.4%   quality +0    duration +200.4%
  vs zero:   tokens 1.9x   quality +1    duration 2.7x

  01-stripe-invoice-api: PASS (traps 11/11 vs savvy 11/11)
  02-rate-limit-middleware: PASS (traps 13/13 vs savvy 13/13)
  03-moment-to-datefns-refactor: PASS (traps 14/15 vs savvy 14/15)

  Full report: .stackpilot/benchmarks/runs/2026-04-20-0419/report.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
