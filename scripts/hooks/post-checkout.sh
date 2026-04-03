#!/usr/bin/env bash
# Stackpilot post-checkout hook
# Triggered by: git checkout / git switch
# Arg $3: 1 = branch checkout, 0 = file checkout — only run on branch checkout

set -euo pipefail

# Only run on branch checkouts (not file checkouts)
[ "${3:-0}" = "1" ] || exit 0

# Only run if tasks/ directory exists (stackpilot initialized)
[ -d "$(git rev-parse --show-toplevel)/tasks" ] || exit 0

ROOT="$(git rev-parse --show-toplevel)"

# Locate stackpilot installation
STACKPILOT_DIR="$(cat "$ROOT/.stackpilot-path" 2>/dev/null || echo "")"
if [ -z "$STACKPILOT_DIR" ] || [ ! -f "$STACKPILOT_DIR/scripts/dispatch.sh" ]; then
  echo "[stackpilot] Warning: stackpilot not found — skipping Coordinator"
  exit 0
fi

echo "[stackpilot] Branch switched — running Coordinator..."
"$STACKPILOT_DIR/scripts/dispatch.sh" \
  --agent coordinator-agent \
  --prompt "Run the Stackpilot Coordinator for the project at $ROOT. Follow the coordinator skill instructions." \
  --tools "Read,Write,Bash,Glob" \
  --project-dir "$ROOT" \
  --background --log "$ROOT/tasks/coordinator.log"
