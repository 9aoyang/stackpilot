---
name: stackpilot-completion-verification
description: Internal/default StackPilot evidence-before-claims completion gate. Trigger behind the StackPilot entry before saying work is complete, fixed, passing, ready to merge, or ready for PR. Verifies commands, requirements, acceptance criteria, and finish choices with fresh evidence.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Completion Verification

No completion claim without fresh evidence from the current turn. This skill is
the portable finish gate for hosts that do not run the full `/stackpilot`
adapter.

## Hard Gates

- Do not say complete/fixed/passing/ready until verification has run.
- Do not rely on prior runs, agent reports, or "should pass".
- Do not use a narrow command to prove a broader claim.
- Do not present merge/PR/discard choices until required verification is done.
- Destructive choices require explicit confirmation.

## Gate Function

1. **Identify claims**

   List every claim you are about to make:

   - Tests pass.
   - Bug fixed.
   - Feature implemented.
   - Acceptance criteria met.
   - Ready to merge or create PR.

2. **Map evidence**

   For each claim, name the command or observable evidence that proves it.

3. **Run fresh verification**

   Run the full command now. Read the output and exit status. For UI work, use a
   rendered-page check, screenshot/DOM assertion, or project-native browser test
   when available.

4. **Check requirements**

   Re-read the spec, plan, user request, and acceptance criteria. Mark every
   requirement:

   - `pass` - directly proven.
   - `fail` - contradicted by evidence.
   - `untested` - no direct evidence.
   - `n/a` - not applicable, with reason.

5. **Report actual state**

   If any required item is `fail` or `untested`, do not claim completion. State
   the exact remaining work.

6. **Finish decision**

   Only after verification passes, present host-appropriate choices:

   - merge locally
   - push/create PR
   - keep as-is
   - discard (typed confirmation required)

## Output Contract

```markdown
## Verification Evidence
- Command:
- Result:
- Key output:

## Requirement Status
| Requirement | Evidence | Status |
|-------------|----------|--------|

## Finish State
- Complete: Yes / No
- Remaining work:
- Safe finish choices:
```

## Red Flags

- "Should work now."
- "Looks good."
- "The agent said it passed."
- "I ran this earlier."
- "Lint passed, so build/tests are fine."
- "Small change, no need to verify."
