#!/usr/bin/env bash
# Stackpilot post-commit hook
# Triggered by: every git commit
# Detects: new .stackpilot/specs/*.md or .stackpilot/plans/*.md files in this commit

set -euo pipefail

# Only run if .stackpilot/ directory exists (stackpilot initialized)
[ -d "$(git rev-parse --show-toplevel)/.stackpilot" ] || exit 0

ROOT="$(git rev-parse --show-toplevel)"

# Check if this commit added any new spec or plan files
# For the first commit, HEAD^ doesn't exist — use git show instead
if git rev-parse HEAD^ >/dev/null 2>&1; then
  NEW_SPECS=$(git diff HEAD^ HEAD --name-only --diff-filter=A 2>/dev/null | grep "^\.stackpilot/\(specs\|plans\)/.\+\.md$" || true)
else
  # First commit — use git show to list added files
  NEW_SPECS=$(git show --name-only --diff-filter=A --format="" HEAD 2>/dev/null | grep "^\.stackpilot/\(specs\|plans\)/.\+\.md$" || true)
fi

# If no new specs, exit silently
[ -n "$NEW_SPECS" ] || exit 0

echo "[stackpilot] New spec detected: $NEW_SPECS"

# Locate stackpilot installation
STACKPILOT_DIR="$(cat "$ROOT/.stackpilot/path" 2>/dev/null || echo "")"
if [ -z "$STACKPILOT_DIR" ] || [ ! -f "$STACKPILOT_DIR/scripts/dispatch.sh" ]; then
  echo "[stackpilot] Warning: stackpilot not found — skipping PM Agent"
  exit 0
fi

echo "[stackpilot] Running PM Agent to decompose tasks..."
"$STACKPILOT_DIR/scripts/dispatch.sh" \
  --agent sp-pm \
  --prompt "A new spec was committed to $ROOT at path: $NEW_SPECS. Run the PM Agent: read the spec file, then decompose it into tasks and write them to .stackpilot/tasks/backlog.yml. Use append-only semantics if backlog.yml already has tasks." \
  --tools "Read,Write,Glob" \
  --project-dir "$ROOT" \
  --background --log "$ROOT/.stackpilot/tasks/pm-agent.log"
