---
name: stackpilot-bench
description: Continuous quantitative benchmark for stackpilot. Runs two-legged comparison (native zero / stackpilot) against one high-discrimination workload, writes CSV time series and scorecard report. Use when you want to know whether stackpilot creates quality lift over native Codex/Claude on tasks that actually warrant orchestration.
---

# /stackpilot-bench

## Overview

`/stackpilot-bench` runs a repeatable, two-legged benchmark comparing native zero-shot usage against the full stackpilot pipeline. Each run dispatches `zero` and `stackpilot` against one high-discrimination workload, collects token cost, wall-clock duration, trap-catch rate, and functional correctness signals, then appends one row per leg to `.stackpilot/benchmarks/history.csv` and writes a markdown scorecard. The question is: **does stackpilot create quality lift over native zero-shot on a task that actually warrants orchestration?**

## Codex Runtime

When this skill is invoked from Codex, use the Codex headless runner instead of the Claude `Agent(...)` protocol:

```bash
bash claude-config/skills/stackpilot-bench/scripts/run-codex-bench.sh
```

The Codex runner uses `codex exec --json --ephemeral` for each leg, keeps edits scoped to the disposable `bench-sandbox/` worktree, writes raw artifacts under `.stackpilot/benchmarks/runs/<timestamp>/raw/`, appends rows to `.stackpilot/benchmarks/history.csv`, and renders `.stackpilot/benchmarks/runs/<timestamp>/scorecard.md`.

For a targeted diagnostic run, use:

```bash
bash claude-config/skills/stackpilot-bench/scripts/run-codex-bench.sh --workload <id> --leg <zero|stackpilot> --no-history
```

The `--no-history` mode is for smoke diagnostics only; full benchmark runs should append to history so future AI-assisted analysis has a durable time series.

---

## Step 0 — Preflight

Run all six checks below before creating a worktree or dispatching any workload. If any check fails, abort immediately with the specified message and do not proceed.

### Check 1 — Stackpilot-initialized project

Run:

```bash
ls .stackpilot/
```

If the `.stackpilot/` directory does not exist, abort:

> `run /stackpilot first to initialize this project`

### Check 2 — Clean git state

Run:

```bash
git status --porcelain
```

If the output is non-empty (any staged, unstaged, or untracked files are present), abort:

> `commit or stash changes before running benchmark`

### Check 3 — Acquire run lock

The lock file is `.stackpilot/benchmarks/.lock`. Its contents when written are: `<PID> <ISO-8601 timestamp>` (e.g., `12345 2026-04-17T14:30:00Z`).

Steps:

1. Ensure the `.stackpilot/benchmarks/` directory exists:

   ```bash
   mkdir -p .stackpilot/benchmarks
   ```

2. Check if `.stackpilot/benchmarks/.lock` exists.

3. If the lock file exists, read the PID from its first field:

   ```bash
   LOCK_PID=$(awk '{print $1}' .stackpilot/benchmarks/.lock)
   ```

   Then test whether that process is still alive:

   ```bash
   kill -0 "$LOCK_PID" 2>/dev/null && echo "alive" || echo "dead"
   ```

   - If the PID is **alive**: abort with:

     > `another benchmark run in progress (PID <LOCK_PID>)`

   - If the PID is **dead** (stale lock from a prior crash): delete the lock file and continue:

     ```bash
     rm .stackpilot/benchmarks/.lock
     ```

4. Write the current PID and ISO timestamp into the lock file:

   ```bash
   echo "$$ $(date -u +%Y-%m-%dT%H:%M:%SZ)" > .stackpilot/benchmarks/.lock
   ```

5. **Lock release protocol**: the lock must be removed on all exit paths — clean exit at Step 5 end, and on any known-fatal error within this skill. Whenever aborting after the lock has been acquired, run:

   ```bash
   rm -f .stackpilot/benchmarks/.lock
   ```

   before printing the abort message.

### Check 4 — No concurrent /stackpilot sprint

A concurrent sprint is indicated when both of the following are true:

- `.stackpilot/plans/` contains at least one `.md` file whose last-modified time is within the past 24 hours.
- That plan file's TaskList contains at least one task with status `in_progress`.

Steps:

1. Find recently modified plan files:

   ```bash
   find .stackpilot/plans/ -name "*.md" -newer .stackpilot/plans/ -mmin -1440 2>/dev/null
   ```

   (1440 minutes = 24 hours)

2. For each recently modified plan file found, search for `in_progress` task status:

   ```bash
   grep -l "in_progress" .stackpilot/plans/*.md 2>/dev/null
   ```

3. If any plan file satisfies both conditions (recently modified AND contains `in_progress`), release the lock (Check 3 step 5) then abort:

   > `finish current sprint or run bench after merge`

### Check 5 — sp-* agents registered

Dispatch a trivial probe to verify the sp-docs agent is registered and responding.

Using the `Agent` tool:

```
Agent(
  subagent_type="sp-docs",
  prompt="reply: registered"
)
```

Evaluate the result:

- If the call **errors** with a message containing `"agent type 'sp-docs' not found"` (or equivalent not-found wording): release the lock (Check 3 step 5) then abort:

  > `sp-* agents not registered — re-run restore.sh and restart Claude Code`

- If the call **succeeds**: extract and record the following fields from the dispatch response for inclusion in the Preflight block of this run's `report.md`:
  - `model`: the model name the sp-docs agent ran on.
  - `tools`: the list of tool names available to sp-docs.

  Record these now in memory as `preflight.sp_docs_model` and `preflight.sp_docs_tools`. They are written into the report at Step 4.

### Check 6 — Stale worktree sweep

Check whether a worktree from a prior crashed run still exists:

```bash
ls .worktrees/bench-run/ 2>/dev/null && echo "exists" || echo "absent"
```

If `.worktrees/bench-run/` exists:

1. Identify the branch it tracks:

   ```bash
   git -C .worktrees/bench-run/ rev-parse --abbrev-ref HEAD
   ```

   Store the branch name (e.g., `bench/run-2026-04-17-1410`) as `STALE_BRANCH`.

2. Remove the worktree:

   ```bash
   git worktree remove --force .worktrees/bench-run
   ```

3. Delete the stale branch:

   ```bash
   git branch -D "$STALE_BRANCH"
   ```

4. Confirm removal succeeded before continuing. If either command fails, release the lock (Check 3 step 5) then abort with the exact error text returned.

---

All six preflight checks passed. Proceed to create the bench worktree and begin the main execution loop.

## Step 1 — Create bench worktree

Create a fresh disposable worktree from `main` and record the base SHA.

```bash
RUN_TS=$(date -u +%Y-%m-%d-%H%M)
git worktree add .worktrees/bench-run -b "bench/run-$RUN_TS" main
git -C .worktrees/bench-run rev-parse HEAD > .worktrees/bench-run/.bench-base-sha
mkdir -p .stackpilot/benchmarks/runs/$RUN_TS/raw
```

Hold `RUN_TS` as a runtime variable for the remainder of the run. All raw artifacts for this run are written to `.stackpilot/benchmarks/runs/$RUN_TS/raw/`.

**Isolation model — sandbox subdirectory**: each workload operates inside `.worktrees/bench-run/bench-sandbox/`, NOT at the worktree root. This preserves the rest of the worktree's tree (CLAUDE.md, `claude-config/`, `.stackpilot/`, etc.) so dispatched agents have context while their edits are scoped to a throwaway subdir. `reset-worktree.sh` (invoked in Step 2) handles the sandbox install + a leg-start commit.

---

## Step 2 — Main execution loop

Iterate the installed workload and two leg dispatches (`zero`, `stackpilot`). After all dispatches complete, hold all rows in memory — do NOT write to CSV until TASK-005 adaptive sampling is complete.

### 2.1 Load workload list

Iterate `claude-config/skills/stackpilot-bench/workloads/*/` in sorted alphanumeric order. If the directory is empty (no workloads installed yet), abort with `"no workloads installed under workloads/ — design and add representative workloads before invoking /stackpilot-bench"` (see ARCHITECTURE.md "workloads must match real /stackpilot usage scope").

### 2.2 Per-workload loop

For each workload `<id>`:

**a. Load workload definition**

- Read `workloads/<id>/prompts.yml` → extract keys `zero`, `stackpilot`.
- Read `workloads/<id>/traps.yml` → extract trap list, `functional_assertions`, and `verification_commands`.

**b. Compute leg order**

Shuffle `["zero", "stackpilot"]` deterministically using `RUN_TS` as seed. See runner.md §Deterministic Leg-Order Shuffling for the full algorithm (seed = md5 of `RUN_TS`, each leg sorted by md5(seed + leg_name)). Record the shuffled order for the report.

**c. Per-leg loop**

For each `leg` in the shuffled order:

1. **Reset worktree to sandbox fixture state**:

   ```bash
   LEG_START_SHA=$(bash claude-config/skills/stackpilot-bench/scripts/reset-worktree.sh \
     .worktrees/bench-run \
     claude-config/skills/stackpilot-bench/workloads/<id>/sandbox \
     | awk '/^reset-worktree: OK/ {print $NF}')
   ```

   The script resets the worktree to `base_sha`, installs the sandbox at `.worktrees/bench-run/bench-sandbox/`, and creates a leg-start commit. The `LEG_START_SHA` is the commit that represents "sandbox pristine, nothing done yet" — later diff capture uses it as the base.

   If the script exits non-zero, treat as a dispatch error (see runner.md §Error Handling During Dispatch) and continue to next leg.

2. **Record start time**:

   ```bash
   LEG_START=$(date +%s)
   ```

3. **Dispatch the leg** (enforce 30-minute soft timeout per runner.md §Timeout Handling):

   Every leg's prompt is prefixed at dispatch time with a **working-directory preamble** so the sub-agent knows to operate inside the sandbox rather than the main repo:

   ```
   PREAMBLE = f"""Working directory for this task: `.worktrees/bench-run/bench-sandbox/`. All file paths below are relative to that directory. Do not read or modify files outside it except for reference (e.g., reading CLAUDE.md at the repo root is allowed).

   {prompts[leg]}
   """
   ```

   - `zero` leg:
     ```
     Agent(subagent_type="general-purpose", prompt=PREAMBLE)
     ```

   - `stackpilot` leg: the main agent drives the full `/stackpilot` flow directly against `prompts["stackpilot"]` (wrapped with the same preamble). Do NOT use `subagent_type="stackpilot"`. The pipeline phases:
     1. Write a mini spec from the prompt text.
     2. Write a mini plan (single task, all paths under `bench-sandbox/`).
     3. Dispatch `sp-architect` if standard complexity, otherwise proceed directly. Pass the preamble + task context.
     4. Dispatch `sp-dev` with the preamble in its prompt so it operates inside `bench-sandbox/`.
     5. Dispatch `sp-qa` against the resulting diff.
     Capture all dispatch return outputs.

4. **Compute duration**:

   ```bash
   LEG_DUR=$(( $(date +%s) - LEG_START ))
   ```

5. **Capture scoped diff** (bench-sandbox/ only, from leg-start SHA):

   ```bash
   git -C .worktrees/bench-run add -N -- \
     bench-sandbox/ \
     ':(exclude)bench-sandbox/node_modules/**' \
     ':(exclude)bench-sandbox/.next/**' \
     ':(exclude)bench-sandbox/dist/**' \
     ':(exclude)bench-sandbox/build/**' \
     ':(exclude)bench-sandbox/coverage/**' \
     ':(exclude)bench-sandbox/*.tsbuildinfo'

   git -C .worktrees/bench-run diff "$LEG_START_SHA" -- \
     bench-sandbox/ \
     ':(exclude)bench-sandbox/node_modules/**' \
     ':(exclude)bench-sandbox/.next/**' \
     ':(exclude)bench-sandbox/dist/**' \
     ':(exclude)bench-sandbox/build/**' \
     ':(exclude)bench-sandbox/coverage/**' \
     ':(exclude)bench-sandbox/*.tsbuildinfo'
   ```

   Write diff to `.stackpilot/benchmarks/runs/$RUN_TS/raw/<id>-<leg>-diff.patch`. Changes made by the agent OUTSIDE `bench-sandbox/` are intentionally excluded from the diff — they're either stray accidental edits (caught at next reset) or context reads (no-op). Generated dependency/build artifacts inside `bench-sandbox/` are also excluded; if generated files still appear in a raw diff, mark the leg `measurement_invalid` and do not use that run as a baseline.

6. **For `stackpilot` leg only**: verify Codex Stackpilot orchestration evidence. A valid stackpilot leg must leave `bench-sandbox/.stackpilot-bench/architect.md`, `bench-sandbox/.stackpilot-bench/dev-report.md`, and `bench-sandbox/.stackpilot-bench/qa-report.md`. Copy these files to the raw run directory and write the QA report text to `.stackpilot/benchmarks/runs/$RUN_TS/raw/<id>-stackpilot-qa.txt`. If any required artifact is missing or generic/empty, mark the row `status=orchestration_invalid`.

7. **Parse token usage** from the dispatch result's `<usage>` block. See runner.md §Capturing Metrics for field names. Compute:

   ```
   total_tokens = input_tokens + output_tokens + cache_read_input_tokens + cache_creation_input_tokens
   ```

8. **Run trap assertions** against the captured diff. For each trap in `traps.yml`:
   - `check_mode: diff` (default): evaluate `diff_bad_regex` against the scoped diff (from step 5). No match → trap avoided.
   - `check_mode: final_file`: read the file at `<worktree>/bench-sandbox/<trap.check_file>` (check_file is relative to the sandbox root). Evaluate `diff_bad_regex` against its FINAL content. No match → trap avoided.
   - `must_match_regex`: optional string or list of strings evaluated against the same target text. If any required regex is missing, the trap is NOT avoided even when `diff_bad_regex` does not match.
   - For `stackpilot` leg only: check `qa_good_regex` against the sp-qa report text.
   - If any regex is invalid, abort the run immediately (no CSV write); point to the offending trap ID.
   - Accumulate `traps_avoided_in_diff` and `traps_caught_in_qa` counts.

9. **Run functional assertions and verification commands**: each `diff_must_match_regex` in `functional_assertions` must match the diff, and each command in `verification_commands` must exit 0 when run inside `bench-sandbox/`. `functional_pass = true` iff ALL regex assertions and verification commands pass. A failed assertion or command does not abort; record it in the row.

10. **Accumulate in-memory row**:

    ```
    {
      workload_id, leg, run_n=1,
      input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, total_tokens,
      duration_sec=LEG_DUR,
      tool_uses,
      traps_total, traps_avoided_in_diff, traps_caught_in_qa,
      functional_pass,
      signals_critical, signals_soft_blocked
    }
    ```

### 2.3 After all 9 dispatches

All rows are held in memory. Do NOT write to `history.csv` here — TASK-005 performs adaptive sampling and then atomically appends all rows.

## Step 2.5 — Failure Handling

This section defines how the runner responds to every class of failure that can occur within or between leg dispatches. All cases are cross-referenced to the spec's "Failure Handling" section.

### 2.5.0 — History CSV validation (before the loop)

**Execute this check at the top of Step 2, before the first workload is loaded.**

The canonical schema for `history.csv` is the 21-column header (the spec's 20 columns plus `status`, resolved in TASK-005):

```
timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status
```

Steps:

1. Check if `.stackpilot/benchmarks/history.csv` exists.

2. If it exists, read its first line (the header row):

   ```bash
   HEADER=$(head -n 1 .stackpilot/benchmarks/history.csv)
   ```

3. Compare `HEADER` to the canonical schema string above (exact string match, whitespace-normalised by stripping surrounding spaces from each field).

4. If the header **does not match**:

   a. Compute a backup filename:
   ```bash
   BAK_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   ```

   b. Rename the existing file:
   ```bash
   mv .stackpilot/benchmarks/history.csv ".stackpilot/benchmarks/history.csv.bak-$BAK_TS"
   ```

   c. Write a fresh header to `history.csv`:
   ```bash
   echo "timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status" \
     > .stackpilot/benchmarks/history.csv
   ```

   d. Emit a one-line warning to stdout:
   ```
   history.csv schema changed — previous file backed up
   ```

5. If the header matches (or the file does not exist yet): continue silently.

### 2.5.1 — Per-leg timeout (30 min)

**Spec reference:** "Per-leg timeout" in Failure Handling.

When dispatching a leg (Step 2.2c item 3), observe the wall-clock elapsed time. If the `Agent()` call returns without a response within **30 minutes**, or if the main agent determines that 30 minutes have elapsed since `LEG_START`:

1. Mark the leg result as:
   ```
   status = "timed_out"
   duration_sec = 1800
   input_tokens = null
   output_tokens = null
   cache_read_tokens = null
   cache_creation_tokens = null
   total_tokens = null
   tool_uses_count = null
   traps_avoided_in_diff = null
   traps_caught_in_qa = null
   functional_pass = null
   signals_critical = null
   signals_soft_blocked = null
   ```

2. Add this row (all-null except `status` and `duration_sec`) to the in-memory results.

3. **Continue with the next leg** in the current workload's shuffled leg list. Do not abort the entire run.

4. **Verdict impact**: when computing the per-workload verdict at Step 4, any workload that contains one or more timed-out legs is reported as `INCOMPLETE` instead of PASS/FAIL. The overall run verdict is not POSITIVE if any workload is INCOMPLETE.

### 2.5.2 — Dispatch error

**Spec reference:** "Dispatch error" in Failure Handling.

If `Agent()` returns an error object (e.g., the subagent type is not found, the call rejected, or the API returned an error) or an empty/nil result:

1. Persist the error text to disk:
   ```bash
   echo "<error text>" > ".stackpilot/benchmarks/runs/$RUN_TS/raw/<workload_id>-<leg>-error.txt"
   ```

2. Mark the leg result as:
   ```
   status = "error"
   duration_sec = null   # unless duration was already measured before the error
   # all other metric fields = null
   ```

3. **Continue with the next leg** in the current workload's leg list (same behavior as the timeout case).

4. **Verdict impact**: identical to the timeout case — any workload with at least one errored leg is reported `INCOMPLETE` and excluded from PASS/FAIL comparison.

**Distinction from timeout**: timeout means the call returned but wall-clock limit was exceeded; error means the call itself returned a failure response or empty result. Both result in all metrics being `null` for that leg, but the `status` field differs (`timed_out` vs `error`) for diagnostics.

### 2.5.3 — Assertion failure (regex compile error)

**Spec reference:** "Assertion library failure" in Failure Handling.

When evaluating trap assertions in Step 2.2c item 8, if either `diff_bad_regex` or `qa_good_regex` of any trap entry throws an exception (e.g., malformed regex syntax that fails to compile):

1. **ABORT the entire run immediately.** Do not mark the leg as an error and continue — this is a configuration bug, not a transient dispatch failure.

2. Print an error message that identifies exactly which trap caused the failure:
   ```
   Aborting run: invalid regex in workload '<workload_id>', trap id '<trap_id>', field '<diff_bad_regex|qa_good_regex>': <error message>
   ```

3. Release the lock:
   ```bash
   rm -f .stackpilot/benchmarks/.lock
   ```

4. **No CSV write** — `history.csv` is NOT modified.

5. Do not render `report.md`. The run directory `runs/$RUN_TS/raw/` may be left with partial raw artifacts; inform the user they can inspect it if needed.

**Why abort rather than continue**: a malformed regex means the trap assertion logic is broken for all remaining traps in that workload, making the results unreliable. The fix must happen in `traps.yml` before the run can proceed.

### 2.5.4 — Mid-run crash recovery

**Spec reference:** "Mid-run crash" in Failure Handling.

If the main agent session or Claude Code itself crashes during a run (power loss, network timeout, user `CTRL-C`, OOM):

- **`history.csv` is safe**: no rows are written to `history.csv` until ALL legs × workloads complete successfully and TASK-005's atomic write executes. A mid-run crash leaves `history.csv` entirely untouched. Partial results in memory are lost.

- **Leftover artifacts**: the crashed run may leave behind:
  - `.worktrees/bench-run/` — a git worktree from the crashed run.
  - `.stackpilot/benchmarks/.lock` — a stale lock file containing the (now dead) PID.
  - `.stackpilot/benchmarks/runs/$RUN_TS/raw/` — partial raw artifact files.

- **Recovery on next run**: the next invocation of `/stackpilot-bench` runs the preflight checks in Step 0. Step 0 Check 3 (lock acquisition) detects a stale PID and removes the lock. Step 0 Check 6 (stale worktree sweep) removes the leftover worktree and its branch. These two preflight steps together fully restore a clean state, allowing the new run to proceed normally.

- **Partial raw directory**: leftover files in `runs/$RUN_TS/raw/` from the crashed run are harmless — they live under the crashed run's timestamp directory, not the new run's. No cleanup is needed; they can be inspected manually if desired.

- **No manual intervention required**: the recovery path is automatic. The user does not need to run any cleanup commands.

---

Summary of per-failure behavior:

| Failure type | Leg status | CSV write | Run continues? | Abort? |
|---|---|---|---|---|
| Timeout (> 30 min) | `timed_out` | No (held in memory) | Yes | No |
| Dispatch error | `error` | No (held in memory) | Yes | No |
| Missing stackpilot phase evidence | `orchestration_invalid` | No (held in memory) | Yes | No |
| Regex compile error | — | No | No | Yes |
| CSV schema mismatch | — | File backed up, fresh header written | Yes | No |
| Mid-run crash | — | `history.csv` untouched | Restart required | — |

---

## Step 3 — Adaptive Sampling

Adaptive sampling conditionally re-runs individual (workload, leg) pairs when their results land close to the historical median. This provides more statistical confidence for near-threshold changes without tripling cost for clear wins or clear regressions.

### 3.1 — Baseline check

Before running any adaptive iterations, check whether `.stackpilot/benchmarks/history.csv` has prior data rows (i.e., rows beyond the header line):

```bash
HISTORY_ROWS=$(awk 'NR > 1' .stackpilot/benchmarks/history.csv 2>/dev/null | wc -l)
```

If `HISTORY_ROWS` equals zero (the file is absent, or contains only the header, or the file does not exist yet): **skip adaptive sampling entirely**. This is the baseline run. Every in-memory row already has `run_n=1`. Proceed directly to Step 4.

### 3.2 — Compute per-pair deltas

For each (workload, leg) pair in the current run's in-memory rows:

1. Filter history rows where `workload_id == W AND leg == L AND status == "ok"`.
2. From those history rows, compute:
   - `median_tokens_prior` = median of the `total_tokens` column across all filtered prior rows.
   - `median_duration_prior` = median of the `duration_sec` column across all filtered prior rows.
3. If the filtered set is empty (no prior successful rows for this pair), skip adaptive for this pair — treat it as unambiguously new data.
4. Compute the relative deltas for the current row (which has `run_n=1` and `status=ok`):
   ```
   delta_tokens   = |current.total_tokens - median_tokens_prior| / median_tokens_prior
   delta_duration = |current.duration_sec - median_duration_prior| / median_duration_prior
   ```
5. If `delta_tokens < 0.20` **OR** `delta_duration < 0.20`: mark this (workload, leg) pair for adaptive re-run.

**Do not mark for adaptive re-run** any pair where the current row has `status=timed_out` or `status=error`. Adaptive sampling only applies to successful legs.

### 3.3 — Execute adaptive re-runs

For each (workload, leg) pair that is marked:

1. Run **two additional iterations** of that leg (so the pair ends up with three rows: `run_n=1`, `run_n=2`, `run_n=3`).

2. For each additional iteration `N` in `[2, 3]`:

   a. Reset the worktree sandbox (capture new `LEG_START_SHA`):

      ```bash
      LEG_START_SHA=$(bash claude-config/skills/stackpilot-bench/scripts/reset-worktree.sh \
        .worktrees/bench-run \
        claude-config/skills/stackpilot-bench/workloads/<id>/sandbox \
        | awk '/^reset-worktree: OK/ {print $NF}')
      ```

   b. Record start time: `LEG_START=$(date +%s)`

   c. Dispatch the leg exactly as in Step 2.2c item 3 (same leg type, same prompt). Observe the 30-minute soft timeout and dispatch-error handling from Step 2.5.1 and 2.5.2 — if an adaptive iteration times out or errors, record its row with the appropriate `status` and `run_n=N`, then skip the remaining iteration for that pair (do not run `run_n=3` if `run_n=2` failed).

   d. Capture `LEG_DUR`, final diff, token usage, trap assertions, and functional assertions exactly as in Step 2.2c items 4–9.

   e. Store the resulting row in memory with `run_n=N` and the workload/leg identifiers.

   f. Write the diff to `.stackpilot/benchmarks/runs/$RUN_TS/raw/<id>-<leg>-run<N>-diff.patch`.

3. After both additional iterations complete for a pair, the in-memory results contain three rows for that (workload, leg): `run_n=1`, `run_n=2`, `run_n=3`. All three rows are written to the CSV as separate entries in Step 4.

### 3.4 — Verdict computation for n>1 pairs

When `compute-verdict.sh` is later called in Step 5, it takes the **median** of the three rows' `total_tokens`, `duration_sec`, `traps_avoided_in_diff`, and `functional_pass` values for the verdict comparison. The median computation is the script's responsibility (see `scripts/compute-verdict.sh`). Rows with `status != "ok"` are excluded from the median but their presence is noted in the report.

---

## Step 4 — CSV Write

All rows are now finalized in memory. Write them atomically to `history.csv`, capture a per-run copy, and render the report.

### 4.1 — Schema

The canonical 21-column header:

```
timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status
```

Column definitions:
- `timestamp`: ISO-8601 UTC, e.g., `2026-04-17T14:30:00Z`. Use the moment the row is being written (not leg start).
- `git_sha`: `git rev-parse HEAD` on the main worktree.
- `stackpilot_version`: contents of the `VERSION` file at project root, trimmed. If absent: `unknown`.
- `status`: one of `ok`, `timed_out`, `error`, `orchestration_invalid`.
- All null metric fields are written as the literal string `null` (not empty, not `NA`).

### 4.2 — Build CSV content in memory

1. Resolve `GIT_SHA` and `STACKPILOT_VERSION`:

   ```bash
   GIT_SHA=$(git rev-parse HEAD)
   STACKPILOT_VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")
   WRITE_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   ```

2. For each row in the in-memory results (all original n=1 rows plus any adaptive rows), produce one CSV line:

   ```
   $WRITE_TS,$GIT_SHA,$STACKPILOT_VERSION,$workload_id,$leg,$run_n,$input_tokens,$output_tokens,$cache_read_tokens,$cache_creation_tokens,$total_tokens,$duration_sec,$tool_uses_count,$traps_total,$traps_avoided_in_diff,$traps_caught_in_qa,$functional_pass,$signals_critical,$signals_soft_blocked,$status
   ```

   All null fields are written as `null` (not empty).

3. Concatenate all row strings into a single `NEW_ROWS` string (one row per line, no trailing newline).

### 4.3 — Atomic append to history.csv

1. If `.stackpilot/benchmarks/history.csv` does **not** exist (first-ever run, or was just recreated by Step 2.5.0): write the header first:

   ```bash
   echo "timestamp,git_sha,...,status" > .stackpilot/benchmarks/history.csv.tmp
   echo "$NEW_ROWS" >> .stackpilot/benchmarks/history.csv.tmp
   mv .stackpilot/benchmarks/history.csv.tmp .stackpilot/benchmarks/history.csv
   ```

2. If `history.csv` already exists (header already written by a prior run or Step 2.5.0 rewrite): append new rows only:

   ```bash
   # Copy existing content to .tmp, then append new rows
   cp .stackpilot/benchmarks/history.csv .stackpilot/benchmarks/history.csv.tmp
   echo "$NEW_ROWS" >> .stackpilot/benchmarks/history.csv.tmp
   mv .stackpilot/benchmarks/history.csv.tmp .stackpilot/benchmarks/history.csv
   ```

   The `cp` + `echo` + `mv` pattern ensures atomicity: `.csv.tmp` is always a complete valid file before the rename, so a crash during write leaves the original `history.csv` intact.

### 4.4 — Per-run rows copy

Capture a self-contained copy of this run's rows (with header) for easy per-run reference:

```bash
mkdir -p .stackpilot/benchmarks/runs/$RUN_TS
echo "timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status" \
  > .stackpilot/benchmarks/runs/$RUN_TS/rows.csv
echo "$NEW_ROWS" >> .stackpilot/benchmarks/runs/$RUN_TS/rows.csv
```

### 4.5 — Render report.md

1. Read the template:

   ```bash
   # Template path (relative to repo root)
   TEMPLATE=claude-config/skills/stackpilot-bench/references/report-template.md
   ```

2. Perform substitution: replace every `{{placeholder}}` in the template with the corresponding computed value from the current run. The substitution map must include at minimum:

   | Placeholder | Source |
   |---|---|
   | `{{RUN_TS}}` | `$RUN_TS` |
   | `{{GIT_SHA}}` | `$GIT_SHA` |
   | `{{STACKPILOT_VERSION}}` | `$STACKPILOT_VERSION` |
   | `{{VERDICT}}` | Overall run verdict (from Step 5) |
   | `{{PREFLIGHT_SP_DOCS_MODEL}}` | `preflight.sp_docs_model` (from Step 0 Check 5) |
   | `{{PREFLIGHT_SP_DOCS_TOOLS}}` | `preflight.sp_docs_tools` (from Step 0 Check 5) |
   | `{{LEG_ORDER_WL01}}` | Shuffled leg order string for workload 01 |
   | `{{LEG_ORDER_WL02}}` | Shuffled leg order string for workload 02 |
   | `{{LEG_ORDER_WL03}}` | Shuffled leg order string for workload 03 |
   | `{{ROWS_CSV_PATH}}` | `.stackpilot/benchmarks/runs/$RUN_TS/rows.csv` |

   Per-workload and per-leg metrics placeholders (e.g., `{{WL01_STACKPILOT_TOTAL_TOKENS}}`) are populated from the in-memory rows. Any `{{placeholder}}` that has no computed value is written as the literal string `N/A`.

3. Write the rendered content:

   ```bash
   # (rendered string built in memory as REPORT_CONTENT)
   echo "$REPORT_CONTENT" > .stackpilot/benchmarks/runs/$RUN_TS/report.md
   ```

---

## Step 5 — Scorecard + Verdict + Cleanup

The run produces two complementary summaries:

- **Scorecard** (primary output, answers "is stackpilot worth using over
  native Claude Code?"): 0-100 per-dimension scores across correctness,
  over-engineering resistance, bug catch rate, token efficiency, and
  wall-clock speed. This is what users read first.
- **Verdict** (secondary, answers "did the last change regress vs the
  prior run?"): POSITIVE / MARGINAL / NEGATIVE call used during iterative
  tuning.

### 5.1a — Run compute-scorecard.sh (primary output)

```bash
SCORECARD_OUTPUT=$(bash claude-config/skills/stackpilot-bench/scripts/compute-scorecard.sh \
  .stackpilot/benchmarks/history.csv \
  "$RUN_TS")
```

Capture stdout to `SCORECARD_OUTPUT`. See `references/scoring.md` for the
weighting model and `references/scorecard-template.md` for the full
rendered document.

### 5.1b — Run compute-verdict.sh (regression tracking)

```bash
VERDICT_OUTPUT=$(bash claude-config/skills/stackpilot-bench/scripts/compute-verdict.sh \
  .stackpilot/benchmarks/history.csv \
  "$RUN_TS")
```

Capture stdout to `VERDICT_OUTPUT`. If either script exits non-zero, print
its stderr to stdout and proceed to cleanup — do not abort cleanup on a
summary-script failure.

### 5.2 — Apply INCOMPLETE workload rule

**Design decision: the INCOMPLETE override is enforced here in the SKILL.md runtime, not inside `compute-verdict.sh`.**

Rationale: `compute-verdict.sh` is a stateless script that reads only CSV rows. Encoding INCOMPLETE logic there would require the script to understand `status` semantics and the POSITIVE/MARGINAL/NEGATIVE enum. It is simpler and more maintainable to have the SKILL.md runtime post-process the script's output: the script computes the pairwise verdict as if all rows were present, and the runtime applies the INCOMPLETE override after the fact. Future versions can move this logic into the script if desired.

The rule:

1. Inspect the in-memory rows. For each workload, check whether any leg has `status=timed_out`, `status=error`, or `status=orchestration_invalid`.
2. If any workload has an INCOMPLETE leg:
   - That workload's per-workload verdict is overridden to `INCOMPLETE` (replaces any PASS/FAIL from the script's output).
   - The overall run verdict collapses as follows:
     - If the remaining complete workloads would all be POSITIVE per the script: overall verdict becomes `MARGINAL` (not POSITIVE — an INCOMPLETE workload prevents a POSITIVE claim).
     - If any complete workload is FAIL per the script: overall verdict becomes `NEGATIVE`.
   - Insert a note in `VERDICT_OUTPUT` before printing: `note: workload-<id> INCOMPLETE (<leg> timed_out|error|orchestration_invalid) — overall verdict capped`.
3. If no workload has an INCOMPLETE leg: use `VERDICT_OUTPUT` as-is.

Apply the INCOMPLETE-adjusted `VERDICT_OUTPUT` as the value for `{{VERDICT}}` during Step 4.5 template substitution. Because Step 4.5 (report write) happens before `compute-verdict.sh` is called here, the report must be re-rendered with the final verdict, OR the verdict block is appended to the report in-place:

```bash
echo "" >> .stackpilot/benchmarks/runs/$RUN_TS/report.md
echo "## Verdict Block" >> .stackpilot/benchmarks/runs/$RUN_TS/report.md
echo "$VERDICT_OUTPUT" >> .stackpilot/benchmarks/runs/$RUN_TS/report.md
```

This append approach is preferred over a full re-render for simplicity.

### 5.3 — Append scorecard to the run directory

```bash
echo "$SCORECARD_OUTPUT" > .stackpilot/benchmarks/runs/$RUN_TS/scorecard.md
```

### 5.3b — Print scorecard then verdict to stdout

Print `SCORECARD_OUTPUT` first (primary product-comparison view), then a
blank line, then `VERDICT_OUTPUT` (after INCOMPLETE adjustment — the
regression-tracking view):

```
echo "$SCORECARD_OUTPUT"
echo ""
echo "$VERDICT_OUTPUT"
```

### 5.4 — Release lock

```bash
rm -f .stackpilot/benchmarks/.lock
```

### 5.5 — Worktree cleanup

By default, remove the bench worktree and its branch:

```bash
git worktree remove .worktrees/bench-run --force
git branch -D "bench/run-$RUN_TS"
```

If either command fails (e.g., the worktree was already removed by a parallel process), print the error but continue — the run is complete regardless.

<!-- v1 does not support a --keep flag. If the user wants to inspect the worktree post-run, they must suppress this step manually by commenting it out. A future version may add --keep as a named option. -->

### 5.6 — Final output line

```bash
echo "Done. Scorecard: .stackpilot/benchmarks/runs/$RUN_TS/scorecard.md | Full report: .stackpilot/benchmarks/runs/$RUN_TS/report.md"
```

---

## Operational Notes

### Workload rotation schedule

Fixed workloads risk becoming stale if prompt engineering iteration overfits to them. Re-review workloads every 3 months or when a stackpilot major version bumps. Rotate in a new workload if any existing one feels too predictable or is no longer exercising a real regression class.

### Verdict interpretation guide

- **POSITIVE OPTIMIZATION**: safe to merge — stackpilot is measurably better or equal on all dimensions.
- **MARGINAL**: use judgment — gains exist but are offset by a degradation in cost or trap-catch rate, or an INCOMPLETE workload prevented a full read.
- **NEGATIVE OPTIMIZATION**: do not merge — the workload fails the pairwise quality check vs native zero; the pipeline is regressing.

### Known biases (summary)

- Parent-session cache leak: all legs share the parent Claude Code session context. See spec §Anti-Contamination.
- n=1 default: single runs are noisy; adaptive sampling provides partial mitigation.
- Regex-based trap detection: can false-positive or false-negative on unusual phrasings. Regexes in `traps.yml` are conservative by design.
