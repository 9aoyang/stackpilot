# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
