#!/usr/bin/env bash
# Tests for scripts/lib/version.sh — safe upgrade with user-modified file preservation

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── Setup: simulate installed stackpilot + project ──────────────────────────

CLAUDE_DIR="$TMPDIR_TEST/home/.claude"
PROJECT_DIR="$TMPDIR_TEST/project"
STACKPILOT_SRC="$TMPDIR_TEST/stackpilot-src"

# Fake HOME so version.sh writes to our temp dir
export HOME="$TMPDIR_TEST/home"

# Create source (upstream) stackpilot
mkdir -p "$STACKPILOT_SRC/claude-config/agents"
mkdir -p "$STACKPILOT_SRC/claude-config/skills/stackpilot"
mkdir -p "$STACKPILOT_SRC/scripts/hooks"
mkdir -p "$STACKPILOT_SRC/templates"

echo "0.4.0" > "$STACKPILOT_SRC/VERSION"

cat > "$STACKPILOT_SRC/claude-config/agents/sp-dev.md" << 'EOF'
---
name: sp-dev
---

New upstream content for sp-dev.
EOF

cat > "$STACKPILOT_SRC/claude-config/skills/stackpilot/SKILL.md" << 'EOF'
---
name: stackpilot
---

New upstream skill content.
EOF

cat > "$STACKPILOT_SRC/scripts/hooks/post-checkout.sh" << 'EOF'
#!/usr/bin/env bash
echo "new hook"
EOF
chmod +x "$STACKPILOT_SRC/scripts/hooks/post-checkout.sh"

cp "$REPO_DIR/templates/stackpilot-inner-gitignore" "$STACKPILOT_SRC/templates/stackpilot-inner-gitignore" 2>/dev/null || echo "*.log" > "$STACKPILOT_SRC/templates/stackpilot-inner-gitignore"

# Create installed (old) versions
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills/stackpilot"

cat > "$CLAUDE_DIR/agents/sp-dev.md" << 'EOF'
---
name: sp-dev
---

Old content that user has NOT modified.
EOF

cat > "$CLAUDE_DIR/agents/sp-qa.md" << 'EOF'
---
name: sp-qa
---

User-customized QA agent with special instructions.
EOF

cat > "$CLAUDE_DIR/skills/stackpilot/SKILL.md" << 'EOF'
---
name: stackpilot
---

User modified skill content.
EOF

# Create project
mkdir -p "$PROJECT_DIR/.stackpilot"
mkdir -p "$PROJECT_DIR/.git/hooks"
echo "0.3.0" > "$PROJECT_DIR/.stackpilot/version"
echo "old" > "$PROJECT_DIR/.stackpilot/.gitignore"

# ── Source and run ──────────────────────────────────────────────────────────

source "$REPO_DIR/scripts/lib/version.sh"
OUTPUT=$(stackpilot_check_version "$PROJECT_DIR" "$STACKPILOT_SRC" 2>&1)

# ── Test 1: version stamp updated ──────────────────────────────────────────

INSTALLED_VER=$(cat "$PROJECT_DIR/.stackpilot/version" 2>/dev/null)
if [ "$INSTALLED_VER" = "0.4.0" ]; then
  pass "version stamp updated to 0.4.0"
else
  fail "version stamp: expected 0.4.0, got '$INSTALLED_VER'"
fi

# ── Test 2: unmodified agent replaced cleanly ───────────────────────────────

if grep -q "New upstream content" "$CLAUDE_DIR/agents/sp-dev.md" 2>/dev/null; then
  pass "unmodified agent: replaced with upstream"
else
  fail "unmodified agent: not replaced"
fi

# ── Test 3: user-modified skill gets .bak backup ───────────────────────────

if [ -f "$CLAUDE_DIR/skills/stackpilot/SKILL.md.pre-upgrade.bak" ]; then
  pass "modified skill: .bak backup created"
else
  fail "modified skill: no .bak backup found"
fi

# ── Test 4: skill replaced with upstream after backup ──────────────────────

if grep -q "New upstream skill content" "$CLAUDE_DIR/skills/stackpilot/SKILL.md" 2>/dev/null; then
  pass "modified skill: replaced with upstream after backup"
else
  fail "modified skill: not replaced"
fi

# ── Test 5: removed agent (sp-qa not in source) gets cleaned up ────────────

# sp-qa exists in installed but NOT in source — should be removed
if [ ! -f "$CLAUDE_DIR/agents/sp-qa.md" ]; then
  pass "removed agent: sp-qa cleaned up"
else
  fail "removed agent: sp-qa still exists"
fi

# ── Test 6: upgrade output mentions backup ─────────────────────────────────

if echo "$OUTPUT" | grep -q "Backed up"; then
  pass "upgrade output: mentions backup"
else
  fail "upgrade output: no backup mention in '$OUTPUT'"
fi

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
