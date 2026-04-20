#!/usr/bin/env bash
set -euo pipefail

# run-leg-codex.sh
# Usage: run-leg-codex.sh <worktree_path> <leg_name> <prompt_file> <output_json>
#
# Runs one benchmark leg through `codex exec --json` in an isolated disposable
# worktree and writes normalized usage/duration/tool metrics to <output_json>.

WORKTREE="${1:?Usage: run-leg-codex.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
LEG="${2:?Usage: run-leg-codex.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
PROMPT_FILE="${3:?Usage: run-leg-codex.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"
OUTPUT_JSON="${4:?Usage: run-leg-codex.sh <worktree_path> <leg_name> <prompt_file> <output_json>}"

if [[ ! -d "$WORKTREE" ]]; then
  echo "ERROR: worktree not found: $WORKTREE" >&2
  exit 2
fi
WORKTREE="$(cd "$WORKTREE" && pwd)"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not on PATH" >&2
  exit 3
fi

mkdir -p "$(dirname "$OUTPUT_JSON")"

TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 1800)
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout 1800)
fi

START_EPOCH=$(date +%s)
JSONL_PATH="${OUTPUT_JSON%.json}.jsonl"
LAST_MESSAGE_PATH="${OUTPUT_JSON%.json}.last.txt"

set +e
(
  cd "$WORKTREE"
  if [[ ${#TIMEOUT_CMD[@]} -gt 0 ]]; then
    "${TIMEOUT_CMD[@]}" codex exec \
      --json \
      --ephemeral \
      --skip-git-repo-check \
      -C "$WORKTREE" \
      -o "$LAST_MESSAGE_PATH" \
      --sandbox workspace-write \
      -c 'model_reasoning_effort="low"' \
      - < "$PROMPT_FILE" \
      > "$JSONL_PATH"
  else
    codex exec \
      --json \
      --ephemeral \
      --skip-git-repo-check \
      -C "$WORKTREE" \
      -o "$LAST_MESSAGE_PATH" \
      --sandbox workspace-write \
      -c 'model_reasoning_effort="low"' \
      - < "$PROMPT_FILE" \
      > "$JSONL_PATH"
  fi
)
CODEX_EXIT=$?
set -e

END_EPOCH=$(date +%s)
DURATION_SEC=$(( END_EPOCH - START_EPOCH ))

if [[ $CODEX_EXIT -eq 124 ]]; then
  python3 - "$LEG" "$OUTPUT_JSON" "$JSONL_PATH" "$LAST_MESSAGE_PATH" <<'PYEOF'
import json
import sys

leg, out_path, jsonl_path, last_path = sys.argv[1:5]
with open(out_path, 'w', encoding='utf-8') as fh:
    json.dump({
        'leg': leg,
        'status': 'timed_out',
        'duration_sec': 1800,
        'input_tokens': None,
        'output_tokens': None,
        'cache_read_tokens': None,
        'cache_creation_tokens': None,
        'total_tokens': None,
        'tool_uses_count': None,
        'jsonl_path': jsonl_path,
        'last_message_path': last_path,
    }, fh, indent=2)
PYEOF
  echo "ERROR: codex leg '$LEG' exceeded 30-minute timeout" >&2
  exit 4
fi

if [[ $CODEX_EXIT -ne 0 ]]; then
  python3 - "$LEG" "$DURATION_SEC" "$CODEX_EXIT" "$OUTPUT_JSON" "$JSONL_PATH" "$LAST_MESSAGE_PATH" <<'PYEOF'
import json
import sys

leg, duration, exit_code, out_path, jsonl_path, last_path = sys.argv[1:7]
with open(out_path, 'w', encoding='utf-8') as fh:
    json.dump({
        'leg': leg,
        'status': 'error',
        'duration_sec': int(duration),
        'input_tokens': None,
        'output_tokens': None,
        'cache_read_tokens': None,
        'cache_creation_tokens': None,
        'total_tokens': None,
        'tool_uses_count': None,
        'codex_exit_code': int(exit_code),
        'jsonl_path': jsonl_path,
        'last_message_path': last_path,
    }, fh, indent=2)
PYEOF
  echo "ERROR: codex subprocess exited $CODEX_EXIT for leg '$LEG'" >&2
  exit 5
fi

python3 - "$JSONL_PATH" "$LEG" "$DURATION_SEC" "$OUTPUT_JSON" "$LAST_MESSAGE_PATH" <<'PYEOF'
import json
import sys

jsonl_path, leg, duration, out_path, last_path = sys.argv[1:6]

input_t = output_t = cached_input_t = None
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

        if evt.get('type') == 'turn.completed':
            usage = evt.get('usage') or {}
            input_t = usage.get('input_tokens')
            output_t = usage.get('output_tokens')
            cached_input_t = usage.get('cached_input_tokens')

        item = evt.get('item') or {}
        if evt.get('type') == 'item.completed' and item.get('type') == 'command_execution':
            tool_uses += 1

# In Codex JSONL, cached_input_tokens is a subset of input_tokens, not an
# additive field. Keep it separately for diagnostics but avoid double counting.
total = None
if input_t is not None or output_t is not None:
    total = (input_t or 0) + (output_t or 0)

with open(out_path, 'w', encoding='utf-8') as fh:
    json.dump({
        'leg': leg,
        'status': 'ok',
        'duration_sec': int(duration),
        'input_tokens': input_t,
        'output_tokens': output_t,
        'cache_read_tokens': cached_input_t,
        'cache_creation_tokens': 0,
        'total_tokens': total,
        'tool_uses_count': tool_uses,
        'jsonl_path': jsonl_path,
        'last_message_path': last_path,
    }, fh, indent=2)
PYEOF

TOKENS=$(python3 -c "import json; print(json.load(open('$OUTPUT_JSON')).get('total_tokens'))")
echo "run-leg-codex: OK $LEG duration=${DURATION_SEC}s tokens=${TOKENS}"
