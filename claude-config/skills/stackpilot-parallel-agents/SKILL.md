---
name: stackpilot-parallel-agents
description: Internal/default StackPilot parallel-dispatch gate. Trigger behind the StackPilot entry when there are two or more independent tasks, failures, research targets, or review domains that can be handled concurrently without shared state or file conflicts.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Parallel Agents

Use independent workers only when parallelism reduces wall time without
creating conflicting state.

## Hard Gates

- Do not parallelize tasks that edit the same files or depend on each other.
- Do not dispatch broad "fix everything" agents.
- Each worker gets scoped context, constraints, expected output, and verification
  requirements.
- The controller reviews every result and runs integration verification.
- A worker success report is not completion evidence.

## Process

1. **Group independent domains**

   Split by subsystem, test file, task id, or research target. If fixes may
   overlap, keep them sequential.

2. **Define worker contracts**

   Each worker prompt must include:

   - scope
   - files or domain
   - non-goals
   - verification command
   - required output format

3. **Dispatch concurrently**

   Use host-native subagents when available. In hosts without subagents, run the
   domains sequentially but keep the same scoped contracts.

4. **Integrate**

   For each worker:

   - inspect summary and diff
   - check for file conflicts
   - run the worker's verification

   After all workers finish, run full integration verification.

## Output Contract

```markdown
## Parallel Dispatch
| Worker | Scope | Files | Verify | Result |
|--------|-------|-------|--------|--------|

## Integration
- Conflict check:
- Full verify command:
- Result:
```

## Red Flags

- Multiple workers editing one shared module.
- Agents diagnosing related failures independently.
- Controller accepts summaries without reading diffs.
- No full-suite verification after integration.
