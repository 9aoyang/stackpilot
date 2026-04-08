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

## Step 4 — Execute choice, THEN cleanup

- **A**: Determine base branch, then `git merge`
- **B**: `git push -u origin <branch>` then create PR
- **C**: Do nothing
- **D**: Confirm once, then `git checkout <base-branch> && git branch -D <feature-branch>`

## Step 5 — Sprint Cleanup

Only after user's choice is executed:

```bash
printf "" > .stackpilot/NEEDS_REVIEW.md
```

Stop dev server if started: `kill <PID> 2>/dev/null`
