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

# 1. Create .stackpilot/tasks/ directory structure
mkdir -p "$PROJECT_ROOT/.stackpilot/tasks/done"
mkdir -p "$PROJECT_ROOT/.stackpilot/tasks/arch-review"

# 2a. Create .stackpilot/.gitignore (defensive: ignores runtime state even if root .gitignore is misconfigured)
if [ ! -f "$PROJECT_ROOT/.stackpilot/.gitignore" ]; then
  cp "$STACKPILOT_DIR/templates/stackpilot-inner-gitignore" "$PROJECT_ROOT/.stackpilot/.gitignore"
  echo "[stackpilot] Created .stackpilot/.gitignore"
fi

# 2. Create .stackpilot/tasks/backlog.yml if missing
if [ ! -f "$PROJECT_ROOT/.stackpilot/tasks/backlog.yml" ]; then
  cp "$STACKPILOT_DIR/templates/backlog.yml" "$PROJECT_ROOT/.stackpilot/tasks/backlog.yml"
  echo "[stackpilot] Created .stackpilot/tasks/backlog.yml"
fi

# 3. Create .stackpilot/tasks/NEEDS_REVIEW.md if missing
if [ ! -f "$PROJECT_ROOT/.stackpilot/tasks/NEEDS_REVIEW.md" ]; then
  cp "$STACKPILOT_DIR/templates/NEEDS_REVIEW.md" "$PROJECT_ROOT/.stackpilot/tasks/NEEDS_REVIEW.md"
  echo "[stackpilot] Created .stackpilot/tasks/NEEDS_REVIEW.md"
fi

if [ ! -f "$PROJECT_ROOT/.stackpilot/tasks/in-progress.yml" ]; then
  cp "$STACKPILOT_DIR/templates/in-progress.yml" "$PROJECT_ROOT/.stackpilot/tasks/in-progress.yml"
  echo "[stackpilot] Created .stackpilot/tasks/in-progress.yml"
fi

# 4. Create stackpilot.config.yml if missing — auto-detect project stack
if [ ! -f "$PROJECT_ROOT/stackpilot.config.yml" ]; then
  # Auto-detect test command from project files
  detect_test_command() {
    local dir="$1"
    # Node.js / JS / TS — check package.json for test script
    if [ -f "$dir/package.json" ]; then
      # Check if there's a test script defined
      if grep -q '"test"' "$dir/package.json" 2>/dev/null; then
        echo "npm test"
      else
        echo "npx vitest run"
      fi
      return
    fi
    # Python
    if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/setup.cfg" ]; then
      if [ -f "$dir/pyproject.toml" ] && grep -q 'pytest' "$dir/pyproject.toml" 2>/dev/null; then
        echo "pytest"
      elif [ -d "$dir/tests" ] || [ -d "$dir/test" ]; then
        echo "pytest"
      else
        echo "python -m pytest"
      fi
      return
    fi
    if [ -f "$dir/requirements.txt" ] || [ -f "$dir/Pipfile" ]; then
      echo "pytest"; return
    fi
    # Go
    if [ -f "$dir/go.mod" ]; then
      echo "go test ./..."; return
    fi
    # Rust
    if [ -f "$dir/Cargo.toml" ]; then
      echo "cargo test"; return
    fi
    # Ruby
    if [ -f "$dir/Gemfile" ]; then
      if grep -q 'rspec' "$dir/Gemfile" 2>/dev/null; then
        echo "bundle exec rspec"
      else
        echo "bundle exec rake test"
      fi
      return
    fi
    # Java / Kotlin (Maven)
    if [ -f "$dir/pom.xml" ]; then
      echo "mvn test"; return
    fi
    # Java / Kotlin (Gradle)
    if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ]; then
      echo "./gradlew test"; return
    fi
    # Elixir
    if [ -f "$dir/mix.exs" ]; then
      echo "mix test"; return
    fi
    # PHP
    if [ -f "$dir/composer.json" ]; then
      echo "./vendor/bin/phpunit"; return
    fi
    # .NET
    if ls "$dir"/*.csproj >/dev/null 2>&1 || ls "$dir"/*.sln >/dev/null 2>&1; then
      echo "dotnet test"; return
    fi
    # Fallback
    echo "npm test"
  }

  # Auto-detect provider from available CLI tools
  detect_provider() {
    if command -v claude >/dev/null 2>&1; then
      echo "claude"
    elif command -v codex >/dev/null 2>&1; then
      echo "codex"
    elif command -v gemini >/dev/null 2>&1; then
      echo "gemini"
    else
      echo "claude"
    fi
  }

  DETECTED_TEST_CMD="$(detect_test_command "$PROJECT_ROOT")"
  DETECTED_PROVIDER="$(detect_provider)"

  cat > "$PROJECT_ROOT/stackpilot.config.yml" << CFGEOF
# Stackpilot project configuration (auto-generated)
# Auto-detected from project files — edit to customize

provider:
  name: ${DETECTED_PROVIDER}             # claude | codex | gemini | custom
  # model: ~               # Override model (optional)
  # command: ~             # Required when name=custom

qa:
  coverage_threshold: 80
  test_command: ${DETECTED_TEST_CMD}

coordinator:
  worktree_limit: 3
  timeout_hours: 2

# Per-agent model routing (works with all providers: claude, codex, gemini)
models:
  sp-pm: haiku
  sp-dev: sonnet
  sp-qa: sonnet
  sp-architect: opus
  sp-docs: haiku
  sp-coordinator: sonnet
CFGEOF

  echo "[stackpilot] Created stackpilot.config.yml (auto-detected: provider=${DETECTED_PROVIDER}, test_command=${DETECTED_TEST_CMD})"

  # Validate the detected test command actually works
  echo "[stackpilot] Validating test command: ${DETECTED_TEST_CMD}..."
  # Extract the binary name from the test command
  TEST_BIN="${DETECTED_TEST_CMD%% *}"
  # Handle npx/bunx — the binary exists even if the package doesn't
  case "$TEST_BIN" in
    npx|bunx|npm|yarn|pnpm)
      if ! command -v "$TEST_BIN" >/dev/null 2>&1; then
        echo "[stackpilot] ⚠ Warning: '$TEST_BIN' not found in PATH — test_command may not work"
        echo "[stackpilot]   Edit stackpilot.config.yml to set the correct qa.test_command"
      else
        echo "[stackpilot] ✓ $TEST_BIN found"
      fi
      ;;
    *)
      if ! command -v "$TEST_BIN" >/dev/null 2>&1; then
        echo "[stackpilot] ⚠ Warning: '$TEST_BIN' not found in PATH — test_command may not work"
        echo "[stackpilot]   Edit stackpilot.config.yml to set the correct qa.test_command"
      else
        echo "[stackpilot] ✓ $TEST_BIN found"
      fi
      ;;
  esac
fi

# 5. Write .stackpilot/path so hooks can locate dispatch.sh
echo "$STACKPILOT_DIR" > "$PROJECT_ROOT/.stackpilot/path"
echo "[stackpilot] Created .stackpilot/path → $STACKPILOT_DIR"

# 5b. Write version stamp for auto-upgrade
if [ -f "$STACKPILOT_DIR/VERSION" ]; then
  cp "$STACKPILOT_DIR/VERSION" "$PROJECT_ROOT/.stackpilot/version"
  echo "[stackpilot] Wrote version: $(cat "$STACKPILOT_DIR/VERSION" | tr -d '\n')"
fi

# 6. Install git hooks
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
mkdir -p "$HOOKS_DIR"

install_hook() {
  local name="$1"
  local src="$STACKPILOT_DIR/scripts/hooks/${name}.sh"
  local dst="$HOOKS_DIR/$name"

  if [ -f "$dst" ]; then
    cp "$dst" "${dst}.bak"
    echo "[stackpilot] Backed up existing hook: ${dst}.bak"
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  echo "[stackpilot] Installed hook: .git/hooks/$name"
}

install_hook "pre-commit"
install_hook "post-checkout"
install_hook "post-commit"

# Add stackpilot runtime state to .gitignore
# specs/ and plans/ are committed (they trigger the agent pipeline)
# tasks/ and path are runtime state — always gitignored
GITIGNORE="$PROJECT_ROOT/.gitignore"

# Step 1: Replace blanket .stackpilot/ ignore with selective rules
# A blanket ignore blocks specs/ and plans/ from being committed
if grep -qE '^\.?stackpilot/?$' "$GITIGNORE" 2>/dev/null; then
  { grep -vE '^\.?stackpilot/?$' "$GITIGNORE" || true; } > "${GITIGNORE}.tmp"
  mv "${GITIGNORE}.tmp" "$GITIGNORE"
  echo "[stackpilot] Removed blanket .stackpilot/ ignore (specs/ and plans/ must be trackable)"
fi

# Step 2: Append selective rules if not already present
if ! grep -q '\.stackpilot/tasks' "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" << 'EOF'

# Stackpilot runtime state (auto-generated)
.stackpilot/tasks/
.stackpilot/path
.stackpilot/version
EOF
  echo "[stackpilot] Updated .gitignore (runtime state excluded; specs/ and plans/ are tracked)"
fi

# 8. Verify dependencies (Claude Code-specific deps only when provider=claude)
source "$STACKPILOT_DIR/scripts/lib/config.sh"
PROVIDER="$(config_get_or "provider.name" "claude" "$PROJECT_ROOT/stackpilot.config.yml")"

install_skill() {
  local name="$1" url="$2" dir="$3"
  if [ -d "$dir" ]; then
    echo "[stackpilot] ✓ $name already installed"
  else
    echo "[stackpilot] $name not found, installing..."
    if git clone "$url" "$dir" 2>/dev/null; then
      echo "[stackpilot] ✓ $name installed at $dir"
    else
      echo "[stackpilot] ⚠ Failed to install $name. Install manually:"
      echo "  git clone $url $dir"
    fi
  fi
}

if [ "$PROVIDER" = "claude" ]; then
  AUTORESEARCH_DIR="${AUTORESEARCH_DIR:-$HOME/.claude/skills/autoresearch}"
  install_skill "autoresearch" "https://github.com/uditgoenka/autoresearch" "$AUTORESEARCH_DIR"

  # Check superpowers plugin
  if [ -f "$HOME/.claude/plugins/installed_plugins.json" ] && grep -q '"superpowers@' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
    echo "[stackpilot] ✓ superpowers plugin already installed"
  else
    echo "[stackpilot] ⚠ superpowers plugin not found. Install in Claude Code:"
    echo "  /install-plugin superpowers"
  fi
else
  echo "[stackpilot] Provider: $PROVIDER (skipping Claude Code-specific dependencies)"
fi

echo ""
echo "[stackpilot] ✓ Initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Review stackpilot.config.yml (auto-configured — customize if needed)"
echo "  2. Create a design spec:  .stackpilot/specs/YYYY-MM-DD-feature-name.md"
echo "  3. Commit the spec → sp-pm auto-decomposes tasks"
echo "  4. Switch branches → Coordinator auto-starts Sprint"
