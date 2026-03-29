#!/usr/bin/env bash
# stackpilot init
# Run from within any git project you want Stackpilot to manage.
# Usage: bash /path/to/stackpilot/scripts/init.sh [--stackpilot-dir PATH]

set -euo pipefail

STACKPILOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stackpilot-dir) STACKPILOT_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Must be run from inside a git repo
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository. Run this from your project root." >&2
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

echo "[stackpilot] Initializing Stackpilot in: $PROJECT_ROOT"

# 1. Create tasks/ directory structure
mkdir -p "$PROJECT_ROOT/tasks/done"
mkdir -p "$PROJECT_ROOT/tasks/arch-review"

# 2. Create tasks/backlog.yml if missing
if [ ! -f "$PROJECT_ROOT/tasks/backlog.yml" ]; then
  cp "$STACKPILOT_DIR/templates/backlog.yml" "$PROJECT_ROOT/tasks/backlog.yml"
  echo "[stackpilot] Created tasks/backlog.yml"
fi

# 3. Create tasks/NEEDS_REVIEW.md if missing
if [ ! -f "$PROJECT_ROOT/tasks/NEEDS_REVIEW.md" ]; then
  cp "$STACKPILOT_DIR/templates/NEEDS_REVIEW.md" "$PROJECT_ROOT/tasks/NEEDS_REVIEW.md"
  echo "[stackpilot] Created tasks/NEEDS_REVIEW.md"
fi

# 4. Create stackpilot.config.yml if missing
if [ ! -f "$PROJECT_ROOT/stackpilot.config.yml" ]; then
  cp "$STACKPILOT_DIR/templates/stackpilot.config.yml" "$PROJECT_ROOT/stackpilot.config.yml"
  echo "[stackpilot] Created stackpilot.config.yml (edit qa.test_command for your stack)"
fi

# 5. Install git hooks
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
mkdir -p "$HOOKS_DIR"

install_hook() {
  local name="$1"
  local src="$STACKPILOT_DIR/scripts/hooks/${name}.sh"
  local dst="$HOOKS_DIR/$name"

  if [ -f "$dst" ]; then
    echo "[stackpilot] WARNING: $name hook already exists — skipping (backup at ${dst}.bak)"
    cp "$dst" "${dst}.bak"
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  echo "[stackpilot] Installed hook: .git/hooks/$name"
}

install_hook "post-checkout"
install_hook "post-commit"

# 6. Verify gstack is installed
GSTACK_DIR="${GSTACK_DIR:-$HOME/.claude/skills/gstack}"
if [ ! -d "$GSTACK_DIR" ]; then
  echo ""
  echo "[stackpilot] WARNING: gstack not found at $GSTACK_DIR"
  echo "  Install with: git clone https://github.com/garrytan/gstack $GSTACK_DIR"
fi

echo ""
echo "[stackpilot] ✓ Initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Edit stackpilot.config.yml (set qa.test_command for your stack)"
echo "  2. Create a design spec:  docs/specs/YYYY-MM-DD-feature-name.md"
echo "  3. Commit the spec → PM Agent auto-decomposes tasks"
echo "  4. Switch branches → Coordinator auto-starts Sprint"
