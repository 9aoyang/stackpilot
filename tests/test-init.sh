#!/usr/bin/env bash
# Smoke test for scripts/init.sh

set -euo pipefail

STACKPILOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$STACKPILOT_DIR/scripts/init.sh"

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

# Create a temp directory with git init
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init --quiet
printf ".stackpilot\nnode_modules/\n" > .gitignore

# Run init.sh pointing at the worktree's stackpilot dir
bash "$INIT_SCRIPT" --stackpilot-dir "$STACKPILOT_DIR"

# Verify all expected files/directories exist
check ".stackpilot/specs exists" "[ -d '$TMPDIR/.stackpilot/specs' ]"
check ".stackpilot/plans exists" "[ -d '$TMPDIR/.stackpilot/plans' ]"
check ".stackpilot/archive not created" "[ ! -d '$TMPDIR/.stackpilot/archive' ]"
check ".stackpilot/review-patterns.md NOT created (single-file memory model)" "[ ! -f '$TMPDIR/.stackpilot/review-patterns.md' ]"
check ".stackpilot/sprint-metrics.md NOT created (single-file memory model)" "[ ! -f '$TMPDIR/.stackpilot/sprint-metrics.md' ]"
check ".stackpilot/.gitignore exists" "[ -f '$TMPDIR/.stackpilot/.gitignore' ]"
check "stackpilot.config.yml exists" "[ -f '$TMPDIR/stackpilot.config.yml' ]"
check "stackpilot.config.yml has qa section" "grep -q '^qa:$' '$TMPDIR/stackpilot.config.yml'"
check "stackpilot.config.yml has test_command" "grep -q '^  test_command:' '$TMPDIR/stackpilot.config.yml'"
check "stackpilot.config.yml has no provider section" "! grep -q '^provider:' '$TMPDIR/stackpilot.config.yml'"
check ".gitignore removed blanket .stackpilot ignore" "! grep -qE '^\\.stackpilot/?$' '$TMPDIR/.gitignore'"
check ".gitignore kept unrelated entries" "grep -q '^node_modules/$' '$TMPDIR/.gitignore'"

# Run init again to verify idempotency (no error on second run)
echo ""
echo "--- Running init.sh again (idempotency check) ---"
bash "$INIT_SCRIPT" --stackpilot-dir "$STACKPILOT_DIR"
check "idempotent: .stackpilot/specs still exists" "[ -d '$TMPDIR/.stackpilot/specs' ]"
check "idempotent: .stackpilot/plans still exists" "[ -d '$TMPDIR/.stackpilot/plans' ]"
check "idempotent: .stackpilot/archive still not created" "[ ! -d '$TMPDIR/.stackpilot/archive' ]"
check "idempotent: .stackpilot/review-patterns.md still absent" "[ ! -f '$TMPDIR/.stackpilot/review-patterns.md' ]"
check "idempotent: blanket .stackpilot ignore stays removed" "! grep -qE '^\\.stackpilot/?$' '$TMPDIR/.gitignore'"


# Legacy file migration — verify notice fires but files are never deleted
echo ""
echo "--- Legacy file migration notice ---"
echo "stale" > "$TMPDIR/.stackpilot/review-patterns.md"
echo "stale" > "$TMPDIR/.stackpilot/sprint-metrics.md"
echo "stale" > "$TMPDIR/.stackpilot/decisions.md"
MIGRATION_OUT="$(bash "$INIT_SCRIPT" --stackpilot-dir "$STACKPILOT_DIR" 2>&1)"
check "legacy review-patterns.md notice printed" "echo \"\$MIGRATION_OUT\" | grep -q 'legacy .stackpilot/review-patterns.md detected'"
check "legacy sprint-metrics.md notice printed" "echo \"\$MIGRATION_OUT\" | grep -q 'legacy .stackpilot/sprint-metrics.md detected'"
check "legacy decisions.md notice printed" "echo \"\$MIGRATION_OUT\" | grep -q 'legacy .stackpilot/decisions.md detected'"
check "legacy review-patterns.md NOT auto-deleted" "[ -f '$TMPDIR/.stackpilot/review-patterns.md' ]"
check "legacy sprint-metrics.md NOT auto-deleted" "[ -f '$TMPDIR/.stackpilot/sprint-metrics.md' ]"
check "legacy decisions.md NOT auto-deleted" "[ -f '$TMPDIR/.stackpilot/decisions.md' ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
