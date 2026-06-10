---
name: stackpilot-skill-authoring
description: Maintainer-only StackPilot skill-authoring gate. Trigger when adding, updating, or reviewing StackPilot skills so trigger scope, hard gates, progressive disclosure, tests, docs, and host neutrality are all verified.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Skill Authoring

Create and maintain StackPilot skills as product surfaces, not loose prompt
snippets.

## Hard Gates

- Every skill needs a clear trigger in `description`.
- The body must define gates and process, not generic encouragement.
- Keep host-neutral skills free of Claude Code-only tool assumptions.
- Add or update tests for routing, manifest exposure, and core invariants.
- Update README/architecture/CHANGELOG when the skill changes product behavior.

## Process

1. **Define trigger and boundary**

   State when the skill must be used, when it must not be used, and which host
   adapter or portable skill owns adjacent responsibilities.

2. **Write the skill**

   Include:

   - hard gates
   - process
   - output contract
   - red flags

   Put long examples or host-specific details in `references/` if needed.

3. **Wire routing**

   Update `stackpilot-bootstrap`, package contexts such as `GEMINI.md`, and
   hook allow-lists when the skill is a process gate.

4. **Test**

   Add structural tests and, when behavior matters, an executable regression
   test. Verify shell syntax, JSON manifests, and `git diff --check`.

5. **Document**

   Update README, architecture docs, `.stackpilot/ARCHITECTURE.md`, CHANGELOG,
   and `docs/sync.md` when the skill maps to an external protocol.

## Output Contract

```markdown
## Skill Change
- Skill:
- Trigger:
- Adjacent skills:
- Host-neutral: Yes / No

## Verification
- Tests:
- Docs:
- Routing:
```

## Red Flags

- A skill says "use when needed" without a concrete trigger.
- A portable skill names a host-only tool as mandatory.
- New skill exists but no bootstrap or docs route can discover it.
- Tests only check file existence, not the behavior the skill is meant to
  enforce.
