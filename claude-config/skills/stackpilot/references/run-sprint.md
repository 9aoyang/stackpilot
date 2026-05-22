# Run Sprint — Detailed Protocol

Sprint execution detailed protocol. `SKILL.md` Node 4 (Plan & Run Sprint) is the
high-level entry; this file has the full bash + agent dispatch templates + state
machine + sprint server lifecycle.

## Pre-Sprint

### 1. Parse plan + config

```bash
PLAN=$(ls -t .stackpilot/plans/*.md | head -1)
SPRINT_SLUG=$(basename "${PLAN}" .md)
RUN_DIR=".stackpilot/runs/${SPRINT_SLUG}"

MAX_PARALLEL=$(yq '.qa.max_parallel // 3' stackpilot.config.yml 2>/dev/null || echo 3)
TEST_CMD=$(yq '.qa.test_command' stackpilot.config.yml)
DEEP_REVIEW=$(yq '.qa.deep_review // true' stackpilot.config.yml)
```

`qa.max_parallel` defaults to 3. Override per project in `stackpilot.config.yml`. Set to 1 to disable parallel dispatch entirely.

### 2. Dependency wave analysis

Parse each `### TASK-NNN` block in the plan, extract `depends_on:` field. Topological sort → waves.

Conceptual algorithm (implement in shell or Python):

```
waves = []
remaining = { task_id: deps_set, ... }
while remaining:
    ready = [t for t, deps in remaining.items() if deps ∩ remaining.keys() == ∅]
    if not ready: ABORT "circular dependency in plan"
    # Cap by max_parallel — split into sub-waves if needed
    for chunk in chunks(ready, MAX_PARALLEL):
        waves.append(chunk)
    for t in ready: del remaining[t]
```

Print wave plan before dispatch:

```
Sprint Wave Plan (max_parallel=3):
  Wave 1 (3 parallel): TASK-001, TASK-002, TASK-005
  Wave 2 (2 parallel): TASK-003, TASK-004
  Wave 3 (1 serial):   TASK-006
Total: 6 tasks across 3 waves
```

### 3. Initialize sprint run directory + per-task state.json

```bash
mkdir -p "${RUN_DIR}"
grep -qxF ".stackpilot/runs/" .gitignore 2>/dev/null || echo ".stackpilot/runs/" >> .gitignore

for TASK_ID in $ALL_TASK_IDS; do
  mkdir -p "${RUN_DIR}/${TASK_ID}"
  # depends_on parsed from plan.md for that task
  DEPS_JSON=$(jq -nc --argjson d "${DEPS_FOR_TASK_AS_JSON_ARRAY}" '$d')
  cat > "${RUN_DIR}/${TASK_ID}/state.json" <<EOF
{
  "task_id": "${TASK_ID}",
  "wave": ${WAVE_NUM},
  "phase": "pending",
  "depends_on": ${DEPS_JSON},
  "verify_fix_rounds": 0,
  "retry_count": 0,
  "last_result": null,
  "started_at": null,
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
done
```

state.json transitions during the loop — see "State Transitions" section below.

The `depends_on` field is consumed by `dashboard.html` to render the DAG edges.
Keep it in sync with the plan's `depends_on:` field per task.

### 4. Start sprint server + push dashboard (HTML view layer)

```bash
SERVER_INFO=$(bash ~/Documents/github/stackpilot/scripts/preview/start-server.sh \
  --project-dir "$PWD" --sprint-slug "${SPRINT_SLUG}" --background 2>&1 | head -1)
PORT=$(echo "${SERVER_INFO}" | sed -n 's/.*"port":[[:space:]]*\([0-9]*\).*/\1/p')
URL_HOST=$(echo "${SERVER_INFO}" | sed -n 's/.*"url_host":[[:space:]]*"\([^"]*\)".*/\1/p')

mkdir -p ".stackpilot/views/${SPRINT_SLUG}"
cp ~/Documents/github/stackpilot/claude-config/skills/stackpilot/references/views/dashboard.html \
   ".stackpilot/views/${SPRINT_SLUG}/dashboard.html"
# Replace {{SPRINT_SLUG}} token so the page knows which slug to fetch state for
sed -i.bak "s/{{SPRINT_SLUG}}/${SPRINT_SLUG}/g" \
  ".stackpilot/views/${SPRINT_SLUG}/dashboard.html" && rm ".stackpilot/views/${SPRINT_SLUG}/dashboard.html.bak"

DASHBOARD_URL="http://${URL_HOST:-localhost}:${PORT}/sprints/${SPRINT_SLUG}/dashboard.html"
echo "📊 Live dashboard: ${DASHBOARD_URL}"
```

**Print the URL exactly once** at sprint start. The dashboard auto-refreshes
via WebSocket as `state.json` files change — no further URL re-prints unless
the user closes their browser and asks for it again.

If `start-server.sh` fails (port conflict, node missing, etc.), capture the
error, log it, and continue sprint in **terminal-only mode** — print
per-task progress lines per the existing protocol. Do not block the sprint
on dashboard generation.

## Pre-coding confirmation

> "Plan ready. ${TOTAL_TASKS} tasks across ${WAVE_COUNT} waves (max_parallel=${MAX_PARALLEL}). Proceed with coding?"
> A. Yes  B. I'll handle it elsewhere

<!-- CONFIRM-GATE: pre-coding -->

## Sprint Execution Loop

### For each wave (topological order):

**Dispatch all tasks in the wave in parallel** via multiple `TaskCreate` + simultaneous `Agent(...)` calls in a single message. Each task has its own worktree (`isolation="worktree"`), so parallel dev is safe.

**Wave completion semantics:** wait for ALL wave-tasks to finish (success or failure) before advancing to the next wave. A failed task (`CRITICAL` or 3x `SOFT-BLOCKED`) does NOT abort the wave — other tasks in the same wave still complete. Sprint pauses after the wave for user decision.

### For each task within the wave:

#### 1. Track

```
TaskCreate(subject="TASK-NNN: <title>", description="<one-line>", activeForm="<gerund>")
TaskUpdate(taskId=<id>, status="in_progress")
update_state TASK-NNN phase="arch" started_at=$NOW
```

#### 2. Architecture review (standard complexity only)

```
Agent(description="Arch: TASK-NNN",
      subagent_type="sp-architect",
      prompt="<task context>")
update_state TASK-NNN phase="dev"
```

sp-architect's methodology is loaded from its registered agent file (frontmatter pins `model: opus` and `tools: Read, Glob, Grep, WebSearch` — enforces read-only). Main agent passes only the task context.

#### 3. Development (route by task.type)

For `type: docs` tasks → `sp-docs` (haiku, cheaper for mechanical doc updates):

```
Agent(description="Docs: TASK-NNN",
      subagent_type="sp-docs",
      prompt="<task>",
      isolation="worktree")
```

All other types → `sp-dev`:

```
Agent(description="Dev: TASK-NNN",
      subagent_type="sp-dev",
      prompt="<task> + <arch review output>",
      isolation="worktree")
```

`update_state TASK-NNN phase="simplify" verify_fix_rounds=<count from dev report>`

#### 4. Handle dev result

- `[ESCALATION]` → present to user, wait; `update_state last_result="escalation"`
- `[SOFT-BLOCKED]` → retry up to 3 times (`update_state retry_count++`), then ask user

#### 4.5. Simplify (standard complexity only — skip light tasks and `type: docs`)

After dev result is clean, invoke the simplify skill to catch over-engineering (premature abstractions, dead error handling, unnecessary helpers, redundant comments) before QA spends cycles on it:

```
Skill(skill="simplify",
      args="Scope: TASK-NNN only. Restrict review and edits to this task's relevant_files: <files>. Preserve test pass status — re-run qa.test_command after any change.")
```

If simplify modifies files, commit the simplify diff separately (e.g. `refactor: simplify TASK-NNN`) so QA sees both dev and simplify diffs distinctly. If simplify breaks tests it cannot self-fix, revert simplify changes and proceed to QA on the un-simplified code (don't block the task on stylistic cleanup).

`update_state TASK-NNN phase="qa"`

#### 5. QA review (standard complexity only)

```
Agent(description="QA: TASK-NNN",
      subagent_type="sp-qa",
      prompt="<task> + <dev result> + Risk level: <from arch review, or LOW> + Project memory: <.stackpilot/ARCHITECTURE.md content> + Acceptance criteria: <read .stackpilot/specs/<feature>-criteria.md>")
```

**sp-qa acceptance-criteria contract:** after passing the standard 12-dim review, sp-qa MUST execute each acceptance criterion's verify command and update the corresponding row's Status field (pass / fail / n-a-this-task) in `.stackpilot/specs/<feature>-criteria.md`. Criteria not applicable to this task → mark `n-a-this-task` with a one-line reason.

For light tasks, skip the sp-qa dispatch. Main agent still runs the Stage 4 consistency audit grep checks inline (absolute-claim / scope-completeness / dead-reference) since these are deterministic and cheap.

`update_state TASK-NNN phase="deep-review"`

#### 5.5. Deep Review (default on, HIGH risk only)

Read `qa.deep_review` from `stackpilot.config.yml`. Default is `true` if absent. Unless explicitly set to `false`, if Risk level is HIGH, dispatch a fresh-context reviewer to catch scope/consistency issues sp-qa may have anchored past:

```
Agent(description="DeepReview: TASK-NNN",
      subagent_type="general-purpose",
      model="sonnet",
      prompt="You are an independent reviewer. You have NO prior context on this task — that is intentional. Review the following diff purely for scope/consistency issues:\n\n<git diff <pre-task-sha>..HEAD -- <relevant_files> output>\n\nTask description: <task.description>\n\nFind:\n1. Absolute claims (sole/only/never/always) that are factually wrong given the rest of the codebase\n2. Unmigrated call sites, dead references, or renamed symbols still appearing in unchanged files\n3. Cross-file inconsistencies (e.g., doc claims X but code says Y)\n\nReport confidence >= 80 with file:line evidence. Under 200 words. If no findings, reply 'No scope/consistency issues found.'")
```

Merge findings into the QA report before Step 6. If `qa.deep_review: false` is explicitly set, skip silently.

`update_state TASK-NNN phase="complete"`

#### 6. Handle QA result

- `[CRITICAL]` → present to user; `update_state last_result="critical"`
- `[SOFT-BLOCKED]` → retry dev+QA cycle; `update_state retry_count++`

#### 7. Complete

```
TaskUpdate(taskId=<id>, status="completed")
update_state TASK-NNN phase="complete" last_result="complete" updated_at=$NOW
```

Print progress line:
```
✅ TASK-NNN  <title>     dev → QA passed     (<wave-completed>/<wave-total> in wave, <total-done>/<sprint-total> overall)
```

**Pause only when:** 3x soft-blocked, QA critical, new external dependency.

### After all tasks in a wave finish

Check each task's state.json `last_result`:
- Any `critical` or unresolved `escalation` → pause sprint, present to user
- Otherwise advance to next wave

## State Transitions

state.json `phase` lifecycle per task:

```
Standard task: pending → arch → dev → simplify → qa → deep-review (HIGH only) → complete
Light task:    pending → dev → complete
type: docs:    pending → dev (sp-docs) → complete
```

Update helper (place in scripts or inline):

```bash
update_state() {
  local task_id=$1 phase=$2
  local state_file="${RUN_DIR}/${task_id}/state.json"
  jq --arg p "${phase}" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.phase = $p | .updated_at = $t' "${state_file}" > "${state_file}.tmp" \
    && mv "${state_file}.tmp" "${state_file}"
}
```

Atomic write (`.tmp` then `mv`) — matches the project's CSV append convention so a mid-write crash leaves the previous state intact.

## Sprint Interrupted — read state.json first

When `/stackpilot` detects an interrupted sprint (plans exist, no active
TaskList from the current session), prefer reading
`.stackpilot/runs/<sprint-slug>/TASK-*/state.json` over grep'ing git log.
Only fall back to git log heuristic if state.json is missing.

When resuming, also restart the sprint server (if not still running) and
print the dashboard URL — re-opening the browser tab will reconnect via WS
and the resumed task states will populate automatically (no state migration
needed; dashboard re-fetches via `/api/state/<slug>`).

```bash
for STATE_FILE in "${RUN_DIR}"/TASK-*/state.json; do
  TASK_ID=$(jq -r '.task_id' "${STATE_FILE}")
  PHASE=$(jq -r '.phase' "${STATE_FILE}")
  LAST_RESULT=$(jq -r '.last_result // "none"' "${STATE_FILE}")
  WAVE=$(jq -r '.wave' "${STATE_FILE}")
  echo "${WAVE} ${TASK_ID} ${PHASE} ${LAST_RESULT}"
done | sort -n
```

Tasks where `phase == "complete" && last_result == "complete"` are done. Otherwise resume from the recorded phase — skip already-completed sub-steps (e.g. if phase is `qa`, dev/simplify already done; jump straight to sp-qa dispatch).

## Sprint Complete

YOU MUST complete the Sprint Finish flow before ending the conversation. Read
`references/sprint-finish.md` and follow every step. You MUST present the
A/B/C/D branch options (either via `finish-report.html` action JSON OR terminal
fallback) and wait for user input.

The sprint server keeps running through Finish — it is stopped at the end of
the Finish flow via `stop-server.sh --slug <sprint-slug>`.

> **Note:** A `pre-merge-commit` git hook enforces squash-only merges on main/master. Non-squash merges will be rejected by the hook.
