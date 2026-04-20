# /stackpilot-bench Implementation Notes

How v1 works, where it's honest about its limits, and what v2 should fix.

This is the **explanation** doc — read this to understand the design.
For the **reference** protocol (exact algorithm), see `claude-config/skills/stackpilot-bench/references/runner.md`.

---

## The mental model

The bench is **not an independent program**. It's a markdown skill (SKILL.md) that the main Claude Code agent reads and executes step by step. Every "step" in the bench is the main agent doing something: running a bash command, dispatching a sub-agent, parsing output, accumulating in-memory state.

That single fact explains most of v1's design choices and most of its limitations.

---

## What happens when you type /stackpilot-bench

### 1. Preflight — 6 checks

- `.stackpilot/` exists (project initialized)
- `git status` clean
- Acquire `.stackpilot/benchmarks/.lock` (PID + timestamp; checks PID liveness so a crashed prior run doesn't permanently block)
- No concurrent /stackpilot sprint
- sp-* agents registered (probe by dispatching `Agent(subagent_type="sp-docs", prompt="reply: registered")`)
- Sweep stale `.worktrees/bench-run/` from prior crashed run

Any failure → abort with a specific error message and release the lock if held.

### 2. Build a bench worktree

```bash
RUN_TS=$(date -u +%Y-%m-%d-%H%M)
git worktree add .worktrees/bench-run -b "bench/run-$RUN_TS" main
git -C .worktrees/bench-run rev-parse HEAD > .worktrees/bench-run/.bench-base-sha
```

The `.bench-base-sha` marker file is what `reset-worktree.sh` reads to know what to reset to.

### 3. Main loop — 3 workloads × 3 legs (per-leg flow)

For each workload, shuffle leg order using `md5(RUN_TS)` as seed (mitigates parent-session cache bias). Then for each leg:

**(a) Reset the sandbox** via `reset-worktree.sh`:

```bash
git -C <worktree> reset --hard <base_sha>     # undo prior leg's edits
git -C <worktree> clean -fdx                   # remove untracked
cp -r workloads/<id>/sandbox/ <worktree>/bench-sandbox/
git -C <worktree> add bench-sandbox/
git -C <worktree> commit --no-verify -m "bench: leg-start fixture"
# stdout: "reset-worktree: OK <leg_start_sha>"
```

The leg-start SHA is the diff base for capturing the agent's edits later.

**(b) Dispatch the leg.** Three different mechanisms:

| Leg | Mechanism |
|---|---|
| `zero` | `Agent(subagent_type="general-purpose", prompt=PREAMBLE+ZERO_PROMPT)` |
| `savvy` | `Agent(subagent_type="general-purpose", prompt=PREAMBLE+SAVVY_PROMPT)` |
| `stackpilot` | Main agent itself runs the full /stackpilot pipeline: write mini spec/plan, dispatch sp-architect (if standard complexity), dispatch sp-dev, dispatch sp-qa |

The PREAMBLE is critical: `"Working directory for this task: .worktrees/bench-run/bench-sandbox/. All file paths below are relative to that directory."` Without it, the sub-agent operates in the main repo's cwd and edits real files.

**(c) Capture metrics from the dispatch result.** Every `Agent(...)` call returns text including a `<usage>` block:

```
<usage>total_tokens: 28949
tool_uses: 10
duration_ms: 85601</usage>
```

Main agent parses this and accumulates it for the row.

**(d) Capture scoped diff:**

```bash
git -C <worktree> diff <leg_start_sha> -- bench-sandbox/
```

The `-- bench-sandbox/` pathspec excludes any stray edits the agent made outside the sandbox (caught by next reset --hard anyway).

**(e) Run assertions.** For each trap in `traps.yml`:
- `check_mode: diff` (default): grep `diff_bad_regex` against the diff
- `check_mode: final_file`: grep against the final content of `bench-sandbox/<check_file>`
- For stackpilot leg only: grep `qa_good_regex` against the sp-qa report text

For each functional_assertion: grep `diff_must_match_regex` against the diff. All must pass for `functional_pass=true`.

**(f) Hold result in memory.** No CSV write yet — Step 4 handles all rows atomically.

### 4. Adaptive sampling (skipped on baseline runs)

If `history.csv` has prior data, compute `|current.tokens - median_prior| / median_prior` per (workload, leg). Any pair where the delta is < 20% triggers 2 more iterations of that pair (so n=3, take median). First-ever run = no history = skip.

### 5. Atomic CSV write + report

```bash
echo "$NEW_ROWS" >> history.csv.tmp
mv history.csv.tmp history.csv
```

The tmp+mv pattern means a crash mid-write leaves the original `history.csv` intact. Then render `runs/<RUN_TS>/report.md` from `references/report-template.md` by substituting `{{placeholders}}`.

### 6. Verdict + cleanup

`compute-verdict.sh history.csv $RUN_TS` reads the CSV, computes per-workload pairwise verdicts (stackpilot vs savvy, stackpilot vs zero), aggregates to overall POSITIVE / MARGINAL / NEGATIVE / BASELINE_ESTABLISHED, prints the ASCII verdict block.

Then: release lock, remove worktree, delete bench branch.

---

## Three key design tricks

1. **bench-sandbox/ subdirectory isolation.** Workloads operate inside a throwaway subdir, not the worktree root. The rest of the worktree retains main's files (CLAUDE.md, claude-config/, .stackpilot/) so sub-agents have project context.

2. **leg-start commit + scoped diff.** Each reset creates a fresh commit representing "fixture installed, agent hasn't touched anything yet". `git diff <leg_start_sha> -- bench-sandbox/` then shows ONLY the agent's edits, not the fixture install churn.

3. **Working-directory preamble.** Sub-agents don't inherit cwd context, so the orchestrator manually prepends a working-directory hint to every dispatch prompt.

---

## v1 known limitations

These are real and intentional trade-offs — listed so v2 work knows what to attack.

### Architectural

- **Main-agent execution model.** The bench protocol runs inside the user's main Claude Code session. Consequences:
  - Token cost is debited from the user's session
  - Parent session's prompt cache leaks across legs (leg-order shuffle mitigates but does not eliminate)
  - Main-agent crash or Ctrl+C kills the run; recovery is via next run's preflight cleanup
  - Cannot run unattended / scheduled
- **Duration is wall-clock around dispatch.** The dispatch's own `duration_ms` (from `<usage>`) is more accurate but the bench currently uses wall clock for the row (sometimes both reported in the report; pick one for v2).

### Verdict formula

- ~~**`compute-verdict.sh` ignores `traps_caught_in_qa`.**~~ **Resolved 2026-04-20.** The verdict quality term is now `stackpilot.traps_avoided_in_diff + 0.5 * stackpilot.traps_caught_in_qa >= baseline.traps_avoided_in_diff`. sp-qa catches count at half-weight (catching-after-the-fact < never-writing-the-bug). See `references/verdict.md` for details.

### Workloads

- **No workloads installed (deleted 2026-04-17).** First-cut workloads were too small to be representative. New workloads pending design — must match real /stackpilot usage scope (multi-file features, cross-system refactors, risky bug fixes). See `.stackpilot/ARCHITECTURE.md`.

### Robustness

- **Trap regex brittleness.** Conservative regexes can false-positive (catch unrelated lines) or false-negative (miss differently-phrased findings). Treat trap counts as a lower bound, not a precise measurement.
- **No isolation between bench runs and ongoing sprints.** Lock file prevents concurrent benches; preflight check 4 prevents bench during active sprint. But that means you can't `/stackpilot-bench` while you're mid-sprint to test "did this sprint's edits regress anything".
- **`<usage>` parsing fragile.** If Anthropic changes the block format, capture breaks silently.

---

## v2 backlog

Ordered roughly by value-per-effort:

1. **Verdict formula counts qa_caught.** ~30 minutes of editing `compute-verdict.sh` and `references/verdict.md`. Highest ROI: without this, every future iteration on sp-qa is invisible to the bench.

2. **Design representative workloads.** A workload set that matches real /stackpilot usage. Candidates:
   - Multi-file feature with API + tests + docs (4-6 files)
   - Cross-system refactor with cascading dependencies
   - Risky bug fix with subtle failure modes (e.g., cache invalidation, concurrency)
   - Each workload should pass the test "would I actually invoke /stackpilot for this?"

3. **Headless execution via `claude --print`.** **Scaffolded 2026-04-20** — see `claude-config/skills/stackpilot-bench/scripts/run-leg-headless.sh` and `references/headless-mode.md`. Not yet wired as SKILL.md default; needs live CLI contract verification + permissions-guard + re-baselining (see `headless-mode.md § Flipping the default`). Expected impact: token efficiency dimension drops 10-25 points for stackpilot, which is the first honest measurement not biased by parent-session cache warmth.

4. **Use dispatch-reported `duration_ms` instead of wall clock.** Cleaner numbers; no clock skew from main-agent overhead.

5. **`--keep` flag** for keeping the worktree post-run (for inspection). Currently you have to comment out the cleanup line in SKILL.md.

6. **Trap regex testing harness.** Run each `diff_bad_regex` against the workload's own sandbox state and assert it does NOT match (proves regex doesn't false-positive on the baseline). Cheap CI-style guard.

7. **Statistical sampling.** Adaptive n=3 is in place but no confidence intervals. v2 could add bootstrap CIs to the verdict to surface "this delta is noise" vs "this delta is real".

8. **Per-project workloads.** Currently workloads are inside the skill (one set for everyone). v2 could let each project define its own workloads under `.stackpilot/bench-workloads/` for project-specific regression catching.

---

## When you (or future-you) iterates on bench

Before starting a v2 task:

1. Read this file's "Known Limitations" section
2. Pick from the v2 backlog (or add a new item)
3. Update this file as v2 work lands — move items from backlog to "Known Limitations → resolved" or just delete

The point is to keep this doc as the single place where bench design state lives. If you find yourself making decisions about bench behavior in conversation that should be persistent, write them here.
