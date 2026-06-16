#!/usr/bin/env bash
# Regression checks for the v2.2.x protocol refresh.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

contains() {
  local pattern="$1"
  local file="$2"
  grep -qE -- "$pattern" "$ROOT_DIR/$file" 2>/dev/null
}

not_contains() {
  local pattern="$1"
  local file="$2"
  ! grep -qE -- "$pattern" "$ROOT_DIR/$file" 2>/dev/null
}

assert_contains() {
  local label="$1" pattern="$2" file="$3"
  if contains "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label -- missing /$pattern/ in $file"
  fi
}

assert_not_contains() {
  local label="$1" pattern="$2" file="$3"
  if not_contains "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label -- found forbidden /$pattern/ in $file"
  fi
}

echo "=== v2.2.x upgrade regression checks ==="
echo ""

# Version metadata must move as one unit.
VERSION_VALUE="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
[ "$VERSION_VALUE" = "2.4.0" ] && pass "VERSION is 2.4.0" || fail "VERSION is '$VERSION_VALUE', expected 2.4.0"
assert_contains "SKILL.md metadata version is 2.4.0" 'version: "2\.4\.0"' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "plugin.json version is 2.4.0" '"version": "2\.4\.0"' ".claude-plugin/plugin.json"
assert_contains "CHANGELOG has 2.4.0 release entry" '^## \[2\.4\.0\] - 2026-06-16' "CHANGELOG.md"
assert_contains "CHANGELOG keeps 2.3.0 release entry" '^## \[2\.3\.0\] - 2026-06-10' "CHANGELOG.md"
assert_contains "CHANGELOG keeps 2.2.2 release entry" '^## \[2\.2\.2\] - 2026-06-09' "CHANGELOG.md"
assert_contains "CHANGELOG keeps 2.2.1 release entry" '^## \[2\.2\.1\] - 2026-06-09' "CHANGELOG.md"
assert_contains "CHANGELOG keeps 2.2.0 release entry" '^## \[2\.2\.0\] - 2026-06-07' "CHANGELOG.md"

# Current live protocol files should not be anchored to obsolete specific model releases.
for file in \
  claude-config/agents/sp-dev.md \
  claude-config/agents/sp-qa.md \
  claude-config/skills/stackpilot/SKILL.md \
  claude-config/skills/stackpilot/references/run-sprint.md \
  claude-config/skills/stackpilot/references/sprint-finish.md \
  templates/stackpilot.config.yml \
  README.md
do
  assert_not_contains "no stale model-version anchor in $file" 'Claude 4\.7|Opus 4\.7|haiku 4\.5|Opus 4\.5/4\.6/4\.7' "$file"
done

# Architecture docs may keep older release rows, but current sections before Evolution Notes must be version-neutral.
for file in docs/architecture.md docs/architecture.zh.md; do
  if awk '/^## Evolution Notes|^## 演进记录/{exit} {print}' "$ROOT_DIR/$file" | grep -qE 'Claude 4\.7|Opus 4\.7|haiku 4\.5|Opus 4\.5/4\.6/4\.7'; then
    fail "current architecture prose is not stale-model neutral in $file"
  else
    pass "current architecture prose is stale-model neutral in $file"
  fi
done

# The main skill summary and detailed run protocol must agree on when architecture review runs.
assert_not_contains "SKILL.md no longer says Arch Review is HIGH-only" 'Arch Review \(HIGH only\)' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL.md says architecture review runs for standard tasks" 'Arch Review \(standard only\)' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "run-sprint.md says architecture review runs for standard tasks" 'Architecture review \(standard complexity only\)' "claude-config/skills/stackpilot/references/run-sprint.md"

# The startup check must be shell-safe under zsh when .claude/plans is absent.
assert_not_contains "Step 0 avoids raw unmatched .claude/plans glob" 'ls \.claude/plans/\*\.md' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "Step 0 uses find for .claude/plans debris" 'find \.claude/plans .* -name' "claude-config/skills/stackpilot/SKILL.md"

# v2.2 adds a hard safety gate that auto mode cannot bypass.
for file in claude-config/skills/stackpilot/SKILL.md claude-config/skills/stackpilot/references/run-sprint.md claude-config/skills/stackpilot/references/sprint-finish.md; do
  assert_contains "Action Safety Gate present in $file" 'Action Safety Gate' "$file"
  assert_contains "destructive actions require confirmation in $file" 'force push|force-push|remote delete|production database|credential' "$file"
done

# Long-running sprint harness must have a durable event log beyond per-task state.json.
assert_contains "run-sprint initializes events.jsonl" 'events\.jsonl' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint records dispatch events" 'task-dispatched' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint records verification events" 'verification' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint records user/action decisions" 'decision' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint preserves sprint-level events with null task_id" 'if \$task_id == "" then null else \$task_id end' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "sprint-finish consumes the event log" 'events\.jsonl' "claude-config/skills/stackpilot/references/sprint-finish.md"

# UI/frontend work should get rendered-page verification before finish, not only a curl at Node 5.
assert_contains "SKILL.md criteria examples include rendered UI verification" 'rendered UI|screenshot|browser' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "run-sprint QA includes visual/browser verification for frontend tasks" 'visual|browser|screenshot|responsive' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "sprint-finish includes preview URL response check" 'HTTP_CODE|curl.*http_code' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "SKILL.md is terminal-first for user gates" 'Terminal output is mandatory at every user gate' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL.md has browser view eligibility gate" 'browser/HTML view that passes the eligibility gate' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL.md forbids prose-only card HTML" 'Do not generate card-only HTML for prose choices' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "eligible browser views must print localhost URL" 'print the browser URL \(`http://localhost:<port>/sprints/<slug>/<view>\.html`\)' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "HTML view handoffs must not only report generated files" 'Do not merely say the file was generated under `\.stackpilot/views/' "claude-config/skills/stackpilot/SKILL.md"
assert_not_contains "SKILL.md no longer says HTML-first" 'HTML-first' "claude-config/skills/stackpilot/SKILL.md"

# Design option handoff must be real, selectable, and visually constrained.
assert_contains "Node 2 requires Apple-like minimal UI" 'Apple-like minimal style' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "Node 2 requires 2-3 real selectable options" '2-3 real, selectable options' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "Node 2 validates unresolved template tokens" 'unresolved tokens' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "design-options template uses Apple neutral page color" '--page: #f5f5f7' "claude-config/skills/stackpilot/references/views/design-options.html"
assert_contains "design-options template validates option count" 'OPTIONS_JSON must contain 2-3 options' "claude-config/skills/stackpilot/references/views/design-options.html"
assert_contains "design-options template has selectable cards" 'selectOption' "claude-config/skills/stackpilot/references/views/design-options.html"
assert_contains "design-options template posts Pick choice to sprint server" 'window\.sp\.action' "claude-config/skills/stackpilot/references/views/design-options.html"
assert_not_contains "design-options template has no demo fallback summary" 'agent did not fill OPTIONS_JSON|Approach A|pro 1|con 1' "claude-config/skills/stackpilot/references/views/design-options.html"

# Cross-host boundary: StackPilot is a general methodology core; Claude Code is one adapter.
assert_contains "README states methodology core works across hosts" 'methodology core.*Codex|general methodology|host adapters|通用方法论' "README.md"
assert_contains "README names Claude Code as an adapter" 'Claude Code adapter|Host adapters|宿主适配器' "README.md"
assert_contains "README names packaged non-Claude hosts" 'Cursor|OpenAI Codex|Gemini CLI|\.codex-plugin|\.cursor-plugin|gemini-extension' "README.md"
assert_contains "README names portable workflow gates" 'stackpilot-planning|stackpilot-workspace|stackpilot-plan-execution|stackpilot-parallel-agents|stackpilot-review-response|stackpilot-completion-verification|stackpilot-skill-authoring' "README.md"
assert_contains "README links Superpowers gap audit" 'superpowers-gap-audit' "README.md"
assert_not_contains "README no longer claims host-specific Stackpilot dispatch" 'host-specific dispatch' "README.md"
assert_contains "architecture docs mention OpenAI Codex skills discovery" 'OpenAI Codex|Codex' "docs/architecture.md"
assert_contains "architecture docs separate methodology core from adapters" 'Methodology Core|Host Adapters|adapter' "docs/architecture.md"
assert_contains "architecture docs list packaged host surfaces" 'Packaged host surfaces|\.codex-plugin|\.cursor-plugin|gemini-extension' "docs/architecture.md"
assert_contains "architecture docs list portable workflow gates" 'stackpilot-planning|stackpilot-workspace|stackpilot-plan-execution|stackpilot-parallel-agents|stackpilot-review-response|stackpilot-completion-verification|stackpilot-skill-authoring' "docs/architecture.md"
assert_contains "architecture docs mention Superpowers parity audit" 'Superpowers parity audit|superpowers-gap-audit' "docs/architecture.md"
assert_not_contains "architecture no longer says StackPilot orchestration is Claude Code-only" 'Stackpilot orchestration remains Claude Code-specific|Stackpilot orchestration is Claude Code-specific|Claude Code-only dispatch' "docs/architecture.md"
assert_contains "Claude plugin description is methodology-first" 'General methodology for coding agents' ".claude-plugin/plugin.json"
assert_not_contains "Claude plugin description no longer starts sprint-only" 'Sprint orchestration for Claude Code' ".claude-plugin/plugin.json"

# The changelog should name the evidence-backed reasons for the update, not just subjective cleanup.
assert_contains "CHANGELOG cites OpenAI Codex evidence" 'OpenAI Codex' "CHANGELOG.md"
assert_contains "CHANGELOG cites Anthropic Claude Code evidence" 'Anthropic|Claude Code' "CHANGELOG.md"
assert_contains "CHANGELOG records verification coverage" 'test-v2-2-upgrade|full test suite|verification' "CHANGELOG.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
