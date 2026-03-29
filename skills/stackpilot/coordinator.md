---
name: coordinator
description: Run the Stackpilot Coordinator. Processes NEEDS_REVIEW replies, checks for timeouts, dispatches pending tasks to specialist agents.
---

Run the Stackpilot Coordinator for the project in the current working directory.

Follow the coordinator-agent instructions exactly:
1. Process tasks/NEEDS_REVIEW.md (handle REPLY: lines, send notification if unresolved)
2. Check tasks/in-progress.yml for timed-out tasks
3. Dispatch pending tasks from tasks/backlog.yml up to worktree_limit
4. Send sprint-complete notification if all tasks are done
