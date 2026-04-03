#!/usr/bin/env bash
# Unit tests for scripts/dispatch.sh
# Uses mock CLI binaries to verify command construction per provider.

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DISPATCH="$REPO_DIR/scripts/dispatch.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── Helper: create a mock CLI that logs its arguments ────────────────────────

make_mock_cli() {
  local name="$1"
  cat > "$TMPDIR_TEST/bin/$name" <<'MOCK'
#!/usr/bin/env bash
# Mock CLI — write all args to a log file
echo "$0 $*" >> "$MOCK_LOG"
MOCK
  chmod +x "$TMPDIR_TEST/bin/$name"
}

mkdir -p "$TMPDIR_TEST/bin"
mkdir -p "$TMPDIR_TEST/project"

MOCK_LOG="$TMPDIR_TEST/mock.log"
export MOCK_LOG

# Create a minimal agent file
mkdir -p "$TMPDIR_TEST/agents"
cat > "$TMPDIR_TEST/agents/test-agent.md" <<'EOF'
---
name: test-agent
description: A test agent
tools: Read, Write
---

You are a test agent.
EOF

# Symlink agent into expected location relative to dispatch.sh
# dispatch.sh uses $STACKPILOT_DIR/claude-config/agents/ — we override via a wrapper
make_dispatch_wrapper() {
  local provider="$1"
  local extra_config="${2:-}"

  cat > "$TMPDIR_TEST/project/stackpilot.config.yml" <<CONF
provider:
  name: $provider
$extra_config
CONF

  # Create a wrapper that overrides STACKPILOT_DIR's agent path
  mkdir -p "$TMPDIR_TEST/stackpilot/claude-config/agents"
  cp "$TMPDIR_TEST/agents/test-agent.md" "$TMPDIR_TEST/stackpilot/claude-config/agents/test-agent.md"
  mkdir -p "$TMPDIR_TEST/stackpilot/scripts/lib"
  cp "$REPO_DIR/scripts/lib/config.sh" "$TMPDIR_TEST/stackpilot/scripts/lib/config.sh"
  cp "$REPO_DIR/scripts/dispatch.sh" "$TMPDIR_TEST/stackpilot/scripts/dispatch.sh"
  chmod +x "$TMPDIR_TEST/stackpilot/scripts/dispatch.sh"
}

run_dispatch() {
  > "$MOCK_LOG"  # clear log
  PATH="$TMPDIR_TEST/bin:$PATH" "$TMPDIR_TEST/stackpilot/scripts/dispatch.sh" "$@" 2>&1
}

# ── Test 1: claude provider passes --allowedTools ─────────────────────────────

make_mock_cli "claude"
make_dispatch_wrapper "claude"

run_dispatch --agent test-agent --prompt "Do the task" --tools "Read,Write,Bash" --project-dir "$TMPDIR_TEST/project"
if grep -q "\-\-allowedTools" "$MOCK_LOG" 2>/dev/null; then
  pass "claude provider: --allowedTools present"
else
  fail "claude provider: --allowedTools missing from: $(cat "$MOCK_LOG" 2>/dev/null)"
fi

# ── Test 2: codex provider does NOT pass --allowedTools ───────────────────────

make_mock_cli "codex"
make_dispatch_wrapper "codex"

run_dispatch --agent test-agent --prompt "Do the task" --tools "Read,Write" --project-dir "$TMPDIR_TEST/project"
if grep -q "\-\-allowedTools" "$MOCK_LOG" 2>/dev/null; then
  fail "codex provider: --allowedTools should not be present"
else
  pass "codex provider: no --allowedTools"
fi

if grep -q "\-\-approval-mode" "$MOCK_LOG" 2>/dev/null; then
  pass "codex provider: --approval-mode present"
else
  fail "codex provider: --approval-mode missing"
fi

# ── Test 3: gemini provider ───────────────────────────────────────────────────

make_mock_cli "gemini"
make_dispatch_wrapper "gemini"

run_dispatch --agent test-agent --prompt "Do the task" --project-dir "$TMPDIR_TEST/project"
if grep -q "gemini" "$MOCK_LOG" 2>/dev/null; then
  pass "gemini provider: invoked gemini CLI"
else
  fail "gemini provider: gemini not invoked"
fi

# ── Test 4: custom provider uses configured command ───────────────────────────

make_mock_cli "my-tool"
make_dispatch_wrapper "custom" '  command: my-tool --yes'

run_dispatch --agent test-agent --prompt "Do the task" --project-dir "$TMPDIR_TEST/project"
if grep -q "my-tool" "$MOCK_LOG" 2>/dev/null; then
  pass "custom provider: invoked custom command"
else
  fail "custom provider: custom command not invoked"
fi

# ── Test 5: missing CLI binary exits gracefully ───────────────────────────────

make_dispatch_wrapper "claude"
# Use an isolated PATH with only basic system utils (no claude)
ISOLATED_PATH="$TMPDIR_TEST/bin:/usr/bin:/bin"
rm -f "$TMPDIR_TEST/bin/claude"

OUTPUT=$(PATH="$ISOLATED_PATH" "$TMPDIR_TEST/stackpilot/scripts/dispatch.sh" \
  --agent test-agent --prompt "Do the task" --project-dir "$TMPDIR_TEST/project" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && echo "$OUTPUT" | grep -qi "not found"; then
  pass "missing CLI: graceful exit with warning"
else
  fail "missing CLI: exit=$STATUS output='$OUTPUT'"
fi

# ── Test 6: frontmatter is stripped from prompt ───────────────────────────────

make_mock_cli "claude"
make_dispatch_wrapper "claude"

run_dispatch --agent test-agent --prompt "Task here" --project-dir "$TMPDIR_TEST/project"
if grep -q "name: test-agent" "$MOCK_LOG" 2>/dev/null; then
  fail "frontmatter NOT stripped from prompt"
else
  pass "frontmatter stripped from prompt"
fi

# ── Test 7: missing --agent errors ────────────────────────────────────────────

OUTPUT=$(PATH="$TMPDIR_TEST/bin:$PATH" "$TMPDIR_TEST/stackpilot/scripts/dispatch.sh" \
  --prompt "Do the task" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
  pass "missing --agent returns error"
else
  fail "missing --agent should error"
fi

# ── Test 8: default provider is claude when no config ─────────────────────────

make_mock_cli "claude"
rm -f "$TMPDIR_TEST/project/stackpilot.config.yml"

run_dispatch --agent test-agent --prompt "Do the task" --project-dir "$TMPDIR_TEST/project"
if grep -q "claude" "$MOCK_LOG" 2>/dev/null; then
  pass "no config: defaults to claude"
else
  fail "no config: did not default to claude"
fi

# ── Test 9: background mode ──────────────────────────────────────────────────

make_mock_cli "claude"
make_dispatch_wrapper "claude"

OUTPUT=$(run_dispatch --agent test-agent --prompt "Task" --project-dir "$TMPDIR_TEST/project" --background --log "$TMPDIR_TEST/bg.log")
sleep 0.2  # give background process a moment
if echo "$OUTPUT" | grep -q "background"; then
  pass "background mode: reports PID"
else
  fail "background mode: no background message in '$OUTPUT'"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
