# Skill References

Skills that have been evaluated and/or inlined into stackpilot agents.

| Skill | Inline Target | Core Contribution | Status | Last Checked |
|-------|--------------|-------------------|--------|--------------|
| brainstorming | SKILL.md | HARD-GATE before any code; explore→clarify one-at-a-time→2-3 approaches→spec→self-review→user gate before proceeding. Also: Visual Companion (browser mockups), large project decomposition gate, design-for-isolation principle (inlined), spec self-review with 4 checks (placeholder/consistency/scope/ambiguity), user review gate after spec | inlined | 2026-04-07 |
| writing-plans | SKILL.md | Bite-sized tasks (2-5 min), file structure map first, zero placeholders allowed, plan self-review before commit. Also: plan document header with agentic worker sub-skill reference, scope check for multi-subsystem specs, type consistency check in self-review (inlined), execution handoff (subagent vs inline) | inlined | 2026-04-07 |
| finishing-a-development-branch | SKILL.md | Verify tests pass first; present 4 options (merge/PR/keep/discard); execute chosen option. Also: determine base branch step, worktree cleanup logic (Options 1/4 cleanup, 2/3 keep), integration docs (called by subagent-driven-dev and executing-plans) | inlined | 2026-04-07 |
| feature-dev:code-architect | sp-architect.md | Analyze existing patterns first (not assumptions); one decisive architecture choice (not options list); full implementation blueprint with build sequence | inlined | 2026-04-07 |
| feature-dev:code-explorer | sp-dev.md | Locate entry point (file:line); trace call chain up and down; find similar existing implementations; confirm file list before writing | inlined | 2026-04-07 |
| feature-dev:code-reviewer | sp-qa.md | Based on git diff only; report only issues with confidence ≥ 80 with specific file:line evidence; Critical → NEEDS_REVIEW.md, Important → fix directly if ≤ 5 lines | inlined | 2026-04-07 |
| autoresearch (uditgoenka/autoresearch) | sp-dev.md, sp-qa.md, sp-architect.md, SKILL.md | Five concepts inlined: (1) git-as-memory; (2) atomic change + stuck detection; (3) 12-dimension scenario testing matrix in sp-qa; (4) multi-persona adversarial review for HIGH-risk architect tasks; (5) Optimize Sprint mode with Guard command. New upstream additions not inlined: /autoresearch:ship (8-phase universal shipping), /autoresearch:learn (docs engine), Interactive Setup Gate with batched AskUserQuestion, post-completion support prompt | inlined | 2026-04-07 |
