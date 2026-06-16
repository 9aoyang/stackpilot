# Skill References

Skills that have been evaluated for StackPilot's methodology, agents, or
internal gates.

> **v2 note**: This file tracks source ideas and coverage decisions. It is not a
> cloning ledger. A referenced skill may contribute a gate, invariant, or test
> expectation without becoming a public StackPilot command. The product shape is
> still one StackPilot entry with default/on-demand internal routing.

| Skill | StackPilot Surface | Core Contribution | Status | Last Checked |
|-------|--------------------|-------------------|--------|--------------|
| brainstorming | SKILL.md | HARD-GATE before any code; explore→clarify one-at-a-time→2-3 approaches→spec→self-review→user gate before proceeding; Visual Companion (browser mockups); design-for-isolation principle; spec self-review with 4 checks; "Too Simple to Need a Design" anti-pattern (every project deserves a 30-second design pause, including Light tasks → mini-brainstorm in SKILL.md Light Feature path); explicit User Reviews Spec gate after self-review (Phase 3.7) | covered in adapter protocol | 2026-05-18 |
| writing-plans | SKILL.md | Bite-sized tasks (2-5 min), file structure map first, fully resolved task descriptions, plan self-review, type consistency check | covered in adapter protocol | 2026-04-08 |
| finishing-a-development-branch | SKILL.md (references/sprint-finish.md) | Verify tests → present 4 options (merge/PR/keep/discard) → execute → cleanup | covered in adapter protocol | 2026-04-08 |
| feature-dev:code-architect | architecture-review (internal portable gate) | Analyze existing patterns first; one decisive architecture choice; full implementation blueprint; multi-persona adversarial review for HIGH-risk tasks | covered as internal gate | 2026-04-08 |
| feature-dev:code-explorer | tdd-development (internal portable gate) | Locate entry point (file:line); trace call chain up and down; find similar implementations; confirm file list before writing | covered as internal gate | 2026-04-08 |
| feature-dev:code-reviewer | qa-12-dimensions (internal portable gate) | Based on git diff only; report only issues with confidence ≥ 80 with specific file:line evidence; Critical → flag, Important → fix directly if ≤ 5 lines | covered as internal gate | 2026-04-08 |
| autoresearch | tdd-development, qa-12-dimensions, architecture-review, SKILL.md, run-sprint.md, sprint-finish.md | Core concepts: git-as-memory; atomic change + stuck detection; 12-dimension scenario testing; multi-persona adversarial review; Optimize Sprint mode with Guard command; evals-style plateau/trend analysis; bounded retry/saturation signals; `handoff.json` as a compact resume contract | covered as internal gates and sprint data artifacts | 2026-06-16 |
| lewislulu/llm-wiki-skill (Karpathy LLM Wiki pattern) | `.stackpilot/feedback/open`, `.stackpilot/feedback/resolved`, sprint-finish.md | Audit feedback inbox: external/human feedback lands as open Markdown files, is never silently ignored, gets summarized before finish decisions, and moves to `resolved/` only after a `# Resolution` section records evidence and disposition | adapted as feedback inbox, not as a wiki renderer | 2026-06-16 |
| superpowers:systematic-debugging | systematic-debugging (internal portable gate) | 4-phase root cause investigation (observe→trace→hypothesize→fix); red flag detection; architecture check after 3 failed fixes | covered as internal gate | 2026-04-08 |
| superpowers:test-driven-development | tdd-development (internal portable gate) | Rationalization blockers: 7 common excuses explicitly countered; "delete and start over" rule for code written before test | covered as internal gate | 2026-04-08 |
| superpowers:writing-plans | stackpilot-planning (internal portable gate) | Exact executable plans: file map first, fully resolved task descriptions, task-sized steps, TDD steps, verification commands, traceability self-review | covered as internal gate | 2026-06-10 |
| superpowers:using-git-worktrees | stackpilot-workspace (internal portable gate) | Detect existing isolation first; prefer host-native workspaces; git worktree fallback only after ignore verification; setup and baseline verification before implementation | covered as internal gate | 2026-06-10 |
| superpowers:executing-plans | stackpilot-plan-execution (internal portable gate) | Execute an existing plan task-by-task, stop on blockers, preserve review/verification gates, then route to finish workflow | covered as internal gate | 2026-06-10 |
| superpowers:subagent-driven-development | stackpilot-plan-execution (internal portable gate) | Fresh scoped worker per task when host supports subagents; spec-compliance review before code-quality review; controller verifies evidence before advancing | covered as internal gate | 2026-06-10 |
| superpowers:dispatching-parallel-agents | stackpilot-parallel-agents (internal portable gate) | Dispatch one scoped worker per independent domain; verify independence, inspect each result, then run integration verification | covered as internal gate | 2026-06-10 |
| superpowers:receiving-code-review | stackpilot-review-response (internal portable gate) | Parse review feedback into items, clarify unclear points before coding, verify suggestions against codebase reality, implement accepted items with tests | covered as internal gate | 2026-06-10 |
| superpowers:verification-before-completion | stackpilot-completion-verification (internal portable gate) | Evidence-before-claims finish gate: identify claim, run fresh proving command, inspect output, verify requirements before saying complete/fixed/passing | covered as internal gate | 2026-06-10 |
| superpowers:writing-skills | stackpilot-skill-authoring (maintainer-only gate) | Skill changes require concrete trigger scope, host-neutral body, routing/docs/test updates, and verification before claim | covered as maintainer gate | 2026-06-10 |
