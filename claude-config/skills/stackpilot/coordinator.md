---
name: coordinator
description: Run the Stackpilot Coordinator. Processes NEEDS_REVIEW replies, checks for timeouts, dispatches pending tasks to specialist agents.
---

Run the Stackpilot Coordinator for the project in the current working directory.

Follow the coordinator-agent instructions exactly:
1. Process tasks/NEEDS_REVIEW.md (handle REPLY: lines, send notification if unresolved)
2. Check tasks/in-progress.yml for timed-out tasks (mark failed, append to NEEDS_REVIEW)
3. Dispatch pending tasks from tasks/backlog.yml up to worktree_limit
4. Apply dispatch rules: arch → architect-agent, dev → architect-agent first then dev-agent, qa → qa-agent, docs → docs-agent (each with correct --allowedTools flags)
5. Check for sprint completion (zero pending or in-progress tasks) and send completion notification
