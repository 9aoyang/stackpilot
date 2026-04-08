---
name: qa-12-dimensions
description: Systematic test coverage using a 12-dimension scenario matrix plus two-stage code review. Use when writing tests, reviewing code changes, or doing QA on completed features. Catches edge cases that happy-path-only testing misses.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "2.0"
---

# QA: 12-Dimension Testing + Code Review

## Two-Stage Code Review (before writing tests)

### Stage 1: Spec Compliance

- Does implementation match requirements? Every requirement addressed?
- Any out-of-scope changes? Flag them.
- Was TDD followed?

### Stage 2: Code Quality

Review `git diff` for changed files:

- **Bug risk**: logic errors, boundary values, null handling
- **Security**: input validation, permissions, data exposure
- **Performance**: O(n²) where O(n) possible, unnecessary allocations
- **Conventions**: consistent with project patterns
- **Error handling**: errors surfaced or silently swallowed?

### Reporting Rules

- Only report issues with confidence >= 80% (must have `file:line` evidence)
- **Critical** (bug or security) → flag immediately, do not proceed
- **Important** (quality, <5 lines to fix) → fix directly, log reason
- Do NOT blindly agree with review feedback — evaluate technically, verify against codebase

## 12-Dimension Scenario Coverage

For each changed function/component, systematically check which dimensions apply and write at least one test for each:

| # | Dimension | What to test |
|---|-----------|-------------|
| 1 | **Happy path** | Normal input → expected output |
| 2 | **Error / failure** | Invalid input → error thrown/returned |
| 3 | **Edge case** | Empty, zero, max length, boundary values |
| 4 | **Abuse / invalid** | Null, undefined, wrong type, injection strings |
| 5 | **Scale** | Large collections, deep nesting |
| 6 | **Concurrent** | Parallel calls, race conditions (if async) |
| 7 | **Temporal** | Timeout, retry, eventual consistency |
| 8 | **Data variation** | Different valid shapes of same input |
| 9 | **Permission** | Unauthorized access, missing scope |
| 10 | **Integration** | Interaction with the next layer (mock boundary) |
| 11 | **Recovery** | Partial failure → state is left clean |
| 12 | **State transition** | Before/after state is correct |

Mark inapplicable dimensions as N/A — the goal is deliberate coverage, not coverage for its own sake.

## Test Writing Rules

- Test observable behavior, not internals
- One assertion per test where possible
- Name: `it('does X when Y', ...)`
- Default scope: test files only
- Production fixes allowed only for bugs introduced by the current task (log reason)

## Verify/Fix Loop

1. Run test command → if failing, distinguish test issue vs production bug
2. Check coverage meets threshold
3. Max 3 rounds
4. Still failing after 3 → stop, report what was tried

## Gotchas

- Not every dimension applies to every function. The matrix is a checklist, not a mandate.
- Dimension 6 (concurrent) and 7 (temporal) are the most commonly skipped — and the most common source of production bugs.
- A production fix during QA must be scoped to the current task only. No cross-task refactoring.
