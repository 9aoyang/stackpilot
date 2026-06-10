---
name: stackpilot-review-response
description: Internal/default StackPilot review-response gate. Trigger behind the StackPilot entry when receiving human or external review feedback before accepting, rejecting, or implementing suggestions. Requires technical verification, scoped fixes, and fresh tests.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Review Response

Treat review feedback as technical claims to verify, not as orders to implement
or compliments to acknowledge.

## Hard Gates

- Do not blindly agree with review feedback.
- Do not implement unclear feedback. Ask for clarification first.
- Do not batch unrelated fixes without testing each one.
- Do not add "professional" features unless the codebase has a real caller or
  requirement for them.
- Do not claim feedback is addressed without fresh verification.

## Process

1. **Parse feedback**

   Split feedback into individual items. Mark each as clear or unclear.

2. **Clarify blockers**

   If any item is unclear and could affect implementation order or scope, ask
   before making changes.

3. **Verify technically**

   For each clear item:

   - Inspect the referenced file/line or behavior.
   - Check whether the suggestion is correct for this codebase.
   - Check whether it conflicts with user/project decisions.
   - Grep for actual callers before adding unused capability.

4. **Decide**

   Mark each item:

   - `accept` - technically correct and in scope.
   - `reject` - technically wrong, out of scope, or violates YAGNI.
   - `clarify` - needs more information.
   - `defer` - valid but not part of this change.

5. **Implement accepted items**

   Fix one item at a time. For production behavior, use TDD or add/update a
   regression test. Run the relevant verification after each fix or coherent
   group of tightly coupled fixes.

6. **Respond with evidence**

   Report what changed, what was rejected/deferred and why, and the verification
   command/output.

## Output Contract

```markdown
## Review Response
| Item | Decision | Evidence | Action |
|------|----------|----------|--------|

## Changes
- `file` - reason

## Verification
- Command:
- Result:
```

## Red Flags

- "You're absolutely right" before checking.
- Implementing a reviewer suggestion that has no caller.
- Fixing items 1, 2, and 6 while items 3-5 are unclear.
- Explaining away a failing verification command.
- Saying "addressed" without a command result.
