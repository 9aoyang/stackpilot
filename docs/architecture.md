# Stackpilot Architecture

> Last updated: 2026-05-20

Stackpilot is a methodology-driven sprint orchestration layer for Claude Code.
It turns a specification into working code by driving the host agent's native
planning and delegation primitives, with no custom service infrastructure.

---

## Mental Model

```
User describes feature → design discussion → spec + plan → agents build it → review + ship
```

The user's interface is the `/stackpilot` skill. The skill orchestrates everything using Claude Code's native tools.

---

## Directory Layout

```
stackpilot/                        ← framework installation
├── claude-config/
│   ├── agents/                    ← agent methodology prompts (sp-*.md)
│   │   ├── sp-architect.md        ← read-only architecture review
│   │   ├── sp-dev.md              ← TDD implementation
│   │   ├── sp-qa.md               ← code review + testing
│   │   └── sp-docs.md             ← documentation updates
│   └── skills/
│       ├── stackpilot/
│       │   ├── SKILL.md           ← /stackpilot main entry point
│       │   └── references/
│       │       ├── run-sprint.md
│       │       ├── sprint-finish.md
│       │       ├── 12-qa-matrix.md
│       │       └── views/         ← v2.0 HTML view templates (5 decision-point nodes)
│       │           ├── design-options.html
│       │           ├── dashboard.html
│       │           ├── spec-review.html
│       │           ├── finish-report.html
│       │           └── architecture.html
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot-compete competitive gap analysis
│       ├── stackpilot-research/
│       │   └── SKILL.md           ← /stackpilot-research deep research (横纵分析法)
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync external skill tracking
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging (portable)
├── scripts/
│   ├── init.sh                    ← project setup (minimal: dirs + test command detection)
│   ├── lib/
│   │   └── config.sh              ← YAML config reader
│   ├── sync-skills.sh             ← idempotent Claude skill sync for non-skillshare installs
│   ├── hooks/
│   │   ├── post-commit            ← auto-sync new skills after commit
│   │   ├── pre-merge-commit       ← blocks non-squash merges on main/master
│   │   └── README.md
│   └── preview/
│       ├── start-server.sh        ← sprint/visual server (v2: HTML view host + WS state stream)
│       ├── stop-server.sh
│       ├── server.cjs             ← extended with /sprints/<slug>, /api/action, /api/state
│       └── helper.js              ← WS client + window.sp.{action,state} sprint API
└── templates/
    ├── stackpilot.config.yml      ← config template (qa section only)
    └── stackpilot-inner-gitignore

<project-root>/                    ← user's project
├── stackpilot.config.yml          ← qa settings (test_command, coverage_threshold)
└── .stackpilot/
    ├── ARCHITECTURE.md            ← project memory (data layer)
    ├── specs/                     ← design documents + criteria (data layer)
    ├── plans/                     ← implementation plans (data layer)
    ├── runs/<sprint>/TASK-*/state.json   ← per-task phase state (data layer)
    └── views/                     ← v2.0 generated HTML artifacts (view layer, gitignored)
        └── <sprint>/{design-options,dashboard,spec-review,finish-report}.html
```

---

## Agent Pipeline

### Standard Task (multi-module, architectural decisions)

```
sp-architect → sp-dev → /simplify → sp-qa
```

### Light Task (single-file, clear requirements)

```
sp-dev
```

sp-architect, /simplify, and sp-qa are skipped for light tasks (low ROI on small/mechanical diffs; sp-dev's TDD verify/fix loop covers correctness). sp-docs runs when plan includes docs tasks.

> **Note:** sp-qa dispatches immediately after /simplify on each task (inline review, not batch). /simplify runs scoped to the task's `relevant_files`, must preserve test pass status, and commits its diff separately so QA sees dev and simplify changes distinctly.

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-architect** | Reviews task against codebase; returns architecture decision | Non-negotiable boundaries at top of prompt (read-only, one decision not a list, justified risk). Extended thinking on every review (not HIGH-only). Multi-persona: full 3 on HIGH, single on LOW/MEDIUM. Reads `.stackpilot/ARCHITECTURE.md § Key Design Decisions`, cites prior decisions verbatim. Prescriptive Process 1-5 steps replaced by general "what to ground in" instructions per Anthropic's Claude 4.x guidance ("prefer general instructions over prescriptive steps"). Emits `## Decision Candidates` on HIGH; returns `[ESCALATION]` for new deps or structural conflicts |
| **sp-dev** | Implements the task | Six explicit "Don't add X" boundaries at the top (primacy position, mirroring Anthropic's "Avoid over-engineering" template): no error handling for impossible cases, no defensive validation on trusted inputs, no comments explaining well-named code, no single-use helpers, no unrelated refactors, no unrequested tests. Reads `git log` to avoid repeating failed approaches. TDD (RED-GREEN-REFACTOR). Verify/fix loop with stuck detection; reverts on failure; `[SOFT-BLOCKED]` after 2 failed rounds |
| **sp-qa** | Reviews code, writes tests | Opens with adversarial KPI ("your job is finding reasons this PR should not ship"). Every finding requires `file:line` + concrete failure scenario + ≥80% confidence. Mandatory "Adversarial Angles Tried" completion field so "no findings" is earned, not assumed. Prescriptive Stages 1-3 replaced by open adversarial angles; deterministic Consistency Audit (absolute-claim / scope-completeness / dead-reference, HIGH-risk mandatory) preserved verbatim — stackpilot's unique value. Reads `.stackpilot/ARCHITECTURE.md` for Review Patterns; emits `## Pattern Candidates`. **Dispatches on standard complexity** — light tasks rely on sp-dev's TDD. |
| **sp-docs** | Updates README, comments, API docs | **Uses haiku 4.5** (mechanical task); runs after QA passes; documentation only. |

---

## How Agents Are Dispatched

### Claude Code

The Claude `/stackpilot` skill orchestrates agents using Claude Code's native
tools:

```
Agent(
  description="Implement TASK-001",
  prompt="<sp-dev methodology> + <task context> + <arch review>",
  isolation="worktree"    ← Claude Code creates/manages the worktree
)
```

**Key benefits over v1 dispatch.sh:**
- Fork pattern cache sharing (~66% input token savings)
- Automatic worktree creation and cleanup
- Built-in timeout and abort handling
- Direct result return (no file I/O for inter-agent communication)
- Agent results flow as prompt context: architect output → dev prompt → QA prompt

**Task tracking** uses Claude Code's native `TaskCreate`/`TaskUpdate` instead of YAML files.

---

## Event Flow

### User-triggered (via `/stackpilot` skill)

```
/stackpilot [feature description]
  └─ Show sprint status + scan workspace
       └─ Route by state:
            not initialized    → run init.sh
            workspace dirty    → tidy (clean workflow artifacts, prune branches/worktrees)
            sprint interrupted → resume (match plan tasks to git log, offer continue/fresh)
            sprint clean       → ask what to build → choose auto or interactive → feature flow
            in-progress        → continue sprint
```

**Standard Feature — 5 nodes (v2.0 HTML-first):**

```
Node 1 — Exploration: scout code first (grep + read 2-5 files) → clarifying questions (one at a time) → canonical refs captured in spec
Node 2 — Design: 2-3 approaches in design-options.html (3-col grid, Pick A/B/C) + terminal fallback
Node 3 — Spec & Criteria: write spec → auto-verify (grep checks) → 12-QA matrix → derive acceptance criteria → spec-review.html (markdown + 12-QA grid + editable criteria + Approve button) or terminal review
Node 4 — Plan & Run Sprint: write plan → auto-verify → traceability trace → branch + commit → start sprint server → push dashboard.html (live DAG + Kanban + criteria) → dispatch tasks in parallel waves
Node 5 — Finish: pre-merge gate (typecheck/lint/tests) → closure gate (criteria all green / CHANGELOG / patterns surfaced) → finish-report.html (timeline + criteria pie + commits + A/B/C/D) or terminal A/B/C/D
  ↳ pre-merge-commit hook rejects non-squash merges on main as a hard guard
```

Inline verifications (grep, 12-QA matrix, traceability check) are sub-steps
inside their node, not separate phases. HTML view artifacts are generated at
Nodes 2, 3, 4, 5; data-layer source-of-truth files (spec, plan, criteria,
state.json) remain markdown/JSON for sub-agent consumption.

---

## Task Lifecycle

```
pending → in-progress → done
                     ↘ soft-blocked (retry ≤ 3) → done
                     ↘ blocked (3x failures → user decision)
```

- `soft-blocked`: agent returned `[SOFT-BLOCKED]`; main session retries up to 3 times
- `blocked`: 3 retries exhausted, escalated to user for decision
- Tracking via Claude Code's `TaskCreate`/`TaskUpdate` (session-scoped)
- Persistence via plan files (git-tracked, survives session restarts)

---

## Configuration

`stackpilot.config.yml` (project root, v2 — minimal):

```yaml
qa:
  coverage_threshold: 80
  test_command: npm test    # auto-detected by init.sh
```

Model routing is handled by Claude Code natively (agent frontmatter `model:` field).

---

## Skill Entry Points

| Slash Command | Purpose |
|--------------|---------|
| `/stackpilot` | Main entry: tidy + resume + status + auto/interactive mode + sprint execution. |
| `/stackpilot-compete` | Competitive gap analysis from power-user persona |
| `/stackpilot-research` | Deep research reports using cross-longitudinal analysis (横纵分析法) |
| `/stackpilot-sync` | External skill tracking and sync (developer maintenance) |
| `/tdd-development` | **Portable** — TDD + verify/fix + rationalization blockers |
| `/qa-12-dimensions` | **Portable** — 12-dimension test coverage + code review |
| `/architecture-review` | **Portable** — Codebase pattern analysis + blueprint |
| `/systematic-debugging` | **Portable** — 4-phase root cause investigation + red flags |

---

## Agent Skills Compliance

Stackpilot follows the [Agent Skills open standard](https://agentskills.io) maintained by Anthropic.

**Portable methodology skills** — work in any Agent Skills-compatible product (Cursor, VS Code Copilot, Gemini CLI, OpenAI Codex, JetBrains Junie, and 25+ more):

| Skill | What it does | Portable? |
|-------|-------------|-----------|
| `tdd-development` | TDD cycle + verify/fix loop + rationalization blockers | Yes |
| `qa-12-dimensions` | Two-stage code review + 12-dimension test coverage | Yes |
| `architecture-review` | Pattern analysis + decisive architecture choice + blueprint | Yes |
| `systematic-debugging` | 4-phase root cause investigation + red flag detection | Yes |

**Orchestration skills** — Claude Code-specific (use native Agent tool, TaskCreate):

| Skill | What it does |
|-------|-------------|
| `stackpilot` | Full sprint lifecycle: tidy → resume → design → spec → plan → code → QA → ship. Includes auto mode (skip confirmations) and workspace cleanup. |

**Progressive disclosure** — SKILL.md stays under 500 lines. Heavy content (visual companion, optimize sprint, sprint finish) lives in `references/` and loads on demand.

---

## Key Design Decisions

**Claude Code-native orchestration (v2).** Agents are dispatched via Claude Code's Agent tool with `isolation: "worktree"`. No custom bash dispatcher, no git worktree management, no file locking. Claude Code handles all infrastructure.

**Prompt-based inter-agent communication.** Agent outputs flow directly as prompt context to downstream agents. No intermediate files (arch-review/, done/). The main session is the coordinator.

**Plan as persistence layer.** Tasks are tracked in-session via TaskCreate. Plan files are the persistent source of truth. The resume flow reconstructs state from plan + git log.

**Zero external dependencies.** All agent protocols are inlined. The skill works without any external plugin installed.

**Complexity routing at the task level.** Each task carries `complexity: light | standard`. Light tasks skip architect, cutting ~60% of agent overhead for simple changes.

**Soft-blocked retry.** Agents self-report failure via `[SOFT-BLOCKED]` output. The main session retries up to 3 times before requiring human input.

**Git as memory.** sp-dev reads `git log --oneline -20` before every task. Prior failed approaches are visible in commit history.

**Agents dispatch via explicit subagent_type.** SKILL.md's `Agent()` calls pass `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"` / `"sp-docs"` so Claude Code routes to the registered agent (with its frontmatter-declared model and tool restrictions) rather than falling back to `general-purpose`. Required path: agents must be registered at `~/.claude/agents/` or within an installed plugin. Claude Code caches the registry at session start — after install, restart Claude Code to activate. sp-docs is routed by task.type: `type: docs` tasks go to sp-docs (haiku), all others to sp-dev (sonnet).

**Don't re-teach Claude what it knows.** Agent methodology files specify the stackpilot orchestration contract — input format, completion output format, escalation signals, cross-sprint memory hooks. They do NOT include generic engineering advice (how to TDD, how to review, how to debug) because Claude 4.7 does those natively. This principle drove a ~47% trim of sp-dev and sp-qa methodologies on 2026-04-17.

**Agent-prompt engineering principles (adopted 2026-04-20).** After a cross-sourced review of Anthropic docs (Claude 4.x prompting guide, effective context engineering, Claude Code best practices), academic literature (Lost in the Middle, Curse of Instructions, Sprague 2024 "To CoT or not to CoT"), and the 2026-04-20 survey in `research/260420-1130-prompt-length-claims/`, sp-* agent prompts follow these rules:

1. **Non-negotiable boundaries at the TOP of every prompt.** First-position tokens have the highest attention weight (primacy + attention-sink), so hard red lines go there — not buried in the middle. U-shape design: repeat critical reminders at the bottom.
2. **≤5 hard rules per agent.** Research on instruction count (Curse of Instructions, IFScale) shows following-rate decays toward ~80% once you exceed ~5 instructions. Anything beyond that belongs as guidance, not as an invariant.
3. **Prefer general instructions over prescriptive steps** (official Anthropic Claude 4.x guidance). Explicit "step 1, step 2, step 3" lists now often *reduce* quality on strong models with adaptive thinking; they're kept only where the structure is part of the output contract (e.g., sp-dev's Completion Output schema).
4. **Explicit negative boundaries for over-engineering.** sp-dev carries six `Don't add X` lines matching Anthropic's own "Avoid over-engineering" template. Anthropic has publicly acknowledged Claude Opus 4.5/4.6 over-engineer by default (FeatBench 2025: 73.6% of coding-agent failures are scope creep). A concrete negative boundary is the single biggest quality lever for a code agent.
5. **No positive-example filler.** "You are a senior engineer who takes pride in…" filler drops the signal-to-token ratio without measurable benefit on Claude 4.x.

**Self-verification at Sprint Finish.** When Step 2 starts the dev server, the main agent auto-curls the preview URL and reports HTTP status before handing control to the user. Non-2xx/3xx or connection failure is surfaced with the last 20 lines of server log — catches the "server binds but app 500s" class of regression without any per-task overhead.

**Single-file project memory.** `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface. Fixed sections: What This Project Is / Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns. Only the main agent writes it, and only at Sprint Finish (Step 4a). Sub-agents are read-only: `sp-architect` reads `§ Key Design Decisions` and surfaces new HIGH-risk decisions via a `## Decision Candidates` block in its report; `sp-qa` reads `§ Review Patterns` & `§ Conventions & Gotchas` and surfaces new patterns via a `## Pattern Candidates` block. The main agent merges both at Sprint Finish. This keeps writes serial on the feature branch and avoids worktree-level write contention.

**TDD enforcement.** sp-dev enforces RED-GREEN-REFACTOR. Tests written before implementation.

**Root cause investigation.** 4-phase investigation (observe → reproduce → trace → hypothesize) before any fix.

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-05-25 | **v2.1.0**: Skill Tighten — sister-file sync via sub-agent contract. Node 1 加 Scope Lock（多文件 refactor 前列 will-touch / will-NOT-touch）；Node 3 § 3.1 默认最小有效版本引导；Node 4 plan task schema 加可选 `sister_files` / `shared_field_grep`，§ 4.2 加对应 grep verify；Node 5 pre-merge 显式三件套（typecheck/lint/test）+ 残留脚本扫描（`scripts/(migrate\|audit\|debug\|oneshot)-*` 命中提示是否合并前删除）。Sub-agent 接力：sp-architect Implementation Blueprint 加 `Will NOT touch`；sp-dev Required behaviors 加 Sister-file ack + Completion Output 加 `## Sister-File Sync` 段；sp-qa Consistency Audit 加第 4 条 sister-file sync audit + Adversarial Angles 加 `sister-file sync`。Why: insights 报告（2026-05-25 / 283 sessions / 4520 messages）跨项目 5 大稳定 friction 中 wrong_approach（34 次）和 sister-file 漏改占主要比重，需要从 SKILL.md 一次性检查升级为 plan→dev→qa 接力 enforce。 |
| 2026-05-22 | **qa-12-dimensions hardening (skill v1.0.1 → v1.1.0; shipped as part of v2.0.0).** After 43 days untouched the portable skill had drifted behind both upstream (Anthropic feature-dev v2 code-reviewer) and the stackpilot internal sp-qa. Three targeted backports: (1) 5-tier confidence rubric (0/25/50/75/100) replaces the single ">=80%" line, matching feature-dev v2; (2) Stage 1 renamed "Spec & Project Guidelines Compliance" and reads `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` / `.cursorrules` as a first-class review angle; (3) "Adversarial Angles Tried" required field sourced from sp-qa — "no findings" only credible when angle list is non-trivial. Sub-agent-only sp-qa features (output schema, Consistency Audit grep triplet, WTF ratio, hard caps) deliberately NOT backported. |
| 2026-05-20 | **Removed `/stackpilot-bench` skill and `codex-config/` Codex support.** Bench harness (3 workloads, history.csv, scoring/verdict scripts, run-codex-bench.sh, references/headless-mode.md) deleted; `codex-config/agents/` Codex-native sp-* prompts deleted; `claude-config/skills/stackpilot/references/codex-dispatch.md` deleted; `docs/bench-implementation.md` deleted; `qa.disable_criteria_gate` and `qa.disable_state_json` config flags (which only existed for the `stackpilot-serial` bench leg) removed from SKILL.md + run-sprint.md. Reason: bench v2 schema/runner/workload were inconsistent and unrunnable, and Codex orchestration was no longer maintained. |
| 2026-05-18 | **v1.11.0**: Run Sprint executes tasks in parallel waves (qa.max_parallel default 3) via dependency topological sort over `depends_on`; per-task `state.json` under `.stackpilot/runs/<sprint>/TASK-NNN/` replaces in-memory-only TaskCreate state and enables Sprint Interrupted recovery without git-log heuristic; Phase 3.6 derives mechanically verifiable `acceptance-criteria.md`, sp-qa updates Status during Run Sprint, sprint-finish Step 0.5 enforces 3 gates (criteria all green / CHANGELOG covers sprint scopes / Pattern Candidates surfaced) blocking merge; Light Feature path adds mandatory mini-brainstorm + Standard adds Phase 3.7 User Reviews Spec Gate (superpowers:brainstorming 5.1.0 re-sync, docs/sync.md updated); SKILL.md Run Sprint section downsized ~100→28 lines (detail in `references/run-sprint.md`). |
| 2026-05-07 | **Step 4.5 simplify between dev and QA.** Standard tasks now invoke the `simplify` skill on the task diff after sp-dev finishes and before sp-qa starts. Scoped to the task's `relevant_files`, must preserve test pass status, commits separately so QA sees both diffs. Catches over-engineering (premature abstractions, dead error handling, single-use helpers) while sp-dev's tests are still green — cheaper than sp-qa fix loops on style issues. Skipped for light tasks and `type: docs` (low ROI on small/mechanical diffs). |
| 2026-04-17 | **v1.10.0**: Opus 4.7 pipeline adaptations: per-phase effort advisory in `stackpilot.config.yml` (architect/dev/qa/docs); effort posture lines in all 4 agents; cross-sprint memory via `.stackpilot/sprint-metrics.md` (appended by sprint-finish) and `.stackpilot/decisions.md` (appended by sp-architect on HIGH-risk); Sprint Clean surfaces 3-sprint trend advisory; auto-verify loops reduced 3→2 rounds; SKILL.md 12-QA tables extracted to `references/12-qa-matrix.md`. |
| 2026-04-16 | **v1.9.1**: Removed codex-plugin-cc cross-model review integration from sp-qa. Replaced with optional Claude Code `/ultrareview` for HIGH-risk tasks (requires Opus 4.7+). Cleaner single-source toolchain aligned with Claude Code native stance. |
| 2026-04-16 | **v1.9.0**: Hardened sprint pipeline with gstack-inspired improvements: sp-qa WTF self-monitoring heuristic (revert/fix ratio, hard cap 15 fixes), anti-sycophancy and forcing questions in Phase 1 Exploration, Step 0 pre-merge verification gate in sprint-finish (typecheck + lint + tests), 3-strike escalation rule in systematic-debugging, `--quick` flag for sync-skills. |
| 2026-04-13 | **v1.8.0**: Skill auto-sync (`sync-skills.sh --auto-update`), post-commit hook for new skill detection, version self-check in `/stackpilot` Step 0, fixed `install.sh` `cp -r` for `references/` subdirs. |
| 2026-04-13 | **v1.7.0**: Added `/stackpilot-research` skill — cross-longitudinal analysis (横纵分析法) for deep research reports. 3-wave research strategy, narrative output, quality self-check. Explicit invocation only. |
| 2026-04-12 | **v1.6.1**: Sharpened agent prompts (sp-dev, sp-architect, sp-qa, sp-docs) and SKILL.md planning gates with Karpathy coding principles: positive traceability over negative constraints, assumption surfacing, simplicity self-checks, anti-scope-creep in plans. |
| 2026-04-11 | **v1.6.0**: Added `pre-merge-commit` git hook to enforce squash-only merges on main/master. Installed by `init.sh`. Bypass via `STACKPILOT_ALLOW_MERGE=1`. |
| 2026-04-11 | **v1.5.3**: Fixed 12-QA phases being skipped — replaced ambiguous `auto-proceed` with explicit phase references so LLMs don't jump over Phase 3.5/4.5. |
| 2026-04-11 | **v1.5.2**: Fixed `/release` skill to include architecture docs in release commit, satisfying pre-commit hook. |
| 2026-04-11 | **v1.5.1**: Removed unused `NEEDS_REVIEW.md` mechanism. Fixed zsh `no matches found` errors by replacing glob patterns with `find`. |
| 2026-04-11 | **v1.5.0**: Added 12-QA review gates after spec (Phase 3.5) and plan (Phase 4.5) — 12-dimension scenario coverage review with hard gates on dimensions 1-4. |
| 2026-04-11 | **v1.4.0**: Project-local `/release` skill — auto-generates CHANGELOG from git log (conventional commits), detects bump type (major/minor/patch), bumps all three version files atomically, validates with pre-commit, tags, and pushes. Added `.stackpilot/ARCHITECTURE.md` quick-reference. |
| 2026-04-11 | **v1.3.0**: Sprint Finish squash merge — feature branch commits folded into one commit on main. Pre-merge housekeeping (arch update, artifact cleanup) committed on feature branch before squash. Feature branch auto-deleted after merge. |
| 2026-04-10 | **v2.1 consolidation**: Merged stackpilot-auto, stackpilot-resume, stackpilot-tidy into main `/stackpilot` as state-routed flows (6→3 orchestration commands). Removed archive mechanism — plans/specs deleted directly (git history is sufficient). Added workspace tidy flow (clean .claude/plans/, .superpowers/, orphaned worktrees, merged branches). Added auto/interactive mode choice after user describes feature. |
| 2026-04-08 | **v2 architecture**: Replaced dispatch.sh with Claude Code native Agent tool; replaced backlog.yml with TaskCreate; removed sp-pm and sp-coordinator (inlined in skill); removed git hooks; simplified config to qa-only; added /stackpilot-resume; agents become pure methodology prompts with no file I/O. Adopted Agent Skills open standard: extracted 3 portable methodology skills (tdd-development, qa-12-dimensions, architecture-review) usable in any Agent Skills-compatible product; restructured SKILL.md with progressive disclosure (references/); all name fields comply with spec |
| 2026-04-07 | Tightened interaction flow; Visual Companion inline; auto-detect project stack; TDD + root cause investigation; per-task inline review; per-provider model routing; git worktree isolation; pre-commit validation; file locking; timeout enforcement; autonomous coding with progress reporting |
| 2026-04-07 | One-at-a-time clarifying questions; Visual Companion browser server; compete skill 12-dimension + 5-persona debate |
| 2026-04-04 | Integrated autoresearch patterns; 12-dimension testing; multi-persona review; Optimize Sprint; docs/sync.md |
| 2026-04-04 | Renamed to sp-* prefix; .stackpilot/ runtime state; inlined all external skill protocols |
| 2026-04-01 | Complexity routing, verify/fix loop, soft-blocked retry |
| 2026-03-29 | Initial implementation |
