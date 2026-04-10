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
check "sp-architect.md"   "$WORKTREE_DIR/claude-config/agents/sp-architect.md"
check "sp-dev.md"         "$WORKTREE_DIR/claude-config/agents/sp-dev.md"
check "sp-qa.md"          "$WORKTREE_DIR/claude-config/agents/sp-qa.md"
check "sp-docs.md"        "$WORKTREE_DIR/claude-config/agents/sp-docs.md"
if [ ! -e "$WORKTREE_DIR/claude-config/agents/sp-pm.md" ] && [ ! -e "$WORKTREE_DIR/claude-config/agents/sp-coordinator.md" ]; then
  echo "  PASS: legacy sp-pm/sp-coordinator agents removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: legacy sp-pm/sp-coordinator agents should be removed in v2"
  FAIL=$((FAIL + 1))
fi
echo ""

# 2. Skill source files in repo
echo "--- Skills (claude-config/skills/) ---"
check "stackpilot/SKILL.md"              "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md"
check "stackpilot-compete/SKILL.md"      "$WORKTREE_DIR/claude-config/skills/stackpilot-compete/SKILL.md"
check "stackpilot-sync/SKILL.md"         "$WORKTREE_DIR/claude-config/skills/stackpilot-sync/SKILL.md"
check "tdd-development/SKILL.md"         "$WORKTREE_DIR/claude-config/skills/tdd-development/SKILL.md"
check "qa-12-dimensions/SKILL.md"        "$WORKTREE_DIR/claude-config/skills/qa-12-dimensions/SKILL.md"
check "architecture-review/SKILL.md"     "$WORKTREE_DIR/claude-config/skills/architecture-review/SKILL.md"
check "systematic-debugging/SKILL.md"    "$WORKTREE_DIR/claude-config/skills/systematic-debugging/SKILL.md"
if [ ! -e "$WORKTREE_DIR/claude-config/skills/stackpilot/coordinator.md" ]; then
  echo "  PASS: legacy stackpilot/coordinator.md removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: legacy stackpilot/coordinator.md should be removed in v2"
  FAIL=$((FAIL + 1))
fi
echo ""

# 3. templates/ — expect 3 files
echo "--- templates/ (expect 3 files) ---"
TEMPLATE_COUNT=$(find "$WORKTREE_DIR/templates" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$TEMPLATE_COUNT" -eq 3 ]; then
  echo "  PASS: templates/ has 3 files (found $TEMPLATE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: templates/ should have 3 files, found $TEMPLATE_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# 4. scripts/hooks/ — v2 keeps docs only
echo "--- scripts/hooks/ (expect docs only) ---"
HOOKS_COUNT=$(find "$WORKTREE_DIR/scripts/hooks" -maxdepth 1 -name "*.sh" -type f | wc -l | tr -d ' ')
if [ "$HOOKS_COUNT" -eq 0 ]; then
  echo "  PASS: scripts/hooks/ has 0 .sh files (found $HOOKS_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/hooks/ should have 0 .sh files, found $HOOKS_COUNT"
  FAIL=$((FAIL + 1))
fi
check "scripts/hooks/README.md" "$WORKTREE_DIR/scripts/hooks/README.md"
echo ""

# 5. scripts/
echo "--- scripts/ ---"
check "scripts/init.sh"            "$WORKTREE_DIR/scripts/init.sh"
check "scripts/restore.sh"         "$WORKTREE_DIR/scripts/restore.sh"
check "scripts/release.sh"         "$WORKTREE_DIR/scripts/release.sh"
check "scripts/lib/config.sh"      "$WORKTREE_DIR/scripts/lib/config.sh"
if [ ! -e "$WORKTREE_DIR/scripts/dispatch.sh" ]; then
  echo "  PASS: scripts/dispatch.sh removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/dispatch.sh should be removed in v2"
  FAIL=$((FAIL + 1))
fi
if [ ! -e "$WORKTREE_DIR/scripts/lib/version.sh" ]; then
  echo "  PASS: scripts/lib/version.sh removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/lib/version.sh should be removed in v2"
  FAIL=$((FAIL + 1))
fi
echo ""

# 6. workflows/
echo "--- .github/workflows/ ---"
check ".github/workflows/ci.yml"       "$WORKTREE_DIR/.github/workflows/ci.yml"
check ".github/workflows/release.yml"  "$WORKTREE_DIR/.github/workflows/release.yml"
check ".claude-plugin/plugin.json"     "$WORKTREE_DIR/.claude-plugin/plugin.json"
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
