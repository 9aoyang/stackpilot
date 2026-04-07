#!/usr/bin/env bash
# Tests for scripts/hooks/pre-commit.sh — spec/plan validation

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_DIR/scripts/hooks/pre-commit.sh"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── Helper: set up a git repo with stackpilot structure ─────────────────────

setup_repo() {
  rm -rf "$TMPDIR_TEST/repo"
  mkdir -p "$TMPDIR_TEST/repo"
  cd "$TMPDIR_TEST/repo"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  mkdir -p .stackpilot/specs .stackpilot/plans
  echo "init" > README.md
  git add . && git commit -q -m "init"
  # Install the hook
  cp "$HOOK" .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
}

# ── Test 1: valid spec passes ───────────────────────────────────────────────

setup_repo
cat > .stackpilot/specs/2026-04-07-feature.md << 'EOF'
# Feature Design

## Overview

This is a well-formed spec with enough content to pass validation.
It describes a new feature that will be implemented by the dev agent.

## Requirements

- Requirement one: the system must do X
- Requirement two: the system must handle Y

## Implementation Notes

The implementation will modify files in src/ and add tests.
EOF

git add .stackpilot/specs/2026-04-07-feature.md
if git commit -q -m "add spec" 2>&1; then
  pass "valid spec: commit succeeds"
else
  fail "valid spec: commit blocked"
fi

# ── Test 2: empty spec is rejected ──────────────────────────────────────────

setup_repo
echo "# Empty" > .stackpilot/specs/2026-04-07-empty.md
git add .stackpilot/specs/2026-04-07-empty.md
if git commit -q -m "add empty spec" 2>&1; then
  fail "empty spec: commit should be blocked"
else
  pass "empty spec: commit blocked"
fi

# ── Test 3: spec with TBD placeholder is rejected ──────────────────────────

setup_repo
cat > .stackpilot/specs/2026-04-07-tbd.md << 'EOF'
# Feature

## Overview

This spec has a placeholder that should not be committed.

## Details

The implementation details are TBD pending further discussion.

## More stuff

Additional content to meet word count minimum.
EOF

git add .stackpilot/specs/2026-04-07-tbd.md
if git commit -q -m "add tbd spec" 2>&1; then
  fail "TBD spec: commit should be blocked"
else
  pass "TBD spec: commit blocked"
fi

# ── Test 4: spec with only 1 heading is rejected ───────────────────────────

setup_repo
cat > .stackpilot/specs/2026-04-07-noheadings.md << 'EOF'
# Feature Spec

This is a long enough document with many words but it only has one section
heading which does not meet the minimum requirement of two double-hash
headings. The validator should catch this and block the commit because
the spec is not well-structured enough for the PM agent to decompose.
EOF

git add .stackpilot/specs/2026-04-07-noheadings.md
if git commit -q -m "add bad spec" 2>&1; then
  fail "missing headings: commit should be blocked"
else
  pass "missing headings: commit blocked"
fi

# ── Test 5: non-spec files are not validated ────────────────────────────────

setup_repo
echo "short" > README.md
git add README.md
if git commit -q -m "update readme" 2>&1; then
  pass "non-spec file: commit not blocked"
else
  fail "non-spec file: commit should not be blocked"
fi

# ── Test 6: plan files are also validated ───────────────────────────────────

setup_repo
echo "# Short" > .stackpilot/plans/2026-04-07-plan.md
git add .stackpilot/plans/2026-04-07-plan.md
if git commit -q -m "add short plan" 2>&1; then
  fail "short plan: commit should be blocked"
else
  pass "short plan: commit blocked"
fi

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
