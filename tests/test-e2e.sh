#!/usr/bin/env bash
# Stackpilot end-to-end structural verification
# Checks that all required files exist in their expected locations.

set -euo pipefail

PASS=0
FAIL=0

check() {
  local description="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description -- not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Stackpilot structural verification ==="
echo ""

# 1. Agent files in ~/.claude/agents/
echo "--- Agent files (~/.claude/agents/) ---"
check "pm-agent.md"          "$HOME/.claude/agents/pm-agent.md"
check "architect-agent.md"   "$HOME/.claude/agents/architect-agent.md"
check "dev-agent.md"         "$HOME/.claude/agents/dev-agent.md"
check "qa-agent.md"          "$HOME/.claude/agents/qa-agent.md"
check "docs-agent.md"        "$HOME/.claude/agents/docs-agent.md"
check "coordinator-agent.md" "$HOME/.claude/agents/coordinator-agent.md"
echo ""

# 2. Skills
echo "--- Skills (~/.claude/skills/stackpilot/) ---"
check "coordinator.md"    "$HOME/.claude/skills/stackpilot/coordinator.md"
check "update-gstack.md"  "$HOME/.claude/skills/stackpilot/update-gstack.md"
echo ""

# Resolve worktree root relative to this script's location
WORKTREE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 3. templates/ — expect 4 files
echo "--- templates/ (expect 4 files) ---"
TEMPLATE_COUNT=$(find "$WORKTREE_DIR/templates" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$TEMPLATE_COUNT" -eq 4 ]; then
  echo "  PASS: templates/ has 4 files (found $TEMPLATE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: templates/ should have 4 files, found $TEMPLATE_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# 4. scripts/hooks/ — expect 2 .sh files
echo "--- scripts/hooks/ (expect 2 .sh files) ---"
HOOKS_COUNT=$(find "$WORKTREE_DIR/scripts/hooks" -maxdepth 1 -name "*.sh" -type f | wc -l | tr -d ' ')
if [ "$HOOKS_COUNT" -eq 2 ]; then
  echo "  PASS: scripts/hooks/ has 2 .sh files (found $HOOKS_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/hooks/ should have 2 .sh files, found $HOOKS_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# 5. scripts/ — init.sh and update-gstack.sh
echo "--- scripts/ ---"
check "scripts/init.sh"            "$WORKTREE_DIR/scripts/init.sh"
check "scripts/update-gstack.sh"   "$WORKTREE_DIR/scripts/update-gstack.sh"
echo ""

# 6. tests/ — 2 existing test files (not counting this one)
echo "--- tests/ (expect at least 2 pre-existing test files) ---"
TESTS_COUNT=$(find "$WORKTREE_DIR/tests" -maxdepth 1 -name "test-*.sh" -type f ! -name "test-e2e.sh" | wc -l | tr -d ' ')
if [ "$TESTS_COUNT" -ge 2 ]; then
  echo "  PASS: tests/ has $TESTS_COUNT pre-existing test file(s) (>= 2)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tests/ should have >= 2 pre-existing test files (not counting test-e2e.sh), found $TESTS_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# Summary
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
