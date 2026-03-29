#!/usr/bin/env bash
# Stackpilot restore — restores Claude Code configuration from this repo to ~/.claude/
# Usage: bash scripts/restore.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/claude-config"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

copy() {
  local src="$1" dst="$2"
  if $DRY_RUN; then
    echo "[dry-run] cp $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    echo "  ✓ $dst"
  fi
}

echo "[stackpilot] Restoring Claude Code configuration..."
$DRY_RUN && echo "[stackpilot] DRY RUN — no files will be written"

# Agents
echo ""
echo "Agents:"
for f in "$CONFIG_DIR/agents/"*.md; do
  [ -f "$f" ] || continue
  copy "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

# Skills
echo ""
echo "Skills:"
for f in "$CONFIG_DIR/skills/stackpilot/"*.md; do
  [ -f "$f" ] || continue
  copy "$f" "$CLAUDE_DIR/skills/stackpilot/$(basename "$f")"
done

# gstack reminder
echo ""
if [ ! -d "$CLAUDE_DIR/skills/gstack" ]; then
  echo "⚠  gstack not found. Install with:"
  echo "   git clone https://github.com/garrytan/gstack $CLAUDE_DIR/skills/gstack"
fi

echo ""
echo "[stackpilot] ✓ Agents and skills restored!"
echo ""
echo "Tip: Restore personal Claude config (CLAUDE.md, settings.json) from your dotfiles repo."
