# Architecture

## Overview

Stackpilot is a skill-based orchestration layer for Claude Code.
Tasks flow through a five-phase pipeline: Spec → Plan → Architect → Dev → QA.

## Agent Pipeline

Each sprint is managed by a sequence of specialist agents:

| Agent   | Responsibility                            |
|---------|-------------------------------------------|
| sp-spec | Translate user request into a formal spec |
| sp-plan | Break spec into ordered task list         |
| sp-arch | Assess risk; write Architecture Review    |
| sp-dev  | Implement one task at a time (TDD)        |
| sp-qa   | Four-stage quality audit per task         |

## Key Design Decisions

**Worktree isolation**: each dev task runs in its own git worktree.
This prevents in-flight changes from one task from contaminating the
working tree of a concurrent task.

**Agent dispatch**: each phase is a separate `Agent()` call so that
context windows stay bounded and errors are isolated to a single phase.

**Append-only history**: `.stackpilot/plans/` files are never deleted;
completed plans are moved to `.stackpilot/plans/archive/`.

## Configuration

Project-level configuration lives in `stackpilot.config.yml`.
Skill-level instructions live in `SKILL.md`.
