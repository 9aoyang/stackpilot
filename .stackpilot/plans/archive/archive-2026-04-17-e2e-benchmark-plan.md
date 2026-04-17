# Plan: End-to-End Stackpilot Benchmark (10 tasks)

**Execution model**: main agent runs this plan directly — **do NOT dispatch tasks to sp-dev / sp-qa etc.** This plan IS the benchmark; running sub-agents IS the measurement. Main agent reads each task, executes the described action, captures the measurement, and at the end writes a report to `docs/benchmarks/`.

**Goal**: quantify the real-world impact of the registration fix (commit 7958460) on per-sprint cost, latency, and quality, using identical workload on two pipelines (new sp-* vs old general-purpose + inline).

**Do not skip the baseline parse (TASK-B01)**. Without it we have no reference.

## Target workload (fake but realistic)

Feature under test: `add --verbose flag to scripts/init.sh that echoes each detected file check and the matched framework`. Small, 3-4 files, deterministic, safe to throw away.

## Output artifact

`docs/benchmarks/YYYY-MM-DD-e2e-report.md` — markdown report with the comparison tables and conclusions.

---

## Task List

### TASK-B01

- title: Parse TasteNet baseline from session history
- description: Read `~/.claude/projects/-Users-gaoyang-Documents-github-TasteNet/ea419122*.jsonl` (the largest real stackpilot session, 79 dispatches). Compute: total wall-clock duration, total tokens (input+output+cache_read+cache_creation), agent dispatch count by subagent_type, `[CRITICAL]`/`[SOFT-BLOCKED]`/`[ESCALATION]` signals in assistant text. Store these as the "Old Pipeline Baseline" row of the report table.
- type: research
- complexity: light
- depends_on: []
- relevant_files:
  - docs/benchmarks/YYYY-MM-DD-e2e-report.md

### TASK-B02

- title: Confirm sp-* agents are registered in this session
- description: Before any dispatch, sanity-check: spawn a cheap `sp-docs` dispatch with a trivial no-op prompt ("reply: registered"). If the call errors with "Agent type 'sp-docs' not found", abort the benchmark and tell the user to re-install (install.sh) and restart Claude Code. If it succeeds, record model + tools reported by sp-docs in the report's "Registration Verified" block.
- type: research
- complexity: light
- depends_on: [TASK-B01]
- relevant_files: []

### TASK-B03

- title: Create a fresh git worktree for the benchmark feature
- description: `git worktree add .worktrees/benchmark-verbose-flag -b bench/verbose-flag main`. All sprint work happens there — prevents polluting the main repo. Capture `git rev-parse HEAD` as the pre-task SHA for later diff measurement.
- type: setup
- complexity: light
- depends_on: [TASK-B02]
- relevant_files:
  - .worktrees/benchmark-verbose-flag

### TASK-B04

- title: Run the fake sprint through the NEW pipeline (sp-*)
- description: In the benchmark worktree, execute a mini /stackpilot sprint for the verbose-flag feature. For each sub-agent dispatch (architecture review, implementation, QA), pass explicit `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"`. Capture per-dispatch: subagent_type used, tokens from the `<usage>` block in the tool result, duration_ms, tool_uses count. Also record the output signals (`[CRITICAL]`, `[SOFT-BLOCKED]`, Pattern Candidates surfaced, Decision Candidates surfaced). Store as "New Pipeline" row.
- type: benchmark
- complexity: standard
- depends_on: [TASK-B03]
- relevant_files:
  - .worktrees/benchmark-verbose-flag/scripts/init.sh

### TASK-B05

- title: Reset worktree, run the same sprint through the OLD pipeline (general-purpose + inline)
- description: `git -C .worktrees/benchmark-verbose-flag reset --hard <pre-task SHA from TASK-B03>` to clean state. Re-run the identical sprint but use `subagent_type="general-purpose"` for every dispatch AND inline the full methodology text from `~/.claude/agents/sp-*.md` into each Agent() prompt parameter (read those files fresh to ensure you inject what's current). Same measurement capture as TASK-B04. Store as "Old Pipeline" row.
- type: benchmark
- complexity: standard
- depends_on: [TASK-B04]
- relevant_files:
  - .worktrees/benchmark-verbose-flag/scripts/init.sh

### TASK-B06

- title: Compute per-dispatch deltas
- description: For each of architecture / dev / QA phases, compute: tokens_new ÷ tokens_old, duration_new ÷ duration_old. Report as three rows (one per phase) with the ratio expressed as "Xx cheaper / Yx faster" or "Zx more expensive" if worse. Add an "Overall sprint" row summing all dispatches.
- type: analysis
- complexity: light
- depends_on: [TASK-B04, TASK-B05]
- relevant_files:
  - docs/benchmarks/YYYY-MM-DD-e2e-report.md

### TASK-B07

- title: Quality comparison — findings, accuracy, risk rating
- description: Read both pipelines' sp-qa output blocks. Count distinct Critical / Important findings each reported. For each finding, verify against the actual diff whether it's (a) a real bug, (b) a real style/convention issue, or (c) a hallucination (no evidence in the diff). Report accuracy percentages per pipeline. If sp-architect output is present, check whether the risk rating has a Justification line (new contract) and whether at least one concrete failure mode was enumerated before the rating.
- type: analysis
- complexity: standard
- depends_on: [TASK-B04, TASK-B05]
- relevant_files:
  - docs/benchmarks/YYYY-MM-DD-e2e-report.md

### TASK-B08

- title: Cross-check against the TasteNet baseline (TASK-B01)
- description: Scale-normalize the benchmark data to TasteNet scale. If TasteNet did 79 dispatches in 495 min / 100M tokens, what would those numbers look like if every dispatch had been via the new pipeline? Report: projected tokens saved per year (assume 50 sprints × 10 dispatches avg), projected wall-clock saved. Call out that this is a projection, not observed.
- type: analysis
- complexity: light
- depends_on: [TASK-B06]
- relevant_files:
  - docs/benchmarks/YYYY-MM-DD-e2e-report.md

### TASK-B09

- title: Write the final benchmark report
- description: Write `docs/benchmarks/YYYY-MM-DD-e2e-report.md` (replace date) with sections: Summary (3-bullet headline numbers) / Methodology / Registration Verification (TASK-B02 output) / Per-phase deltas (TASK-B06 table) / Quality comparison (TASK-B07 table) / Projected impact (TASK-B08 math) / Caveats (n=1 sprint, worktree isolation, fake feature not real project) / Raw data appendix (copy of the captured tokens/duration/signals). Under 1500 words.
- type: docs
- complexity: light
- depends_on: [TASK-B06, TASK-B07, TASK-B08]
- relevant_files:
  - docs/benchmarks/YYYY-MM-DD-e2e-report.md

### TASK-B10

- title: Clean up worktree and branch
- description: `git worktree remove .worktrees/benchmark-verbose-flag --force` then `git branch -D bench/verbose-flag`. Confirm `.worktrees/` is empty or doesn't exist. Confirm the benchmark feature branch is gone. The benchmark report stays in `docs/benchmarks/`.
- type: cleanup
- complexity: light
- depends_on: [TASK-B09]
- relevant_files:
  - .worktrees
