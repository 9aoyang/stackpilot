#!/usr/bin/env bash
# Stackpilot version check & auto-upgrade
# Source this from hooks to auto-upgrade when stackpilot has been updated.

# Usage (from any hook):
#   source "$STACKPILOT_DIR/scripts/lib/version.sh"
#   stackpilot_check_version "$ROOT" "$STACKPILOT_DIR"

stackpilot_check_version() {
  local project_root="$1"
  local stackpilot_dir="$2"
  local installed_version current_version

  installed_version="$(cat "$project_root/.stackpilot/version" 2>/dev/null || echo "")"
  current_version="$(cat "$stackpilot_dir/VERSION" 2>/dev/null || echo "")"

  # No version file in stackpilot source — skip check
  [ -n "$current_version" ] || return 0

  # Versions match — nothing to do
  [ "$installed_version" != "$current_version" ] || return 0

  echo "[stackpilot] Version mismatch: installed=${installed_version:-<none>} current=${current_version}"
  echo "[stackpilot] Auto-upgrading..."

  local claude_dir="$HOME/.claude"

  # --- 1. Re-install hooks (with backup) ---
  local hooks_dir="$project_root/.git/hooks"
  for hook_src in "$stackpilot_dir/scripts/hooks/"*.sh; do
    [ -f "$hook_src" ] || continue
    local hook_name
    hook_name="$(basename "$hook_src" .sh)"
    local dst="$hooks_dir/$hook_name"
    if [ -f "$dst" ]; then
      cp "$dst" "${dst}.pre-upgrade.bak"
    fi
    cp "$hook_src" "$dst"
    chmod +x "$dst"
  done

  # --- 2. Re-install agents: preserve user-customized files ---
  mkdir -p "$claude_dir/agents"
  for f in "$stackpilot_dir/claude-config/agents/"*.md; do
    [ -f "$f" ] || continue
    local base_name
    base_name="$(basename "$f")"
    local dst="$claude_dir/agents/$base_name"
    if [ -f "$dst" ] && ! diff -q "$f" "$dst" >/dev/null 2>&1; then
      # File exists and differs — user may have customized it
      cp "$dst" "${dst}.pre-upgrade.bak"
      echo "[stackpilot] Backed up modified agent: $base_name → ${base_name}.pre-upgrade.bak"
    fi
    cp "$f" "$dst"
  done
  # Clean up agents that no longer exist in source
  for installed in "$claude_dir/agents/sp-"*.md; do
    [ -f "$installed" ] || continue
    local base_name
    base_name="$(basename "$installed")"
    if [ ! -f "$stackpilot_dir/claude-config/agents/$base_name" ]; then
      rm -f "$installed"
    fi
  done

  # --- 3. Re-install skills: preserve user-customized files ---
  mkdir -p "$claude_dir/skills/stackpilot"
  for f in "$stackpilot_dir/claude-config/skills/stackpilot/"*.md; do
    [ -f "$f" ] || continue
    local base_name
    base_name="$(basename "$f")"
    local dst="$claude_dir/skills/stackpilot/$base_name"
    if [ -f "$dst" ] && ! diff -q "$f" "$dst" >/dev/null 2>&1; then
      cp "$dst" "${dst}.pre-upgrade.bak"
      echo "[stackpilot] Backed up modified skill: $base_name → ${base_name}.pre-upgrade.bak"
    fi
    cp "$f" "$dst"
  done
  # Clean up skills that no longer exist in source
  for installed in "$claude_dir/skills/stackpilot/"*.md; do
    [ -f "$installed" ] || continue
    local base_name
    base_name="$(basename "$installed")"
    if [ ! -f "$stackpilot_dir/claude-config/skills/stackpilot/$base_name" ]; then
      rm -f "$installed"
    fi
  done

  # --- 4. Update inner .gitignore (may have new entries) ---
  local inner_gitignore_src="$stackpilot_dir/templates/stackpilot-inner-gitignore"
  if [ -f "$inner_gitignore_src" ]; then
    cp "$inner_gitignore_src" "$project_root/.stackpilot/.gitignore"
  fi

  # --- 5. Update version stamp ---
  echo "$current_version" > "$project_root/.stackpilot/version"

  echo "[stackpilot] Upgraded to v${current_version} (hooks, agents, skills)"
}
