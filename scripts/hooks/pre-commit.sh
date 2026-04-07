#!/usr/bin/env bash
# Stackpilot pre-commit hook
# Validates spec and plan files before allowing commit.
# Prevents malformed files from triggering the PM agent unnecessarily.

set -euo pipefail

# Only run if .stackpilot/ directory exists (stackpilot initialized)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[ -n "$ROOT" ] && [ -d "$ROOT/.stackpilot" ] || exit 0

# Check staged spec/plan files
STAGED_SPECS=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep "^\.stackpilot/\(specs\|plans\)/.\+\.md$" || true)

[ -n "$STAGED_SPECS" ] || exit 0

ERRORS=0

for spec_file in $STAGED_SPECS; do
  full_path="$ROOT/$spec_file"
  [ -f "$full_path" ] || continue

  # Check 1: File is not empty
  word_count=$(wc -w < "$full_path" | tr -d '[:space:]')
  if [ "$word_count" -lt 30 ]; then
    echo "[stackpilot] ✗ $spec_file: too short ($word_count words, minimum 30)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check 2: Has at least 2 markdown headings (## sections)
  heading_count=$(grep '^## ' "$full_path" 2>/dev/null | wc -l | tr -d '[:space:]')
  if [ "$heading_count" -lt 2 ]; then
    echo "[stackpilot] ✗ $spec_file: needs at least 2 sections (## headings), found $heading_count"
    ERRORS=$((ERRORS + 1))
  fi

  # Check 3: No placeholder text
  placeholders=$(grep -inE '\bTBD\b|\bTODO\b|\bFIXME\b|\bplaceholder\b' "$full_path" 2>/dev/null | head -3 || true)
  if [ -n "$placeholders" ]; then
    echo "[stackpilot] ✗ $spec_file: contains placeholders:"
    echo "$placeholders" | sed 's/^/    /'
    ERRORS=$((ERRORS + 1))
  fi

  if [ "$ERRORS" -eq 0 ]; then
    echo "[stackpilot] ✓ $spec_file validated"
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "[stackpilot] Commit blocked: $ERRORS spec/plan file(s) failed validation."
  echo "[stackpilot] Fix the issues above, then retry your commit."
  exit 1
fi

exit 0
