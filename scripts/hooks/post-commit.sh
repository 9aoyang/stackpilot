#!/usr/bin/env bash
# Stackpilot post-commit hook
# Triggered by: every git commit
# Detects: new docs/specs/*.md files in this commit

set -euo pipefail

# Only run if tasks/ directory exists (stackpilot initialized)
[ -d "$(git rev-parse --show-toplevel)/tasks" ] || exit 0

ROOT="$(git rev-parse --show-toplevel)"

# Check if this commit added any new spec files
NEW_SPECS=$(git diff HEAD^ HEAD --name-only --diff-filter=A 2>/dev/null | grep "^docs/specs/.*\.md$" || true)

# If no new specs, exit silently
[ -n "$NEW_SPECS" ] || exit 0

echo "[stackpilot] New spec detected: $NEW_SPECS"
echo "[stackpilot] Running PM Agent to decompose tasks..."

claude -p "A new design spec was committed to $ROOT. Run the PM Agent: read all files in docs/specs/ and docs/superpowers/plans/, then decompose the spec into tasks and write them to tasks/backlog.yml. Use append-only semantics if backlog.yml already has tasks." \
  --allowedTools "Read,Write,Glob" \
  >> "$ROOT/tasks/pm-agent.log" 2>&1 &

echo "[stackpilot] PM Agent started in background (PID $!)"
