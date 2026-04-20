#!/usr/bin/env bash
set -euo pipefail

# run-leg-headless.sh
# Usage: run-leg-headless.sh <worktree_path> <leg_name> <prompt_file> <output_json>
#
# Spawns `claude --print` as a subprocess to run one leg in full cache
# isolation from the main bench-driver session. Writes the leg result
# (transcript + usage block + duration) as JSON to <output_json>.
#
# This eliminates the parent-session prompt-cache leak that biased v1
# token counts. With headless mode, each leg starts cold — token counts
# reflect real stackpilot cost, not cache-warmed artifacts.
#
# Exit codes:
#   0 — success, output JSON written
#   2 — bad arguments / missing paths
#   3 — claude CLI not found on PATH
#   4 — subprocess timed out (30 min soft cap)
#   5 — subprocess returned non-zero
#
# STATUS: scaffolded 2026-04-20 as part of bench M4 milestone. Requires
# live integration testing against the real `claude --print` CLI before
# it replaces the current Agent-dispatch path in SKILL.md. See
# docs/bench-implementation.md "M4 handoff" for the checklist.

WORKTREE="${1:?Usage: run-leg-headless.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
LEG="${2:?Usage: run-leg-headless.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
PROMPT_FILE="${3:?Usage: run-leg-headless.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
OUTPUT_JSON="${4:?Usage: run-leg-headless.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"

if [[ ! -d "$WORKTREE" ]]; then
  echo "ERROR: worktree not found: $WORKTREE" >&2
  exit 2
fi
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not on PATH" >&2
  exit 3
fi

# Timeout — 30 minutes soft, enforced via `timeout(1)` if available; if not
# (BSD macOS default), fall back to gtimeout (brew coreutils). Last resort:
# run without timeout and rely on main-agent watchdog.
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout 1800"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout 1800"
fi

START_EPOCH=$(date +%s)
TMPFILE=$(mktemp -t sp-bench-leg.XXXXXX.jsonl)
trap 'rm -f "$TMPFILE"' EXIT

PROMPT_TEXT=$(cat "$PROMPT_FILE")

# --- Run claude --print with stream-json output in the worktree cwd ---
# `--output-format stream-json` emits one JSON event per line. The final
# "result" event carries the usage block we care about.
#
# `-p` passes the prompt non-interactively.
# `--dangerously-skip-permissions` — mandatory for unattended runs in a
# sandbox worktree. NEVER use in a real user repo.
set +e
(
  cd "$WORKTREE"
  $TIMEOUT_CMD claude \
    -p "$PROMPT_TEXT" \
    --output-format stream-json \
    --verbose \
    --dangerously-skip-permissions \
    > "$TMPFILE"
)
CLAUDE_EXIT=$?
set -e

END_EPOCH=$(date +%s)
DURATION_SEC=$(( END_EPOCH - START_EPOCH ))

if [[ $CLAUDE_EXIT -eq 124 ]]; then
  # timeout(1) exit on timeout
  echo "ERROR: leg '$LEG' exceeded 30-minute timeout" >&2
  cat > "$OUTPUT_JSON" <<JSON
{
  "leg": "$LEG",
  "status": "timed_out",
  "duration_sec": 1800,
  "input_tokens": null,
  "output_tokens": null,
  "cache_read_input_tokens": null,
  "cache_creation_input_tokens": null,
  "total_tokens": null,
  "tool_uses_count": null
}
JSON
  exit 4
fi

if [[ $CLAUDE_EXIT -ne 0 ]]; then
  echo "ERROR: claude subprocess exited $CLAUDE_EXIT for leg '$LEG'" >&2
  # Preserve partial transcript for post-mortem
  cp "$TMPFILE" "${OUTPUT_JSON%.json}.partial.jsonl" 2>/dev/null || true
  cat > "$OUTPUT_JSON" <<JSON
{
  "leg": "$LEG",
  "status": "error",
  "duration_sec": $DURATION_SEC,
  "input_tokens": null,
  "output_tokens": null,
  "cache_read_input_tokens": null,
  "cache_creation_input_tokens": null,
  "total_tokens": null,
  "tool_uses_count": null,
  "claude_exit_code": $CLAUDE_EXIT
}
JSON
  exit 5
fi

# --- Parse the stream-json transcript ---
# The usage block appears in the final `"type": "result"` event.
# Tool-use count = number of `"type": "tool_use"` blocks across all assistant turns.
python3 - "$TMPFILE" "$LEG" "$DURATION_SEC" "$OUTPUT_JSON" <<'PYEOF'
import sys, json

jsonl_path  = sys.argv[1]
leg         = sys.argv[2]
duration    = int(sys.argv[3])
out_path    = sys.argv[4]

input_t = output_t = cache_read = cache_creation = None
tool_uses = 0

with open(jsonl_path, 'r', encoding='utf-8', errors='replace') as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            evt = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = evt.get('type')
        # "result" event carries the aggregated usage
        if t == 'result':
            usage = evt.get('usage') or {}
            input_t        = usage.get('input_tokens')
            output_t       = usage.get('output_tokens')
            cache_read     = usage.get('cache_read_input_tokens')
            cache_creation = usage.get('cache_creation_input_tokens')
        # Tool-use events
        if t == 'assistant':
            message = evt.get('message') or {}
            for block in (message.get('content') or []):
                if isinstance(block, dict) and block.get('type') == 'tool_use':
                    tool_uses += 1

total = None
if any(v is not None for v in (input_t, output_t, cache_read, cache_creation)):
    total = sum(v for v in (input_t or 0, output_t or 0, cache_read or 0, cache_creation or 0))

result = {
    'leg': leg,
    'status': 'ok',
    'duration_sec': duration,
    'input_tokens':                input_t,
    'output_tokens':               output_t,
    'cache_read_input_tokens':     cache_read,
    'cache_creation_input_tokens': cache_creation,
    'total_tokens':                total,
    'tool_uses_count':             tool_uses,
}
with open(out_path, 'w', encoding='utf-8') as fh:
    json.dump(result, fh, indent=2)
PYEOF

echo "run-leg-headless: OK $LEG duration=${DURATION_SEC}s tokens=$(python3 -c "import json; print(json.load(open('$OUTPUT_JSON')).get('total_tokens'))")"
