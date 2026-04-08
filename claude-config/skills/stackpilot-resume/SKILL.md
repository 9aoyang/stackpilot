---
name: stackpilot-resume
description: Resume an interrupted stackpilot sprint. Reads the plan file and git history to determine which tasks are done vs pending, then continues the sprint.
---

# Resume Sprint

Use this when a previous `/stackpilot` session was interrupted mid-sprint and you want to continue from where it left off.

## Step 1: Find the Plan

```bash
ls -t .stackpilot/plans/*.md 2>/dev/null | head -1
```

If no plan file exists, tell the user: "No plan found. Run `/stackpilot` to start a new feature."

Read the latest plan file and parse all `### TASK-` sections.

## Step 2: Determine Completed Tasks

```bash
git log --oneline --all -50
```

For each TASK in the plan:
- Search git log for commit messages containing the TASK ID (e.g., "TASK-001", "implement user model" — match on task title keywords too)
- Check if the task's `relevant_files` exist and have recent modifications
- If evidence of completion found → mark as **done**
- If no evidence → mark as **pending**

## Step 3: Check for Blockers

Read `.stackpilot/NEEDS_REVIEW.md`:
- If has unresolved content → present to user, resolve before continuing
- If empty → proceed

## Step 4: Show Status and Confirm

Present a task status table:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Sprint Resume — <plan name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  add user model         done (commit abc1234)
✅ TASK-002  add auth middleware     done (commit def5678)
⏳ TASK-003  payment integration     pending
⏳ TASK-004  write unit tests        pending
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Completed: 2/4  |  Remaining: 2
```

Ask:
> "Resume sprint from TASK-003?"
>
> A. Yes, continue coding
> B. Show me the plan details first
> C. Start fresh (re-run all tasks)

## Step 5: Execute

- **A** → Create TaskCreate entries for pending tasks only, then execute Run Sprint (from the main `/stackpilot` skill) starting from the first pending task
- **B** → Display the full plan, then ask again
- **C** → Create TaskCreate entries for ALL tasks, execute Run Sprint from the beginning
