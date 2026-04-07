#!/usr/bin/env bash
# Tests for release automation helpers

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/scripts/release.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

VERSION_FILE="$TMPDIR/VERSION"
CHANGELOG_FILE="$TMPDIR/CHANGELOG.md"

cat > "$VERSION_FILE" <<'EOF'
0.3.0
EOF

cat > "$CHANGELOG_FILE" <<'EOF'
# Changelog

## [Unreleased]

## [0.3.0] - 2026-04-07

### Added
- Automated release workflow

## [0.2.0] - 2026-04-05

### Changed
- Previous release
EOF

OUTPUT=$(bash "$RELEASE_SCRIPT" verify-version "v0.3.0" "$VERSION_FILE" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ]; then
  pass "verify-version accepts matching tag and VERSION"
else
  fail "verify-version accepts matching tag and VERSION -- exit=$STATUS output='$OUTPUT'"
fi

OUTPUT=$(bash "$RELEASE_SCRIPT" verify-version "v0.3.1" "$VERSION_FILE" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ] && echo "$OUTPUT" | grep -q "Version mismatch"; then
  pass "verify-version rejects mismatched tag and VERSION"
else
  fail "verify-version rejects mismatched tag and VERSION -- exit=$STATUS output='$OUTPUT'"
fi

OUTPUT=$(bash "$RELEASE_SCRIPT" verify-version "0.3.0" "$VERSION_FILE" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ] && echo "$OUTPUT" | grep -q "Invalid tag"; then
  pass "verify-version rejects malformed tag"
else
  fail "verify-version rejects malformed tag -- exit=$STATUS output='$OUTPUT'"
fi

OUTPUT=$(bash "$RELEASE_SCRIPT" release-notes "v0.3.0" "$CHANGELOG_FILE" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && echo "$OUTPUT" | grep -q "Automated release workflow" && ! echo "$OUTPUT" | grep -q "Previous release"; then
  pass "release-notes extracts the matching changelog section"
else
  fail "release-notes extracts the matching changelog section -- exit=$STATUS output='$OUTPUT'"
fi

OUTPUT=$(bash "$RELEASE_SCRIPT" release-notes "v9.9.9" "$CHANGELOG_FILE" 2>&1)
STATUS=$?
if [ $STATUS -eq 0 ] && [ "$OUTPUT" = "Release v9.9.9" ]; then
  pass "release-notes falls back when version is missing from changelog"
else
  fail "release-notes falls back when version is missing from changelog -- exit=$STATUS output='$OUTPUT'"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
