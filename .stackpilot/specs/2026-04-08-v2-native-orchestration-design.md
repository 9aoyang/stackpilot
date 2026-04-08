# Stackpilot v2: Native Claude Code Orchestration Layer

## Problem Statement

Stackpilot v1 builds its own infrastructure layer (~700 lines of bash) that duplicates what Claude Code provides natively: agent dispatch, worktree isolation, concurrent execution, state tracking, and file locking. This infrastructure is fragile (bash YAML parsing, manual PID tracking), expensive to maintain, and misses Claude Code's cache-sharing optimizations.

## Design Goal

Restructure stackpilot from a "self-contained agent framework" into a "methodology layer that drives Claude Code's native primitives." Keep the unique value (sprint lifecycle, spec-driven workflow, quality gates, visual companion), remove the duplicated infrastructure.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  /stackpilot skill (SKILL.md)                       │
│  ┌───────────────┐  ┌────────────┐  ┌────────────┐ │
│  │ Design Phase  │→│ Spec+Plan  │→│ Run Sprint │ │
│  │ (visual comp) │  │ (quality   │  │ (native    │ │
│  │               │  │  gates)    │  │  Agent+Task│ │
│  └───────────────┘  └────────────┘  └────────────┘ │
│                                          │          │
│                          ┌───────────────┼──────────┤
│                          ▼               ▼          │
│                    ┌──────────┐   ┌──────────┐      │
│                    │Agent tool│   │TaskCreate│      │
│                    │(worktree)│   │TaskUpdate│      │
│                    └────┬─────┘   └──────────┘      │
│                         │                           │
│              ┌──────────┼──────────┐                │
│              ▼          ▼          ▼                │
│         sp-architect  sp-dev    sp-qa               │
│         (read-only)   (TDD)    (12-dim)            │
│                                                     │
│  Claude Code native: worktree, cache, lifecycle     │
└─────────────────────────────────────────────────────┘
```

## Key Design Decisions

### D1: State Management — TaskCreate replaces backlog.yml

**Decision**: Use Claude Code's native TaskCreate/TaskUpdate for runtime task tracking. Plan files remain the persistent source of truth.

**Rationale**: TaskCreate provides automatic progress display, dependency tracking, and status management without custom YAML parsing or file locking.

**Session continuity**: If a session is interrupted, `/stackpilot:resume` reads the plan file + git log to reconstruct state and continue.

### D2: Agent Dispatch — Agent tool replaces dispatch.sh

**Decision**: The main skill uses Claude Code's Agent tool with `isolation: "worktree"` to dispatch sp-dev/sp-qa/sp-architect.

**Rationale**: Agent tool provides:
- Fork pattern cache sharing (~66% input token savings)
- Automatic worktree creation and cleanup
- Built-in timeout and abort handling
- Direct result return (no file I/O for inter-agent communication)

### D3: Inter-Agent Communication — Prompt injection replaces file exchange

**Decision**: The coordinator (main session) collects agent outputs and passes them downstream as prompt context.

**Flow**:
```
arch_result = Agent(sp-architect, task_context)
dev_result  = Agent(sp-dev, task_context + arch_result, isolation="worktree")
qa_result   = Agent(sp-qa, task_context + dev_result)
```

**Rationale**: Eliminates arch-review/ and done/ directories, file race conditions, and stale-read bugs.

### D4: Coordinator Inlined — No separate sp-coordinator agent

**Decision**: The "Run Sprint" section of SKILL.md IS the coordinator. It executes inline in the main session.

**Rationale**: sp-coordinator was a workaround for git-hook-triggered background execution. With hooks removed and the skill running interactively, the main session can orchestrate directly.

### D5: PM Agent Removed — Task decomposition is inline

**Decision**: The skill's Phase 4 (Plan writing) already produces the task list. TaskCreate is called directly from the plan. No separate sp-pm agent.

**Rationale**: sp-pm existed to bridge "spec committed via git hook → background task decomposition." Without hooks, this bridging is unnecessary.

### D6: Git Hooks Removed

**Decision**: Remove all 3 hooks (pre-commit, post-commit, post-checkout).

**Rationale**:
- pre-commit validation → moved into skill's Phase 3/4 inline verification
- post-commit sp-pm trigger → PM removed, decomposition is inline
- post-checkout coordinator trigger → coordinator is inline

### D7: Config Simplified

**Decision**: stackpilot.config.yml reduced to `qa` section only.

**Rationale**: Provider routing, model matrix, worktree limits, and timeout config are all handled by Claude Code natively (settings.json, agent frontmatter, built-in limits).

### D8: Claude Code-Only

**Decision**: Drop cross-provider support (Codex/Gemini/custom).

**Rationale**: User directive — "focus on better driving Claude Code." Native integration provides cache sharing, worktree management, and task tracking that are impossible through generic CLI dispatch.

## Component Specifications

### Agent Files (claude-config/agents/)

Each agent becomes a pure methodology prompt. No file I/O, no backlog reads/writes. Receives all context via prompt parameter.

**sp-architect.md**: Read-only codebase analysis → returns architecture decision + blueprint as text output. No more writing to arch-review/.

**sp-dev.md**: TDD + verify/fix loop methodology. Receives task description + arch review in prompt. Commits to worktree branch. Returns completion report as text. No more backlog.yml updates.

**sp-qa.md**: Two-stage code review + 12-dimension test coverage. Receives task + dev completion report in prompt. Returns QA report. Critical issues returned as structured escalation text (not written to NEEDS_REVIEW.md).

**sp-docs.md**: Unchanged (already minimal, no file I/O to remove).

### SKILL.md — Run Sprint Section

Replaces current "Run Coordinator" section. New flow:

```
For each task in plan:
  1. TaskUpdate(status=in_progress)
  2. If standard complexity:
     arch_result = Agent(sp-architect prompt + task, read-only)
  3. dev_result = Agent(sp-dev prompt + task + arch_result, isolation="worktree")
  4. If dev escalated: present to user, wait for decision, retry
  5. qa_result = Agent(sp-qa prompt + task + dev_result)
  6. If QA critical: present to user, wait
  7. TaskUpdate(status=completed)
  8. Print one-line progress: ✅ TASK-001 implement user model (1/5)
```

### NEEDS_REVIEW.md — Simplified Role

No longer written by agents (they return escalations as output). Only used for:
- Cross-session persistence of unresolved escalations
- Manual notes by user

### init.sh — Simplified

Creates: `.stackpilot/specs/`, `.stackpilot/plans/`, `.stackpilot/NEEDS_REVIEW.md`
Detects: `qa.test_command`
Writes: minimal `stackpilot.config.yml`
Skips: hooks, model routing, provider detection, dependency installation

### /stackpilot:resume — New Skill

```
1. Read .stackpilot/plans/*.md → parse TASK list
2. Read git log --oneline → match commit messages to TASK IDs
3. Identify completed vs pending tasks
4. TaskCreate for each pending task
5. Continue sprint from where it left off
```

## Files Changed

### Deleted
- `scripts/dispatch.sh` (272 lines)
- `scripts/hooks/pre-commit.sh`
- `scripts/hooks/post-commit.sh`
- `scripts/hooks/post-checkout.sh`
- `claude-config/agents/sp-pm.md` (86 lines)
- `claude-config/agents/sp-coordinator.md` (166 lines)
- `templates/backlog.yml`
- `templates/in-progress.yml`

### Rewritten
- `claude-config/skills/stackpilot/SKILL.md` — Run Coordinator → Run Sprint
- `claude-config/agents/sp-dev.md` — remove file I/O
- `claude-config/agents/sp-qa.md` — remove file I/O
- `claude-config/agents/sp-architect.md` — remove file I/O

### Simplified
- `scripts/init.sh` — remove hooks, provider detection, model routing
- `scripts/lib/config.sh` — keep only config_get utilities

### New
- `claude-config/skills/stackpilot-resume/SKILL.md`

### Updated
- `claude-config/skills/stackpilot-auto/SKILL.md` — adjust overrides
- `docs/sync.md` — update status

## Risk Assessment

**LOW**: Agent file rewrites — removing file I/O from prompts is safe, agents still have the same methodology.

**MEDIUM**: SKILL.md rewrite — the Run Sprint section is complex, but the new version is structurally simpler (linear loop vs state machine).

**LOW**: File deletions — removing clearly deprecated infrastructure.

**MEDIUM**: init.sh simplification — must ensure existing projects don't break (old .stackpilot/ dirs may have legacy files).
