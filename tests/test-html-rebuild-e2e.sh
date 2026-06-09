#!/usr/bin/env bash
# E2E smoke test for v2.0 HTML-first rebuild:
# 1. start sprint server with a slug
# 2. verify /sprints/<slug>/<artifact>.html routing works
# 3. POST a small action JSON, verify file write
# 4. POST an oversize (>64KB) body, verify 413 response
# 5. GET /api/state/<slug> returns valid JSON
# 6. stop server via --slug, verify cleanup

set -u

STACKPILOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
START="$STACKPILOT_DIR/scripts/preview/start-server.sh"
STOP="$STACKPILOT_DIR/scripts/preview/stop-server.sh"

PASS=0
FAIL=0

check() {
  local label="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

# Workspace
TMPDIR="$(mktemp -d)"
SLUG="e2e-$$"
cleanup() {
  bash "$STOP" --slug "$SLUG" --project-dir "$TMPDIR" >/dev/null 2>&1 || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

cd "$TMPDIR"
mkdir -p .stackpilot/views/"$SLUG" .stackpilot/runs/"$SLUG"/TASK-001 .stackpilot/specs
echo '{"task_id":"TASK-001","phase":"complete","wave":1}' > .stackpilot/runs/"$SLUG"/TASK-001/state.json
# Minimal criteria.md so GET /api/state has something to return
cat > .stackpilot/specs/"$SLUG"-criteria.md <<EOF
# Criteria
| ID | Description | Verify Command | Status | Notes |
|----|-------------|----------------|--------|-------|
| C1 | dummy check | echo ok | pass | |
EOF

# Sample HTML artifact (routing test target)
cat > .stackpilot/views/"$SLUG"/sample.html <<'EOF'
<!DOCTYPE html><html><body><h1>sample</h1></body></html>
EOF

# 1. Start server
SERVER_OUT=$(STACKPILOT_ROOT="$TMPDIR" bash "$START" --project-dir "$TMPDIR" --sprint-slug "$SLUG" --background 2>&1 | head -1)
PORT=$(echo "$SERVER_OUT" | sed -n 's/.*"port":[[:space:]]*\([0-9]*\).*/\1/p')

check "server started with a port" "[ -n '$PORT' ]"
check "background server does not monitor short-lived owner PID" "echo '$SERVER_OUT' | grep -q '\"owner_pid_monitored\":false'"
MARKER=".stackpilot/views/$SLUG/.server-info.json"
SERVER_PID=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$MARKER" | head -1)
SERVER_PGID=$(ps -o pgid= -p "$SERVER_PID" 2>/dev/null | tr -d ' ')
CALLER_PGID=$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')
check "background server is detached from caller process group" "[ -n '$SERVER_PGID' ] && [ '$SERVER_PGID' != '$CALLER_PGID' ]"
sleep 0.5  # let server bind

if [ -z "$PORT" ]; then
  echo "Server start output: $SERVER_OUT"
  echo "Results: $PASS passed, $FAIL failed (aborted — server start fail)"
  exit 1
fi

URL="http://127.0.0.1:$PORT"

# 2. Sprint routing serves the HTML
RESP=$(curl -sS -o /dev/null -w '%{http_code}' "$URL/sprints/$SLUG/sample.html" --max-time 5)
check "GET /sprints/<slug>/sample.html returns 200" "[ '$RESP' = '200' ]"

# 3. Action POST writes JSON
POST_RESP=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d '{"choice":"A","note":"smoke"}' "$URL/api/action/$SLUG/design-options" --max-time 5)
check "POST /api/action returns 200" "[ '$POST_RESP' = '200' ]"
check "action JSON written to disk" "[ -f .stackpilot/views/$SLUG/design-options-action.json ]"
check "action JSON contains choice=A" "grep -q '\"choice\"' .stackpilot/views/$SLUG/design-options-action.json && grep -q '\"A\"' .stackpilot/views/$SLUG/design-options-action.json"

# 4. Oversize body → 413
BIG=$(head -c 70000 /dev/zero | tr '\0' 'X')
OVERSIZE_RESP=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d "{\"junk\":\"$BIG\"}" "$URL/api/action/$SLUG/oversize" --max-time 5)
check "POST oversize body returns 413" "[ '$OVERSIZE_RESP' = '413' ]"

# 5. State endpoint returns JSON
STATE_BODY=$(curl -sS "$URL/api/state/$SLUG" --max-time 5)
check "GET /api/state returns valid JSON with tasks" "echo '$STATE_BODY' | grep -q '\"tasks\"'"
check "GET /api/state surfaces our seeded criterion" "echo '$STATE_BODY' | grep -q '\"C1\"'"

# 6. Stop server via --slug
STOP_OUT=$(bash "$STOP" --slug "$SLUG" --project-dir "$TMPDIR" 2>&1)
check "stop-server --slug reports stopped" "echo '$STOP_OUT' | grep -qE 'stopped|not_running'"
check "sprint marker removed" "[ ! -f .stackpilot/views/$SLUG/.server-info.json ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
