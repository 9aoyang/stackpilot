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

# Run init.sh pointing at the worktree's stackpilot dir
bash "$INIT_SCRIPT" --stackpilot-dir "$STACKPILOT_DIR"

# Verify all expected files/directories exist
check "tasks/backlog.yml exists" "[ -f '$TMPDIR/tasks/backlog.yml' ]"
check "tasks/NEEDS_REVIEW.md exists" "[ -f '$TMPDIR/tasks/NEEDS_REVIEW.md' ]"
check "stackpilot.config.yml exists" "[ -f '$TMPDIR/stackpilot.config.yml' ]"
check ".git/hooks/post-checkout exists" "[ -f '$TMPDIR/.git/hooks/post-checkout' ]"
check ".git/hooks/post-checkout is executable" "[ -x '$TMPDIR/.git/hooks/post-checkout' ]"
check ".git/hooks/post-commit exists" "[ -f '$TMPDIR/.git/hooks/post-commit' ]"
check ".git/hooks/post-commit is executable" "[ -x '$TMPDIR/.git/hooks/post-commit' ]"
check ".stackpilot-path exists" "[ -f '$TMPDIR/.stackpilot-path' ]"
check ".stackpilot-path points to stackpilot dir" "[ \"\$(cat '$TMPDIR/.stackpilot-path')\" = '$STACKPILOT_DIR' ]"
check "stackpilot.config.yml has provider section" "grep -q 'provider:' '$TMPDIR/stackpilot.config.yml'"
check ".gitignore has .stackpilot-path" "grep -q '.stackpilot-path' '$TMPDIR/.gitignore'"

# Run init again to verify idempotency (no error on second run)
echo ""
echo "--- Running init.sh again (idempotency check) ---"
bash "$INIT_SCRIPT" --stackpilot-dir "$STACKPILOT_DIR"
check "idempotent: tasks/backlog.yml still exists" "[ -f '$TMPDIR/tasks/backlog.yml' ]"
check "idempotent: .git/hooks/post-checkout still executable" "[ -x '$TMPDIR/.git/hooks/post-checkout' ]"
check "idempotent: .git/hooks/post-commit still executable" "[ -x '$TMPDIR/.git/hooks/post-commit' ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
