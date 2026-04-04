# Skill References

Skills that have been evaluated and/or inlined into stackpilot agents.

| Skill | Inline Target | Core Contribution | Status | Last Checked |
|-------|--------------|-------------------|--------|--------------|
| brainstorming | SKILL.md | HARD-GATE before any code; explore→clarify one-at-a-time→2-3 approaches→spec→self-review→user gate before proceeding | inlined | 2026-04-04 |
| writing-plans | SKILL.md | Bite-sized tasks (2-5 min), file structure map first, zero placeholders allowed, plan self-review before commit | inlined | 2026-04-04 |
| finishing-a-development-branch | SKILL.md | Verify tests pass first; present 4 options (merge/PR/keep/discard); execute chosen option | inlined | 2026-04-04 |
| feature-dev:code-architect | sp-architect.md | Analyze existing patterns first (not assumptions); one decisive architecture choice (not options list); full implementation blueprint with build sequence | inlined | 2026-04-04 |
| feature-dev:code-explorer | sp-dev.md | Locate entry point (file:line); trace call chain up and down; find similar existing implementations; confirm file list before writing | inlined | 2026-04-04 |
| feature-dev:code-reviewer | sp-qa.md | Based on git diff only; report only issues with confidence ≥ 80 with specific file:line evidence; Critical → NEEDS_REVIEW.md, Important → fix directly if ≤ 5 lines | inlined | 2026-04-04 |
| autoresearch (uditgoenka/autoresearch) | sp-dev.md, sp-qa.md, sp-architect.md, SKILL.md | Four concepts inlined: (1) git-as-memory — read `git log` before starting to avoid repeating failed approaches; (2) atomic change + stuck detection — one logical change per fix round, switch strategy if round 2 error == round 1 error; (3) 12-dimension scenario testing matrix in sp-qa; (4) multi-persona adversarial review (Security/Performance/Reliability) for HIGH-risk architect tasks; (5) Optimize Sprint mode in SKILL.md — Goal+Scope+Metric+Verify four-parameter loop with TSV logging and git revert on regression | inlined | 2026-04-04 |
