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
| `.stackpilot/` | Per-project: specs, plans, NEEDS_REVIEW.md |
| `scripts/` | init.sh, hooks, preview server |
| `templates/` | stackpilot.config.yml, NEEDS_REVIEW.md |

## Agent Pipeline

```
sp-architect (HIGH complexity only) → sp-dev (TDD, worktree) → sp-qa (12-dim + optional codex) → sp-docs
```

## Key Design Decisions

- **Fork-pattern caching**: agents share parent context → ~66% token savings
- **Worktree isolation**: each dev task runs in its own git worktree
- **Zero custom infra**: everything uses Claude Code native tools
- **Cross-model review**: sp-qa calls `/codex:adversarial-review` when codex-plugin-cc is present
- **NEEDS_REVIEW.md**: human escalation channel; gitignored; cleared after each sprint

## External Skill Dependencies

See `docs/sync.md` for all tracked external skills.
