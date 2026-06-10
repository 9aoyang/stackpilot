---
name: stackpilot-plan-execution
description: Internal/default StackPilot execution gate. Trigger behind the StackPilot entry when a spec or plan exists and work should be executed task-by-task with TDD, isolated workspaces/subagents when available, spec-compliance review before quality review, and controller verification before advancing.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Plan Execution

Execute an existing implementation plan without weakening StackPilot gates. This
skill is host-neutral; use the strongest host adapter available.

## Adapter Rule

- Claude Code with `/stackpilot` available: the full adapter may run the sprint
  after the methodology has routed the work.
- Hosts with subagents/workspaces: dispatch fresh agents with scoped context and
  isolated workspaces.
- Hosts without subagents: execute inline, but keep the same gates.

## Hard Gates

- No implementation without a written plan or a concise plan section in the
  current response.
- Every task needs exact files, dependencies, verification commands, and scope.
- Production code follows TDD unless explicitly exempted with a reason.
- Spec-compliance review happens before implementation-quality review.
- Do not trust implementer self-reports. Inspect diff, command output, and
  acceptance criteria evidence before marking a task complete.
- Stop on destructive/external side effects and ask for explicit confirmation.

## Process

1. **Load and critique the plan**

   Read the plan once, extract every task, and identify missing files,
   dependencies, verification commands, or scope boundaries. Fix small gaps
   before execution; escalate blocking gaps.

2. **Prepare workspace**

   Use `stackpilot-workspace` or the host adapter's equivalent before changing
   files unless the user explicitly chose in-place work.

3. **Create task tracking**

   Use the host task tracker. Track at least: task id, title, status, files,
   verify command, and blockers.

4. **Execute task-by-task**

   For each task:

   - Start only after dependencies are complete.
   - Run TDD for production code.
   - Keep changes inside task scope.
   - Commit or record a durable checkpoint when the task passes verification.

5. **Review each task**

   Review in this order:

   - Spec compliance: required behavior present, no scope creep.
   - Quality: correctness, security, performance, maintainability.
   - Deterministic checks: renamed symbols, deleted references, shared-field
     sync, absolute claims.

6. **Advance only with evidence**

   Required evidence for completion:

   - Diff inspected.
   - Verification command run or independently validated.
   - Acceptance criteria updated or explicitly N/A.
   - Review findings resolved or escalated.

7. **Finish**

   Use `stackpilot-completion-verification` before any completion claim or
   merge/PR decision.

## Output Contract

```markdown
## Execution Summary
- Plan:
- Workspace:
- Tasks: <done>/<total>

## Task Evidence
### TASK-001 - <title>
- Files changed:
- TDD: Yes / No, reason:
- Verify command:
- Verify result:
- Spec review:
- Quality review:
- Criteria status:

## Blockers
- <none or exact blocker>
```

## Red Flags

- "I'll just execute the first step before reviewing the plan."
- Task says "write tests" but no behavior or command is specified.
- Reviewer starts with style/quality before checking spec compliance.
- Task is marked done because an agent said it was done.
- Criteria remain `untested` after task completion.
