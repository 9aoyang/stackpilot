# Benchmark Runner Protocol

Reference documentation for the main agent executing `/stackpilot-bench`. This file specifies how to invoke workload legs, capture metrics, manage worktree state, and shuffle execution order deterministically.

## Resetting the Worktree (sandbox model)

Call the reset script before each leg to restore the sandbox to pristine fixture state.

**Signature:**
```bash
bash scripts/reset-worktree.sh <worktree_path> <sandbox_source>
```

**Arguments:**
- `<worktree_path>`: absolute path to the git worktree (e.g., `/path/to/repo/.worktrees/bench-run`)
- `<sandbox_source>`: absolute path to the workload's sandbox source dir (e.g., `/path/to/repo/claude-config/skills/stackpilot-bench/workloads/01-trap-heavy-bash/sandbox`)

**What the script does:**
1. Reads `<worktree_path>/.bench-base-sha` — the main-branch SHA the worktree was created from. Aborts (exit 3) if missing.
2. Runs `git -C <worktree_path> reset --hard <base_sha>` — undoes ALL changes from the prior leg across the entire worktree.
3. Runs `git clean -fdx` (while preserving the `.bench-base-sha` marker file).
4. Removes any existing `<worktree>/bench-sandbox/` and copies `<sandbox_source>/` into it.
5. Runs `git add bench-sandbox/` then commits with `--no-verify` (fixed author/committer identity, no VERSION/hook checks applied). The commit is the "leg-start SHA".
6. Prints the leg-start SHA to stdout in the form `reset-worktree: OK <sha>`.

**Exit behavior:**
- Exit 0 on success; `reset-worktree: OK <sha>` on stdout.
- Exit 2 on bad arguments / missing paths.
- Exit 3 if `.bench-base-sha` marker missing or empty.
- Exit 1 if git/cp operations fail.

**Why this model:**
- Workload edits are scoped to `bench-sandbox/` (a throwaway subdirectory).
- The rest of the worktree retains main's files (CLAUDE.md, `claude-config/`, etc.), so dispatched agents have normal project context.
- The leg-start commit lets the runner compute a CLEAN diff scoped to `bench-sandbox/` after the leg finishes, without fixture-install churn showing up as "agent changes".

**Diff capture after the leg:**
```bash
git -C <worktree_path> diff <leg_start_sha> -- \
  bench-sandbox/ \
  ':(exclude)bench-sandbox/node_modules/**' \
  ':(exclude)bench-sandbox/.next/**' \
  ':(exclude)bench-sandbox/dist/**' \
  ':(exclude)bench-sandbox/build/**' \
  ':(exclude)bench-sandbox/coverage/**' \
  ':(exclude)bench-sandbox/*.tsbuildinfo'
```

The `-- bench-sandbox/` pathspec excludes any stray edits the agent may have made outside the sandbox (CLAUDE.md etc.); those are cleaned up by the next leg's `reset --hard`.
The exclude pathspecs keep dependency installs and generated build artifacts out of scoring. A raw diff containing `node_modules/`, `.next/`, `dist/`, `build/`, `coverage/`, or `*.tsbuildinfo` is measurement pollution and should invalidate the run.

**Idempotency:** safe to call multiple times; each call produces a new leg-start commit and a freshly-installed sandbox.

## Invoking Legs

Three leg types; each has a different dispatch mechanism.

### Zero Leg (naive baseline)

**Purpose:** one-line prompt with no best practices; serves as the lower-cost bound.

**Dispatch:**
```
Agent(
  subagent_type="general-purpose",
  prompt=workload.prompts.zero
)
```

**Notes:**
- `workload.prompts.zero` is a string loaded from `prompts.yml` under the key `zero`.
- The subagent is a stateless general-purpose agent — no stackpilot methodology injected.
- Capture the result: tokens, duration, tool_uses count, final git diff.

### Savvy Leg (best-practice baseline)

**Purpose:** a prompt a prompt-literate user would write, including best practices like "read CLAUDE.md", "write tests", "explain plan before changes".

**Dispatch:**
```
Agent(
  subagent_type="general-purpose",
  prompt=workload.prompts.savvy
)
```

**Notes:**
- `workload.prompts.savvy` is a string loaded from `prompts.yml` under the key `savvy`.
- This is the upper-cost baseline; stackpilot must beat or match savvy on quality while staying within the 3x token budget.
- Capture same metrics as zero leg.

### Stackpilot Leg (the pipeline under test)

**Purpose:** full `/stackpilot` methodology applied to the workload prompt.

**Dispatch:**
- The main agent itself (not a subagent dispatch) runs the full `/stackpilot` flow:
  1. Read `workload.prompts.stackpilot` (from `prompts.yml` under key `stackpilot`).
  2. Execute the five-phase pipeline: Spec → Plan → Architect → Dev → QA.
  3. Each phase consumes its input and produces its output (spec → plan, etc.).
  4. The final phase (QA) produces an `sp-qa` report.

**Notes:**
- Do NOT dispatch the stackpilot leg as `Agent(subagent_type="stackpilot", ...)`. Stackpilot is a skill, not an agent type; the main agent drives the pipeline.
- The pipeline runs against `workload.prompts.stackpilot` as the initial user request (the "task spec" text).
- Capture the same metrics as zero/savvy legs PLUS the sp-qa report text (see below).

## Capturing Metrics

Each leg dispatch returns a result with usage data and a transcript. Extract the following:

### Token counts

The result contains a `<usage>` block (or equivalent API response object) with four fields:
- `input_tokens`: tokens consumed by the model on input (prompt + context).
- `output_tokens`: tokens generated by the model.
- `cache_read_input_tokens`: tokens read from the model's prompt cache (if enabled).
- `cache_creation_input_tokens`: tokens written to the model's prompt cache.

**Compute:**
```
total_tokens = input_tokens + output_tokens + cache_read_input_tokens + cache_creation_input_tokens
```

Record `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, and `total_tokens` separately in the CSV row.

### Duration

Measure wall-clock time around the dispatch call:
```
start_ms = current_epoch_ms()
result = Agent(...)
end_ms = current_epoch_ms()
duration_ms = end_ms - start_ms
```

Convert to seconds for the CSV: `duration_sec = duration_ms / 1000`.

### Tool uses count

Parse the subagent's transcript (or the main agent's transcript if stackpilot leg) to count invocations of tool-use blocks. This includes Read, Write, Edit, Glob, etc. — any use of a tool by the agent during execution.

```
tool_uses = count of <function_calls> blocks in the transcript
```

For the stackpilot leg, this is the total across all five phases.

### Final diff

After the leg completes, capture the final state of the worktree:
```bash
cd <worktree_path>
git diff --no-ext-diff main -- .
```

Store this diff for later trap-assertion evaluation. The diff is a multi-line string; do not truncate.

### SP-QA Report (stackpilot leg only)

Only for the stackpilot leg, after the full pipeline completes:

1. Extract the sp-qa report text from the final QA phase dispatch output.
2. The report is the markdown text generated by the `sp-qa` agent in the Diagnostic, Actions, and Verification sections.
3. Store this text in `runs/<timestamp>/raw/<workload_id>-stackpilot-qa.txt` as a raw artifact.
4. This text is used later to match against `qa_good_regex` patterns from `traps.yml`.

## Deterministic Leg-Order Shuffling

Leg order must be permuted deterministically per workload, with the same seed guaranteeing the same order across multiple runs. This enables debugging a specific run.

**Seed generation:**
```
seed_string = "<timestamp in YYYY-MM-DD-HHMM format>"
# Example: "2026-04-17-1430" for April 17, 2026 at 14:30

# Hash to 8-character seed
seed_hex = md5sum(seed_string) | head -c 8
# Example: "a3f2d1b7"
```

**Permutation algorithm:**
```
legs = ["zero", "savvy", "stackpilot"]

# Sort legs by md5(seed_hex + leg_name), lexicographically
legs_with_hash = [
  (leg, md5sum(seed_hex + leg)) for leg in legs
]
shuffled_legs = sorted(legs_with_hash, key=lambda x: x[1])[0]

# shuffled_legs is now a deterministically permuted order
```

**Example:**
```
seed_string = "2026-04-17-1430"
seed_hex = "a3f2d1b7"  # from md5sum

Hash values:
  md5("a3f2d1b7" + "zero")     = "9c5f2e1a..."
  md5("a3f2d1b7" + "savvy")    = "7d4e1b3c..."
  md5("a3f2d1b7" + "stackpilot") = "5a2f9d8e..."

Sorted order (lexicographically by hash):
  1. "5a2f9d8e..." → stackpilot
  2. "7d4e1b3c..." → savvy
  3. "9c5f2e1a..." → zero

Execution order for this workload: stackpilot, savvy, zero
```

**Recording:**
Store the shuffled leg order in the report's Per-Workload section. This helps explain why a later leg's performance may be affected by earlier cache warmth (a known bias documented in the spec).

## Trap Assertion Evaluation

For each leg, after capturing the diff:

1. Load `traps.yml` for the current workload.
2. For each trap entry:
   - Check if `diff_bad_regex` matches anywhere in the final diff.
     - If it does NOT match: increment `traps_avoided_in_diff`.
     - If it does match: the trap was NOT avoided (the bug is present).
   - For stackpilot leg only, check if `qa_good_regex` matches anywhere in the sp-qa report text.
     - If it does match: increment `traps_caught_in_qa`.
     - If it does not match: the trap was missed by sp-qa.

3. Count totals:
   - `traps_total` = count of trap entries in `traps.yml`.
   - `traps_avoided_in_diff` = count of traps where `diff_bad_regex` does NOT match.
   - `traps_caught_in_qa` = count of traps where `qa_good_regex` matches (stackpilot leg only; `null` for zero/savvy).

**Regex error handling:**
If any regex (either `diff_bad_regex` or `qa_good_regex`) is invalid, the run aborts immediately with an error message pointing to the offending trap ID and workload file. No CSV is written.

## Functional Assertion Evaluation

For each leg, after capturing the diff:

1. Load the workload README (or `traps.yml` under a `functional_assertions` key).
2. Each assertion is a grep pattern that must match in the final diff.
3. Run each pattern against the diff:
   ```bash
   grep -q "<pattern>" <<< "$final_diff" && echo "PASS" || echo "FAIL"
   ```
4. All patterns must match (AND logic). If any fails:
   - `functional_pass = false` for that leg.
   - Leg continues (do not abort; the CSV row is still written).

If all patterns match:
   - `functional_pass = true` for that leg.

**Example (workload 01):**
- Assertion 1: `--verbose` flag parsed: grep pattern `add_argument.*--verbose` in diff.
- Assertion 2: verbose output emitted: grep pattern `echo.*framework` in diff.
- Both must match.

## Timeout Handling

Each leg dispatch has a 30-minute soft timeout.

```
set timeout to 30 minutes
start_time = current_time()
result = Agent(...)  # may block up to 30 minutes
elapsed = current_time() - start_time

if elapsed >= 30 minutes:
  mark leg as timed_out
  all metric fields = null EXCEPT duration_sec = 1800
  write to CSV
  continue to next leg
```

If the dispatch returns before 30 minutes:
- Record the actual duration.
- Proceed to metrics capture.

## CSV Row Construction

After all metrics are captured for a leg, construct a CSV row:

```
timestamp, git_sha, stackpilot_version, workload_id, leg, run_n,
input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, total_tokens,
duration_sec, tool_uses_count,
traps_total, traps_avoided_in_diff, traps_caught_in_qa,
functional_pass, signals_critical, signals_soft_blocked
```

**Definitions:**
- `timestamp`: ISO 8601 format, e.g., `2026-04-17T14:30:00Z`.
- `git_sha`: the current HEAD SHA of main (captured at the start of the run, before worktree creation).
- `stackpilot_version`: from the `VERSION` file in the repo root, or `unknown` if file doesn't exist.
- `workload_id`: e.g., `01-trap-heavy-bash`, `02-doc-consistency`, `03-cross-file-refactor`.
- `leg`: `zero`, `savvy`, or `stackpilot`.
- `run_n`: iteration number (1, 2, 3 for adaptive sampling; usually 1).
- Token fields: numeric or `null` if timed out / error.
- `duration_sec`: numeric (float).
- `tool_uses_count`: numeric or `null` if error.
- `traps_total`: numeric (count of entries in `traps.yml`).
- `traps_avoided_in_diff`: numeric (0 to `traps_total`).
- `traps_caught_in_qa`: numeric or `null` if leg is not stackpilot.
- `functional_pass`: boolean (`true` / `false`).
- `signals_critical`, `signals_soft_blocked`: reserved for future use; write as empty string or `null`.

**Example row:**
```
2026-04-17T14:30:00Z, a1b2c3d4, 1.10.0, 01-trap-heavy-bash, stackpilot, 1,
45000, 8500, 12000, 5000, 70500,
180.5, 23,
5, 5, 4,
true, , 
```

## Error Handling During Dispatch

If `Agent()` returns an error or an empty result:

1. Write the error text to `runs/<timestamp>/raw/<workload_id>-<leg>-error.txt`.
2. Mark the leg as `error` in the CSV.
3. All metric fields except `leg` and `error_text_path` are `null`.
4. Continue to the next leg (do not abort the entire run).

If the error is clearly fatal (e.g., agent type not registered), the preflight check should have caught it; if not, abort the entire run with a specific error message.

## Deterministic Seed to Order Mapping (Reference)

For reproducibility, include this mapping in the report:

```markdown
### Leg Execution Order

Run timestamp: 2026-04-17-1430
Seed: a3f2d1b7

Workload 01: [stackpilot, savvy, zero]
Workload 02: [zero, stackpilot, savvy]
Workload 03: [savvy, zero, stackpilot]
```

This demonstrates that order varies per workload but is deterministic within a run.

## Trap Evaluation Modes

Each trap entry may optionally declare `check_mode`:

- `check_mode: diff` (default, assumed if absent) — `diff_bad_regex` is evaluated against the scoped diff (`git -C .worktrees/bench-run diff <leg_start_sha> -- bench-sandbox/`).
- `check_mode: final_file` — the trap declares `check_file: <path relative to bench-sandbox/>`; `diff_bad_regex` is evaluated against the final content of that file (read from `<worktree>/bench-sandbox/<check_file>` after dispatch completes, before reset). Use this mode when the trap condition is "old phrase X still exists in file Y" — testable regardless of whether the agent touched the file.

Pseudocode for trap evaluation:

    for trap in workload.traps:
        mode = trap.get('check_mode', 'diff')
        if mode == 'diff':
            text = captured_diff
        elif mode == 'final_file':
            text = read_file(f"{worktree}/bench-sandbox/{trap['check_file']}")
        if re.search(trap['diff_bad_regex'], text, re.MULTILINE):
            traps_avoided_in_diff += 0    # trap triggered
        else:
            traps_avoided_in_diff += 1    # trap avoided

**Example trap entry using `check_mode: final_file`:**

```yaml
- id: trap-02-stale-readme-wording
  description: "README.md still contains the old design decision wording after update"
  check_mode: final_file
  check_file: README.md
  detection:
    diff_bad_regex: 'Key Design Decision: events are stored as mutable state'
    qa_good_regex: 'README|stale|inconsisten|outdated'
  severity: high
```

In this example, the trap fires if the old phrase is still present in `README.md` regardless of whether the agent produced a diff touching that file. This is more reliable than scanning the diff for an absence of a change, because an agent that simply never opens `README.md` would produce a diff that matches neither the old nor new wording — a diff-mode check would incorrectly report the trap as "avoided".

**When to use `check_mode: final_file`:**

- The trap condition is "old text still exists in file X" (i.e., the agent should have removed or replaced it).
- The file is always present in the worktree fixture and the agent might not touch it at all.
- Checking the diff would give a false "avoided" result if the agent never opened the file.

**When to use the default `check_mode: diff` (or omit `check_mode`):**

- The trap condition is "agent introduced a new bug" (the bad pattern would only appear if the agent wrote something wrong).
- The bad pattern does not exist in the fixture baseline, so a no-op agent would trivially avoid it.
- The evaluation is about what the agent DID, not what it FAILED to do.
