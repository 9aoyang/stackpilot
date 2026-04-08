# Git Hooks (Removed in v2)

Stackpilot v1 used git hooks to trigger agents automatically:
- `pre-commit` — validated spec/plan completeness before commit
- `post-commit` — triggered sp-pm to decompose specs into tasks
- `post-checkout` — triggered sp-coordinator to dispatch pending tasks

In v2, these are replaced by:
- **Spec/plan validation** — inline in the `/stackpilot` skill's Phase 3/4 auto-verify loops
- **Task decomposition** — handled directly by the skill (no separate PM agent)
- **Agent dispatch** — handled by the skill using Claude Code's native Agent tool

No hooks need to be installed.
