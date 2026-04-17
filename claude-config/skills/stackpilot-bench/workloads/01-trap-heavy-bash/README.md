# Workload 01: trap-heavy-bash

## Scenario

Add a `--verbose` flag to `scripts/detector.sh` that echoes each framework-detection check and the matched framework name.

When `--verbose` is active the script should print:
- `CHECK: <check_name>` before each detection attempt
- `MATCHED: <framework>` immediately after a successful match

## Purpose

Tests sp-qa's ability to catch bash-specific subtle bugs. Bash is unforgiving and a common place where unassisted Claude makes quiet mistakes. The five seeded traps cover the most frequent classes of bash regression: unsafe variable expansion, flag-namespace collisions, grep misuse, pipe interaction, and debug-trace leakage.

## Fixture

The fixture is `fixtures/scripts/detector.sh` — a synthetic bash script that mimics the structure of a stackpilot-like framework detector. It is intentionally NOT a copy of the real `scripts/init.sh`. Keeping the fixture self-contained ensures the workload remains stable as the real repository evolves.

## Seeded Traps

| ID | Severity | Short Description |
|----|----------|-------------------|
| trap-01-unquoted-var | high | Verbose output uses unquoted `$framework` or `$lang` expansion, causing word-splitting on values with spaces. |
| trap-02-flag-collision | high | New `-v` short flag collides with the existing `-q` silent-mode flag namespace — script already uses getopts with short flags. |
| trap-03-grep-comment-match | medium | Grep patterns used in detection lack a `-v '^#'` filter, so commented-out manifest lines incorrectly trigger a framework match during verbose output. |
| trap-04-broken-pipe | high | Verbose output is written to stdout, breaking the documented `detector.sh | jq` pipe that consumers rely on; stdout must carry only JSON, verbose to stderr. |
| trap-05-debug-leak | medium | Adding `set -x` (or `DEBUG=1` toggle) inside the verbose block causes `$PS4` to print env values including secrets when callers set `DEBUG`. |

## How the Benchmark Uses This Workload

1. The runner resets `fixtures/scripts/detector.sh` into the worktree before each leg.
2. The leg's prompt (from `prompts.yml`) is dispatched to the agent under test.
3. The final diff is evaluated against:
   - `functional_assertions` — basic correctness (does the feature exist at all?)
   - `traps.yml` `diff_bad_regex` — did the agent introduce the trap in its diff?
   - `traps.yml` `qa_good_regex` (stackpilot leg only) — did sp-qa's report mention the fix?
