---
name: stackpilot
description: Sprint orchestration for Claude Code. Turns feature requests into working code through a 5-node pipeline (Exploration → Design → Spec & Criteria → Plan & Run Sprint → Finish). HTML view artifacts at human decision points; markdown data layer for sub-agents. Use when starting, resuming, tidying, or checking on development work.
license: Apache-2.0
compatibility: Claude Code native.
metadata:
  author: stackpilot
  version: "2.0.0"
---

# Stackpilot

> v2.0 HTML-first rebuild. Data layer (markdown/YAML/JSON) feeds sub-agents and git diff;
> view layer (self-contained HTML) gets generated at human decision points and is never
> source of truth. See `## Dual-Track Principle` below.

## Dual-Track Principle

**One-liner: data layer → sub-agents, view layer → humans.**

Every stackpilot artifact lives in exactly one of two layers: the **data layer** (markdown / YAML / JSON for sub-agents and git) or the **view layer** (HTML rendered from the data layer for humans). The data layer is always source of truth; the view layer can be deleted and regenerated.

| Layer | Audience | Format | SoT? | Examples |
|-------|----------|--------|------|----------|
| **Data** | sub-agents (sp-architect/dev/qa/docs), git diff, version control | markdown / YAML / JSON | ✅ | `.stackpilot/ARCHITECTURE.md`, `specs/*-design.md`, `specs/*-criteria.md`, `plans/*-plan.md`, `runs/<sprint>/TASK-*/state.json`, agent completion reports |
| **View** | human decision-maker, browser | HTML (self-contained, CDN libs) | ❌ | `.stackpilot/views/<sprint>/{design-options,dashboard,spec-review,finish-report,architecture}.html` |

**Rules:**

- Sub-agents only consume / produce data layer. They never see HTML.
- View HTML is regenerated from the data layer; deleting `.stackpilot/views/` is always safe.
- User actions on HTML (button click, editing criteria rows) write `*-action.json` files via `POST /api/action/<slug>/<name>`. The main agent reads that JSON and applies edits back to the data layer (e.g. updated criteria descriptions written into `criteria.md`).
- When CDN is blocked, the server fails to start, or the user prefers terminal — fall back to terminal prompt at every node. HTML is an enhancement, not a prerequisite.

## Step 0+1: Initialize (single bash call — do NOT split)

```bash
SP_DIR="${STACKPILOT_DIR:-$HOME/.stackpilot}"
[ -L ~/.claude/skills/stackpilot ] && SP_DIR="$(readlink ~/.claude/skills/stackpilot | sed 's|/claude-config/skills/stackpilot.*||')"
[ -x "$SP_DIR/scripts/sync-skills.sh" ] && "$SP_DIR/scripts/sync-skills.sh" --auto-update --quick 2>&1 || true

echo "---STATE---"
[ -d .stackpilot ] && echo "initialized" || echo "NOT_INITIALIZED"
[ -f .stackpilot/ARCHITECTURE.md ] && echo "ARCH_EXISTS" || echo "ARCH_MISSING"
ls -t .stackpilot/plans/*.md 2>/dev/null || echo "NO_PLANS"
ls -t .stackpilot/specs/*.md 2>/dev/null || echo "NO_SPECS"

echo "---DEBRIS---"
ls .claude/plans/*.md 2>/dev/null || true
[ -d .superpowers ] && echo "SUPERPOWERS_EXISTS"
git status --porcelain 2>/dev/null | head -5
```

Also check TaskList for any in-progress sprint tasks from the current session.

Default output: concise state summary + routing decision in 1–3 lines. Detailed status format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  implement login page    done
🔄 TASK-002  integrate payment API   in-progress
⏳ TASK-003  write unit tests        pending
━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 2: Route by State

### Not Initialized

```bash
bash ~/Documents/github/stackpilot/scripts/init.sh 2>&1
```

Re-run Step 0+1 after init. Only mention config if test_command binary was not found.

### Architecture Missing (first run only)

`.stackpilot/ARCHITECTURE.md` does not exist. Run one-time project assessment:

1. Read `CLAUDE.md`
2. Scan structure: `find src -type d | head -30`, `ls package.json pyproject.toml Cargo.toml go.mod`, `git log --oneline -10`
3. Read key entry points (`src/app/`, `src/lib/`, main config)
4. Write `.stackpilot/ARCHITECTURE.md` with these `##` sections: **What This Project Is**, **Stack**, **Key Directories**, **Data Flow / Agent Pipeline**, **Key Design Decisions**, **Conventions & Gotchas** (empty placeholder `<!-- add entries as they surface -->`), **Review Patterns** (max 20 entries; `<!-- maintained via Sprint Finish -->`)
5. Commit: `git add .stackpilot/ARCHITECTURE.md && git commit -m "docs(arch): initial project assessment"`

Continue routing to next state.

### Architecture Exists (subsequent runs)

**Before doing anything else**, read `.stackpilot/ARCHITECTURE.md` in full. Authoritative context. Do not re-explore for information already captured.

### Tidy (workspace has debris)

If Step 0+1 found `.claude/plans/`, `.superpowers/`, or uncommitted changes, deep scan:

```bash
git worktree prune --dry-run 2>/dev/null
git remote prune origin --dry-run 2>/dev/null
git branch --merged main 2>/dev/null | grep -vE '^\*|main|master|develop'
git stash list 2>/dev/null
```

Report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Tidy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Will clean:
    · 4 Claude plan files (.claude/plans/)
    · .superpowers/ (3 files)
    · 1 orphaned worktree
    · 2 merged branches: feature/old, fix/typo
  Needs attention:
    · 3 uncommitted changes
    · 2 stashed entries
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Will clean** (safe; ask once to confirm): `git worktree prune`, `git remote prune origin`, delete merged local branches (exclude main/master/develop), delete `.claude/plans/*.md` (non-git-tracked only — check with `git ls-files --error-unmatch`), delete `.superpowers/`.

**Needs attention** (report only): uncommitted changes, stale stashes.

After cleanup commit if stackpilot files changed:
```bash
git add .stackpilot/ 2>/dev/null
git diff --cached --quiet || git commit -m "chore(stackpilot): tidy"
```

Then continue routing.

### Sprint Interrupted (plans exist, no active TaskList from this session)

**1. Find plan:** `ls -t .stackpilot/plans/*.md | head -1` — read, parse `### TASK-` sections.

**2. Determine done:** prefer reading `.stackpilot/runs/<sprint>/TASK-*/state.json` (`phase == complete && last_result == complete` → done). Fall back to `git log --oneline -50` heuristic (commit messages contain TASK ID or title keywords) only if state.json missing.

**3. Show status + offer choices:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Sprint Resume — <plan name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  add user model         done (commit abc1234)
✅ TASK-002  add auth middleware     done (commit def5678)
⏳ TASK-003  payment integration     pending
⏳ TASK-004  write unit tests        pending
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Completed: 2/4  |  Remaining: 2

A. Resume from TASK-003
B. Show plan details first
C. Start fresh (re-run all tasks)
D. Discard sprint and start new
```

- **A** → TaskCreate pending tasks only, Run Sprint from first pending
- **B** → display plan, ask again
- **C** → TaskCreate ALL, Run Sprint from beginning
- **D** → clear plans/specs, Sprint Clean

### Sprint In-Progress

If user signals merge/finish ("可以合并了", "merge it", "ship it") → skip to **Node 5 — Finish**.

```
A. Continue current sprint (Run Sprint)
B. Add a new feature to the current sprint
```

### Sprint Clean (no plans/specs)

Ask what to build. After response, route:

> How should I run this?
> A. Walk through (I'll check in at each node)
> B. Full auto (no checkpoints, result stays on feature branch)

If **B (auto mode)**: skip every `(user gate)` prompt. At Node 5, auto-select "Leave as-is". Pick the conservative non-destructive default at any decision point.

Then choose path by scope:
- **Light** (single clear requirement, ≤ 2 sentences): skip Node 2 + Node 3; do Node 1 (mini) → write plan → Node 4 → Node 5
- **Standard** (multi-module, ambiguous, architectural decisions): full Node 1 → 2 → 3 → 4 → 5

---

## Node 1 — Exploration

**Goal:** understand the request thoroughly enough to write a non-vague spec.

**Scout first — before any clarifying question:** grep request's key terms across the codebase, read `CLAUDE.md` + 2-5 most relevant files + recent commits. No question to the user until this completes (otherwise you ask about things discoverable by grep).

If the request spans multiple subsystems, flag and decompose first.

**Then ask clarifying questions one at a time** — multiple-choice preferred, focus on purpose/constraints/success criteria.

**Exploration rigor rules:**

- **Take a position.** Do NOT hedge with "That could work." If the user's direction has a gap, say so and state what you'd do instead.
- **Push for specificity.** Vague requirements ("make it better") → "Who benefits, and what do they do differently after this exists?"
- **Challenge status-quo assumptions.** If user describes a solution, ask once: "What problem does this solve that can't be solved by [simpler alternative]?"
- **Two-push rule.** Push once if first answer is still vague. After two pushes, accept and move on.
- **Canonical Refs.** Any doc path the user cites → Read immediately; record under `## Canonical Refs` in the spec.
- **Scope Lock (多文件改动前必须做).** 当请求触及共享 identifier / shared field / 同一概念的多个组件时，先全仓 grep，列出 will-touch / will-NOT-touch 文件清单（按推断 sister-file 关系），等用户确认后再进入 Node 2 / Node 4。歧义组件名（"ConfigPanel" 这种可能多处存在）必须先问再改。

**Light tasks (mini-mode, ≤2 minutes, mandatory):**

<HARD-GATE>
Do NOT start implementation until a plan is written and committed.
Even "simple" tasks need a 30-second design check — silent assumptions cause the most wasted work later.
</HARD-GATE>

1. Scout once (1 grep + 1-2 files)
2. At most one clarifying question (only if genuine ambiguity)
3. State ONE chosen approach in 1-2 sentences + explicitly what you'll NOT do (YAGNI)
4. User confirms with "go" or rejection *(user gate)*
5. Skip ahead to "write plan" inside Node 4

Skip mini-mode only when user explicitly said "just do it" / "skip planning" / chose auto mode.

**Artifact:** none from this node (text-only dialog). Notes feed the next node.

## Node 2 — Design

**Goal:** present 2-3 architectural approaches, get user to pick one.

**Produce two things in lockstep:**

1. Text proposal in terminal (always — fallback when HTML/server unavailable).
2. `design-options.html` view artifact (template at `references/views/design-options.html`).

**Steps:**

1. Propose 2-3 approaches with trade-offs and your recommendation.
2. Start sprint server if not yet running:
   ```bash
   SLUG="$(date +%Y-%m-%d)-<feature-slug>"
   bash ~/Documents/github/stackpilot/scripts/preview/start-server.sh \
     --project-dir "$PWD" --sprint-slug "$SLUG" --background 2>&1 | head -1
   ```
   Parse the returned JSON for `port` and `url`.
3. Fill template tokens — `{{SPRINT_SLUG}}`, `{{SPRINT_DESCRIPTION}}`, `{{QUESTION}}`, `{{OPTIONS_JSON}}` — write to `.stackpilot/views/<slug>/design-options.html`. The template will fetch it and render via mermaid (CDN) on load. Each option provides `diagram_mermaid` (preferred) or `diagram_svg` for the architecture sketch.
4. Print to terminal: the 3 approaches in compressed form + the URL `http://localhost:<port>/sprints/<slug>/design-options.html`.
5. **Wait for either** the user's terminal response OR `.stackpilot/views/<slug>/design-options-action.json` (poll every 2-5s; the server writes this when a Pick button is clicked). First to arrive wins. *(user gate)*
6. Record the choice. Proceed to Node 3.

**Fallback:** if server failed to start or template not found, print 3 approaches in terminal only and wait for text response.

**Skip Node 2 entirely** for Light tasks (jump from Node 1 directly to Node 4 plan writing).

## Node 3 — Spec & Criteria

**Goal:** produce a verifiable spec and 3-7 mechanically checkable acceptance criteria, get user approval before writing the plan.

### 3.1 Write spec → `.stackpilot/specs/YYYY-MM-DD-<topic>-design.md`

**默认最小有效版本**：spec 先出最小可执行版本（目标 / 范围 / 验收 / Canonical Refs）。Comparison framework / decision matrix / "send to X" framing / 多 audience 切片这类扩展只在用户明确要求时加。≥300 字下限不是要求"凑长度"，是要求"覆盖必要语义"。

### 3.2 Auto-verify (≤ 1 self-fix round)

```bash
grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/specs/*.md | wc -l   # 0
grep -c "^## " .stackpilot/specs/*-design.md                                # ≥ 4
wc -w .stackpilot/specs/*-design.md | tail -1                               # ≥ 300
```

Fail after 1 self-fix → escalate specific failures.

### 3.3 12-QA matrix (inline scan)

Read [references/12-qa-matrix.md](references/12-qa-matrix.md) §Spec. Mark each dimension ✅ / ⚠️ / ❌ / N/A:

- Any ❌ on dimensions 1-4 → **must fix spec** before proceeding
- Any ❌ on dimensions 5-12 → fix if applicable, mark N/A with reason if not
- ⚠️ → add a one-line clarifying note to the spec

Output the 12-QA table. Re-run 3.2 after any spec changes.

### 3.4 Derive acceptance criteria → `.stackpilot/specs/YYYY-MM-DD-<topic>-criteria.md`

```markdown
# Acceptance Criteria — <feature>
> Generated by Node 3.4 from spec. sp-qa updates Status during Node 4.

| ID | Description | Verify Command | Status | Notes |
|----|-------------|----------------|--------|-------|
| C1 | <mechanically verifiable check> | `<shell-runnable command>` | untested | |
```

**Rule:** every criterion is mechanically verifiable — `grep`, `test`, `curl`, `tsc`, benchmark whose output is parseable. No "looks correct" / "feels fast". If you can't write a command for it, it doesn't belong in criteria.

Examples:

| Feature type | Criteria |
|--------------|----------|
| API endpoint | `curl -w '%{http_code}' /api/X` returns `200`; `pytest tests/test_X.py` exits 0; p95 ≤ N ms |
| Bug fix | failing-test-from-repro now passes; `npm test` no regression; specific log line absent |
| Refactor | `npm test` still passes; LOC of module decreases ≥ X%; no new `any` types |
| Docs | `markdown-link-check` passes; section word count ≥ N; required headings present |

In auto mode, still write criteria — sp-qa needs them.

### 3.5 User reviews spec — HTML view

Generate `spec-review.html` from `references/views/spec-review.html`. Fill tokens: `{{SPRINT_SLUG}}`, `{{SPEC_MARKDOWN}}` (raw spec text), `{{CRITERIA_JSON}}` (criteria as JSON array), `{{QA_JSON}}` (12-QA result as `[{dim, name, status, note}, ...]`). Write to `.stackpilot/views/<slug>/spec-review.html`.

Print URL `http://localhost:<port>/sprints/<slug>/spec-review.html` to terminal. Also print:

> "Spec written and committed to `.stackpilot/specs/<file>`. Open the URL or reply in terminal with 'approve' / 'changes: <text>' / 'reverify'."

Wait for either `spec-review-action.json` (`{approved, criteria_edits, change_request, reverify}`) or terminal reply. *(user gate)*

- If `approved: true` → apply `criteria_edits` back to `criteria.md` (write each row's edited description), commit, proceed to Node 4.
- If `change_request` → edit spec, re-run 3.2 + 3.3, regenerate `spec-review.html`, wait again.
- If `reverify: true` → re-run 3.2 + 3.3 only.

Skip 3.5 only in auto mode.

Commit spec + criteria:
```bash
git add .stackpilot/specs/<date>-<feature>-design.md .stackpilot/specs/<date>-<feature>-criteria.md
git commit -m "docs(spec): <feature> — design + criteria"
```

## Node 4 — Plan & Run Sprint

**Goal:** convert spec into discrete dispatchable tasks, execute them, surface real-time progress.

### 4.1 Write plan → `.stackpilot/plans/YYYY-MM-DD-<feature>-plan.md`

Bite-sized tasks (2-5 min each). Every task: `title`, `description`, `type`, `complexity` (light/standard), `depends_on`, `relevant_files`. No placeholders.

**Sister-file 字段（可选）：** 任务触及 shared identifier / shared component / shared field 时，task 必须填这两个字段之一或全部。

- `sister_files`: 必须同步改动的姊妹文件路径列表（如 `[OnboardingView-A.tsx, OnboardingView-B.tsx]`）。
- `shared_field_grep`: rename / shared field 改动时的 grep 模式列表（如 `["yumi_id", "ageRange"]`），sp-dev 启动前跑这些 grep 验证范围，sp-qa Stage 4 做 sync audit。

### 4.2 Plan auto-verify (≤ 1 self-fix round)

```bash
grep -inE "TBD|TODO|FIXME|\bplaceholder\b" .stackpilot/plans/*.md | wc -l   # 0
grep -c "^### TASK-" .stackpilot/plans/*.md                                 # ≥ 3
grep -cE "relevant_files:|depends_on:|complexity:" .stackpilot/plans/*.md   # task_count * 3
# rename / shared_field / migrate 类型的 task 必须填 shared_field_grep
grep -B2 -A6 "type:.*\(rename\|shared_field\|migrate\)" .stackpilot/plans/*.md | grep -c "shared_field_grep:"
```

Also manually scan for type consistency across tasks. Fail after 1 self-fix → escalate.

### 4.3 Plan traceability (two-check trace, NOT a 12-QA re-run)

Per [references/12-qa-matrix.md](references/12-qa-matrix.md) §Plan:

- **Forward:** every spec ✅/⚠️ dimension → at least one plan task. Missing → add task.
- **Reverse:** every plan task → traces to a spec requirement. Orphan → scope creep, remove.

Output a two-column table (spec item → task ID). Re-run 4.2 after any plan edits.

### 4.4 Branch + commit

Create feature branch, commit spec + plan.

### 4.5 Run Sprint (full protocol in [references/run-sprint.md](references/run-sprint.md))

```
Pre-Sprint:
  1. Parse plan + read config (qa.max_parallel default 3, qa.test_command, qa.deep_review)
  2. Dependency wave analysis — topological sort over depends_on, cap per wave by max_parallel
  3. Init .stackpilot/runs/<sprint-slug>/TASK-NNN/state.json
  4. Start sprint server (if not already running) with --sprint-slug; copy
     references/views/dashboard.html → .stackpilot/views/<slug>/dashboard.html
  5. Print dashboard URL once

Sprint Execution Loop (per wave):
  Dispatch ALL wave-tasks in PARALLEL via TaskCreate + simultaneous Agent calls.
  Pipeline per task: Track → Arch Review (HIGH only) → sp-dev (worktree) → Simplify (skip light)
    → sp-qa (skip light; updates acceptance-criteria.md) → Deep Review (HIGH) → Complete
  Wait for ALL wave-tasks before next wave. Pause on CRITICAL or 3x SOFT-BLOCKED.

Pre-coding confirmation:
  > "Plan ready. <N> tasks across <W> waves (max_parallel=<P>). Proceed?"
  A. Yes   B. I'll handle it elsewhere
```

Dashboard auto-refreshes via WS as `state.json` files change — user can leave it open the whole sprint. Terminal still prints per-task `✅ TASK-NNN  passed (k/N)` lines.

When all tasks complete (or sprint paused for user attention) → proceed to Node 5.

## Node 5 — Finish

**Goal:** verify acceptance criteria, surface sprint outcome to the user, execute their merge/PR/keep/discard choice. **YOU MUST complete this flow before ending the conversation.**

Full protocol in [references/sprint-finish.md](references/sprint-finish.md). High level:

1. **Pre-merge gate** — 显式三件套：`tsc --noEmit`（若存在）、`npm run lint` / `pnpm lint`（若存在）、`qa.test_command`（无显式时按 `npm test` / `pytest` 等存在性兜底；都不存在记录 `N/A`）。任一红 → 问用户是否继续。**残留脚本扫描**：`git diff --name-only $(git merge-base main HEAD)..HEAD | grep -E '^scripts/(migrate|audit|debug|oneshot)-.+\.(ts|js|sh|py)$'` — 命中即报告"以下一次性脚本是否合并前删除？"（按全局 CLAUDE.md `## 多文件同步律` 一次性脚本即用即删原则；auto mode 下保留并记录到 finish-report）。
2. **Closure gate** — acceptance criteria all green (`pass` or `n-a-this-task`), CHANGELOG updated, pattern candidates surfaced. Block merge on red.
3. **Generate `finish-report.html`** from `references/views/finish-report.html`. Fill: elapsed_ms, tasks (with per-phase timings from state.json), commits (`git log <base>..HEAD --stat`), criteria, patterns, decisions, branch. Push URL to terminal.
4. **Wait** for `finish-action.json` or terminal A/B/C/D. *(user gate)* Terminal fallback if no action.json in 30s.
5. **Execute choice:**
   - **merge** → squash merge into base branch, delete feature branch
   - **pr** → push + `gh pr create`
   - **keep** → no-op
   - **discard** → confirm once, then delete feature branch
6. **Stop sprint server:** `bash ~/Documents/github/stackpilot/scripts/preview/stop-server.sh --slug <sprint-slug>`

> **Note:** a `pre-merge-commit` git hook enforces squash-only merges on main/master.

---

## Config flags (`stackpilot.config.yml` qa.*)

| Flag | Default | Effect when set |
|------|---------|-----------------|
| `qa.max_parallel` | `3` | Cap on simultaneous sub-agent dispatches per wave. `1` = fully serial. |
| `qa.test_command` | auto-detect | Test runner for Node 5 pre-merge gate. May be `N/A` for meta-projects. |
| `qa.deep_review` | `true` | HIGH-risk Deep Review at the end of each task. |
| `qa.coverage_threshold` | `80` | sp-qa coverage gate. |

Absent keys default as shown. See `references/run-sprint.md` for read protocol.

## On-demand views

- **Architecture diagram** (`references/views/architecture.html`): user explicitly asks ("show me the module graph"). Main agent grep's import/require relationships from `Key Directories` listed in `ARCHITECTURE.md`, generates `flowchart TD` mermaid source, fills `{{MERMAID_SOURCE}}` + `{{FILE_MAP_JSON}}`, writes to `.stackpilot/views/architecture.html`. Skip if `ARCHITECTURE.md` lists fewer than 3 directories (too small to visualize).

## Failure modes & fallbacks

- **CDN blocked**: every HTML node degrades — print terminal-equivalent prompt alongside HTML URL so user always has a path forward.
- **Server failed to start**: terminal-only mode for whole sprint. Notify once.
- **Action JSON write race**: server uses .tmp + rename. Main agent reads with up to 3 retries × 100ms backoff before falling back to terminal.
- **Browser closed mid-sprint**: server keeps running and writing files. User can reopen any time; dashboard reconnects via WS.
- **Multiple browser tabs**: last-write-wins on action JSON. Server logs the override.

## Sub-agent contracts (unchanged from v1.x)

`sp-architect`, `sp-dev`, `sp-qa`, `sp-docs` only consume and produce markdown — they do not see HTML. Their schemas (`## Risk`, `## Architecture Decision`, `## QA Summary`, etc.) are unchanged. See agent files in `claude-config/agents/`.
