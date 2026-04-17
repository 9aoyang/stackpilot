# Stackpilot — Sprint Architecture Summary

> This is the quick-reference for sprint routing. Full architecture: `docs/architecture.md`

## What This Project Is

Stackpilot is a sprint orchestration layer for Claude Code. `/stackpilot` skill drives the full dev loop: spec → plan → agent dispatch → QA → ship.

## Stack

- **Runtime**: Claude Code native (Agent tool, TaskCreate, worktrees — no custom infra)
- **Language**: Markdown-driven skills + Bash scripts
- **Distribution**: install.sh → symlinks into `~/.claude/`

## Key Directories

| Path | Purpose |
|------|---------|
| `claude-config/agents/sp-*.md` | Agent methodology prompts (architect/dev/qa/docs) |
| `claude-config/skills/stackpilot/SKILL.md` | Main `/stackpilot` entry point |
| `claude-config/skills/stackpilot/references/` | Sub-protocols (sprint-finish, optimize-sprint, visual-companion) |
| `docs/architecture.md` | Full architecture reference |
| `docs/sync.md` | External skill dependency tracking |
| `.stackpilot/` | Per-project: specs, plans |
| `scripts/` | init.sh, hooks, preview server |
| `templates/` | stackpilot.config.yml |

## Agent Pipeline

```
sp-architect (HIGH complexity only) → sp-dev (TDD, worktree) → sp-qa (12-dim + Stage 4 consistency audit) → [opt-in Deep Review] → sp-docs
```

## Key Design Decisions

- **Fork-pattern caching**: agents share parent context → ~66% token savings
- **Worktree isolation**: each dev task runs in its own git worktree
- **Zero custom infra**: everything uses Claude Code native tools
- **Deep review (2-layer, local)**: Layer 1 — sp-qa Stage 4 Consistency Audit (grep-based, HIGH-risk mandatory, <1s). Layer 2 — main agent spawns a fresh-context reviewer after sp-qa on HIGH-risk tasks (default on, `qa.deep_review: false` disables; ~30-60s, no remote)
- **Don't re-teach Claude what it already knows**: agent methodology files specify stackpilot's orchestration contract (input format, completion output format, escalation signals, cross-sprint memory hooks) — NOT generic engineering advice (how to do TDD, how to review code, how to debug). Claude 4.7 does those natively. sp-dev and sp-qa were trimmed ~47% on 2026-04-17 to enforce this separation.
- **Light tasks skip sp-qa dispatch**: for `complexity: light`, sp-dev's TDD verify/fix is sufficient. Main agent still runs Stage 4 consistency audit inline (cheap deterministic greps). sp-qa dispatch only fires on standard complexity.
- **sp-docs uses haiku**: docs updates are mechanical; haiku 4.5 handles them at ~3-5x lower cost than sonnet.
- **Auto-verify 1 round, not 2**: 4.7 self-catches first-pass issues ~95% of the time. Second round is rare hit with high cost; escalate on failure instead.
- **Plan review = traceability check, not 12-QA re-run**: spec 12-QA already scored all 12 dimensions. Plan review only verifies spec→task forward trace and task→spec reverse trace. No re-derivation.
- **Registered agents >> inline methodology**: 2026-04-17 micro-benchmark on identical read-only QA task: sp-qa dispatch = 10.7k tokens / 13.6s; general-purpose with inlined sp-qa methodology = 21.5k tokens / 31.1s. 2x cheaper and 2.3x faster. Root cause: registered agent methodology caches as Claude Code system prompt; inline counts as input tokens every dispatch. This is WHY sp-* registration correctness matters — without it, every optimization (haiku for docs, opus for arch, tool restrictions) is dead code.

## Conventions & Gotchas

<!-- project-specific conventions, decisions, gotchas; add entries as they surface -->

- **Squash merge only on main** — enforced by `scripts/hooks/pre-merge-commit` (installed by `init.sh` into each clone's `.git/hooks/`); feature branches fold into one commit on merge
- **Markdown + Bash only** — no runtime tests; verification is grep-based on references across `claude-config/`, `scripts/`, `docs/`
- **Single-file project memory** — `.stackpilot/ARCHITECTURE.md` is the sole per-project memory surface; `sp-qa` never writes it, only reads and surfaces Pattern Candidates in its report (2026-04-17)
- **stackpilot.config.yml `qa.test_command` may be `N/A`** for meta-projects (like this repo) — Step 0 pre-merge gate handles absent test commands by reporting `N/A`, not failing

## Review Patterns

<!-- maintained via Sprint Finish; sp-qa surfaces candidates, main agent merges; max 20 entries -->

## External Skill Dependencies

See `docs/sync.md` for all tracked external skills.
