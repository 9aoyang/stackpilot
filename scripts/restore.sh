#!/usr/bin/env bash
# Stackpilot restore — restores Claude Code configuration and installs all dependencies
# Usage: bash scripts/restore.sh [--dry-run] [--skip-deps]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/claude-config"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-deps) SKIP_DEPS=true; shift ;;
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

install_skill() {
  local name="$1" url="$2" dir="$3"
  if [ -d "$dir" ]; then
    echo "  ✓ $name (already installed)"
  elif $DRY_RUN; then
    echo "  [dry-run] git clone $url → $dir"
  else
    echo "  ⏳ Installing $name..."
    if git clone "$url" "$dir" 2>/dev/null; then
      echo "  ✓ $name installed"
    else
      echo "  ⚠ Failed to install $name — check your network and retry:"
      echo "    git clone $url $dir"
    fi
  fi
}

install_plugin() {
  local name="$1"
  # Check if plugin is already installed
  if [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ] && grep -q "\"$name@" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null; then
    echo "  ✓ $name plugin (already installed)"
  elif $DRY_RUN; then
    echo "  [dry-run] claude /install-plugin $name"
  elif command -v claude >/dev/null 2>&1; then
    echo "  ⏳ Installing $name plugin..."
    claude -p "/install-plugin $name" --max-turns 1 2>/dev/null && echo "  ✓ $name plugin installed" || echo "  ⚠ Auto-install failed. Run manually in Claude Code: /install-plugin $name"
  else
    echo "  ⚠ claude CLI not found. Install $name plugin manually in Claude Code:"
    echo "    /install-plugin $name"
  fi
}

echo "[stackpilot] Restoring configuration..."
$DRY_RUN && echo "[stackpilot] DRY RUN — no files will be written"

# --- 1. Copy agents to ~/.claude/agents/ (Claude Code integration) ---
echo ""
echo "Agents (Claude Code integration — also usable via dispatch.sh for any provider):"
for f in "$CONFIG_DIR/agents/"*.md; do
  [ -f "$f" ] || continue
  copy "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

# --- 2. Copy skills to ~/.claude/skills/ (Claude Code only) ---
echo ""
echo "Skills (Claude Code only):"
for f in "$CONFIG_DIR/skills/stackpilot/"*.md; do
  [ -f "$f" ] || continue
  copy "$f" "$CLAUDE_DIR/skills/stackpilot/$(basename "$f")"
done

# --- 3. Install dependencies (Claude Code-specific) ---
if ! $SKIP_DEPS; then
  echo ""
  echo "Dependencies (Claude Code skills — skip with --skip-deps if using another provider):"
  install_skill "autoresearch" "https://github.com/uditgoenka/autoresearch" "$CLAUDE_DIR/skills/autoresearch"

  echo ""
  echo "Dependencies (Claude Code plugins):"
  install_plugin "superpowers"
  install_plugin "frontend-design"
else
  echo ""
  echo "[stackpilot] Skipping dependency installation (--skip-deps)"
fi

echo ""
echo "[stackpilot] ✓ Restore complete!"
echo ""
echo "Next steps:"
echo "  1. Initialize a project:  bash $REPO_DIR/scripts/init.sh"
echo "  2. Edit stackpilot.config.yml to set provider (claude/codex/gemini/custom)"
echo "  3. Or type /stackpilot in Claude Code to get started"
