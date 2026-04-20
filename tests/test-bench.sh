#!/usr/bin/env bash
# Structural tests for stackpilot-bench Codex execution contracts.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/claude-config/skills/stackpilot-bench/scripts/run-codex-bench.sh"
SCORECARD="$ROOT_DIR/claude-config/skills/stackpilot-bench/scripts/compute-scorecard.sh"
TRAPS="$ROOT_DIR/claude-config/skills/stackpilot-bench/workloads/01-regional-billing-ledger-cutover/traps.yml"
CODEX_DISPATCH="$ROOT_DIR/claude-config/skills/stackpilot/references/codex-dispatch.md"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

grep_in() {
  local pattern="$1"
  local file="$2"
  grep -qE "$pattern" "$file" 2>/dev/null
}

grep_not_in() {
  local pattern="$1"
  local file="$2"
  ! grep -qE "$pattern" "$file" 2>/dev/null
}

grep_in "Codex execution contract" "$CODEX_DISPATCH" \
  && pass "Codex dispatch reference defines a hard execution contract" \
  || fail "Codex dispatch reference missing hard execution contract"

for artifact in "architect.md" "dev-report.md" "qa-report.md"; do
  grep_in "$artifact" "$CODEX_DISPATCH" \
    && pass "Codex dispatch reference requires $artifact" \
    || fail "Codex dispatch reference missing $artifact requirement"
  grep_in "$artifact" "$RUNNER" \
    && pass "bench runner checks $artifact" \
    || fail "bench runner missing $artifact orchestration check"
done

grep_in "orchestration_invalid" "$RUNNER" \
  && pass "bench runner records orchestration_invalid status" \
  || fail "bench runner does not record orchestration_invalid status"

grep_in "orchestration_invalid" "$SCORECARD" \
  && pass "scorecard surfaces orchestration-invalid legs" \
  || fail "scorecard does not surface orchestration-invalid legs"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
cat > "$TMPDIR_TEST/invalid.csv" <<'EOF'
timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status
2099-01-01-0000,abc,1.10.0,wl,zero,1,100,10,0,0,110,10,1,10,10,null,true,0,0,ok
2099-01-01-0000,abc,1.10.0,wl,stackpilot,1,100,10,0,0,110,10,1,10,10,10,true,0,0,orchestration_invalid
EOF
SCORECARD_OUT="$(bash "$SCORECARD" "$TMPDIR_TEST/invalid.csv" 2099-01-01-0000 2>&1)"
if echo "$SCORECARD_OUT" | grep -q "orchestration_invalid" \
   && echo "$SCORECARD_OUT" | awk '/^Stackpilot$/ { getline; print }' | grep -q "0/100"; then
  pass "scorecard gives orchestration-invalid Stackpilot a zero quality score"
else
  fail "scorecard did not zero orchestration-invalid Stackpilot quality"
fi

grep_in "verification_commands" "$TRAPS" \
  && pass "workload uses verification commands for functional pass" \
  || fail "workload missing verification_commands"

grep_in "subprocess.run" "$RUNNER" \
  && pass "runner executes workload verification commands" \
  || fail "runner does not execute verification commands"

grep_not_in "contract tests updated or preserved" "$TRAPS" \
  && pass "workload removed diff-keyword contract-test assertion" \
  || fail "workload still uses diff-keyword contract-test assertion"

if grep -A8 "trap-12-missing-rollback-read-path" "$TRAPS" | grep -q "check_mode: final_file" \
   && grep -A12 "trap-12-missing-rollback-read-path" "$TRAPS" | grep -q "must_match_regex"; then
  pass "trap-12 uses final-file positive checks"
else
  fail "trap-12 still uses brittle global diff negative regex"
fi

if grep -A8 "trap-14-no-reconciliation-shadow-check" "$TRAPS" | grep -q "check_mode: final_file" \
   && grep -A12 "trap-14-no-reconciliation-shadow-check" "$TRAPS" | grep -q "src/jobs/reconcileStripe.ts"; then
  pass "trap-14 scopes reconciliation check to reconcileStripe.ts"
else
  fail "trap-14 still accepts global shadow/parity keyword matches"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
