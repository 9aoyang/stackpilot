# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-04-11

### Changed
- **Sprint Finish: squash merge as standard** — merging to base branch now uses `git merge --squash`, producing exactly one commit on main
- **Pre-merge housekeeping on feature branch** — architecture update and sprint artifact cleanup are committed on the feature branch before squash, so they get folded into the single merge commit
- **Feature branch auto-deleted after merge** — `git branch -d` runs automatically on choice A

## [1.2.0] - 2026-04-10

### Added
- **sp-qa Stage 3: Adversarial Review** — attacker-mindset review checking 6 attack surfaces (auth, data integrity, rollback, race conditions, null/timeout, version skew). Full review for HIGH risk tasks, top 3 for others.
- **Review Patterns (cross-sprint memory)** — `.stackpilot/review-patterns.md` accumulates recurring QA findings across sprints. Frequency-based retention (max 20, lowest-count pruned first). sp-qa reads patterns on startup and actively watches for known issues.
- **Cross-model review (optional)** — when codex-plugin-cc is installed, sp-qa automatically requests `/codex:adversarial-review` as supplementary second opinion. Silently skipped when unavailable.
- **Risk-aware QA dispatch** — architecture review risk level passed to sp-qa, controlling adversarial review depth.

## [1.1.0] - 2026-04-10

### Changed
- **Consolidated orchestration commands** (6→3): merged `stackpilot-auto`, `stackpilot-resume`, `stackpilot-tidy` into main `/stackpilot` as state-routed flows
- **Removed archive mechanism**: plans/specs are deleted directly after sprint (git history is sufficient)
- **Auto/interactive mode**: user chooses after describing feature, replacing standalone `/stackpilot-auto`

### Added
- **Workspace tidy flow**: cleans `.claude/plans/`, `.superpowers/`, orphaned worktrees, merged branches, stale remote tracking branches
- **Sprint resume flow**: detects interrupted sprints from plan + git log, offers continue/fresh/discard

### Removed
- `stackpilot-auto` skill (merged into `/stackpilot`)
- `stackpilot-resume` skill (merged into `/stackpilot`)
- `stackpilot-tidy` skill (merged into `/stackpilot`)
- `.stackpilot/archive/` directory and all archive logic

## [1.0.1] - 2026-04-08

### Added
- New portable skill: `systematic-debugging` — 4-phase root cause investigation
- TDD rationalization blockers in `tdd-development` (7 common excuses countered)

### Changed
- Updated all docs for v1.0 completeness (README, architecture, sync, CONTRIBUTING)

## [1.0.0] - 2026-04-08

### Changed — Architecture Rewrite
- **Agent dispatch**: replaced `dispatch.sh` (272 lines bash) with Claude Code native Agent tool — Fork pattern cache sharing, automatic worktree isolation
- **Task tracking**: replaced `backlog.yml` + `in-progress.yml` with Claude Code native `TaskCreate`/`TaskUpdate`
- **Inter-agent communication**: replaced file exchange (`arch-review/`, `done/`) with prompt-level passing
- **Coordinator**: inlined into SKILL.md "Run Sprint" section (was separate `sp-coordinator` agent)
- **Task decomposition**: inlined into skill Phase 4 (was separate `sp-pm` agent)
- **Config**: simplified from 40-line multi-provider to 5-line qa-only (`stackpilot.config.yml`)
- **SKILL.md**: restructured with progressive disclosure — 482→186 lines, heavy content moved to `references/`
- **All skill names**: migrated from colon syntax (`stackpilot:auto`) to hyphen syntax (`stackpilot-auto`) for Agent Skills spec compliance

### Added
- **Portable methodology skills** (Agent Skills standard, work in Cursor/Copilot/Gemini CLI/Codex/25+ products):
  - `tdd-development` — TDD cycle + verify/fix loop + 4-phase root cause investigation
  - `qa-12-dimensions` — two-stage code review + 12-dimension scenario test coverage
  - `architecture-review` — codebase pattern analysis → decisive choice → implementation blueprint
- **`/stackpilot-resume`** skill — recover interrupted sprints from plan + git log
- **Claude Plugin manifest** (`.claude-plugin/plugin.json`) — installable via marketplace
- **Progressive disclosure references**: `references/visual-companion.md`, `references/optimize-sprint.md`, `references/sprint-finish.md`

### Removed
- `scripts/dispatch.sh` — replaced by Claude Code native Agent tool
- `scripts/hooks/pre-commit.sh`, `post-commit.sh`, `post-checkout.sh` — validation and triggers inlined into skill
- `claude-config/agents/sp-pm.md` — task decomposition inlined into skill
- `claude-config/agents/sp-coordinator.md` — orchestration inlined into skill
- `templates/backlog.yml`, `templates/in-progress.yml` — replaced by TaskCreate
- Cross-provider support (Codex/Gemini/custom) — now Claude Code-only
- Provider detection, model routing matrix, worktree management, file locking from init.sh

## [0.3.0] - 2026-04-07

### Added
- Automated GitHub Release workflow triggered by `v*` tags
- Release helper script for validating tag and `VERSION` consistency

### Changed
- CI now runs release automation tests

## [0.2.0] - 2026-04-05

### Changed
- Renamed all agent files to `sp-*` prefix (`sp-pm`, `sp-architect`, `sp-dev`, `sp-qa`, `sp-docs`, `sp-coordinator`) — **breaking change** for existing installations
- Moved task runtime directory from `tasks/` to `.stackpilot/tasks/` — **breaking change** for existing installations
- Renamed config pointer from `.stackpilot-path` to `.stackpilot/path`
- Git hooks now watch `.stackpilot/specs/` and `.stackpilot/plans/` instead of `docs/specs/`
- Updated GitHub org/username references in README and install URL
- Significant rewrite of `/stackpilot` skill (`SKILL.md`) for improved agent dispatch logic
- Replaced dependency table in README with link to architecture docs

### Added
- Architecture documentation: `docs/architecture.md` and `docs/architecture.zh.md`
- `docs/skill-refs.md` skill reference index

### Removed
- Old design specs and implementation plan docs (`docs/specs/`, `docs/superpowers/`)
- Workflow diagram (`docs/workflow.png`, `docs/workflow.html`)

## [0.1.0] - 2026-03-29

### Added
- Core agent definitions: PM, Architect, Dev, QA, Docs, Coordinator
- Project templates: `backlog.yml`, `in-progress.yml`, `stackpilot.config.yml`, `NEEDS_REVIEW.md`
- `init.sh` script to initialize Stackpilot in any project
- `restore.sh` script to install agents and skills to `~/.claude/`
- Git hooks: `post-commit` (triggers PM Agent), `post-checkout` (triggers Coordinator)
- `/stackpilot` skill as primary workflow entry point
- `/update-gstack` skill and cron-based auto-updater
- Test suite: `test-init.sh`, `test-hooks.sh`, `test-e2e.sh`
- Workflow diagram (`docs/workflow.png`)
- Design specs and implementation plan documentation

### Fixed
- Auto-install gstack if not found during init
- Correct `--allowedTools` syntax in coordinator dispatch table
- Use append semantics for `NEEDS_REVIEW.md` in all agents
- Skill file renamed to `SKILL.md` for Claude Code discovery
