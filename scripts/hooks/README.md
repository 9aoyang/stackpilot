# Git Hooks

## pre-merge-commit

Blocks non-squash merges into main/master. `git merge --squash` doesn't create a merge commit, so this hook won't fire. Any other merge type (--no-ff, fast-forward merge commit) on main is rejected.

Bypass: `STACKPILOT_ALLOW_MERGE=1 git merge ...`

Installed by `scripts/init.sh` into the target project's `.git/hooks/`.
