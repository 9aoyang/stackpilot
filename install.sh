#!/usr/bin/env bash
# Stackpilot one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
set -euo pipefail

STACKPILOT_DIR="${STACKPILOT_DIR:-$HOME/.stackpilot}"
CLAUDE_DIR="$HOME/.claude"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stackpilot Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- 1. Clone or update Stackpilot ---
if [ -d "$STACKPILOT_DIR/.git" ]; then
  echo "[1/3] Updating Stackpilot..."
  git -C "$STACKPILOT_DIR" pull --ff-only origin main 2>/dev/null || true
else
  echo "[1/3] Installing Stackpilot..."
  git clone https://github.com/9aoyang/stackpilot.git "$STACKPILOT_DIR"
fi

# --- 2. Copy agents + skills ---
echo "[2/3] Installing agents and skills..."
mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills/stackpilot"

for f in "$STACKPILOT_DIR/claude-config/agents/"*.md; do
  [ -f "$f" ] && cp "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

for f in "$STACKPILOT_DIR/claude-config/skills/stackpilot/"*.md; do
  [ -f "$f" ] && cp "$f" "$CLAUDE_DIR/skills/stackpilot/$(basename "$f")"
done

# --- 3. Install dependencies ---
echo "[3/3] Installing dependencies..."

install_skill() {
  local name="$1" url="$2" dir="$3"
  if [ -d "$dir" ]; then
    echo "  ✓ $name"
  else
    git clone "$url" "$dir" 2>/dev/null && echo "  ✓ $name" || echo "  ⚠ $name failed — run: git clone $url $dir"
  fi
}

install_skill "autoresearch" "https://github.com/uditgoenka/autoresearch" "$CLAUDE_DIR/skills/autoresearch"

check_plugin() {
  local name="$1"
  if [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ] && grep -q "\"$name@" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null; then
    echo "  ✓ $name plugin"
  else
    echo "  ⚠ $name plugin — run in Claude Code: /install-plugin $name"
  fi
}

check_plugin "superpowers"
check_plugin "frontend-design"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Stackpilot installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  cd /your/project"
echo "  bash $STACKPILOT_DIR/scripts/init.sh"
echo "  # or type /stackpilot in Claude Code"
