#!/usr/bin/env bash
# Regression checks for the Superpowers-like Stackpilot experience.

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

assert_file() {
  local label="$1" file="$2"
  if [ -f "$ROOT_DIR/$file" ]; then
    pass "$label"
  else
    fail "$label -- missing $file"
  fi
}

assert_no_file() {
  local label="$1" file="$2"
  if [ ! -e "$ROOT_DIR/$file" ]; then
    pass "$label"
  else
    fail "$label -- should not exist: $file"
  fi
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
  if ! contains "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label -- found forbidden /$pattern/ in $file"
  fi
}

echo "=== Superpowers-like experience regression checks ==="
echo ""

# Session bootstrap: Stackpilot must be present at conversation start, not only
# when the user remembers to type /stackpilot.
assert_file "session-start hook exists" "hooks/session-start"
assert_file "pre-tool-use hook exists" "hooks/pre-tool-use"
assert_file "Claude hook manifest exists" "hooks/hooks.json"
assert_file "Cursor hook manifest exists" "hooks/hooks-cursor.json"
assert_contains "Claude hook manifest registers SessionStart" '"SessionStart"' "hooks/hooks.json"
assert_contains "Claude hook manifest registers PreToolUse" '"PreToolUse"' "hooks/hooks.json"
assert_contains "Cursor hook manifest registers sessionStart" '"sessionStart"' "hooks/hooks-cursor.json"
assert_contains "Cursor hook manifest registers preToolUse" '"preToolUse"' "hooks/hooks-cursor.json"
assert_contains "session-start injects bootstrap skill" 'stackpilot-bootstrap' "hooks/session-start"
assert_contains "session-start emits additional context" 'additionalContext|additional_context|hookSpecificOutput' "hooks/session-start"
assert_contains "pre-tool-use blocks before skill activation" 'routing gate blocked|no StackPilot process' "hooks/pre-tool-use"

# Cross-host package surfaces: the StackPilot method should be discoverable
# beyond Claude Code, even though the full sprint adapter remains Claude-only.
assert_file "Claude plugin manifest exists" ".claude-plugin/plugin.json"
assert_file "Cursor plugin manifest exists" ".cursor-plugin/plugin.json"
assert_file "Codex plugin manifest exists" ".codex-plugin/plugin.json"
assert_file "Gemini extension manifest exists" "gemini-extension.json"
assert_file "Gemini routing context exists" "GEMINI.md"
assert_contains "Claude plugin positions StackPilot as methodology" 'General methodology|coding agents|methodology' ".claude-plugin/plugin.json"
assert_contains "Codex plugin exposes skills path" '"skills": "\./skills/"' ".codex-plugin/plugin.json"
assert_contains "Cursor plugin exposes session hook" '"hooks": "\./hooks/hooks-cursor\.json"' ".cursor-plugin/plugin.json"
assert_contains "Gemini context routes to methodology core" 'stackpilot-methodology' "GEMINI.md"

# Bootstrap discipline: model should check routing before action and auto-route
# non-trivial feature work into the portable methodology core first.
assert_file "bootstrap skill exists" "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_file "portable methodology core exists" "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_file "portable planning skill exists" "claude-config/skills/stackpilot-planning/SKILL.md"
assert_file "portable workspace skill exists" "claude-config/skills/stackpilot-workspace/SKILL.md"
assert_file "portable plan execution skill exists" "claude-config/skills/stackpilot-plan-execution/SKILL.md"
assert_file "portable parallel agents skill exists" "claude-config/skills/stackpilot-parallel-agents/SKILL.md"
assert_file "portable review response skill exists" "claude-config/skills/stackpilot-review-response/SKILL.md"
assert_file "portable completion verification skill exists" "claude-config/skills/stackpilot-completion-verification/SKILL.md"
assert_file "portable skill authoring skill exists" "claude-config/skills/stackpilot-skill-authoring/SKILL.md"
assert_file "Superpowers gap audit exists" "docs/superpowers-gap-audit.md"
assert_contains "bootstrap checks skills before action" 'BEFORE any response or action|before any response or action' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap has 1 percent trigger rule" '1%|one percent' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes feature work to methodology core" 'feature work|building|modifying behavior|/stackpilot-methodology' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes planning work to planning skill" 'implementation plan|/stackpilot-planning' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes existing plans to plan execution" 'Existing spec/plan|/stackpilot-plan-execution' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes independent domains to parallel agents" 'independent tasks|/stackpilot-parallel-agents' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes workspace setup to workspace skill" 'Starting implementation|/stackpilot-workspace' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes review feedback to review-response" 'review feedback|/stackpilot-review-response' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes skill changes to skill-authoring" 'StackPilot skills|/stackpilot-skill-authoring' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap routes completion claims to completion verification" '/stackpilot-completion-verification|completion-verification' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap says quick iteration is not opt-out" 'quick iteration|speed.*NOT opt-outs|not.*opt-out' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap forbids TaskCreate before methodology" 'TaskCreate|TodoWrite|not a substitute|after methodology activation' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap requires technical review feedback handling" 'reviewer.*right|stackpilot-review-response|verify technically' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap suggests parallel agents for independent work" 'stackpilot-parallel-agents|independent.*concurrently' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap treats /stackpilot as host adapter" 'adapter|Claude Code adapter|host adapter' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap documents single StackPilot entry" 'StackPilot is the user entry|one.*StackPilot entry|internal process skills' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "bootstrap preserves user override" 'User instructions|explicit user|highest priority' "claude-config/skills/stackpilot-bootstrap/SKILL.md"
assert_contains "methodology delegates planning gate" 'stackpilot-planning' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology delegates workspace gate" 'stackpilot-workspace' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology delegates plan execution gate" 'stackpilot-plan-execution' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology delegates parallel agents gate" 'stackpilot-parallel-agents' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology delegates review response gate" 'stackpilot-review-response' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology delegates completion gate" 'stackpilot-completion-verification' "claude-config/skills/stackpilot-methodology/SKILL.md"

# Run Sprint must not trust agent self-reports. A controller-level gate should
# validate report shape and evidence before phase advancement.
assert_contains "run-sprint has controller contract gate" 'Controller Contract Gate' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint says not to trust agent reports" 'Do not trust|do NOT trust|agent self-report|success reports' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint validates required report sections" 'required sections|schema-complete|Completion Output' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint verifies criteria updates independently" 'criteria.*Status|acceptance.*criteria.*independently|criteria-updated' "claude-config/skills/stackpilot/references/run-sprint.md"

# Mechanical enforcement: natural feature work cannot use tools before a
# StackPilot process skill has been activated.
HOOK_TMP="$(mktemp -d)"
cat > "$HOOK_TMP/transcript.jsonl" <<'JSONL'
{"type":"user","message":{"content":"Build a small React todo list. Please implement it."}}
JSONL
HOOK_INPUT="{\"tool_name\":\"Bash\",\"transcript_path\":\"$HOOK_TMP/transcript.jsonl\"}"
if printf '%s' "$HOOK_INPUT" | "$ROOT_DIR/hooks/pre-tool-use" >"$HOOK_TMP/stdout" 2>"$HOOK_TMP/stderr"; then
  fail "pre-tool-use blocks Bash before StackPilot skill -- hook allowed tool"
else
  STATUS=$?
  if [ "$STATUS" -eq 2 ] && grep -q 'StackPilot routing gate blocked Bash' "$HOOK_TMP/stderr"; then
    pass "pre-tool-use blocks Bash before StackPilot skill"
  else
    fail "pre-tool-use blocks Bash before StackPilot skill -- unexpected status $STATUS"
  fi
fi

HOOK_INPUT="{\"tool_name\":\"Skill\",\"transcript_path\":\"$HOOK_TMP/transcript.jsonl\"}"
if printf '%s' "$HOOK_INPUT" | "$ROOT_DIR/hooks/pre-tool-use" >/dev/null 2>&1; then
  pass "pre-tool-use allows Skill activation"
else
  fail "pre-tool-use allows Skill activation -- hook blocked Skill"
fi
cat > "$HOOK_TMP/transcript.jsonl" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"stackpilot:stackpilot-planning"}}]}}
JSONL
HOOK_INPUT="{\"tool_name\":\"Bash\",\"transcript_path\":\"$HOOK_TMP/transcript.jsonl\"}"
if printf '%s' "$HOOK_INPUT" | "$ROOT_DIR/hooks/pre-tool-use" >/dev/null 2>&1; then
  pass "pre-tool-use allows tools after planning skill"
else
  fail "pre-tool-use allows tools after planning skill -- hook blocked tool"
fi
cat > "$HOOK_TMP/transcript.jsonl" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"stackpilot:stackpilot"}}]}}
JSONL
HOOK_INPUT="{\"tool_name\":\"Bash\",\"transcript_path\":\"$HOOK_TMP/transcript.jsonl\"}"
if printf '%s' "$HOOK_INPUT" | "$ROOT_DIR/hooks/pre-tool-use" >/dev/null 2>&1; then
  pass "pre-tool-use allows tools after primary StackPilot entry"
else
  fail "pre-tool-use allows tools after primary StackPilot entry -- hook blocked tool"
fi
cat > "$HOOK_TMP/transcript.jsonl" <<'JSONL'
{"type":"user","message":{"content":"Build a small React todo list. Please implement it."}}
{"type":"user","message":{"content":"StackPilot routing gate blocked Bash. Activate stackpilot:stackpilot-methodology first."}}
JSONL
HOOK_INPUT="{\"tool_name\":\"Bash\",\"transcript_path\":\"$HOOK_TMP/transcript.jsonl\"}"
if printf '%s' "$HOOK_INPUT" | "$ROOT_DIR/hooks/pre-tool-use" >"$HOOK_TMP/stdout" 2>"$HOOK_TMP/stderr"; then
  fail "pre-tool-use ignores textual skill names without actual Skill tool -- hook allowed tool"
else
  STATUS=$?
  if [ "$STATUS" -eq 2 ]; then
    pass "pre-tool-use ignores textual skill names without actual Skill tool"
  else
    fail "pre-tool-use ignores textual skill names without actual Skill tool -- unexpected status $STATUS"
  fi
fi
rm -rf "$HOOK_TMP"

# Behavior testing: repository should test triggering discipline locally through
# hook behavior, not through a live Claude CLI/API integration test.
assert_no_file "Claude CLI triggering test runner removed" "tests/stackpilot-triggering/run-test.sh"
assert_no_file "Claude CLI feature prompt fixture removed" "tests/stackpilot-triggering/prompts/feature-work.txt"
assert_contains "CI runs Superpowers-like experience test" 'test-superpowers-experience\.sh' ".github/workflows/ci.yml"

# Docs should no longer position Stackpilot as explicit-invocation-only.
assert_contains "architecture documents session bootstrap" 'Session bootstrap|session bootstrap|auto-route|auto-route' "docs/architecture.md"
assert_contains "README documents automatic Stackpilot routing" 'automatic Stackpilot routing|session bootstrap|auto-route' "README.md"
assert_contains "README positions StackPilot as general methodology" 'general methodology|methodology core|host adapters|通用方法论' "README.md"
assert_contains "README documents one StackPilot entry" 'One StackPilot Entry|一个 StackPilot 入口|Users should start with \*\*StackPilot\*\*|用户应该从 \*\*StackPilot\*\* 开始' "README.md"
assert_contains "README documents cross-host support" 'Cursor|OpenAI Codex|Gemini CLI|\.codex-plugin|\.cursor-plugin|gemini-extension' "README.md"
assert_contains "README documents internal StackPilot gates" 'stackpilot-planning|stackpilot-workspace|stackpilot-plan-execution|stackpilot-parallel-agents|stackpilot-review-response|stackpilot-completion-verification|stackpilot-skill-authoring' "README.md"
assert_contains "README links Superpowers gap audit" 'superpowers-gap-audit' "README.md"
assert_contains "architecture separates core from adapters" 'Methodology Core|Host Adapters|host adapters|adapter' "docs/architecture.md"
assert_contains "architecture documents entry layers" 'Entry Layers|one normal user entry|internal gates|入口层级' "docs/architecture.md"
assert_contains "architecture documents packaged host surfaces" 'Packaged host surfaces|\.codex-plugin|\.cursor-plugin|gemini-extension' "docs/architecture.md"
assert_contains "architecture documents portable execution gates" 'stackpilot-planning|stackpilot-workspace|stackpilot-plan-execution|stackpilot-parallel-agents|stackpilot-review-response|stackpilot-completion-verification|stackpilot-skill-authoring' "docs/architecture.md"
assert_contains "gap audit maps Superpowers using-superpowers" 'using-superpowers.*stackpilot-bootstrap' "docs/superpowers-gap-audit.md"
assert_contains "gap audit maps all Superpowers workflow skills" 'writing-plans.*stackpilot-planning|dispatching-parallel-agents.*stackpilot-parallel-agents|writing-skills.*stackpilot-skill-authoring' "docs/superpowers-gap-audit.md"
assert_contains "gap audit rejects skill-count cloning" 'not a cloning target|not.*skill count|Do not infer' "docs/superpowers-gap-audit.md"
assert_not_contains "README no longer says orchestration is Claude Code-only" 'Stackpilot orchestration.*Claude Code-only|Claude Code-only.*Stackpilot orchestration' "README.md"
assert_not_contains "architecture no longer says explicit-invocation only" 'explicit-invocation only' ".stackpilot/ARCHITECTURE.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
