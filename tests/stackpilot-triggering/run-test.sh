#!/usr/bin/env bash
# Test Stackpilot skill triggering with a natural feature prompt.
#
# This is intentionally an integration-style harness. It is not run by default
# in CI because it requires Claude Code, but it documents and verifies the
# Superpowers-like acceptance criterion: natural feature work should trigger the
# StackPilot methodology skill before implementation tools are used.

set -euo pipefail

PROMPT_FILE="${1:-$(dirname "${BASH_SOURCE[0]}")/prompts/feature-work.txt}"
MAX_TURNS="${2:-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
TIMESTAMP="$(date +%s)"
OUTPUT_DIR="/tmp/stackpilot-tests/${TIMESTAMP}/triggering"
LOG_FILE="$OUTPUT_DIR/claude-output.json"

mkdir -p "$OUTPUT_DIR/project"
cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

cat > "$OUTPUT_DIR/project/package.json" <<'JSON'
{
  "scripts": {
    "test": "echo baseline ok"
  }
}
JSON

cd "$OUTPUT_DIR/project"

echo "=== Stackpilot Triggering Test ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Prompt: $PROMPT_FILE"
echo "Output: $LOG_FILE"

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not found"
  exit 0
fi

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

if [ -n "$TIMEOUT_BIN" ]; then
  "$TIMEOUT_BIN" 300 claude -p "$(cat "$PROMPT_FILE")" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true
else
  claude -p "$(cat "$PROMPT_FILE")" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true
fi

echo ""
echo "=== Results ==="

if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE '"skill":"([^"]*:)?stackpilot-methodology"' "$LOG_FILE"; then
  echo "PASS: StackPilot methodology Skill tool invocation found"
  TRIGGERED=true
else
  echo "FAIL: StackPilot methodology Skill tool invocation not found"
  TRIGGERED=false
fi

FIRST_SKILL_LINE="$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1 || true)"
if [ -n "$FIRST_SKILL_LINE" ]; then
  PREMATURE_TOOLS="$(head -n "$FIRST_SKILL_LINE" "$LOG_FILE" \
    | grep '"type":"tool_use"' \
    | grep -v '"name":"Skill"' \
    | grep -v '"name":"TodoWrite"' || true)"
  if [ -n "$PREMATURE_TOOLS" ]; then
    PREMATURE_UNBLOCKED=""
    PREMATURE_BLOCKED_COUNT=0
    while IFS= read -r tool_line; do
      [ -n "$tool_line" ] || continue
      TOOL_ID="$(printf '%s' "$tool_line" | jq -r '.message.content[]? | select(.type == "tool_use") | .id' 2>/dev/null | head -1 || true)"
      if [ -n "$TOOL_ID" ] && head -n "$FIRST_SKILL_LINE" "$LOG_FILE" | grep -F "\"tool_use_id\":\"$TOOL_ID\"" | grep -q 'PreToolUse.*hook error'; then
        PREMATURE_BLOCKED_COUNT=$((PREMATURE_BLOCKED_COUNT + 1))
      else
        PREMATURE_UNBLOCKED="${PREMATURE_UNBLOCKED}${tool_line}
"
      fi
    done <<EOF
$PREMATURE_TOOLS
EOF

    if [ -n "$PREMATURE_UNBLOCKED" ]; then
      echo "FAIL: successful premature tool use BEFORE Skill invocation"
      printf '%s' "$PREMATURE_UNBLOCKED" | head -5
      PREMATURE=true
    else
      echo "PASS: no successful premature tools before Skill (blocked attempts: $PREMATURE_BLOCKED_COUNT)"
      PREMATURE=false
    fi
  else
    echo "PASS: no premature tools before Skill"
    PREMATURE=false
  fi
else
  echo "FAIL: no Skill invocation; cannot check premature tools"
  PREMATURE=true
fi

echo "Full log: $LOG_FILE"

if [ "$TRIGGERED" = true ] && [ "$PREMATURE" = false ]; then
  exit 0
fi

exit 1
