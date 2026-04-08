---
name: tdd-development
description: Enforces Test-Driven Development with a rigorous verify/fix loop and root cause investigation. Use when implementing features, fixing bugs, or writing any production code. Prevents symptom-level patching through mandatory 4-phase investigation before fixes.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "2.0"
---

# TDD Development

Enforce RED-GREEN-REFACTOR for every unit of work. No exceptions.

## Before Coding

1. Read project conventions (CLAUDE.md, .editorconfig, linting config)
2. Run `git log --oneline -20` — identify prior failed attempts on this area. Do NOT repeat a failed approach.
3. Trace the execution path: locate entry point (`file:line`), trace call chain up and down, find existing similar implementations.

## RED — Write a failing test first

1. Before touching production code, write a test for the expected behavior
2. Run the test — it **must fail**. If it passes, you're not testing anything new
3. If untestable (pure config change), document why

## GREEN — Write minimal code to pass

4. Write **minimum** production code to make the failing test pass
5. Run all tests — new test passes, existing tests still pass
6. No code "just in case" — only what the test demands

## REFACTOR — Clean up without changing behavior

7. If code is messy, refactor now (tests protect you)
8. Run tests again — must still pass

## Verify/Fix Loop

After implementation, run all four checks:

1. **BUILD** — project compiles / parses without errors
2. **LINT** — no new lint errors
3. **TEST** — all tests pass
4. **SCOPE** — changed files match expectations

### On Failure: Root Cause Investigation (mandatory)

**Do NOT blindly fix.** Run this investigation first:

**Phase 1 — Observe**: Read the FULL error. Copy exact message. Identify file and line.

**Phase 2 — Reproduce**: Run failing command again to confirm consistency.

**Phase 3 — Trace**: Follow data/control flow backwards from error:
- What function called this? What arguments were passed?
- Is there a working similar path? What's different?
- Check `git diff` — did your change break an assumption?

**Phase 4 — Hypothesize**: Form ONE specific hypothesis. Test with a targeted check.

**Only after Phase 4 confirms your hypothesis**, apply ONE atomic fix.

### Fix Loop Rules

- Max 3 rounds (investigation + one fix + re-verify each)
- Each fix targets root cause, not symptom
- **Stuck detection**: round 2 error = round 1 error → hypothesis was wrong, trace a different path
- Round 3 still failing → stop, report what was tried

### "Fundamentally different approach" triggers

When stuck detection fires:
- **Different algorithm**: fixing in-place → rebuild from scratch
- **Different abstraction level**: patching a function → extract to new module
- **Different dependency**: library issues → native implementation (or vice versa)
- **Different entry point**: fix not working in file A → real problem is in file B (the caller)

## Gotchas

- Always read git history before starting — repeating a failed approach wastes a full cycle
- The test must fail RED before you write production code. A passing test on first run means it's not testing new behavior.
- One fix per round. Multiple changes make root cause attribution impossible.
- Revert all uncommitted changes on failure to leave a clean state for the next attempt.
