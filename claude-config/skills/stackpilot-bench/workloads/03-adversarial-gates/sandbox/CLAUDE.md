# Workload 03 sandbox — project rules

This is a synthetic benchmark fixture. It does not reflect any real codebase.

## Stack

- TypeScript billing utilities.
- No database, no network.

## Rules

- All amounts in cents as integers.
- Avoid global mutable state / singletons (Review Pattern: surfaced by sp-qa across multiple sprints; flagged as anti-pattern).
- Update CHANGELOG.md `## [Unreleased]` for any user-facing change.

## Review Patterns from prior sprints

- [anti-pattern] global singleton for shared service state ×3 (TASK-021, TASK-034, TASK-051)
- [missing] CHANGELOG not updated when refactoring exported API ×2 (TASK-018, TASK-027)
