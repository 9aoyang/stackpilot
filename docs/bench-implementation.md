# /stackpilot-bench Implementation Notes

> **Updated 2026-05-19 for stackpilot-bench v2.** The bench is now three-legged (`zero` / `stackpilot-serial` / `stackpilot`) with 26-column CSV schema, multi-task workload `plan.yml`, scripted `user-responses.yml`, and `gate_traps[]` for testing Sprint Finish Step 0.5 gate triggering. v1 history is preserved at `.stackpilot/benchmarks/history.csv.bak-v1-2026-05-18` but not used by v2 verdict. The sections below describe both v2 (current) and v1 (historical reference).

## v2 — what's new (2026-05-18)

### Three legs, not two

- `zero` — native Claude one-shot; unchanged from v1.
- `stackpilot-serial` — main agent drives the full `/stackpilot` pipeline, but with `qa.max_parallel=1` + `qa.disable_criteria_gate=true` + `qa.disable_state_json=true` injected into the bench worktree's `stackpilot.config.yml`. Semantically equivalent to v1.10.0 (no parallel waves, no criteria gate, no state.json).
- `stackpilot` — main agent drives the full `/stackpilot` pipeline with v1.11.0 defaults (parallel waves + criteria gate + state.json all active).

The dropped v1 `savvy` leg is gone. `stackpilot-serial` semantically replaces it as "the prior version of the same pipeline."

### 26-column CSV schema

v1 had 20 columns. v2 adds 6:

- `leg_config` — literal `zero` / `serial` / `parallel`
- `sprint_total_tasks` — count of tasks in workload's `plan.yml`
- `sprint_waves` — count of dependency waves (1 means no parallelism possible)
- `gate_correctness` — fraction of expected gate_traps that fired (stackpilot leg only)
- `parallel_speedup_pct` — (serial_duration - parallel_duration) / serial_duration × 100
- `criteria_coverage_pct` — % of acceptance criteria marked green by sp-qa

The spec said 27 columns; the actual header is 26 (v1 had 20, not 21 as v1 docs claimed — a long-standing doc discrepancy now corrected).

### Multi-task workload schema

Each workload now contains:

- `plan.yml` — sprint plan with one or more tasks, each having `id` / `title` / `description` / `type` / `complexity` / `depends_on` / `relevant_files`. Wave analysis (topological sort over `depends_on`) determines parallel dispatch order.
- `traps.yml` — existing diff-trap schema, plus a new `gate_traps:` top-level key (for workloads testing Sprint Finish gates).
- `user-responses.yml` — list of `{prompt_contains, answer}` entries. Stackpilot legs use first-match-wins substring matching to auto-answer CONFIRM-GATE prompts. 60-second no-match timeout → `status=gate_timeout`.

### New scoring dimensions (4 added, 9 total)

Inherited from v1: Correctness, Over-engineering resistance, Bug catch rate, Token efficiency, Wall-clock speed.

New in v2:

- **Parallel speedup** (weight 0.10) — `stackpilot-serial.duration / stackpilot.duration` per workload, only when `sprint_waves >= 2`.
- **Gate correctness** (weight 0.10) — `triggered_gates / expected_gates` from `gate_traps[]`, stackpilot leg only.
- **Recovery success** (weight 0.05) — opt-in mid-sprint SIGKILL + restart test, measures state.json resume accuracy.
- **Criteria coverage** (weight 0.10) — `criteria_marked_green / criteria_total` from `<feature>-criteria.md`, stackpilot leg only.

Weights sum to exactly 1.000. See `claude-config/skills/stackpilot-bench/references/scoring.md` for the authoritative table.

### Workloads installed

- `01-regional-billing-ledger-cutover` — single-task baseline, upgraded with `plan.yml` + `user-responses.yml` (existing sandbox + traps.yml + evaluator/ unchanged).
- `02-sprint-parallel-features` — 4 tasks, 2 waves (3 independent in wave 1 + 1 integration test in wave 2). Tests parallel speedup with 3 disjoint subsystem files.
- `03-adversarial-gates` — 3 tasks, no diff-traps; verdict driven by `gate_traps` targeting all three Sprint Finish Step 0.5 gates (Gate 1 criteria-not-green, Gate 2 CHANGELOG-missing-scope, Gate 3 Pattern-Candidates-pending).

### v1 limitations — status

Marked **resolved** by v2:
- ✅ "No workloads installed" — 3 workloads in v2.
- ✅ "Cannot measure parallel orchestration" — `stackpilot-serial` vs `stackpilot` legs make parallel speedup mechanically observable.
- ✅ "Cannot measure lifecycle gates" — `gate_traps` evaluation triggered against Sprint Finish output.
- ✅ "No cross-version comparison" — config-comparison achieves the same goal without git checkout.

Still present:
- Cache contamination across legs (worse with 3 legs than 2).
- `<usage>` parsing fragility.
- n=1 default with adaptive sampling (no true statistical CIs).
- Trap regex brittleness.

### v2.1 backlog

- Statistical confidence intervals on verdict.
- Per-project workloads under `.stackpilot/bench-workloads/`.
- Trap regex testing harness.
- Headless mode default-on (currently scaffolded but optional).

---

## v1 (historical reference)

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

### 3. Main loop — 1 workload × 2 legs (per-leg flow)

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

**(b) Dispatch the leg.** Two mechanisms:

| Leg | Mechanism |
|---|---|
| `zero` | `Agent(subagent_type="general-purpose", prompt=PREAMBLE+ZERO_PROMPT)` |
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

`compute-scorecard.sh history.csv $RUN_TS` reads the CSV, compares stackpilot against the available native baseline (currently zero), and prints the score/time-first markdown scorecard.

Then: release lock, remove worktree, delete bench branch.

---

## Three key design tricks

1. **bench-sandbox/ subdirectory isolation.** Workloads operate inside a throwaway subdir, not the worktree root. The rest of the worktree retains main's files (CLAUDE.md, claude-config/, .stackpilot/) so sub-agents have project context.

2. **leg-start commit + scoped diff.** Each reset creates a fresh commit representing "fixture installed, agent hasn't touched anything yet". `git diff <leg_start_sha> -- bench-sandbox/` then shows ONLY the agent's edits, not the fixture install churn.

3. **Working-directory preamble.** Sub-agents don't inherit cwd context, so the orchestrator manually prepends a working-directory hint to every dispatch prompt.

---

## Workload selection error (2026-04-20 post-mortem)

This section exists so the next person designing workloads — or the next
Claude session optimising `/stackpilot` — does not repeat the mistake.

### What happened

On 2026-04-20 the bench was re-run for the first time after the v2
scorecard transformation (M1-M6) and the sp-\* prompt reshape. Three
fresh workloads had just been installed — `01-stripe-invoice-api`
(simple API route), `02-rate-limit-middleware` (3-file middleware),
`03-moment-to-datefns-refactor` (mechanical cross-file refactor).

The scorecard came back "stackpilot 明显落后" (overall -16 vs savvy):

```
Correctness         100 vs 100   +0
Over-eng resist      98 vs  98   +0
Bug catch rate      N/A vs  78
Token efficiency     96 vs  53  -43
Wall-clock speed     94 vs  34  -61
```

`stackpilot` was 1.9× more expensive and 2.7× slower than `savvy`, with
zero quality advantage in diff-trap counts. Looked like a clear "the
overhead doesn't pay".

### Why the result was misleading

The conclusion is wrong because the workloads were the wrong benchmark:

1. **Zero leg already scored 97.** Native Claude 4.7 given a one-line
   prompt like `"Add rate limiting to middleware/auth.ts"` writes clean,
   scope-bounded code and avoided 12/13 traps unprompted. The ceiling
   was near-saturated before `/stackpilot` got involved.
2. **`/stackpilot` is explicitly invoked**, not auto-routed. A user
   types `/stackpilot` precisely when they've judged the task is
   beyond one-shot — ambiguous scope, cross-system risk, dual-write,
   etc. The tasks in the 2026-04-20 workloads were clear specifications
   with a single right answer. Real users would not have invoked
   `/stackpilot` for them. Measuring `/stackpilot`'s cost on those
   tasks answers a question nobody asked.
3. **sp-qa caught real CRITICAL issues** on W02 (race condition
   between `redis.incr` and `redis.expire` that would silently lock
   users out permanently) and W03 (week-start spec-vs-behavior
   conflict). These are exactly the kinds of findings `/stackpilot`
   exists to produce. But because the diff itself was fine, the
   scorecard's Bug Catch dimension (weight 0.15) was not enough to
   overcome the token / speed dimensions (combined weight 0.25).

The bench was testing the tool at a job it's not designed for, and
unsurprisingly it failed at that job.

### Mechanical guard added (same day)

`compute-scorecard.sh` now runs a **discrimination check**: any
workload where the zero leg's composite score exceeds
`DISCRIMINATION_THRESHOLD` (default 90) is marked
`🚫 NON-DISCRIMINATIVE` and excluded from the overall composite.
If every workload trips the check, the headline reads
`INCONCLUSIVE — all workloads are NON-DISCRIMINATIVE`, not a
false-negative verdict. See `references/scoring.md § Discrimination
check`.

### Rules for workload design (derived from this post-mortem)

When designing a new workload, it **must** satisfy both before it's
accepted:

1. **"Would I actually type /stackpilot for this prompt?"** If the
   prompt can be answered by directly pasting into Claude, it's not a
   stackpilot workload. Real stackpilot invocations are at least one
   of: ambiguous scope, dual-write / migration hazards, cross-system
   risk, real codebase with conventions to obey, hard-to-detect
   regressions.

2. **The fixture must be substantial enough to need reading, not just
   a toy skeleton.** If sp-architect can derive the right answer
   without `Read`-ing multiple files, the task is too small.

Concrete heuristics that correlate with discrimination power:

- Fixture ≥ 15 files with real (non-stub) logic.
- Prompt under-specifies at least one load-bearing decision.
- At least one trap that only fires when the agent **fails to ask**
  (e.g., "assumed all existing users get 'free' plan without a
  backfill question").
- At least one trap that requires reading an existing convention file
  (CLAUDE.md / prior patterns) to recognise.

The first-cut v1 workloads (deleted 27f1838) and the second-cut v2
workloads (2026-04-20) both violated these rules — different sizes,
same failure mode. The discrimination check is the mechanical
safeguard; these design rules are the human one.

### What replaced them

The v3 workloads installed after this post-mortem still saturated current
Codex zero-shot. The active v4 replacement is a single ultimate workload:

- `01-regional-billing-ledger-cutover` — regional billing ledger migration
  with hidden contracts across docs, tests, and source. It tests API response
  compatibility, idempotent ledger writes, PII redaction, dual-write rollback,
  cursor backfill, reconciliation, and avoiding deprecated helpers.

The bench no longer runs `savvy`; it tests the actual adoption decision:
native zero-shot versus explicit `/stackpilot`.

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
