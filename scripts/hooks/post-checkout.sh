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

echo "[stackpilot] Branch switched — running Coordinator..."
claude -p "Run the Stackpilot Coordinator for the project at $ROOT. Follow the coordinator skill instructions." \
  --allowedTools Read --allowedTools Write --allowedTools Bash --allowedTools Glob \
  >> "$ROOT/tasks/coordinator.log" 2>&1 &

echo "[stackpilot] Coordinator started in background (PID $!)"
