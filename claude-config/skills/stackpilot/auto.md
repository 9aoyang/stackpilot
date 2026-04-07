---
name: stackpilot:auto
description: Full-auto mode for stackpilot. Same workflow as /stackpilot but skips all user confirmations — plan straight through to coding, testing, and sprint finish without stopping.
---

# Stackpilot Auto Mode

Follow the exact same workflow as the main stackpilot skill (SKILL.md), with these overrides:

## Overrides (skip all interactive gates)

1. **Standard Feature Phase 2 — design confirmation**: Do NOT wait for user reply. Write the design, auto-proceed to spec.

2. **Pre-coding confirmation (Run Coordinator step 4)**: Skip entirely. Dispatch agents immediately.

3. **Sprint Finish — dev server preview**: Skip dev server startup. After tests pass, auto-select option **C (Leave as-is)** — do not merge, do not create PR, do not discard. Just report completion.

4. **Sprint Finish — Sprint Cleanup**: Still run cleanup after reporting.

5. **Any "show options and wait" prompt**: Pick the most conservative non-destructive default and continue.

## Summary

`/stackpilot` = interactive, confirms at each gate
`/stackpilot:auto` = full auto, no stops, ends with code on feature branch ready for user review
