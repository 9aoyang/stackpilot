#!/usr/bin/env bash
# Stackpilot end-to-end structural verification
# Checks that all required files exist in their expected locations.

set -euo pipefail

PASS=0
FAIL=0

check() {
  local description="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description -- not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Stackpilot structural verification ==="
echo ""

# Resolve repo root relative to this script's location
WORKTREE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Agent source files in repo
echo "--- Agent files (claude-config/agents/) ---"
check "sp-architect.md"   "$WORKTREE_DIR/claude-config/agents/sp-architect.md"
check "sp-dev.md"         "$WORKTREE_DIR/claude-config/agents/sp-dev.md"
check "sp-qa.md"          "$WORKTREE_DIR/claude-config/agents/sp-qa.md"
check "sp-docs.md"        "$WORKTREE_DIR/claude-config/agents/sp-docs.md"
echo ""

# 1b. Codex-native agent source files in repo
echo "--- Codex agent files (codex-config/agents/) ---"
check "codex sp-architect.md" "$WORKTREE_DIR/codex-config/agents/sp-architect.md"
check "codex sp-dev.md"       "$WORKTREE_DIR/codex-config/agents/sp-dev.md"
check "codex sp-qa.md"        "$WORKTREE_DIR/codex-config/agents/sp-qa.md"
check "codex sp-docs.md"      "$WORKTREE_DIR/codex-config/agents/sp-docs.md"
check "shared codex dispatch reference" "$WORKTREE_DIR/claude-config/skills/stackpilot/references/codex-dispatch.md"
echo ""

# 2. Skill source files in repo
echo "--- Skills (claude-config/skills/) ---"
check "stackpilot/SKILL.md"              "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md"
check "stackpilot-compete/SKILL.md"      "$WORKTREE_DIR/claude-config/skills/stackpilot-compete/SKILL.md"
check "stackpilot-sync/SKILL.md"         "$WORKTREE_DIR/claude-config/skills/stackpilot-sync/SKILL.md"
check "tdd-development/SKILL.md"         "$WORKTREE_DIR/claude-config/skills/tdd-development/SKILL.md"
check "qa-12-dimensions/SKILL.md"        "$WORKTREE_DIR/claude-config/skills/qa-12-dimensions/SKILL.md"
check "architecture-review/SKILL.md"     "$WORKTREE_DIR/claude-config/skills/architecture-review/SKILL.md"
check "systematic-debugging/SKILL.md"    "$WORKTREE_DIR/claude-config/skills/systematic-debugging/SKILL.md"
if [ ! -e "$WORKTREE_DIR/claude-config/skills/stackpilot/coordinator.md" ]; then
  echo "  PASS: legacy stackpilot/coordinator.md removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: legacy stackpilot/coordinator.md should be removed in v2"
  FAIL=$((FAIL + 1))
fi
echo ""

# 3. templates/ — expect 2 files (stackpilot.config.yml, stackpilot-inner-gitignore)
echo "--- templates/ (expect 2 files) ---"
TEMPLATE_COUNT=$(find "$WORKTREE_DIR/templates" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$TEMPLATE_COUNT" -eq 2 ]; then
  echo "  PASS: templates/ has 2 files (found $TEMPLATE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: templates/ should have 2 files, found $TEMPLATE_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# 4. scripts/hooks/ — v2 keeps docs only
echo "--- scripts/hooks/ (expect docs only) ---"
HOOKS_COUNT=$(find "$WORKTREE_DIR/scripts/hooks" -maxdepth 1 -name "*.sh" -type f | wc -l | tr -d ' ')
if [ "$HOOKS_COUNT" -eq 0 ]; then
  echo "  PASS: scripts/hooks/ has 0 .sh files (found $HOOKS_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/hooks/ should have 0 .sh files, found $HOOKS_COUNT"
  FAIL=$((FAIL + 1))
fi
check "scripts/hooks/README.md" "$WORKTREE_DIR/scripts/hooks/README.md"
echo ""

# 5. scripts/
echo "--- scripts/ ---"
check "scripts/init.sh"            "$WORKTREE_DIR/scripts/init.sh"
check "scripts/restore.sh"         "$WORKTREE_DIR/scripts/restore.sh"
check "scripts/release.sh"         "$WORKTREE_DIR/scripts/release.sh"
check "scripts/lib/config.sh"      "$WORKTREE_DIR/scripts/lib/config.sh"
if [ ! -e "$WORKTREE_DIR/scripts/dispatch.sh" ]; then
  echo "  PASS: scripts/dispatch.sh removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/dispatch.sh should be removed in v2"
  FAIL=$((FAIL + 1))
fi
if [ ! -e "$WORKTREE_DIR/scripts/lib/version.sh" ]; then
  echo "  PASS: scripts/lib/version.sh removed in v2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: scripts/lib/version.sh should be removed in v2"
  FAIL=$((FAIL + 1))
fi
echo ""

# 6. workflows/
echo "--- .github/workflows/ ---"
check ".github/workflows/ci.yml"       "$WORKTREE_DIR/.github/workflows/ci.yml"
check ".github/workflows/release.yml"  "$WORKTREE_DIR/.github/workflows/release.yml"
check ".claude-plugin/plugin.json"     "$WORKTREE_DIR/.claude-plugin/plugin.json"
echo ""

# 6. tests/ — 2 existing test files (not counting this one)
echo "--- tests/ (expect at least 2 pre-existing test files) ---"
TESTS_COUNT=$(find "$WORKTREE_DIR/tests" -maxdepth 1 -name "test-*.sh" -type f ! -name "test-e2e.sh" | wc -l | tr -d ' ')
if [ "$TESTS_COUNT" -ge 2 ]; then
  echo "  PASS: tests/ has $TESTS_COUNT pre-existing test file(s) (>= 2)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tests/ should have >= 2 pre-existing test files (not counting test-e2e.sh), found $TESTS_COUNT"
  FAIL=$((FAIL + 1))
fi
echo ""

# 7. Agent methodology contracts — protect stackpilot-specific invariants from
#    drift, WITHOUT re-testing generic behaviors Claude 4.7 does natively.
echo "--- Agent contracts (structural assertions) ---"
grep_in() { grep -q "$1" "$WORKTREE_DIR/$2" 2>/dev/null; }

# sp-docs uses haiku (mechanical task, cheaper model)
grep_in "^model: haiku" "claude-config/agents/sp-docs.md" \
  && { echo "  PASS: sp-docs uses haiku"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-docs missing 'model: haiku'"; FAIL=$((FAIL + 1)); }

# sp-architect HIGH-risk invokes extended thinking
grep_in "extended thinking" "claude-config/agents/sp-architect.md" \
  && { echo "  PASS: sp-architect declares extended thinking for HIGH risk"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-architect missing 'extended thinking' directive"; FAIL=$((FAIL + 1)); }

# sp-architect emits Decision Candidates (read-only contract — see docs/architecture single-file memory)
grep_in "Decision Candidates" "claude-config/agents/sp-architect.md" \
  && { echo "  PASS: sp-architect emits Decision Candidates"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-architect missing Decision Candidates contract"; FAIL=$((FAIL + 1)); }

# sp-dev enforces TDD
grep_in "RED-GREEN-REFACTOR\|TDD" "claude-config/agents/sp-dev.md" \
  && { echo "  PASS: sp-dev declares TDD"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-dev missing TDD requirement"; FAIL=$((FAIL + 1)); }

# sp-dev and sp-qa emit orchestrator signals
for agent in sp-dev sp-qa; do
  for signal in '\[SOFT-BLOCKED\]'; do
    if grep_in "$signal" "claude-config/agents/${agent}.md"; then
      echo "  PASS: ${agent} declares ${signal}"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: ${agent} missing ${signal} signal"
      FAIL=$((FAIL + 1))
    fi
  done
done
grep_in '\[ESCALATION\]' "claude-config/agents/sp-dev.md" \
  && { echo "  PASS: sp-dev declares [ESCALATION]"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-dev missing [ESCALATION]"; FAIL=$((FAIL + 1)); }

# sp-qa Stage 4 consistency audit (our deterministic value-add)
grep_in "Consistency Audit" "claude-config/agents/sp-qa.md" \
  && { echo "  PASS: sp-qa declares Stage 4 Consistency Audit"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-qa missing Stage 4 Consistency Audit"; FAIL=$((FAIL + 1)); }

# sp-qa Pattern Candidates contract (cross-sprint memory flow)
grep_in "Pattern Candidates" "claude-config/agents/sp-qa.md" \
  && { echo "  PASS: sp-qa emits Pattern Candidates"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sp-qa missing Pattern Candidates"; FAIL=$((FAIL + 1)); }

# SKILL.md auto-verify is 1 round (4.7 first-pass)
grep_in "1 self-fix round\|up to 1 self-fix" "claude-config/skills/stackpilot/SKILL.md" \
  && { echo "  PASS: SKILL.md auto-verify is 1 round"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: SKILL.md auto-verify not declared as 1 round"; FAIL=$((FAIL + 1)); }

# SKILL.md skips sp-qa for light tasks
grep_in "standard complexity only" "claude-config/skills/stackpilot/SKILL.md" \
  && { echo "  PASS: SKILL.md skips sp-qa for light tasks"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: SKILL.md missing light-task skip"; FAIL=$((FAIL + 1)); }

# 12-qa-matrix Plan section is traceability (not re-run of 12 dimensions)
grep_in "traceability check" "claude-config/skills/stackpilot/references/12-qa-matrix.md" \
  && { echo "  PASS: 12-qa-matrix Plan is traceability check"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: 12-qa-matrix Plan not declared as traceability check"; FAIL=$((FAIL + 1)); }

# Sprint Finish Step 2 auto-curls the preview URL
grep_in "HTTP_CODE\|curl.*http_code" "claude-config/skills/stackpilot/references/sprint-finish.md" \
  && { echo "  PASS: sprint-finish Step 2 auto-curls preview URL"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: sprint-finish Step 2 missing auto-curl"; FAIL=$((FAIL + 1)); }

# Agent frontmatter uses the Claude Code standard: tools: (comma-separated), not allowed-tools: (YAML list)
# Without this, Claude Code silently ignores the restriction and the agent never registers.
for agent in sp-architect sp-dev sp-docs sp-qa; do
  if grep -qE "^tools:[[:space:]]" "$WORKTREE_DIR/claude-config/agents/${agent}.md" \
     && ! grep -qE "^allowed-tools:" "$WORKTREE_DIR/claude-config/agents/${agent}.md"; then
    echo "  PASS: ${agent} uses 'tools:' frontmatter (Claude Code standard)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${agent} frontmatter uses non-standard 'allowed-tools:' — Claude Code will silently skip registration"
    FAIL=$((FAIL + 1))
  fi
done

# SKILL.md Agent() dispatches pass subagent_type so they route to sp-* (not general-purpose)
for agent_name in sp-architect sp-dev sp-qa; do
  if grep -qE "subagent_type=\"${agent_name}\"" "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md"; then
    echo "  PASS: SKILL.md dispatches subagent_type=${agent_name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: SKILL.md missing subagent_type=${agent_name} — dispatch falls back to general-purpose"
    FAIL=$((FAIL + 1))
  fi
done

# SKILL.md routes docs tasks to sp-docs (haiku cost savings only materialize here)
grep_in "subagent_type=\"sp-docs\"" "claude-config/skills/stackpilot/SKILL.md" \
  && { echo "  PASS: SKILL.md routes docs tasks to sp-docs"; PASS=$((PASS + 1)); } \
  || { echo "  FAIL: SKILL.md missing sp-docs routing — haiku cost savings will not apply"; FAIL=$((FAIL + 1)); }

# Shared skill must support Codex without installing a second stackpilot skill.
if ! grep -q "Requires Claude Code" "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md" \
   && grep -q "references/codex-dispatch.md" "$WORKTREE_DIR/claude-config/skills/stackpilot/SKILL.md" \
   && grep -q "update_plan" "$WORKTREE_DIR/claude-config/skills/stackpilot/references/codex-dispatch.md" \
   && grep -q "explorer" "$WORKTREE_DIR/claude-config/skills/stackpilot/references/codex-dispatch.md" \
   && grep -q "worker" "$WORKTREE_DIR/claude-config/skills/stackpilot/references/codex-dispatch.md"; then
  echo "  PASS: shared stackpilot skill declares Codex-native dispatch"
  PASS=$((PASS + 1))
else
  echo "  FAIL: shared stackpilot skill missing Codex-native dispatch contract"
  FAIL=$((FAIL + 1))
fi

for agent in sp-architect sp-dev sp-docs sp-qa; do
  if grep -qE "^model: inherit" "$WORKTREE_DIR/codex-config/agents/${agent}.md"; then
    echo "  PASS: Codex ${agent} inherits runtime model"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Codex ${agent} should use model: inherit"
    FAIL=$((FAIL + 1))
  fi
done

if [ ! -e "$WORKTREE_DIR/codex-config/skills/stackpilot/SKILL.md" ] \
   && [ ! -e "$WORKTREE_DIR/scripts/sync-codex-config.sh" ]; then
  echo "  PASS: no direct Codex skill sync path"
  PASS=$((PASS + 1))
else
  echo "  FAIL: direct Codex skill sync path should not exist when skillshare owns sync"
  FAIL=$((FAIL + 1))
fi

echo ""

# Summary
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
