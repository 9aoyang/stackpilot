#!/usr/bin/env bash
# Stackpilot full lifecycle state machine test
# Simulates init → plan → backlog → in-progress → soft-blocked → blocked →
# needs-review → done → failed → sprint-finish → cleanup
# No real AI agents — all state transitions are file-based.

set -uo pipefail

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Count matches in a file (returns "0" when no matches, unlike raw grep -c which exits 1)
count_matches() {
  local pattern="$1" file="$2"
  local n
  n=$(grep -c "$pattern" "$file" 2>/dev/null) || true
  echo "${n:-0}"
}

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cd "$TMPDIR_TEST"
git init --quiet
git config user.email "test@test.com"
git config user.name "Test"

BACKLOG=".stackpilot/tasks/backlog.yml"

# ── Helper: update a field for a given task ID in backlog.yml ──────────────
# Usage: update_task TASK-001 status done
update_task() {
  local task_id="$1" field="$2" value="$3"
  awk -v id="$task_id" -v fld="$field" -v val="$value" '
    /^  - id: / { in_task = (index($0, id) > 0) }
    in_task && index($0, fld ":") > 0 && $0 !~ /^#/ {
      # Replace everything after "field:" with new value
      idx = index($0, fld ":")
      prefix = substr($0, 1, idx - 1)
      print prefix fld ": " val
      next
    }
    { print }
  ' "$BACKLOG" > "${BACKLOG}.tmp" && mv "${BACKLOG}.tmp" "$BACKLOG"
}

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 1: Initialization ==="
# ═══════════════════════════════════════════════════════════════════════════════

bash "$REPO_DIR/scripts/init.sh" --stackpilot-dir "$REPO_DIR" > /dev/null 2>&1

[ -d ".stackpilot/tasks" ] && pass "P1: .stackpilot/tasks/ created" || fail "P1: .stackpilot/tasks/ missing"
[ -f "$BACKLOG" ] && pass "P1: backlog.yml created" || fail "P1: backlog.yml missing"
[ -f ".stackpilot/tasks/in-progress.yml" ] && pass "P1: in-progress.yml created" || fail "P1: in-progress.yml missing"
[ -f ".stackpilot/tasks/NEEDS_REVIEW.md" ] && pass "P1: NEEDS_REVIEW.md created" || fail "P1: NEEDS_REVIEW.md missing"
[ -f "stackpilot.config.yml" ] && pass "P1: config copied to project root" || fail "P1: config missing"
[ -f ".stackpilot/path" ] && pass "P1: .stackpilot/path exists" || fail "P1: .stackpilot/path missing"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 2: Sprint Clean → Plan → Backlog populated ==="
# ═══════════════════════════════════════════════════════════════════════════════

# State: "Sprint Clean" = backlog has no real task entries (template is all comments)
BACKLOG_TASKS=$(count_matches "^  - id:" "$BACKLOG")
[ "$BACKLOG_TASKS" = "0" ] && pass "P2: sprint is clean (no tasks)" || fail "P2: backlog not empty after init ($BACKLOG_TASKS)"

# Simulate: plan written → spec committed → PM creates backlog
mkdir -p .stackpilot/specs .stackpilot/plans
cat > .stackpilot/specs/2026-04-07-login-design.md <<'EOF'
## Overview
Login page with email/password auth.
## Goals
Allow users to authenticate.
## Technical Requirements
Use JWT tokens for session management.
## Acceptance Criteria
- User can log in with email/password
- Invalid credentials show error message
EOF

cat > .stackpilot/plans/2026-04-07-login-plan.md <<'EOF'
### TASK-001
- title: Create login API endpoint
- type: dev
- complexity: standard
- depends_on: []
- relevant_files: src/api/auth.ts

### TASK-002
- title: Build login form component
- type: dev
- complexity: standard
- depends_on: [TASK-001]
- relevant_files: src/components/LoginForm.tsx

### TASK-003
- title: Write auth integration tests
- type: qa
- complexity: light
- depends_on: [TASK-001, TASK-002]
- relevant_files: tests/auth.test.ts

### TASK-004
- title: Document auth flow
- type: docs
- complexity: light
- depends_on: [TASK-001]
- relevant_files: docs/auth.md
EOF

# PM agent populates backlog
cat > "$BACKLOG" <<'EOF'
tasks:
  - id: TASK-001
    title: Create login API endpoint
    type: dev
    complexity: standard
    priority: high
    status: pending
    depends_on: []
    attempt_count: 0
    last_error_summary: null
    description: |
      Create POST /api/auth/login endpoint
    assigned_to: null

  - id: TASK-002
    title: Build login form component
    type: dev
    complexity: standard
    priority: high
    status: pending
    depends_on: [TASK-001]
    attempt_count: 0
    last_error_summary: null
    description: |
      React component with email/password fields
    assigned_to: null

  - id: TASK-003
    title: Write auth integration tests
    type: qa
    complexity: light
    priority: medium
    status: pending
    depends_on: [TASK-001, TASK-002]
    attempt_count: 0
    last_error_summary: null
    description: |
      Integration tests for login flow
    assigned_to: null

  - id: TASK-004
    title: Document auth flow
    type: docs
    complexity: light
    priority: low
    status: pending
    depends_on: [TASK-001]
    attempt_count: 0
    last_error_summary: null
    description: |
      Write docs/auth.md explaining auth flow
    assigned_to: null
EOF

TASK_COUNT=$(count_matches "^  - id:" "$BACKLOG")
[ "$TASK_COUNT" = "4" ] && pass "P2: backlog has 4 tasks" || fail "P2: expected 4 tasks, got $TASK_COUNT"

[ -f .stackpilot/specs/2026-04-07-login-design.md ] && pass "P2: spec exists" || fail "P2: spec missing"
[ -f .stackpilot/plans/2026-04-07-login-plan.md ] && pass "P2: plan exists" || fail "P2: plan missing"

PENDING_COUNT=$(count_matches "status: pending" "$BACKLOG")
[ "$PENDING_COUNT" = "4" ] && pass "P2: all 4 tasks are pending" || fail "P2: expected 4 pending, got $PENDING_COUNT"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 3: Coordinator dispatches → in-progress ==="
# ═══════════════════════════════════════════════════════════════════════════════

update_task TASK-001 status in-progress
update_task TASK-001 assigned_to sp-dev

cat > .stackpilot/tasks/in-progress.yml <<'EOF'
tasks:
  - id: TASK-001
    agent: sp-dev
    started_at: "2026-04-07T10:00:00+08:00"
EOF

grep -q "TASK-001" "$BACKLOG" && grep -A10 "TASK-001" "$BACKLOG" | grep -q "status: in-progress" \
  && pass "P3: TASK-001 is in-progress" || fail "P3: TASK-001 not in-progress"

grep -q "id: TASK-001" .stackpilot/tasks/in-progress.yml \
  && pass "P3: TASK-001 tracked in in-progress.yml" || fail "P3: TASK-001 not in in-progress.yml"

# TASK-002 still pending (depends on TASK-001)
grep -A10 "TASK-002" "$BACKLOG" | grep -q "status: pending" \
  && pass "P3: TASK-002 still pending (dependency)" || fail "P3: TASK-002 should be pending"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 4: Agent completes TASK-001 → done ==="
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p .stackpilot/tasks/done
cat > .stackpilot/tasks/done/TASK-001.md <<'EOF'
# TASK-001: Create login API endpoint
Status: done
Agent: sp-dev
Completed: 2026-04-07T10:25:00+08:00

## Changes
- Created src/api/auth.ts with POST /api/auth/login
- JWT token generation with configurable expiry

## Files Modified
- src/api/auth.ts (new)
- src/api/routes.ts (modified)
EOF

update_task TASK-001 status done
cat > .stackpilot/tasks/in-progress.yml <<'EOF'
tasks: []
EOF

[ -f .stackpilot/tasks/done/TASK-001.md ] && pass "P4: TASK-001 done file exists" || fail "P4: TASK-001 done file missing"
grep -A10 "TASK-001" "$BACKLOG" | grep -q "status: done" \
  && pass "P4: TASK-001 status is done in backlog" || fail "P4: TASK-001 not marked done"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 5: TASK-002 dispatched → soft-blocked → retry ==="
# ═══════════════════════════════════════════════════════════════════════════════

update_task TASK-002 status in-progress
update_task TASK-002 assigned_to sp-dev

# sp-dev hits a transient failure → soft-blocked
update_task TASK-002 status soft-blocked
update_task TASK-002 attempt_count 1

grep -A10 "TASK-002" "$BACKLOG" | grep -q "status: soft-blocked" \
  && pass "P5: TASK-002 is soft-blocked" || fail "P5: TASK-002 not soft-blocked"
grep -A10 "TASK-002" "$BACKLOG" | grep -q "attempt_count: 1" \
  && pass "P5: TASK-002 attempt_count is 1" || fail "P5: TASK-002 attempt_count wrong"

# Coordinator retries (attempt < 3)
update_task TASK-002 status pending

grep -A10 "TASK-002" "$BACKLOG" | grep -q "status: pending" \
  && pass "P5: TASK-002 rescheduled to pending" || fail "P5: TASK-002 not rescheduled"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 6: TASK-002 soft-blocked 3x → escalated to blocked ==="
# ═══════════════════════════════════════════════════════════════════════════════

update_task TASK-002 attempt_count 3
update_task TASK-002 status blocked

grep -A10 "TASK-002" "$BACKLOG" | grep -q "status: blocked" \
  && pass "P6: TASK-002 blocked after 3 attempts" || fail "P6: TASK-002 not blocked"
grep -A10 "TASK-002" "$BACKLOG" | grep -q "attempt_count: 3" \
  && pass "P6: TASK-002 attempt_count is 3" || fail "P6: TASK-002 attempt_count wrong"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 7: Blocked → NEEDS_REVIEW → user replies → unblocked ==="
# ═══════════════════════════════════════════════════════════════════════════════

cat > .stackpilot/tasks/NEEDS_REVIEW.md <<'EOF'
[DEV][TASK-002] LoginForm component has a type conflict
Option A: Refactor UserContext
Option B: Add adapter layer
Recommendation: Option A
EOF

grep -q "TASK-002" .stackpilot/tasks/NEEDS_REVIEW.md && pass "P7: NEEDS_REVIEW has TASK-002" || fail "P7: NEEDS_REVIEW empty"
grep -q "Option A" .stackpilot/tasks/NEEDS_REVIEW.md && pass "P7: NEEDS_REVIEW has options" || fail "P7: NEEDS_REVIEW no options"

printf "\nREPLY: Option A\n" >> .stackpilot/tasks/NEEDS_REVIEW.md

grep -q "^REPLY:" .stackpilot/tasks/NEEDS_REVIEW.md && pass "P7: user REPLY recorded" || fail "P7: REPLY missing"

# Coordinator unblocks
update_task TASK-002 status pending
update_task TASK-002 attempt_count 0
printf "" > .stackpilot/tasks/NEEDS_REVIEW.md

grep -A10 "TASK-002" "$BACKLOG" | grep -q "status: pending" \
  && pass "P7: TASK-002 unblocked → pending" || fail "P7: TASK-002 still blocked"

REVIEW_SIZE=$(wc -c < .stackpilot/tasks/NEEDS_REVIEW.md | tr -d ' ')
[ "$REVIEW_SIZE" = "0" ] && pass "P7: NEEDS_REVIEW cleared" || fail "P7: NEEDS_REVIEW not cleared"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 8: All remaining tasks complete ==="
# ═══════════════════════════════════════════════════════════════════════════════

for TASK_ID in TASK-002 TASK-003 TASK-004; do
  update_task "$TASK_ID" status done
  cat > ".stackpilot/tasks/done/$TASK_ID.md" <<EOF
# $TASK_ID completed
Status: done
EOF
done

DONE_COUNT=$(count_matches "status: done" "$BACKLOG")
[ "$DONE_COUNT" = "4" ] && pass "P8: all 4 tasks are done" || fail "P8: expected 4 done, got $DONE_COUNT"

DONE_FILES=$(ls .stackpilot/tasks/done/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$DONE_FILES" = "4" ] && pass "P8: 4 done files exist" || fail "P8: expected 4 done files, got $DONE_FILES"

REMAINING=$(count_matches "status: \(pending\|in-progress\|soft-blocked\|blocked\)" "$BACKLOG")
[ "$REMAINING" = "0" ] && pass "P8: no non-done tasks remain" || fail "P8: $REMAINING tasks not done"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 9: Failed task scenario ==="
# ═══════════════════════════════════════════════════════════════════════════════

cat >> "$BACKLOG" <<'EOF'

  - id: TASK-005
    title: Set up CI pipeline
    type: dev
    complexity: standard
    priority: low
    status: failed
    depends_on: []
    attempt_count: 3
    last_error_summary: "Timed out after 2 hours"
    description: |
      Configure GitHub Actions CI pipeline
    assigned_to: sp-dev
EOF

grep -A10 "TASK-005" "$BACKLOG" | grep -q "status: failed" \
  && pass "P9: TASK-005 is failed" || fail "P9: TASK-005 not failed"
grep -A10 "TASK-005" "$BACKLOG" | grep -q "Timed out" \
  && pass "P9: TASK-005 has error summary" || fail "P9: TASK-005 no error summary"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 10: Architect review flow ==="
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p .stackpilot/tasks/arch-review
cat > .stackpilot/tasks/arch-review/TASK-001.md <<'EOF'
# Architecture Review: TASK-001

Risk: LOW
Decision: Proceed with JWT + refresh token pattern.

## Approach
- POST /api/auth/login returns { accessToken, refreshToken }

## Alternatives Considered
1. Session-based auth (rejected)
2. OAuth2 only (rejected — overkill)
EOF

[ -f .stackpilot/tasks/arch-review/TASK-001.md ] && pass "P10: arch-review file exists" || fail "P10: arch-review missing"
grep -q "Risk: LOW" .stackpilot/tasks/arch-review/TASK-001.md && pass "P10: arch-review has risk assessment" || fail "P10: no risk"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 11: Sprint Finish → cleanup ==="
# ═══════════════════════════════════════════════════════════════════════════════

# Remove the failed task (user chose "skip")
awk '
  /^  - id: TASK-005/ { skip=1; next }
  skip && /^  - id:/ { skip=0 }
  skip { next }
  { print }
' "$BACKLOG" > "${BACKLOG}.tmp" && mv "${BACKLOG}.tmp" "$BACKLOG"

NON_DONE=$(grep -cE "status: (pending|in-progress|soft-blocked|blocked|failed)" "$BACKLOG" 2>/dev/null) || true
[ "${NON_DONE:-0}" = "0" ] && pass "P11: sprint complete — all tasks done" || fail "P11: $NON_DONE tasks not done"

# Sprint cleanup (as defined in SKILL.md)
rm -f .stackpilot/tasks/done/*.md
rm -f .stackpilot/tasks/arch-review/*.md
printf "tasks: []\n" > "$BACKLOG"
printf "" > .stackpilot/tasks/NEEDS_REVIEW.md
printf "tasks: []\n" > .stackpilot/tasks/in-progress.yml

DONE_AFTER=$(ls .stackpilot/tasks/done/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$DONE_AFTER" = "0" ] && pass "P11: done/ cleaned" || fail "P11: done/ not cleaned"

ARCH_AFTER=$(ls .stackpilot/tasks/arch-review/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$ARCH_AFTER" = "0" ] && pass "P11: arch-review/ cleaned" || fail "P11: arch-review/ not cleaned"

BACKLOG_AFTER=$(count_matches "^  - id:" "$BACKLOG")
[ "$BACKLOG_AFTER" = "0" ] && pass "P11: backlog reset to empty" || fail "P11: backlog not empty"

IP_AFTER=$(count_matches "^  - id:" ".stackpilot/tasks/in-progress.yml")
[ "$IP_AFTER" = "0" ] && pass "P11: in-progress reset to empty" || fail "P11: in-progress not empty"

REVIEW_AFTER=$(wc -c < .stackpilot/tasks/NEEDS_REVIEW.md | tr -d ' ')
[ "$REVIEW_AFTER" = "0" ] && pass "P11: NEEDS_REVIEW cleared" || fail "P11: NEEDS_REVIEW not cleared"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 12: Post-cleanup = Sprint Clean ==="
# ═══════════════════════════════════════════════════════════════════════════════

[ -d ".stackpilot/tasks" ] && pass "P12: tasks dir still exists" || fail "P12: tasks dir gone"
[ -f "stackpilot.config.yml" ] && pass "P12: config still exists" || fail "P12: config gone"
[ -f ".stackpilot/path" ] && pass "P12: path file still exists" || fail "P12: path gone"
[ -f .stackpilot/specs/2026-04-07-login-design.md ] && pass "P12: spec persists after cleanup" || fail "P12: spec deleted"
[ -f .stackpilot/plans/2026-04-07-login-plan.md ] && pass "P12: plan persists after cleanup" || fail "P12: plan deleted"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 13: Optimize Sprint state transitions ==="
# ═══════════════════════════════════════════════════════════════════════════════

cat > .stackpilot/optimize-log.tsv <<'EOF'
iteration	commit	metric	delta	outcome	description
1	abc1234	245ms	-12ms	keep	removed N+1 query in getUserList
2	def5678	248ms	+3ms	discard	added index on unused column
3	ghi9012	220ms	-25ms	keep	batch database calls in auth flow
EOF

[ -f .stackpilot/optimize-log.tsv ] && pass "P13: optimize-log.tsv exists" || fail "P13: optimize-log missing"

LINE_COUNT=$(tail -n +2 .stackpilot/optimize-log.tsv | wc -l | tr -d ' ')
[ "$LINE_COUNT" = "3" ] && pass "P13: 3 iterations logged" || fail "P13: expected 3, got $LINE_COUNT"

KEEP_COUNT=$(count_matches "keep" ".stackpilot/optimize-log.tsv")
[ "$KEEP_COUNT" = "2" ] && pass "P13: 2 iterations kept" || fail "P13: expected 2 keeps, got $KEEP_COUNT"

DISCARD_COUNT=$(count_matches "discard" ".stackpilot/optimize-log.tsv")
[ "$DISCARD_COUNT" = "1" ] && pass "P13: 1 iteration discarded" || fail "P13: expected 1, got $DISCARD_COUNT"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo "=== Phase 14: Compete insights tracking ==="
# ═══════════════════════════════════════════════════════════════════════════════

# Use printf with \t to ensure real tabs
printf "iteration\tcompetitor\tdimension\tclassification\tseverity\ttitle\tgap_description\n" > .stackpilot/compete-insights.tsv
printf "1\tCursor\tdaily_workflow\tnew\tinstant-close\tTab completion\tCursor full-file context\n" >> .stackpilot/compete-insights.tsv
printf "2\tCursor\tmuscle_memory\tnew\tweek-1\tInline diff\tCursor shows inline diffs\n" >> .stackpilot/compete-insights.tsv
printf "3\tCursor\tdaily_workflow\tduplicate\t-\tTab context\tSame as iteration 1\n" >> .stackpilot/compete-insights.tsv
printf "4\tAider\tintegration\tnew\tgradual-drift\tGit auto-commit\tAider commits automatically\n" >> .stackpilot/compete-insights.tsv

[ -f .stackpilot/compete-insights.tsv ] && pass "P14: compete-insights.tsv exists" || fail "P14: compete-insights missing"

NEW_COUNT=$(count_matches "	new	" ".stackpilot/compete-insights.tsv")
[ "$NEW_COUNT" = "3" ] && pass "P14: 3 new insights" || fail "P14: expected 3 new, got $NEW_COUNT"

DUP_COUNT=$(count_matches "	duplicate	" ".stackpilot/compete-insights.tsv")
[ "$DUP_COUNT" = "1" ] && pass "P14: 1 duplicate detected" || fail "P14: expected 1, got $DUP_COUNT"

cat > .stackpilot/compete-log.md <<'EOF'
## 2026-04-07 — vs Cursor, Aider

- Moat items: 2
- Migration blockers: 3 (instant-close: 1, week-1: 1, gradual: 1)
- P0 gaps: tab completion context, inline diff
- Specs generated: none
EOF

[ -f .stackpilot/compete-log.md ] && pass "P14: compete-log.md exists" || fail "P14: compete-log missing"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
