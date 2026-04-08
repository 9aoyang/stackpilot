---
name: architecture-review
description: Analyzes existing codebase patterns to make decisive architecture choices and deliver implementation blueprints. Use before implementing multi-file features, when facing architectural decisions, or when a task touches shared data structures. Read-only — never writes source code.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.1"
---

# Architecture Review

Read-only analysis. Never create or modify source code.

## Process

1. Read project conventions (CLAUDE.md or equivalent)
2. Search the codebase for how similar things are built:
   - Find existing implementations (`file:line` references)
   - Identify naming conventions, error handling, data flow patterns
   - Do NOT assume — read the actual code
3. Make **one decisive architecture choice** — not a list of options

## Output Format

```
## Risk
LOW / MEDIUM / HIGH

## Existing Patterns
- `path/to/file.ts:42` — how similar functionality is already implemented
- Conventions observed: naming / error handling / data flow

## Architecture Decision
- **Chosen approach:** <specific approach>
- **Why:** fits existing style better than alternatives
- **Rejected alternatives:** brief reason each was not chosen

## Implementation Blueprint
- **New files:** `path/to/create.ts` — purpose
- **Modified files:** `path/to/existing.ts:L42-L60` — what changes
- **Component design:** interface definitions / data structures
- **Build sequence:** Step 1 → Step 2 → Step 3

## Critical Details
- Edge cases to watch
- Integration points with existing code
```

## Multi-Persona Adversarial Review (HIGH Risk Only)

When Risk is HIGH, analyze from 3 independent perspectives before the final decision:

| Persona | Question |
|---------|----------|
| **Security** | What can be exploited? What inputs must be validated? What data must not leak? |
| **Performance** | Where is the hot path? Worst-case complexity? Will it degrade under 10x load? |
| **Reliability** | What breaks if a dependency fails? Partial-success state? How to recover? |

After all 3: resolve conflicts explicitly — which concern wins and why.

Skip for LOW/MEDIUM risk tasks.

## Escalation Triggers

Stop and report if:
- Task requires a new external dependency
- Task changes a data structure used in 2+ other files
- Direct conflict between task requirements and existing code

## Gotchas

- "Analyze existing patterns" means READ the code, not assume based on project type. A React project might use class components in one area and hooks in another.
- One decision, not a menu. If you can't decide, the task needs more information — escalate.
- The implementation blueprint must include specific line ranges for modified files. "Update the auth module" is too vague; "`src/auth/middleware.ts:L15-L30` — add role check before token validation" is actionable.
