---
name: stackpilot-planning
description: Internal/default StackPilot planning gate. Trigger behind the StackPilot entry when a spec, design, or clear requirement exists and code has not started. Produces task-sized plans with exact files, dependencies, verification commands, TDD steps, and fully resolved task descriptions.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Planning

Turn an approved design or clear requirement into an implementation plan that a
fresh worker can execute without guessing.

## Hard Gates

- Do not write implementation code while planning.
- Every task must name exact files, dependencies, verification commands, and
  scope boundaries.
- No placeholders: no TODO/TBD, "similar to above", "add tests", or "handle
  edge cases" without concrete behavior and commands.
- Plan TDD explicitly for production code: failing test, expected failure,
  minimal implementation, green verification.
- Scope creep is a planning bug. Every task must trace to the spec or request.

## Process

1. **Load source requirements**

   Read the spec/design/user request and any canonical refs. If the request
   covers multiple independent subsystems, split it before planning.

2. **Map files first**

   List files to create/modify/test and their responsibility. Follow existing
   codebase patterns; do not introduce unrelated refactors.

3. **Write tasks**

   Keep tasks small enough for focused execution. Each task must include:

   - `files`
   - `depends_on`
   - `verify`
   - `scope`
   - TDD steps or an exemption reason
   - `sister_files` / `shared_field_grep` when shared identifiers or fields are
     involved

4. **Traceability check**

   Forward: every requirement maps to at least one task.

   Reverse: every task maps back to a requirement. Remove orphan tasks.

5. **Self-review**

   Scan for placeholders, type/name inconsistencies across tasks, missing
   verification commands, missing dependencies, and tasks that are too broad.

6. **Handoff**

   Save to `.stackpilot/plans/<date>-<feature>-plan.md` when the repo uses
   StackPilot artifacts. Otherwise keep the plan in the response and route to
   `stackpilot-plan-execution` for implementation.

## Output Contract

```markdown
# Plan - <feature>

## Goal
## Requirements Trace

## Tasks
### TASK-001 - <title>
- files:
- depends_on:
- verify:
- scope:
- TDD:
- sister_files:
- shared_field_grep:
```

## Red Flags

- "Implement the rest."
- "Add appropriate tests."
- "Use the existing pattern" without naming the file/line.
- A task changes files not listed in its scope.
- A verification command proves only one small piece but is used to claim the
  entire task.
