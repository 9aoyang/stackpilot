# Sprint Finish

Run after all tasks are done. Confirms tests pass, optionally starts dev server for preview, then presents merge/PR/keep/discard options.

## Step 1 — Detect dev server command

Auto-detect from project files. Only detect when there is a clear web server signal.

```
Check in order, use the first match:
1. package.json exists → read scripts:
   a. Has "dev" script AND dependencies include vite/next/nuxt/webpack/remix/astro/svelte → npm run dev
   b. Has "dev" script with no web framework signal → skip
   c. No "dev" script → skip
2. manage.py exists + contains "django" → python manage.py runserver
3. Gemfile exists + config/routes.rb exists → bundle exec rails server
4. No match → skip preview, go directly to Step 3
```

Do NOT blindly run `cargo run`, `go run .`, `python app.py`, or `npm start`.

## Step 2 — Start server and present preview URL

1. Start detected command in background, capture PID: `<command> & echo $!`
2. Wait for output containing `http://localhost:` (timeout 15s)
3. If no URL detected → kill process, skip preview
4. Present to user:

> "Sprint complete. All tests passing. Dev server running at:"
>
> `http://localhost:XXXX`  (PID: XXXX)
>
> "Please review in your browser, then tell me how to proceed."

**Wait for user to finish reviewing.**

## Step 3 — Present options

> A. Merge into base branch
> B. Push and create a PR
> C. Leave as-is (handle later)
> D. Discard all changes (destructive — confirm first)

## Step 4 — Pre-merge commits on feature branch (A and B)

Commit all housekeeping on the feature branch **before** touching the base branch. These commits will be squashed away and never appear on main.

**4a. Architecture Memory Check:**

> "需要更新 `.stackpilot/ARCHITECTURE.md` 吗？（路由、数据库、API、产品设计有变化就建议更新）"
> A. 要  B. 不用

- **A**: Update `.stackpilot/ARCHITECTURE.md` in-place, then:
  ```bash
  git add .stackpilot/ARCHITECTURE.md
  git commit -m "docs(arch): update after sprint"
  ```
- **B**: Skip silently

**4b. Clear sprint artifacts:**

```bash
printf "" > .stackpilot/NEEDS_REVIEW.md
rm -f .stackpilot/plans/*.md 2>/dev/null
rm -f .stackpilot/specs/*.md 2>/dev/null
git add .stackpilot/
git commit -m "chore(stackpilot): clear sprint artifacts"
```

## Step 5 — Execute choice

- **A**: Squash merge — produces exactly one commit on base branch:
  ```bash
  git checkout <base-branch>
  git merge --squash <feature-branch>
  git commit -m "<descriptive summary of the sprint>"
  git branch -d <feature-branch>
  ```
- **B**: Push and create PR (squash merge policy enforced on the PR, not locally):
  ```bash
  git push -u origin <feature-branch>
  # create PR — title becomes the squash commit message on merge
  ```
- **C**: Do nothing
- **D**: Confirm once, then `git checkout <base-branch> && git branch -D <feature-branch>`

## Step 6 — Stop dev server

```bash
kill <PID> 2>/dev/null
```
