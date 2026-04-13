# Stackpilot Architecture

> Last updated: 2026-04-11

Stackpilot is a methodology-driven sprint orchestration layer for Claude Code. It turns a specification into working code by driving Claude Code's native Agent tool, TaskCreate, and worktree isolation — no custom infrastructure needed.

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
│       │   └── SKILL.md           ← /stackpilot main entry point
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
│   ├── hooks/
│   │   ├── pre-merge-commit       ← blocks non-squash merges on main/master
│   │   └── README.md
│   └── preview/
│       ├── start-server.sh        ← visual design companion server
│       └── stop-server.sh
└── templates/
    ├── stackpilot.config.yml      ← config template (qa section only)
    └── stackpilot-inner-gitignore

<project-root>/                    ← user's project
├── stackpilot.config.yml          ← qa settings (test_command, coverage_threshold)
└── .stackpilot/                   ← specs and plans are git-tracked
    ├── specs/                     ← design documents (current sprint)
    └── plans/                     ← implementation plans (current sprint)
```

---

## Agent Pipeline

### Standard Task (multi-module, architectural decisions)

```
sp-architect → sp-dev → sp-qa
```

### Light Task (single-file, clear requirements)

```
sp-dev → sp-qa
```

sp-architect is skipped for light tasks. sp-docs runs when plan includes docs tasks.

> **Note:** sp-qa dispatches immediately after each sp-dev task completes (inline review, not batch).

---

## Agent Responsibilities

| Agent | Role | Key Protocol |
|-------|------|-------------|
| **sp-architect** | Reviews task against codebase; returns architecture decision | Analyzes existing patterns first (file:line references); one decisive choice; full implementation blueprint; multi-persona adversarial review (Security/Performance/Reliability) for HIGH-risk tasks; returns `[ESCALATION]` for new deps or structural conflicts |
| **sp-dev** | Implements the task | Reads `git log` to avoid repeating failed approaches; traces entry point and call chain; enforces TDD (RED-GREEN-REFACTOR); 4-phase root cause investigation (observe/reproduce/trace/hypothesize); verify/fix loop (BUILD/LINT/TEST/SCOPE) with stuck detection; reverts on failure; returns `[SOFT-BLOCKED]` after 3 failed rounds |
| **sp-qa** | Reviews code, writes tests | Three-stage review (spec compliance + code quality + adversarial); 12-dimension scenario testing; cross-sprint review patterns (`.stackpilot/review-patterns.md`); optional cross-model review via codex-plugin-cc; confidence >= 80 reporting; returns `[CRITICAL]` for bugs/security, `[SOFT-BLOCKED]` after 3 rounds |
| **sp-docs** | Updates README, comments, API docs | Runs after QA passes; documentation only; verification before completion |

---

## How Agents Are Dispatched (v2 — Native Claude Code)

In v2, the `/stackpilot` skill orchestrates agents using Claude Code's native tools:

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

**Standard Feature — human intervention points:**

```
Phase 1: clarifying questions (one at a time, deep exploration)
Phase 1.5: visual companion (browser-based mockups, only when visual helps)
Phase 2: design proposal (sectioned, user approves each)
Phase 3: spec auto-verify loop (self-fix, escalates only on 3x failure)
Phase 3.5: spec 12-QA (12-dimension scenario coverage review of spec)
Phase 4: plan auto-verify loop (self-fix, escalates only on 3x failure)
Phase 4.5: plan 12-QA (12-dimension scenario coverage review of plan, cross-ref with spec)
Pre-coding: confirm to start
Coding: autonomous with per-task progress reporting
Sprint finish: squash merge (1 commit on main) / PR / leave / discard choice
  ↳ pre-merge-commit hook rejects non-squash merges on main as a hard guard
```

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
| `/stackpilot` | Main entry: tidy + resume + status + auto/interactive mode + sprint execution |
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

**TDD enforcement.** sp-dev enforces RED-GREEN-REFACTOR. Tests written before implementation.

**Root cause investigation.** 4-phase investigation (observe → reproduce → trace → hypothesize) before any fix.

---

## Evolution Notes

| Date | Change |
|------|--------|
| 2026-04-12 | **v1.6.1**: Sharpened agent prompts (sp-dev, sp-architect, sp-qa, sp-docs) and SKILL.md planning gates with Karpathy coding principles: positive traceability over negative constraints, assumption surfacing, simplicity self-checks, anti-scope-creep in plans. |
| 2026-04-11 | **v1.6.0**: Added `pre-merge-commit` git hook to enforce squash-only merges on main/master. Installed by `init.sh`. Bypass via `STACKPILOT_ALLOW_MERGE=1`. |
| 2026-04-11 | **v1.5.3**: Fixed 12-QA phases being skipped — replaced ambiguous `auto-proceed` with explicit phase references so LLMs don't jump over Phase 3.5/4.5. |
| 2026-04-11 | **v1.5.2**: Fixed `/release` skill to include architecture docs in release commit, satisfying pre-commit hook. |
| 2026-04-11 | **v1.5.1**: Removed unused `NEEDS_REVIEW.md` mechanism. Fixed zsh `no matches found` errors by replacing glob patterns with `find`. |
| 2026-04-11 | **v1.5.0**: Added 12-QA review gates after spec (Phase 3.5) and plan (Phase 4.5) — 12-dimension scenario coverage review with hard gates on dimensions 1-4. |
| 2026-04-11 | **v1.4.0**: Project-local `/release` skill — auto-generates CHANGELOG from git log (conventional commits), detects bump type (major/minor/patch), bumps all three version files atomically, validates with pre-commit, tags, and pushes. Added `.stackpilot/ARCHITECTURE.md` quick-reference. Tracked `codex-plugin-cc` in `docs/sync.md`. |
| 2026-04-11 | **v1.3.0**: Sprint Finish squash merge — feature branch commits folded into one commit on main. Pre-merge housekeeping (arch update, artifact cleanup) committed on feature branch before squash. Feature branch auto-deleted after merge. |
| 2026-04-10 | **v2.1 consolidation**: Merged stackpilot-auto, stackpilot-resume, stackpilot-tidy into main `/stackpilot` as state-routed flows (6→3 orchestration commands). Removed archive mechanism — plans/specs deleted directly (git history is sufficient). Added workspace tidy flow (clean .claude/plans/, .superpowers/, orphaned worktrees, merged branches). Added auto/interactive mode choice after user describes feature. |
| 2026-04-08 | **v2 architecture**: Replaced dispatch.sh with Claude Code native Agent tool; replaced backlog.yml with TaskCreate; removed sp-pm and sp-coordinator (inlined in skill); removed git hooks; simplified config to qa-only; added /stackpilot-resume; agents become pure methodology prompts with no file I/O. Adopted Agent Skills open standard: extracted 3 portable methodology skills (tdd-development, qa-12-dimensions, architecture-review) usable in any Agent Skills-compatible product; restructured SKILL.md with progressive disclosure (references/); all name fields comply with spec |
| 2026-04-07 | Tightened interaction flow; Visual Companion inline; auto-detect project stack; TDD + root cause investigation; per-task inline review; per-provider model routing; git worktree isolation; pre-commit validation; file locking; timeout enforcement; autonomous coding with progress reporting |
| 2026-04-07 | One-at-a-time clarifying questions; Visual Companion browser server; compete skill 12-dimension + 5-persona debate |
| 2026-04-04 | Integrated autoresearch patterns; 12-dimension testing; multi-persona review; Optimize Sprint; docs/sync.md |
| 2026-04-04 | Renamed to sp-* prefix; .stackpilot/ runtime state; inlined all external skill protocols |
| 2026-04-01 | Complexity routing, verify/fix loop, soft-blocked retry |
| 2026-03-29 | Initial implementation |
