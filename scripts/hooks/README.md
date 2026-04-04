# Stackpilot Git Hooks

These hook templates are copied to `.git/hooks/` by `stackpilot init`.

## Manual install (without stackpilot init)

```bash
cp scripts/hooks/post-checkout.sh .git/hooks/post-checkout
cp scripts/hooks/post-commit.sh .git/hooks/post-commit
chmod +x .git/hooks/post-checkout .git/hooks/post-commit
```

## What they do

- **post-checkout**: Triggers the Coordinator when you switch branches (only runs when `.stackpilot/` exists)
- **post-commit**: Triggers the PM Agent when a new `docs/specs/*.md` file is committed
