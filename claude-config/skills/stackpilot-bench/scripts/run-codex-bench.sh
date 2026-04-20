#!/usr/bin/env bash
set -euo pipefail

# run-codex-bench.sh
# Usage:
#   run-codex-bench.sh [--workload <id>] [--leg <zero|stackpilot>] [--no-history]
#
# Runs the stackpilot benchmark through Codex headless mode. By default this
# executes all fixed workloads and the zero/stackpilot legs, appends rows to history.csv,
# and renders a scorecard for the run.

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SCRIPT_DIR="$ROOT/claude-config/skills/stackpilot-bench/scripts"
WORKLOAD_ROOT="$ROOT/claude-config/skills/stackpilot-bench/workloads"
RUN_LEG="$SCRIPT_DIR/run-leg-codex.sh"
RESET_WORKTREE="$SCRIPT_DIR/reset-worktree.sh"
COMPUTE_SCORECARD="$SCRIPT_DIR/compute-scorecard.sh"

BENCH_DIR="$ROOT/.stackpilot/benchmarks"
HISTORY_CSV="$BENCH_DIR/history.csv"
LOCK_FILE="$BENCH_DIR/.lock"
WORKTREE="$ROOT/.worktrees/bench-run"
HEADER="timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status"

WORKLOAD_FILTER=""
LEG_FILTER=""
NO_HISTORY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workload)
      WORKLOAD_FILTER="${2:?--workload requires an id}"
      shift 2
      ;;
    --leg)
      LEG_FILTER="${2:?--leg requires a leg name}"
      shift 2
      ;;
    --no-history)
      NO_HISTORY=1
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "$LEG_FILTER" && "$LEG_FILTER" != "zero" && "$LEG_FILTER" != "stackpilot" ]]; then
  echo "ERROR: --leg must be one of zero, stackpilot" >&2
  exit 2
fi

mkdir -p "$BENCH_DIR"

cleanup_lock() {
  rm -f "$LOCK_FILE"
}

cleanup_worktree() {
  if [[ -d "$WORKTREE" ]]; then
    local branch
    branch="$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    if [[ "$branch" == bench/run-* ]]; then
      git branch -D "$branch" >/dev/null 2>&1 || true
    fi
  fi
}

cleanup() {
  cleanup_worktree
  cleanup_lock
}
trap cleanup EXIT

if [[ ! -d "$ROOT/.stackpilot" ]]; then
  echo "run /stackpilot first to initialize this project" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "commit or stash changes before running benchmark" >&2
  exit 1
fi

if [[ -f "$LOCK_FILE" ]]; then
  LOCK_PID="$(awk '{print $1}' "$LOCK_FILE" 2>/dev/null || true)"
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "another benchmark run in progress (PID $LOCK_PID)" >&2
    exit 1
  fi
  rm -f "$LOCK_FILE"
fi
echo "$$ $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOCK_FILE"

python3 - "$ROOT/.stackpilot/plans" <<'PYEOF'
import pathlib
import sys
import time

plans_dir = pathlib.Path(sys.argv[1])
if not plans_dir.exists():
    sys.exit(0)

cutoff = time.time() - 24 * 60 * 60
for path in plans_dir.glob('*.md'):
    try:
        if path.stat().st_mtime < cutoff:
            continue
        if 'in_progress' in path.read_text(encoding='utf-8', errors='replace'):
            print(f"finish current sprint or run bench after merge: {path}", file=sys.stderr)
            sys.exit(42)
    except OSError:
        continue
PYEOF

if [[ ! -x "$RUN_LEG" ]]; then
  echo "ERROR: missing executable runner: $RUN_LEG" >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not on PATH" >&2
  exit 1
fi

if [[ -f "$HISTORY_CSV" ]]; then
  CURRENT_HEADER="$(head -n 1 "$HISTORY_CSV" | python3 -c 'import csv,sys; print(",".join(next(csv.reader(sys.stdin))))')"
  if [[ "$CURRENT_HEADER" != "$HEADER" ]]; then
    BAK_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    mv "$HISTORY_CSV" "$HISTORY_CSV.bak-$BAK_TS"
    printf '%s\n' "$HEADER" > "$HISTORY_CSV"
    echo "history.csv schema changed — previous file backed up"
  fi
else
  printf '%s\n' "$HEADER" > "$HISTORY_CSV"
fi

if [[ -d "$WORKTREE" ]]; then
  STALE_BRANCH="$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ "$STALE_BRANCH" != bench/run-* ]]; then
    echo "ERROR: stale worktree is not on a benchmark branch: $STALE_BRANCH" >&2
    exit 1
  fi
  cleanup_worktree
fi

RUN_TS="$(date -u +%Y-%m-%d-%H%M)"
RUN_DIR="$BENCH_DIR/runs/$RUN_TS"
RAW_DIR="$RUN_DIR/raw"
ROWS_CSV="$RUN_DIR/rows.csv"

if [[ -e "$RUN_DIR" ]]; then
  RUN_TS="$(date -u +%Y-%m-%d-%H%M%S)"
  RUN_DIR="$BENCH_DIR/runs/$RUN_TS"
  RAW_DIR="$RUN_DIR/raw"
  ROWS_CSV="$RUN_DIR/rows.csv"
fi

mkdir -p "$RAW_DIR"
printf '%s\n' "$HEADER" > "$ROWS_CSV"

BASE_BRANCH="${SP_BENCH_BASE_BRANCH:-main}"
BRANCH="bench/run-$RUN_TS"
git worktree add "$WORKTREE" -b "$BRANCH" "$BASE_BRANCH" >/dev/null
git -C "$WORKTREE" rev-parse HEAD > "$WORKTREE/.bench-base-sha"

GIT_SHA="$(git rev-parse HEAD)"
STACKPILOT_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo unknown)"

workload_dirs=()
while IFS= read -r dir; do
  workload_dirs+=("$dir")
done < <(find "$WORKLOAD_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#workload_dirs[@]} -eq 0 ]]; then
  echo "no workloads installed under workloads/ — design and add representative workloads before invoking /stackpilot-bench" >&2
  exit 1
fi

write_prompt() {
  local prompts_yml="$1"
  local leg="$2"
  local prompt_out="$3"
  python3 - "$prompts_yml" "$leg" "$prompt_out" <<'PYEOF'
import pathlib
import sys
import textwrap
import yaml

prompts_yml, leg, prompt_out = sys.argv[1:4]
data = yaml.safe_load(pathlib.Path(prompts_yml).read_text(encoding='utf-8'))
task = data[leg].strip()

preamble = textwrap.dedent(f"""
    You are running a Stackpilot benchmark leg inside a disposable Codex git worktree.

    Hard constraints:
    - Work only under `bench-sandbox/`.
    - If the workload text says `sandbox/...`, treat that as `bench-sandbox/...`.
    - Do not modify files outside `bench-sandbox/`.
    - Do not ask the user follow-up questions; record assumptions in your final answer.
    - Implement real code changes for the requested feature. Add or update tests when practical.
    - Avoid broad rewrites, generated dependency folders, and unrequested features.

    Benchmark leg: `{leg}`
""").strip()

if leg == 'stackpilot':
    body = textwrap.dedent(f"""
        $stackpilot

        {preamble}

        Use the Codex Stackpilot flow for this request.

        Required orchestration evidence:
        - Write `bench-sandbox/.stackpilot-bench/architect.md` with the architecture decision,
          rejected alternatives, risks, and implementation boundary.
        - Write `bench-sandbox/.stackpilot-bench/dev-report.md` with files changed, behavior
          implemented, assumptions, and verification commands attempted.
        - Write `bench-sandbox/.stackpilot-bench/qa-report.md` with the QA verdict, findings,
          exact commands run, and whether fixes were required.
        - QA must inspect the final diff. If QA finds a critical issue, run one scoped fix loop,
          then update dev-report.md and qa-report.md with the result.

        User request:
        {task}
    """).strip()
else:
    body = textwrap.dedent(f"""
        {preamble}

        User request:
        {task}
    """).strip()

pathlib.Path(prompt_out).write_text(body + "\n", encoding='utf-8')
PYEOF
}

leg_order() {
  local run_ts="$1"
  python3 - "$run_ts" <<'PYEOF'
import hashlib
import sys

run_ts = sys.argv[1]
seed = hashlib.md5(run_ts.encode()).hexdigest()[:8]
legs = ['zero', 'stackpilot']
for leg in sorted(legs, key=lambda item: hashlib.md5((seed + item).encode()).hexdigest()):
    print(leg)
PYEOF
}

evaluate_leg() {
  local traps_yml="$1"
  local diff_file="$2"
  local qa_file="$3"
  local leg="$4"
  local sandbox_dir="$5"
  local eval_out="$6"
  python3 - "$traps_yml" "$diff_file" "$qa_file" "$leg" "$sandbox_dir" "$eval_out" <<'PYEOF'
import json
import pathlib
import re
import shutil
import subprocess
import sys
import yaml

traps_yml, diff_file, qa_file, leg, sandbox_dir, eval_out = sys.argv[1:7]
config = yaml.safe_load(pathlib.Path(traps_yml).read_text(encoding='utf-8')) or {}
diff_text = pathlib.Path(diff_file).read_text(encoding='utf-8', errors='replace') if pathlib.Path(diff_file).exists() else ''
qa_text = pathlib.Path(qa_file).read_text(encoding='utf-8', errors='replace') if pathlib.Path(qa_file).exists() else ''
sandbox = pathlib.Path(sandbox_dir)

def search(pattern, text, workload, trap_id, field):
    try:
        return re.search(pattern, text, flags=re.MULTILINE) is not None
    except re.error as exc:
        print(
            f"Aborting run: invalid regex in workload '{workload}', trap id '{trap_id}', field '{field}': {exc}",
            file=sys.stderr,
        )
        sys.exit(17)

def patterns(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]

workload = pathlib.Path(traps_yml).parent.name
workload_dir = pathlib.Path(traps_yml).parent
hidden_evaluator_src = workload_dir / 'evaluator'
hidden_evaluator_dst = sandbox / '.stackpilot-hidden-evaluator'
traps = config.get('traps') or []
traps_avoided = 0
traps_caught = None if leg != 'stackpilot' else 0
trap_results = []

for trap in traps:
    trap_id = trap.get('id', '<missing-id>')
    mode = trap.get('check_mode', 'diff')
    target_text = diff_text
    if mode == 'final_file':
        check_file = trap.get('check_file')
        if check_file:
            target_path = sandbox / check_file
            target_text = target_path.read_text(encoding='utf-8', errors='replace') if target_path.exists() else ''

    bad_regex = trap.get('diff_bad_regex') or r'(?!)'
    bad_present = search(bad_regex, target_text, workload, trap_id, 'diff_bad_regex')

    missing_required = []
    for required in patterns(trap.get('must_match_regex')):
        if not search(required, target_text, workload, trap_id, 'must_match_regex'):
            missing_required.append(required)

    avoided = (not bad_present) and not missing_required
    if avoided:
        traps_avoided += 1

    caught = None
    if leg == 'stackpilot':
        qa_regex = trap.get('qa_good_regex') or r'(?!)'
        caught = search(qa_regex, qa_text, workload, trap_id, 'qa_good_regex')
        if caught:
            traps_caught += 1

    trap_results.append({
        'id': trap_id,
        'avoided': avoided,
        'missing_required': missing_required,
        'caught_in_qa': caught,
    })

functional_results = []
functional_pass = True
for idx, assertion in enumerate(config.get('functional_assertions') or [], start=1):
    pattern = assertion.get('diff_must_match_regex') or r'(?!)'
    ok = search(pattern, diff_text, workload, f'functional-{idx}', 'diff_must_match_regex')
    functional_results.append({
        'description': assertion.get('description', f'functional-{idx}'),
        'passed': ok,
    })
    functional_pass = functional_pass and ok

verification_results = []
hidden_evaluator_present = hidden_evaluator_src.exists()
if hidden_evaluator_present:
    if hidden_evaluator_dst.exists():
        shutil.rmtree(hidden_evaluator_dst)
    shutil.copytree(hidden_evaluator_src, hidden_evaluator_dst)

for idx, verification in enumerate(config.get('verification_commands') or [], start=1):
    command = verification.get('command')
    if not command:
        continue
    timeout = int(verification.get('timeout_sec') or 120)
    try:
        completed = subprocess.run(
            command,
            cwd=sandbox,
            shell=True,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
        ok = completed.returncode == 0
        stdout = completed.stdout[-4000:]
        stderr = completed.stderr[-4000:]
        exit_code = completed.returncode
    except subprocess.TimeoutExpired as exc:
        ok = False
        stdout = (exc.stdout or '')[-4000:] if isinstance(exc.stdout, str) else ''
        stderr = (exc.stderr or '')[-4000:] if isinstance(exc.stderr, str) else ''
        exit_code = 'timeout'

    verification_results.append({
        'description': verification.get('description', f'verification-{idx}'),
        'command': command,
        'passed': ok,
        'exit_code': exit_code,
        'stdout_tail': stdout,
        'stderr_tail': stderr,
    })
    functional_pass = functional_pass and ok

orchestration_valid = None
orchestration_results = []
if leg == 'stackpilot':
    artifact_dir = sandbox / '.stackpilot-bench'
    required_artifacts = {
        'architect.md': [r'(?i)architecture|decision|risk|boundary|rejected', r'bench-sandbox|src/'],
        'dev-report.md': [r'(?i)files changed|changed files|implementation|implemented', r'(?i)verification|npm test|test'],
        'qa-report.md': [r'(?i)QA|verdict|PASS|FAIL|CRITICAL', r'(?i)git diff|diff|npm test|test'],
    }
    orchestration_valid = True
    for name, required_patterns in required_artifacts.items():
        path = artifact_dir / name
        text = path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''
        missing = [p for p in required_patterns if not search(p, text, workload, f'orchestration-{name}', 'must_match_regex')]
        ok = path.exists() and len(text.strip()) >= 80 and not missing
        orchestration_results.append({
            'artifact': name,
            'exists': path.exists(),
            'non_empty': len(text.strip()) >= 80,
            'missing_required': missing,
            'passed': ok,
        })
        orchestration_valid = orchestration_valid and ok

with open(eval_out, 'w', encoding='utf-8') as fh:
    json.dump({
        'traps_total': len(traps),
        'traps_avoided_in_diff': traps_avoided,
        'traps_caught_in_qa': traps_caught,
        'functional_pass': functional_pass,
        'orchestration_valid': orchestration_valid,
        'hidden_evaluator_present': hidden_evaluator_present,
        'trap_results': trap_results,
        'functional_results': functional_results,
        'verification_results': verification_results,
        'orchestration_results': orchestration_results,
    }, fh, indent=2)
PYEOF
}

append_row() {
  local rows_csv="$1"
  local workload_id="$2"
  local leg="$3"
  local result_json="$4"
  local eval_json="$5"
  python3 - "$rows_csv" "$RUN_TS" "$GIT_SHA" "$STACKPILOT_VERSION" "$workload_id" "$leg" "$result_json" "$eval_json" <<'PYEOF'
import csv
import json
import sys

rows_csv, run_ts, git_sha, version, workload_id, leg, result_json, eval_json = sys.argv[1:9]
header = "timestamp,git_sha,stackpilot_version,workload_id,leg,run_n,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,total_tokens,duration_sec,tool_uses_count,traps_total,traps_avoided_in_diff,traps_caught_in_qa,functional_pass,signals_critical,signals_soft_blocked,status".split(',')

with open(result_json, encoding='utf-8') as fh:
    result = json.load(fh)
with open(eval_json, encoding='utf-8') as fh:
    evaluation = json.load(fh)

def val(value):
    if value is None:
        return 'null'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return value

status = result.get('status') or 'error'
if leg == 'stackpilot' and evaluation.get('orchestration_valid') is False and status == 'ok':
    status = 'orchestration_invalid'

row = {
    'timestamp': run_ts,
    'git_sha': git_sha,
    'stackpilot_version': version,
    'workload_id': workload_id,
    'leg': leg,
    'run_n': 1,
    'input_tokens': val(result.get('input_tokens')),
    'output_tokens': val(result.get('output_tokens')),
    'cache_read_tokens': val(result.get('cache_read_tokens')),
    'cache_creation_tokens': val(result.get('cache_creation_tokens')),
    'total_tokens': val(result.get('total_tokens')),
    'duration_sec': val(result.get('duration_sec')),
    'tool_uses_count': val(result.get('tool_uses_count')),
    'traps_total': val(evaluation.get('traps_total')),
    'traps_avoided_in_diff': val(evaluation.get('traps_avoided_in_diff')),
    'traps_caught_in_qa': val(evaluation.get('traps_caught_in_qa')),
    'functional_pass': val(evaluation.get('functional_pass')),
    'signals_critical': 0,
    'signals_soft_blocked': 0,
    'status': status,
}

with open(rows_csv, 'a', newline='', encoding='utf-8') as fh:
    writer = csv.DictWriter(fh, fieldnames=header)
    writer.writerow(row)
PYEOF
}

for workload_dir in "${workload_dirs[@]}"; do
  workload_id="$(basename "$workload_dir")"
  if [[ -n "$WORKLOAD_FILTER" && "$WORKLOAD_FILTER" != "$workload_id" ]]; then
    continue
  fi

  prompts_yml="$workload_dir/prompts.yml"
  traps_yml="$workload_dir/traps.yml"
  sandbox_src="$workload_dir/sandbox"

  if [[ ! -f "$prompts_yml" || ! -f "$traps_yml" || ! -d "$sandbox_src" ]]; then
    echo "ERROR: incomplete workload: $workload_id" >&2
    exit 1
  fi

  while IFS= read -r leg; do
    if [[ -n "$LEG_FILTER" && "$LEG_FILTER" != "$leg" ]]; then
      continue
    fi

    echo "bench: $workload_id / $leg"

    reset_output="$(bash "$RESET_WORKTREE" "$WORKTREE" "$sandbox_src")"
    leg_start_sha="$(awk '/^reset-worktree: OK/ {print $NF}' <<< "$reset_output")"
    if [[ -z "$leg_start_sha" ]]; then
      echo "ERROR: reset-worktree did not return leg-start SHA" >&2
      exit 1
    fi

    prompt_file="$RAW_DIR/$workload_id-$leg.prompt.txt"
    result_json="$RAW_DIR/$workload_id-$leg.result.json"
    diff_file="$RAW_DIR/$workload_id-$leg-diff.patch"
    qa_file="$RAW_DIR/$workload_id-$leg-qa.txt"
    eval_json="$RAW_DIR/$workload_id-$leg.eval.json"

    write_prompt "$prompts_yml" "$leg" "$prompt_file"

    set +e
    bash "$RUN_LEG" "$WORKTREE" "$leg" "$prompt_file" "$result_json"
    leg_exit=$?
    set -e
    if [[ $leg_exit -ne 0 ]]; then
      echo "bench: $workload_id / $leg ended with runner exit $leg_exit; recording row and continuing" >&2
    fi

    git -C "$WORKTREE" add -N -- \
      bench-sandbox/ \
      ':(exclude)bench-sandbox/.stackpilot-bench/**' \
      ':(exclude)bench-sandbox/.stackpilot-hidden-evaluator/**' \
      ':(exclude)bench-sandbox/node_modules/**' \
      ':(exclude)bench-sandbox/.next/**' \
      ':(exclude)bench-sandbox/dist/**' \
      ':(exclude)bench-sandbox/build/**' \
      ':(exclude)bench-sandbox/coverage/**' \
      ':(exclude)bench-sandbox/*.tsbuildinfo' \
      >/dev/null 2>&1 || true

    git -C "$WORKTREE" diff "$leg_start_sha" -- \
      bench-sandbox/ \
      ':(exclude)bench-sandbox/.stackpilot-bench/**' \
      ':(exclude)bench-sandbox/.stackpilot-hidden-evaluator/**' \
      ':(exclude)bench-sandbox/node_modules/**' \
      ':(exclude)bench-sandbox/.next/**' \
      ':(exclude)bench-sandbox/dist/**' \
      ':(exclude)bench-sandbox/build/**' \
      ':(exclude)bench-sandbox/coverage/**' \
      ':(exclude)bench-sandbox/*.tsbuildinfo' \
      > "$diff_file"

    if [[ "$leg" == "stackpilot" ]]; then
      artifact_dir="$WORKTREE/bench-sandbox/.stackpilot-bench"
      for artifact in architect.md dev-report.md qa-report.md; do
        if [[ -f "$artifact_dir/$artifact" ]]; then
          cp "$artifact_dir/$artifact" "$RAW_DIR/$workload_id-stackpilot-$artifact"
        fi
      done
      cp "$artifact_dir/qa-report.md" "$qa_file" 2>/dev/null \
        || cp "${result_json%.json}.last.txt" "$qa_file" 2>/dev/null \
        || : > "$qa_file"
    else
      : > "$qa_file"
    fi

    evaluate_leg "$traps_yml" "$diff_file" "$qa_file" "$leg" "$WORKTREE/bench-sandbox" "$eval_json"
    append_row "$ROWS_CSV" "$workload_id" "$leg" "$result_json" "$eval_json"
  done < <(leg_order "$RUN_TS")
done

if [[ "$(wc -l < "$ROWS_CSV" | tr -d ' ')" == "1" ]]; then
  echo "ERROR: no benchmark rows produced" >&2
  exit 1
fi

if [[ "$NO_HISTORY" == "0" ]]; then
  tail -n +2 "$ROWS_CSV" >> "$HISTORY_CSV"
  bash "$COMPUTE_SCORECARD" "$HISTORY_CSV" "$RUN_TS" > "$RUN_DIR/scorecard.md"
  echo "bench: scorecard $RUN_DIR/scorecard.md"
  cat "$RUN_DIR/scorecard.md"
else
  echo "bench: rows $ROWS_CSV"
fi
