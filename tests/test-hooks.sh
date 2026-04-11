#!/usr/bin/env bash
# Tests for Stackpilot git hooks

set -euo pipefail

PASS=0
FAIL=0

HOOKS_DIR="$(cd "$(dirname "$0")/../scripts/hooks" && pwd)"

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# --- File existence ---

if [ -f "$HOOKS_DIR/README.md" ]; then
  pass "hooks README exists"
else
  fail "hooks README missing"
fi

if [ -f "$HOOKS_DIR/pre-merge-commit" ]; then
  pass "pre-merge-commit hook exists"
else
  fail "pre-merge-commit hook missing"
fi

if [ -x "$HOOKS_DIR/pre-merge-commit" ]; then
  pass "pre-merge-commit is executable"
else
  fail "pre-merge-commit is not executable"
fi

# --- Behavior tests (in a temp repo) ---

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

git init -q "$TMPDIR/test-repo"
cd "$TMPDIR/test-repo"
git checkout -q -b main

# Initial commit on main
echo "init" > file.txt
git add file.txt
git commit -q -m "init"

# Create feature branch with a commit
git checkout -q -b feat/test
echo "feature" > feature.txt
git add feature.txt
git commit -q -m "feat: add feature"

# Install hook
cp "$HOOKS_DIR/pre-merge-commit" .git/hooks/pre-merge-commit
chmod +x .git/hooks/pre-merge-commit

# Save main HEAD for resets
MAIN_HEAD="$(git rev-parse HEAD)"

# Test 1: --no-ff merge on main should be BLOCKED
git checkout -q main
if git merge --no-ff feat/test -m "merge" 2>/dev/null; then
  fail "non-squash merge on main was NOT blocked"
else
  pass "non-squash merge on main was blocked"
fi
git reset --hard "$MAIN_HEAD" -q
git clean -fd -q

# Test 2: --squash merge on main should WORK (use a fresh branch)
git checkout -q main
git checkout -q -b feat/squash-test
echo "squash-feature" > squash.txt
git add squash.txt
git commit -q -m "feat: squash feature"
git checkout -q main
if git merge --squash feat/squash-test 2>/dev/null && git commit -q -m "feat: squash merge"; then
  pass "squash merge on main was allowed"
else
  fail "squash merge on main was blocked (should be allowed)"
fi
git reset --hard "$MAIN_HEAD" -q
git clean -fd -q

# Test 3: bypass via env var
git checkout -q main
if STACKPILOT_ALLOW_MERGE=1 git merge --no-ff feat/test -m "bypass merge" 2>/dev/null; then
  pass "STACKPILOT_ALLOW_MERGE=1 bypass works"
else
  fail "STACKPILOT_ALLOW_MERGE=1 bypass did not work"
fi
git reset --hard "$MAIN_HEAD" -q
git clean -fd -q

# Test 4: merge on non-main branch should be allowed
git checkout -q -b develop
git checkout -q -b feat/test2
echo "test2" > test2.txt
git add test2.txt
git commit -q -m "feat: test2"
git checkout -q develop
if git merge --no-ff feat/test2 -m "merge on develop" 2>/dev/null; then
  pass "non-squash merge on non-main branch was allowed"
else
  fail "non-squash merge on non-main branch was blocked (should be allowed)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
