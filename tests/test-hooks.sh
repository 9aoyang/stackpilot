#!/usr/bin/env bash
# Smoke tests for Stackpilot git hook templates

set -uo pipefail

PASS=0
FAIL=0

HOOKS_DIR="$(cd "$(dirname "$0")/../scripts/hooks" && pwd)"

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# Helper: create a temp dir with a fake git repo structure
make_fake_repo() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.git"
  # Provide a minimal git rev-parse shim via PATH override
  mkdir -p "$dir/bin"
  cat > "$dir/bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"--show-toplevel"* ]]; then
  echo "$FAKE_ROOT"
  exit 0
fi
# Passthrough for any other git commands (not expected in these tests)
exit 1
EOF
  chmod +x "$dir/bin/git"
  echo "$dir"
}

# ─── Test 1: post-checkout with $3=0 (file checkout) exits 0 silently ───────
T1_DIR=$(make_fake_repo)
mkdir -p "$T1_DIR/tasks"
export FAKE_ROOT="$T1_DIR"
OUTPUT=$(PATH="$T1_DIR/bin:$PATH" bash "$HOOKS_DIR/post-checkout.sh" "old-sha" "new-sha" "0" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "post-checkout: \$3=0 (file checkout) exits 0 with no output"
else
  fail "post-checkout: \$3=0 (file checkout) — exit=$STATUS output='$OUTPUT'"
fi
rm -rf "$T1_DIR"

# ─── Test 2: post-checkout with $3=1 but no tasks/ dir exits 0 silently ─────
T2_DIR=$(make_fake_repo)
# No tasks/ directory created
export FAKE_ROOT="$T2_DIR"
OUTPUT=$(PATH="$T2_DIR/bin:$PATH" bash "$HOOKS_DIR/post-checkout.sh" "old-sha" "new-sha" "1" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "post-checkout: \$3=1 but no tasks/ dir exits 0 with no output"
else
  fail "post-checkout: \$3=1 no tasks/ dir — exit=$STATUS output='$OUTPUT'"
fi
rm -rf "$T2_DIR"

# ─── Test 3: post-commit with no tasks/ dir exits 0 silently ─────────────────
T3_DIR=$(make_fake_repo)
# No tasks/ directory created
export FAKE_ROOT="$T3_DIR"
OUTPUT=$(PATH="$T3_DIR/bin:$PATH" bash "$HOOKS_DIR/post-commit.sh" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "post-commit: no tasks/ dir exits 0 with no output"
else
  fail "post-commit: no tasks/ dir — exit=$STATUS output='$OUTPUT'"
fi
rm -rf "$T3_DIR"

# ─── Test 4: post-checkout with tasks/ but no .stackpilot-path warns and exits ─
T4_DIR=$(make_fake_repo)
mkdir -p "$T4_DIR/tasks"
export FAKE_ROOT="$T4_DIR"
OUTPUT=$(PATH="$T4_DIR/bin:$PATH" bash "$HOOKS_DIR/post-checkout.sh" "old-sha" "new-sha" "1" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && echo "$OUTPUT" | grep -q "stackpilot not found"; then
  pass "post-checkout: missing .stackpilot-path warns and exits 0"
else
  fail "post-checkout: missing .stackpilot-path — exit=$STATUS output='$OUTPUT'"
fi
rm -rf "$T4_DIR"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
