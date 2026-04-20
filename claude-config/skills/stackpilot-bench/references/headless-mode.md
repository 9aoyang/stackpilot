# Headless Execution Mode

## Why

In v1, every leg of the benchmark ran inside the user's main Claude Code
session via the `Agent()` tool. That path shares one prompt cache across
all three legs, so the second and third leg read cache warm-up the first
leg paid for. The token-efficiency dimension of the scorecard is therefore
a **systematic over-estimate**: stackpilot looks cheaper than it actually
is, especially on workloads where the earlier leg established shared
context.

Shuffling the leg order per workload (runner.md §Deterministic Leg-Order
Shuffling) averages the bias across workloads but does not eliminate it.
To get a token count that answers the real question — "how much does a
cold-start stackpilot dispatch cost?" — each leg must run in its own
subprocess with its own cache.

## What M4 ships

`scripts/run-leg-headless.sh` — spawns `claude --print` as a child process
and parses the stream-json output for the usage block. Output is a single
JSON file per leg with exactly the fields the CSV row needs:

```json
{
  "leg": "stackpilot",
  "status": "ok",
  "duration_sec": 172,
  "input_tokens": 12345,
  "output_tokens": 6789,
  "cache_read_input_tokens": 0,
  "cache_creation_input_tokens": 2345,
  "total_tokens": 21479,
  "tool_uses_count": 14
}
```

Exit codes carry the leg status:
- `0` — ok
- `2` — bad arguments (treat as configuration bug, abort run)
- `3` — `claude` CLI missing (same)
- `4` — timed out after 30 min (map to `status: timed_out` in CSV)
- `5` — subprocess returned non-zero (map to `status: error`)

## What M4 does not ship yet

The script is scaffolded and internally tested against a happy-path JSONL
transcript, but it is NOT wired into SKILL.md by default. The default
dispatch path in v1 still goes through `Agent(...)`. Reason: enabling
headless mode for every run depends on:

1. **Live CLI contract check** — confirm the exact shape of the
   stream-json `result` event in the current Claude Code CLI release. If
   Anthropic renames or restructures the usage block, the parser in this
   script breaks silently and produces `total_tokens: 0`. One live run
   with a known-high-token workload will confirm or break the contract.
2. **Permissions story** — `--dangerously-skip-permissions` is required
   for unattended runs. That flag is safe in `.worktrees/bench-run/`
   where the fixture is disposable, but it is a footgun if wired into
   the main repo by accident. SKILL.md needs an explicit guard that
   headless mode is only invoked when `cwd` is a bench worktree.
3. **Cost accounting** — the headless run still bills the user's API
   key (assuming they're using API keys; for subscription they just
   eat into their rate limits). The scorecard header should print
   "headless=true" when using this path so operators understand why
   tokens jumped vs the previous in-session run.

## Flipping the default

When the above three checks pass, flip SKILL.md Step 2.2c item 3:

```
# Before (in-session Agent dispatch)
Agent(subagent_type="general-purpose", prompt=PREAMBLE + prompts[leg])

# After (headless subprocess)
bash claude-config/skills/stackpilot-bench/scripts/run-leg-headless.sh \
  .worktrees/bench-run \
  "$leg" \
  "<(echo "$PREAMBLE"; echo "$prompts[$leg]")" \
  ".stackpilot/benchmarks/runs/$RUN_TS/raw/$workload_id-$leg.json"
```

For the `stackpilot` leg the subprocess also invokes the /stackpilot flow,
so the prompt file would be the full spec/plan/architect/dev/qa wrapped
into a single driver prompt. This is the largest behavioural change in
the flip and deserves its own integration test.

## Expected impact

Two separable effects:

- **Token numbers rise across the board** — once caches aren't shared,
  the nominal `total_tokens` per leg goes up. The relative ordering
  between legs stays directionally the same, but the Δ shrinks.
- **Stackpilot's relative cost looks worse** — the v1 numbers made
  stackpilot look disproportionately cheaper because its multi-phase
  dispatch benefited most from parent cache. Expect scorecard "token
  efficiency" dimension to drop for stackpilot by 10-25 points.

These are not regressions. They are the first honest numbers the bench
has produced. Re-baseline after flipping the default.

## Non-goals for M4

- The script is **not** a general-purpose Claude Code automation wrapper.
  It exists solely to run one workload leg.
- It does **not** attempt to stream results to the main session in real
  time. The main agent polls on subprocess exit.
- It does **not** implement retries; a subprocess failure surfaces as a
  CSV row with `status: error` and the run continues (same behaviour as
  the existing dispatch error path in SKILL.md Step 2.5.2).
