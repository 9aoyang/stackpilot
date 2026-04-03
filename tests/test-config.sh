#!/usr/bin/env bash
# Unit tests for scripts/lib/config.sh

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

SCRIPT_DIR="$(cd "$(dirname "$0")/../scripts" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── config_get tests ─────────────────────────────────────────────────────────

cat > "$TMPDIR_TEST/config.yml" <<'EOF'
provider:
  name: claude
  model: opus
  command: my-tool --flag

qa:
  coverage_threshold: 80
  test_command: npm test

coordinator:
  worktree_limit: 3
  timeout_hours: 2
EOF

# Test: nested key
VAL=$(config_get "provider.name" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "claude" ] && pass "config_get provider.name = claude" || fail "config_get provider.name got '$VAL'"

VAL=$(config_get "provider.model" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "opus" ] && pass "config_get provider.model = opus" || fail "config_get provider.model got '$VAL'"

VAL=$(config_get "provider.command" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "my-tool --flag" ] && pass "config_get provider.command" || fail "config_get provider.command got '$VAL'"

VAL=$(config_get "qa.coverage_threshold" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "80" ] && pass "config_get qa.coverage_threshold = 80" || fail "config_get qa.coverage_threshold got '$VAL'"

VAL=$(config_get "coordinator.timeout_hours" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "2" ] && pass "config_get coordinator.timeout_hours = 2" || fail "config_get coordinator.timeout_hours got '$VAL'"

# Test: value with inline comment is stripped
cat > "$TMPDIR_TEST/config-comments.yml" <<'EOF'
provider:
  name: claude             # claude | codex | gemini | custom
  model: opus              # optional override
EOF

VAL=$(config_get "provider.name" "$TMPDIR_TEST/config-comments.yml")
[ "$VAL" = "claude" ] && pass "config_get strips inline comment" || fail "config_get inline comment got '$VAL'"

# Test: missing key returns empty
VAL=$(config_get "provider.nonexistent" "$TMPDIR_TEST/config.yml")
[ -z "$VAL" ] && pass "config_get missing key returns empty" || fail "config_get missing key got '$VAL'"

# Test: missing file returns error
config_get "provider.name" "$TMPDIR_TEST/nonexistent.yml" 2>/dev/null
[ $? -ne 0 ] && pass "config_get missing file returns error" || fail "config_get missing file did not error"

# ── config_get_or tests ──────────────────────────────────────────────────────

VAL=$(config_get_or "provider.name" "fallback" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "claude" ] && pass "config_get_or existing key returns value" || fail "config_get_or existing got '$VAL'"

VAL=$(config_get_or "provider.nonexistent" "fallback" "$TMPDIR_TEST/config.yml")
[ "$VAL" = "fallback" ] && pass "config_get_or missing key returns default" || fail "config_get_or missing got '$VAL'"

# Test: tilde (~) treated as empty
cat > "$TMPDIR_TEST/config-tilde.yml" <<'EOF'
provider:
  name: claude
  model: ~
EOF

VAL=$(config_get_or "provider.model" "default-model" "$TMPDIR_TEST/config-tilde.yml")
[ "$VAL" = "default-model" ] && pass "config_get_or tilde returns default" || fail "config_get_or tilde got '$VAL'"

# Test: missing config file returns default
VAL=$(config_get_or "provider.name" "claude" "/dev/null")
[ "$VAL" = "claude" ] && pass "config_get_or /dev/null returns default" || fail "config_get_or /dev/null got '$VAL'"

# ── strip_frontmatter tests ─────────────────────────────────────────────────

cat > "$TMPDIR_TEST/agent.md" <<'EOF'
---
name: test-agent
description: A test agent
tools: Read, Write, Bash
---

# Test Agent

You are a test agent. Do the thing.
EOF

BODY=$(strip_frontmatter "$TMPDIR_TEST/agent.md")
echo "$BODY" | grep -q "# Test Agent" && pass "strip_frontmatter keeps body" || fail "strip_frontmatter lost body"
echo "$BODY" | grep -q "name: test-agent" && fail "strip_frontmatter kept frontmatter" || pass "strip_frontmatter removes frontmatter"
echo "$BODY" | grep -q "^---" && fail "strip_frontmatter kept delimiters" || pass "strip_frontmatter removes delimiters"

# Test: file without frontmatter
cat > "$TMPDIR_TEST/no-fm.md" <<'EOF'
# No Frontmatter

Just content.
EOF

BODY=$(strip_frontmatter "$TMPDIR_TEST/no-fm.md")
echo "$BODY" | grep -q "# No Frontmatter" && pass "strip_frontmatter handles no-frontmatter file" || fail "strip_frontmatter broke on no-frontmatter"

# ── get_frontmatter_field tests ──────────────────────────────────────────────

VAL=$(get_frontmatter_field "$TMPDIR_TEST/agent.md" "name")
[ "$VAL" = "test-agent" ] && pass "get_frontmatter_field name" || fail "get_frontmatter_field name got '$VAL'"

VAL=$(get_frontmatter_field "$TMPDIR_TEST/agent.md" "tools")
[ "$VAL" = "Read, Write, Bash" ] && pass "get_frontmatter_field tools" || fail "get_frontmatter_field tools got '$VAL'"

VAL=$(get_frontmatter_field "$TMPDIR_TEST/agent.md" "missing" 2>/dev/null)
[ -z "$VAL" ] && pass "get_frontmatter_field missing field" || fail "get_frontmatter_field missing got '$VAL'"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
