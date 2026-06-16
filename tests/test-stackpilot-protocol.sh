#!/usr/bin/env bash
# Regression checks for StackPilot sprint protocol data artifacts.

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

assert_contains() {
  local label="$1" pattern="$2" file="$3"
  if contains "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label -- missing /$pattern/ in $file"
  fi
}

echo "=== StackPilot protocol artifact regression checks ==="
echo ""

# Main adapter must advertise the data-layer artifacts, not just the optional
# browser views.
assert_contains "SKILL data layer lists handoff" 'handoff\.json' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL data layer lists sprint evals" 'sprint-evals\.md' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL data layer lists feedback inbox" '\.stackpilot/feedback' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL finish uses evals" 'Sprint evals' "claude-config/skills/stackpilot/SKILL.md"
assert_contains "SKILL finish handles high critical feedback" 'HIGH/CRITICAL feedback' "claude-config/skills/stackpilot/SKILL.md"

# Run Sprint owns the structured phase handoff contract.
assert_contains "run-sprint defines handoff path" 'HANDOFF=.*handoff\.json' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint schema has version" '"version"' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint schema has sprint slug" '"sprint_slug"' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint schema has next action" 'next_action' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint updates handoff after parsing" 'Update `handoff\.json` after plan parsing' "claude-config/skills/stackpilot/references/run-sprint.md"
assert_contains "run-sprint reads handoff on resume" 'handoff\.json` first' "claude-config/skills/stackpilot/references/run-sprint.md"

# Sprint Finish owns retrospective evals and audit feedback processing.
assert_contains "sprint-finish writes sprint evals" 'sprint-evals\.md' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish tracks soft-blocked tasks" 'tasks_soft_blocked' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish tracks retry count" 'retry_count' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish detects plateau" 'plateau' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish scans open feedback" '\.stackpilot/feedback/open' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish records feedback resolution" '# Resolution' "claude-config/skills/stackpilot/references/sprint-finish.md"
assert_contains "sprint-finish preserves feedback artifacts" 'Do not delete.*\.stackpilot/feedback' "claude-config/skills/stackpilot/references/sprint-finish.md"

# Portable gates should carry the same concepts for non-Claude hosts.
assert_contains "methodology mentions handoff" 'handoff\.json' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "methodology mentions feedback inbox" 'feedback inbox' "claude-config/skills/stackpilot-methodology/SKILL.md"
assert_contains "planning writes handoff when possible" 'handoff\.json' "claude-config/skills/stackpilot-planning/SKILL.md"
assert_contains "execution tracks handoff next action" 'Handoff next action' "claude-config/skills/stackpilot-plan-execution/SKILL.md"
assert_contains "completion checks feedback inbox" 'Feedback inbox' "claude-config/skills/stackpilot-completion-verification/SKILL.md"

# Public docs and source tracking must describe the external inspirations and
# the chosen non-bench integration surface.
assert_contains "sync updated autoresearch date" 'autoresearch.*2026-06-16' "docs/sync.md"
assert_contains "sync tracks llm wiki feedback" 'llm-wiki.*feedback' "docs/sync.md"
assert_contains "sync tracks handoff contribution" 'handoff\.json' "docs/sync.md"
assert_contains "README documents plan handoff persistence" 'Plan/handoff' "README.md"
assert_contains "README documents sprint evals" 'Sprint evals' "README.md"
assert_contains "README documents feedback inbox" 'Feedback inbox' "README.md"
assert_contains "architecture documents handoff decision" 'Data-layer handoff' "docs/architecture.md"
assert_contains "architecture documents evals decision" 'Sprint evals from events/state/criteria' "docs/architecture.md"
assert_contains "architecture documents feedback decision" 'Feedback inbox audit loop' "docs/architecture.md"
assert_contains "architecture evolution notes refresh" '2026-06-16.*handoff.*evals.*feedback' "docs/architecture.md"
assert_contains "architecture zh documents handoff" '数据层 handoff' "docs/architecture.zh.md"
assert_contains "changelog records protocol artifacts" 'sprint handoff, evals, and feedback inbox' "CHANGELOG.md"
assert_contains "changelog says bench was not restored" 'without restoring `/stackpilot-bench`' "CHANGELOG.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
