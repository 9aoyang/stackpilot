---
name: stackpilot-workspace
description: Internal/default StackPilot workspace gate. Trigger behind the StackPilot entry before executing implementation plans or non-trivial feature work to detect existing isolation, prefer host-native workspaces, fall back to git worktrees, run setup, and verify a clean baseline.
license: Apache-2.0
metadata:
  author: stackpilot
  version: "1.0.0"
---

# StackPilot Workspace

Ensure implementation happens in an isolated, verified workspace whenever the
host can support it. Prefer host-native workspace tools; use git worktrees only
as a fallback.

## Hard Gates

- Detect existing isolation before creating anything.
- Do not create a git worktree if the host already provides managed workspaces.
- Do not create a project-local worktree unless its parent directory is ignored.
- Do not proceed from a failing baseline without reporting the evidence and
  getting an explicit decision.
- Do not clean up a workspace you did not create or cannot prove you own.

## Process

1. **Detect isolation**

   ```bash
   GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
   GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
   BRANCH=$(git branch --show-current)
   git rev-parse --show-superproject-working-tree 2>/dev/null
   ```

   `GIT_DIR != GIT_COMMON` means linked worktree unless the superproject check
   shows you are inside a submodule.

2. **Prefer host-native isolation**

   If the host provides a workspace/worktree tool, use it. Native tools own
   placement, branch metadata, cleanup, and UI state.

3. **Git worktree fallback**

   If no native tool exists and isolation is needed:

   - Reuse existing `.worktrees/` or `worktrees/` when present.
   - Otherwise default to `.worktrees/` at project root.
   - Verify the chosen directory is ignored with `git check-ignore`.
   - Add and commit the ignore rule before creating the worktree if needed.

   ```bash
   git worktree add "$path" -b "$branch_name"
   ```

4. **Project setup**

   Run the setup command that matches the repo:

   - Node: `npm install` / `pnpm install` / `yarn install`
   - Python: `pip install -r requirements.txt` / `poetry install`
   - Go: `go mod download`
   - Rust: `cargo build`

   Skip setup only when the project has no recognized dependency manifest.

5. **Baseline verification**

   Run the configured test command or a detected equivalent. If it fails, stop
   and report the exact command, exit status, and the failing output summary.

## Output Contract

```markdown
## Workspace
- Mode: existing-isolated | host-native | git-worktree | in-place
- Path:
- Branch:
- Owner: host | stackpilot | unknown

## Setup
- Command:
- Result: PASS | FAIL | N/A

## Baseline
- Command:
- Result: PASS | FAIL | N/A
- Evidence:
```

## Red Flags

- Creating nested worktrees.
- Using git worktree when the host can create a managed workspace.
- Skipping baseline tests because "the change is small".
- Treating a detached HEAD as a normal branch.
- Deleting a workspace based on path guesses rather than provenance.
