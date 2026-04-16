---
name: systematic-debugging
description: Structured 4-phase debugging methodology with root cause investigation. Use when fixing bugs, diagnosing errors, troubleshooting failures, or when a fix attempt didn't work. Prevents symptom-level patching through mandatory investigation before any code changes.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.1"
---

# Systematic Debugging

**Iron Law: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

## Phase 1 — Observe

1. Read the FULL error output. The answer is often in the message.
2. Copy the exact error text — file, line, stack trace.
3. Reproduce consistently: run the failing command again. If it doesn't reproduce, it's a different problem.
4. Check recent changes: `git diff`, new deps, config changes, environment differences.

## Phase 2 — Trace

5. Follow data/control flow **backwards** from the error:
   - What function called this? What arguments were passed?
   - Where did the bad value come from? Trace one step further back.
6. Find a working example in the codebase — how does a similar path succeed?
7. Compare: identify ALL differences, however small.
8. In multi-component systems: add diagnostic instrumentation at each component boundary.

## Phase 3 — Hypothesize

9. Form ONE specific hypothesis in writing: "The error happens because X passes null where Y expects a string."
10. Test MINIMALLY — change one variable at a time.
11. If hypothesis is wrong, form a NEW one. Do not patch the old hypothesis.

## Phase 4 — Fix

12. Write a failing test that reproduces the bug.
13. Implement a single fix targeting the root cause (not the symptom).
14. Verify: the failing test now passes, all existing tests still pass.
15. If the fix doesn't work, return to Phase 2 — you traced the wrong path.

## Red Flags — Return to Phase 1 Immediately

Stop and restart investigation if you catch yourself thinking:

| Thought | Why it's dangerous |
|---------|-------------------|
| "Quick fix for now, investigate later" | "Later" never comes. You'll ship a band-aid. |
| "Just try changing X and see" | Cargo-cult debugging. You don't understand the cause. |
| "Add multiple changes, run tests" | If it works, you don't know which change fixed it. If it doesn't, you've muddied the waters. |
| "It's probably X, let me fix that" | "Probably" = no evidence. Investigate first. |
| "I don't fully understand but this might work" | Unverified fixes create new bugs. |
| Each fix reveals a new problem in a different place | You're chasing symptoms, not the cause. Step back. |

## 3-Strike Escalation Rule

If you've formed 3 hypotheses and all were disproven by evidence: **STOP. Do not form a 4th hypothesis.**

Instead:
1. Report what you know: the 3 hypotheses, why each was wrong, what evidence disproved them
2. Report what you don't know: the remaining unknowns
3. Ask the user for direction — they likely have domain context you lack

This prevents the "guess spiral" where each attempt muddies the codebase further.

## Architecture Check (after 3 failed fixes)

If you've tried 3 different fixes and none worked, stop fixing. Ask:

- Is there a shared mutable state problem?
- Is the coupling between components too tight?
- Is the abstraction wrong (fighting the design, not the bug)?
- Should this be redesigned rather than patched?

## Gotchas

- The most common debugging mistake is not reading the full error message. Read it twice.
- "It worked before" means something changed. `git log`, `git diff`, and `git bisect` are your friends.
- Intermittent bugs are usually race conditions (async), resource exhaustion, or uninitialized state. Don't dismiss them as flakes.
- If adding a log statement "fixes" the bug, it's a timing issue.
