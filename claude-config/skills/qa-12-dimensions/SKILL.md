---
name: qa-12-dimensions
description: Systematic test coverage using a 12-dimension scenario matrix plus two-stage code review. Use when writing tests, reviewing code changes, or doing QA on completed features. Catches edge cases that happy-path-only testing misses.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.1.0"
---

# QA: 12-Dimension Testing + Code Review

## Two-Stage Code Review (before writing tests)

### Stage 1: Spec & Project Guidelines Compliance

- **Project guidelines**: read `CLAUDE.md` (or equivalent — `GEMINI.md`, `AGENTS.md`, `.cursorrules`). Verify the diff follows explicit project rules: import patterns, framework conventions, language style, error-handling shape, logging shape, testing conventions, naming. Guideline violations are first-class findings.
- **Spec compliance**: does the implementation match requirements? Is every requirement addressed? Any out-of-scope changes? Flag scope creep.
- **TDD**: was a test written first? If not, why?

### Stage 2: Code Quality

Review `git diff` for changed files:

- **Bug risk**: logic errors, boundary values, null/undefined handling
- **Security**: input validation, permissions, data exposure, injection surfaces
- **Performance**: O(n²) where O(n) possible, unnecessary allocations, N+1 queries
- **Conventions**: consistent with project patterns + CLAUDE.md rules
- **Error handling**: errors surfaced or silently swallowed?

### Reporting Rules

Rate each potential finding 0-100 on the **confidence scale** (only report ≥ 80):

| Score | Meaning |
|-------|---------|
| **0**   | Not confident — false positive that doesn't survive scrutiny, or pre-existing issue. |
| **25**  | Somewhat confident — might be real, might be false positive. If stylistic, not in project guidelines. |
| **50**  | Moderately confident — real issue but might be a nitpick or rare in practice. Low priority relative to rest of diff. |
| **75**  | Highly confident — double-checked, very likely real, the existing approach is insufficient. Important; directly impacts functionality or is in project guidelines. |
| **100** | Absolutely certain — confirmed real issue that will happen frequently in practice. Direct evidence. |

Findings under 80 are noise; do not report them. Quality over quantity.

For each reported finding, include:

- Confidence score
- `file:line`
- Concrete failure scenario (inputs / state / caller context)
- Specific fix suggestion or guideline citation

Group by severity:

- **Critical** (bug, security, spec mismatch) → flag immediately, do not proceed past review
- **Important** (quality issue, < 5 lines to fix) → fix directly, log reason

Do NOT blindly agree with external review feedback — evaluate technically, verify against the actual codebase.

### Adversarial Angles Tried (required)

After the review, write a one-line-per-angle list of what you actually tried. If you found nothing, "no findings" is only credible when this list is non-trivial. Example angles:

- Spec / scope compliance
- Project guideline compliance (CLAUDE.md)
- Over-engineering (unrequested validation, helpers, caches, comments)
- Authentication / data integrity / rollback
- Null / empty / timeout / race
- Absolute claims in prose ("only", "always", "never") — reverse-checked
- Cross-file consistency (unmigrated call sites after rename)

An empty or two-item Adversarial Angles list with "no findings" means the review didn't really happen — go back and try more angles.

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
- "No findings" is only a valid conclusion when the Adversarial Angles Tried list shows real effort. A short list with zero findings is a review that didn't happen.
