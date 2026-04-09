#!/usr/bin/env bash
# Smoke tests for Stackpilot v2 hook removal

set -euo pipefail

PASS=0
FAIL=0

HOOKS_DIR="$(cd "$(dirname "$0")/../scripts/hooks" && pwd)"
README_FILE="$HOOKS_DIR/README.md"

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if [ -f "$README_FILE" ]; then
  pass "hooks README exists"
else
  fail "hooks README missing"
fi

if grep -q "Removed in v2" "$README_FILE"; then
  pass "hooks README documents removal in v2"
else
  fail "hooks README does not mention v2 removal"
fi

HOOK_SCRIPTS=$(find "$HOOKS_DIR" -maxdepth 1 -name "*.sh" -type f | wc -l | tr -d ' ')
if [ "$HOOK_SCRIPTS" -eq 0 ]; then
  pass "legacy hook shell scripts are absent"
else
  fail "expected no legacy hook shell scripts, found $HOOK_SCRIPTS"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
