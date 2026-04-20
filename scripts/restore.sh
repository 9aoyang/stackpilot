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

# --- 1. Install agents to ~/.claude/agents/ ---
echo ""
echo "Agents (Claude Code integration):"
if $DRY_RUN; then
  echo "[dry-run] rm sp-*.md from $CLAUDE_DIR/agents/"
  echo "[dry-run] cp agents from $CONFIG_DIR/agents/"
else
  rm -f "$CLAUDE_DIR/agents/sp-"*.md
  mkdir -p "$CLAUDE_DIR/agents"
  for f in "$CONFIG_DIR/agents/"*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
    echo "  ✓ $(basename "$f")"
  done
fi

# --- 2. Install skills to ~/.claude/skills/ ---
echo ""
echo "Skills (Claude Code only):"
if $DRY_RUN; then
  if [ -L "$CLAUDE_DIR/skills" ]; then
    echo "[dry-run] $CLAUDE_DIR/skills externally managed — would skip direct skill copy"
  else
    echo "[dry-run] rm -rf stackpilot* skills from $CLAUDE_DIR/skills/"
    echo "[dry-run] cp skills from $CONFIG_DIR/skills/"
  fi
elif [ -L "$CLAUDE_DIR/skills" ]; then
  echo "  ⚠ $CLAUDE_DIR/skills is externally managed; skipping direct skill copy"
  echo "    Run skillshare sync from your skillshare source instead."
else
  # Remove old stackpilot skills
  rm -rf "$CLAUDE_DIR/skills/stackpilot" "$CLAUDE_DIR/skills/stackpilot-"*
  rm -rf "$CLAUDE_DIR/skills/tdd-development" "$CLAUDE_DIR/skills/qa-12-dimensions" "$CLAUDE_DIR/skills/architecture-review"
  # Install each skill directory (symlink to preserve references/ structure)
  for skill_dir in "$CONFIG_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    ln -sf "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
    echo "  ✓ $skill_name"
  done
fi

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

# --- 4. Install post-commit hook for auto skill sync ---
echo ""
echo "Git hooks (auto skill sync):"
HOOK_SRC="$REPO_DIR/scripts/hooks/post-commit"
HOOK_DST="$REPO_DIR/.git/hooks/post-commit"
if [ -f "$HOOK_SRC" ]; then
  if $DRY_RUN; then
    echo "  [dry-run] install post-commit hook"
  elif [ -f "$HOOK_DST" ] && ! grep -q "sync-skills" "$HOOK_DST" 2>/dev/null; then
    echo "  ⚠ Existing post-commit hook found — append manually or run:"
    echo "    cat $HOOK_SRC >> $HOOK_DST"
  else
    cp "$HOOK_SRC" "$HOOK_DST"
    chmod +x "$HOOK_DST"
    echo "  ✓ post-commit (auto skill sync)"
  fi
fi

echo ""
echo "[stackpilot] ✓ Restore complete!"
echo ""
echo "Next steps:"
echo "  1. Initialize a project:  bash $REPO_DIR/scripts/init.sh"
echo "  2. Or type /stackpilot in Claude Code to get started"
