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

# Resolve repo root relative to this script's location
WORKTREE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Agent source files in repo
echo "--- Agent files (claude-config/agents/) ---"
check "sp-pm.md"          "$WORKTREE_DIR/claude-config/agents/sp-pm.md"
check "sp-architect.md"   "$WORKTREE_DIR/claude-config/agents/sp-architect.md"
check "sp-dev.md"         "$WORKTREE_DIR/claude-config/agents/sp-dev.md"
check "sp-qa.md"          "$WORKTREE_DIR/claude-config/agents/sp-qa.md"
check "sp-docs.md"        "$WORKTREE_DIR/claude-config/agents/sp-docs.md"
check "sp-coordinator.md" "$WORKTREE_DIR/claude-config/agents/sp-coordinator.md"
echo ""

# 2. Skill source files in repo
echo "--- Skills (claude-config/skills/stackpilot/) ---"
check "SKILL.md"          "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md"
check "coordinator.md"    "$WORKTREE_DIR/claude-config/skills/stackpilot/coordinator.md"
echo ""

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

# 5. scripts/
echo "--- scripts/ ---"
check "scripts/init.sh"            "$WORKTREE_DIR/scripts/init.sh"
check "scripts/restore.sh"         "$WORKTREE_DIR/scripts/restore.sh"
check "scripts/dispatch.sh"        "$WORKTREE_DIR/scripts/dispatch.sh"
check "scripts/lib/config.sh"      "$WORKTREE_DIR/scripts/lib/config.sh"
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
