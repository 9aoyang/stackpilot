# Skill References

Skills that have been evaluated and/or inlined into stackpilot agents and portable skills.

> **v2 note**: In v1, external skill protocols were inlined into agent files (sp-dev.md, sp-qa.md, etc.). In v2, methodologies are extracted as standalone portable Agent Skills (tdd-development, qa-12-dimensions, architecture-review, systematic-debugging). The orchestration skill (SKILL.md) references these portable skills by name when dispatching agents.

| Skill | Inline Target (v2) | Core Contribution | Status | Last Checked |
|-------|-------------------|-------------------|--------|--------------|
| brainstorming | SKILL.md | HARD-GATE before any code; explore→clarify one-at-a-time→2-3 approaches→spec→self-review→user gate before proceeding; Visual Companion (browser mockups); design-for-isolation principle; spec self-review with 4 checks; "Too Simple to Need a Design" anti-pattern (every project deserves a 30-second design pause, including Light tasks → mini-brainstorm in SKILL.md Light Feature path); explicit User Reviews Spec gate after self-review (Phase 3.7) | inlined | 2026-05-18 |
| writing-plans | SKILL.md | Bite-sized tasks (2-5 min), file structure map first, zero placeholders allowed, plan self-review, type consistency check | inlined | 2026-04-08 |
| finishing-a-development-branch | SKILL.md (references/sprint-finish.md) | Verify tests → present 4 options (merge/PR/keep/discard) → execute → cleanup | inlined | 2026-04-08 |
| feature-dev:code-architect | architecture-review (portable skill) | Analyze existing patterns first; one decisive architecture choice; full implementation blueprint; multi-persona adversarial review for HIGH-risk tasks | extracted | 2026-04-08 |
| feature-dev:code-explorer | tdd-development (portable skill) | Locate entry point (file:line); trace call chain up and down; find similar implementations; confirm file list before writing | extracted | 2026-04-08 |
| feature-dev:code-reviewer | qa-12-dimensions (portable skill) | Based on git diff only; report only issues with confidence ≥ 80 with specific file:line evidence; Critical → flag, Important → fix directly if ≤ 5 lines | extracted | 2026-04-08 |
| autoresearch | tdd-development, qa-12-dimensions, architecture-review, SKILL.md | Five concepts: (1) git-as-memory; (2) atomic change + stuck detection; (3) 12-dimension scenario testing; (4) multi-persona adversarial review; (5) Optimize Sprint mode with Guard command | extracted | 2026-04-08 |
| superpowers:systematic-debugging | systematic-debugging (portable skill) | 4-phase root cause investigation (observe→trace→hypothesize→fix); red flag detection; architecture check after 3 failed fixes | extracted | 2026-04-08 |
| superpowers:test-driven-development | tdd-development (portable skill) | Rationalization blockers: 7 common excuses explicitly countered; "delete and start over" rule for code written before test | extracted | 2026-04-08 |
