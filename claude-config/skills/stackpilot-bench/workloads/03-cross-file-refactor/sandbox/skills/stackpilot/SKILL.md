---
name: stackpilot
description: Orchestrates plan → dev → qa → docs sprint pipeline.
model: claude-opus-4-5
---

# /stackpilot Skill

Runs a full sprint: architect, dev, qa, docs. Each stage dispatches a sub-agent.

## Pipeline Overview

1. **sp-architect** — breaks the request into tasks.
2. **sp-dev** — implements each task using TDD.
3. **sp-qa** — reviews the diff using the four-stage methodology; Stage 4 Consistency Audit ensures no cross-file references are left stale.
4. **sp-docs** — updates documentation to reflect changes.

## Invocation

```
/stackpilot <feature description>
```

The skill reads `.stackpilot/plans/` for existing plans before creating a new one.
