#!/usr/bin/env bash
# stackpilot init (v2)
# Run from within any git project you want Stackpilot to manage.
# Usage: bash /path/to/stackpilot/scripts/init.sh

set -euo pipefail

STACKPILOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Must be run from inside a git repo
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository. Run this from your project root." >&2
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

echo "[stackpilot] Initializing Stackpilot in: $PROJECT_ROOT"

# 1. Create .stackpilot/ directory structure (specs, plans — tasks are tracked by Claude Code natively)
mkdir -p "$PROJECT_ROOT/.stackpilot/specs"
mkdir -p "$PROJECT_ROOT/.stackpilot/plans"

# 2. Legacy memory files (pre-single-file model) — notice only, never delete
for legacy in review-patterns.md sprint-metrics.md decisions.md; do
  if [ -f "$PROJECT_ROOT/.stackpilot/$legacy" ]; then
    echo "[stackpilot] legacy .stackpilot/$legacy detected — content can be merged into ARCHITECTURE.md; file is no longer used"
  fi
done

# 3. Create or update .stackpilot/.gitignore
if [ ! -f "$PROJECT_ROOT/.stackpilot/.gitignore" ]; then
  cp "$STACKPILOT_DIR/templates/stackpilot-inner-gitignore" "$PROJECT_ROOT/.stackpilot/.gitignore"
  echo "[stackpilot] Created .stackpilot/.gitignore"
fi

# 3a. Ensure v2.0 HTML view layer (views/) is gitignored — idempotent for upgrades
if [ -f "$PROJECT_ROOT/.stackpilot/.gitignore" ] && ! grep -qE '^views/?$' "$PROJECT_ROOT/.stackpilot/.gitignore" 2>/dev/null; then
  printf '\n# v2.0 HTML view layer (generated, regenerable)\nviews/\n' >> "$PROJECT_ROOT/.stackpilot/.gitignore"
  echo "[stackpilot] Added views/ to .stackpilot/.gitignore (v2.0 HTML views)"
fi

# 4. Create stackpilot.config.yml if missing — auto-detect test command
if [ ! -f "$PROJECT_ROOT/stackpilot.config.yml" ]; then
  detect_test_command() {
    local dir="$1"
    if [ -f "$dir/package.json" ]; then
      if grep -q '"test"' "$dir/package.json" 2>/dev/null; then
        echo "npm test"
      else
        echo "npx vitest run"
      fi
      return
    fi
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
    if [ -f "$dir/go.mod" ]; then
      echo "go test ./..."; return
    fi
    if [ -f "$dir/Cargo.toml" ]; then
      echo "cargo test"; return
    fi
    if [ -f "$dir/Gemfile" ]; then
      if grep -q 'rspec' "$dir/Gemfile" 2>/dev/null; then
        echo "bundle exec rspec"
      else
        echo "bundle exec rake test"
      fi
      return
    fi
    if [ -f "$dir/pom.xml" ]; then
      echo "mvn test"; return
    fi
    if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ]; then
      echo "./gradlew test"; return
    fi
    if [ -f "$dir/mix.exs" ]; then
      echo "mix test"; return
    fi
    if [ -f "$dir/composer.json" ]; then
      echo "./vendor/bin/phpunit"; return
    fi
    if ls "$dir"/*.csproj >/dev/null 2>&1 || ls "$dir"/*.sln >/dev/null 2>&1; then
      echo "dotnet test"; return
    fi
    echo "npm test"
  }

  DETECTED_TEST_CMD="$(detect_test_command "$PROJECT_ROOT")"

  cat > "$PROJECT_ROOT/stackpilot.config.yml" << CFGEOF
# Stackpilot project configuration (auto-generated)

qa:
  coverage_threshold: 80
  test_command: ${DETECTED_TEST_CMD}
CFGEOF

  echo "[stackpilot] Created stackpilot.config.yml (test_command=${DETECTED_TEST_CMD})"

  # Validate the detected test command
  TEST_BIN="${DETECTED_TEST_CMD%% *}"
  if ! command -v "$TEST_BIN" >/dev/null 2>&1; then
    echo "[stackpilot] ⚠ Warning: '$TEST_BIN' not found in PATH — test_command may not work"
    echo "[stackpilot]   Edit stackpilot.config.yml to set the correct qa.test_command"
  else
    echo "[stackpilot] ✓ $TEST_BIN found"
  fi
fi

# 6. Update .gitignore — ensure specs/ and plans/ are trackable
GITIGNORE="$PROJECT_ROOT/.gitignore"

# Remove blanket .stackpilot/ ignore if present
if grep -qE '^\.?stackpilot/?$' "$GITIGNORE" 2>/dev/null; then
  { grep -vE '^\.?stackpilot/?$' "$GITIGNORE" || true; } > "${GITIGNORE}.tmp"
  mv "${GITIGNORE}.tmp" "$GITIGNORE"
  echo "[stackpilot] Removed blanket .stackpilot/ ignore (specs/ and plans/ must be trackable)"
fi

# 7. Install git hooks
HOOKS_SRC="$STACKPILOT_DIR/scripts/hooks"
HOOKS_DST="$PROJECT_ROOT/.git/hooks"

for hook in "$HOOKS_SRC"/pre-merge-commit; do
  [ -f "$hook" ] || continue
  hook_name="$(basename "$hook")"
  if [ -f "$HOOKS_DST/$hook_name" ] && ! grep -q "stackpilot" "$HOOKS_DST/$hook_name" 2>/dev/null; then
    echo "[stackpilot] ⚠ Existing $hook_name hook found — skipping (add manually)"
  else
    cp "$hook" "$HOOKS_DST/$hook_name"
    chmod +x "$HOOKS_DST/$hook_name"
    echo "[stackpilot] ✓ Installed $hook_name hook"
  fi
done

echo ""
echo "[stackpilot] ✓ Initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Review stackpilot.config.yml (auto-configured — customize if needed)"
echo "  2. Run /stackpilot to start building"
