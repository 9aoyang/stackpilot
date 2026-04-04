---
name: skill-refs
description: Manage external skill references for stackpilot. Use /skill-refs add to extract and track a new skill, /skill-refs check to detect updates in previously referenced skills.
---

# Skill Refs

Internal skill for tracking and syncing external skills that have been referenced and inlined into stackpilot agents or SKILL.md.

Triggered explicitly via slash commands:
- `/skill-refs add` — Mode A: add and extract a new skill
- `/skill-refs check` — Mode B: check for updates in all tracked skills

---

## Mode A: Add (`/skill-refs add`)

**Step 1: Identify the source**

Ask the user (via AskUserQuestion):
> "What skill do you want to add? Provide a URL (to the plugin page or raw skill file) or a local skill name (e.g. `brainstorming` or `feature-dev:code-reviewer`)."

**Step 2: Fetch/read the skill content**

- If URL → fetch the page content and extract the skill protocol
- If local skill name:
  - Single skill: read `~/.claude/skills/<name>/SKILL.md`
  - Namespaced skill (e.g. `feature-dev:code-reviewer`): read `~/.claude/skills/feature-dev/agents/code-reviewer.md` or equivalent path

**Step 3: Extract core protocol**

Summarize in 2–3 sentences the most important design decisions and logic from the skill. Focus on:
- What is the key constraint or gate the skill enforces?
- What is the core workflow or sequence?
- What is the most non-obvious thing about how it works?

**Step 4: Determine inline target**

Decide which stackpilot file is the best home for this protocol:
- `sp-architect.md` — architecture review and blueprint
- `sp-dev.md` — implementation and codebase exploration
- `sp-qa.md` — code review and test writing
- `sp-docs.md` — documentation
- `SKILL.md` — brainstorming, planning, or finishing workflows

**Step 5: Update tracking table**

Append a row to `docs/skill-refs.md` (create the file if it doesn't exist):

```markdown
| Skill | Inline Target | Core Contribution | Status | Last Checked |
|-------|--------------|-------------------|--------|--------------|
| <name> | <file> | <2-3 sentence summary> | evaluated | YYYY-MM-DD |
```

**Step 6: Give recommendation**

Output:
- Why this skill is worth inlining (or why it isn't)
- Estimated scope of change (which sections in the target file, roughly how many lines)
- Ask: "Should I inline this now, or just track it for later?"

If user says yes → make the change to the target file, update `docs/skill-refs.md` status to `inlined`.

---

## Mode B: Check (`/skill-refs check`)

**Step 1: Read tracking table**

Read `docs/skill-refs.md`. Find all rows where status is not `removed`.

**Step 2: Re-read each skill**

For each tracked skill, re-read the source file (same path resolution as Mode A Step 2).

**Step 3: Compare against recorded core contribution**

For each skill, determine if there is new logic or protocol that wasn't captured in the "Core Contribution" summary.

Focus on:
- New constraints or gates added
- Workflow steps added or reordered
- New edge-case handling
- Significant behavior changes

**Step 4: Report differences**

For each skill:
- No meaningful change → output `✅ <skill-name>: no changes` and update "Last Checked" date
- New logic found → output `⚠️ <skill-name>: new content detected` with a bullet list of what changed

**Step 5: Sync if user approves**

For each skill flagged with `⚠️`, ask the user:
> "Do you want to sync these changes into `<inline-target>`?"

If yes → update the target file with the new logic, update the "Core Contribution" summary and "Last Checked" date in `docs/skill-refs.md`.

---

## Tracking File Format (`docs/skill-refs.md`)

```markdown
# Skill References

Skills that have been evaluated and/or inlined into stackpilot agents.

| Skill | Inline Target | Core Contribution | Status | Last Checked |
|-------|--------------|-------------------|--------|--------------|
| brainstorming | SKILL.md | HARD-GATE before any code; explore→clarify one-at-a-time→2-3 approaches→spec→self-review→user gate before proceeding | inlined | YYYY-MM-DD |
| writing-plans | SKILL.md | Bite-sized tasks (2-5 min), file structure map first, zero placeholders allowed, plan self-review before commit | inlined | YYYY-MM-DD |
| finishing-a-development-branch | SKILL.md | Verify tests pass first; present 4 options (merge/PR/keep/discard); execute chosen option | inlined | YYYY-MM-DD |
| feature-dev:code-architect | sp-architect.md | Analyze existing patterns first (not assumptions); one decisive architecture choice (not options list); full implementation blueprint with build sequence | inlined | YYYY-MM-DD |
| feature-dev:code-explorer | sp-dev.md | Locate entry point (file:line); trace call chain up and down; find similar existing implementations; confirm file list before writing | inlined | YYYY-MM-DD |
| feature-dev:code-reviewer | sp-qa.md | Based on git diff only; report only issues with confidence ≥ 80 with specific file:line evidence; Critical → NEEDS_REVIEW.md, Important → fix directly if ≤ 5 lines | inlined | YYYY-MM-DD |
```
