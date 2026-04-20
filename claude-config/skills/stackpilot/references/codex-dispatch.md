# Codex Dispatch Protocol

Use this reference when `/stackpilot` is running inside Codex.

## Runtime mapping

| Stackpilot concept | Codex primitive |
|---|---|
| TaskCreate / TaskUpdate | `update_plan` |
| sp-architect | named `sp-architect` if available, otherwise `explorer` with the architect prompt |
| sp-dev | named `sp-dev` if available, otherwise `worker` with explicit file ownership |
| sp-qa | named `sp-qa` if available, otherwise `worker` with QA-only ownership |
| sp-docs | named `sp-docs` if available, otherwise `worker` with docs-only ownership |

## Agent prompt loading

Load role prompts from the first existing location:

1. `$STACKPILOT_DIR/codex-config/agents/sp-<role>.md`
2. `$HOME/.stackpilot/codex-config/agents/sp-<role>.md`
3. `claude-config/agents/sp-<role>.md` as a last-resort compatibility fallback

Do not install a separate Codex-only `stackpilot` skill. The shared
`stackpilot/SKILL.md` is synchronized by skillshare to every target.

## Delegation rules

- `sp-architect`: delegate to a named `sp-architect` agent if available;
  otherwise use an `explorer` subagent with the full architect prompt pasted at
  the top of the task. It must be read-only.
- `sp-dev`: delegate to a named `sp-dev` agent if available; otherwise use a
  `worker` subagent. Assign ownership of the relevant files and tell it it is
  not alone in the codebase.
- `sp-qa`: delegate to a named `sp-qa` agent if available; otherwise use a
  `worker` subagent with QA-only ownership. It may write tests and small scoped
  fixes only.
- `sp-docs`: delegate to a named `sp-docs` agent if available; otherwise use a
  `worker` subagent with documentation-only ownership.

Only wait on a subagent when its result is needed for the next critical-path
step. While a worker runs, do non-overlapping local work.

## Prompt construction

Every delegated prompt must include:

- The full role prompt.
- Task ID, title, description, complexity, type, dependencies, and
  `relevant_files`.
- Current branch and `git status --porcelain`.
- `stackpilot.config.yml` QA command.
- Relevant excerpts from `.stackpilot/ARCHITECTURE.md`.
- Architecture review output for sp-dev, if available.
- Dev completion report for sp-qa.

## Worker ownership wording

For code-changing workers, include this sentence:

> You are not alone in the codebase. Do not revert or overwrite edits made by
> others; adapt your implementation around them. Your write ownership is:
> `<paths>`.

## Status tracking

Use `update_plan` for the visible task list. Keep exactly one task
`in_progress`. Mark a task `completed` only after dev and required QA pass.

## Codex execution contract

Codex must not treat `/stackpilot` as a style hint. A Codex Stackpilot run is
valid only when it produces auditable phase evidence and obeys the same
quality gates as the Claude Code agent pipeline.

For every standard-or-higher task, create or update these artifacts in the
task's allowed working directory:

- `.stackpilot-bench/architect.md` — architecture decision, rejected
  alternatives, relevant files, risks, and the implementation boundary.
- `.stackpilot-bench/dev-report.md` — files changed, behavior implemented,
  assumptions, and verification commands attempted.
- `.stackpilot-bench/qa-report.md` — QA verdict, findings, exact commands
  run, and whether fixes were required.

If a benchmark or caller provides a different artifact directory, use that
directory but keep the same filenames: `architect.md`, `dev-report.md`, and
`qa-report.md`.

The QA phase must inspect the final diff, not just summarize the implementation.
If QA finds a `[CRITICAL]` issue, Codex must run one materially scoped fix loop,
then update `dev-report.md` and `qa-report.md` with the new result. If the issue
remains after that loop, leave the implementation in place but mark
`qa-report.md` with `[CRITICAL]` and explain the blocker.

If these artifacts are missing, empty, or only contain generic prose unrelated
to the diff, the run is `orchestration_invalid`; consumers must not score it as
a normal Stackpilot result.

## Result handling

- `[ESCALATION]`: stop and present the decision.
- `[SOFT-BLOCKED]`: retry only with a materially different approach, up to 3
  total attempts.
- `[CRITICAL]`: stop and present the QA blocker.
- PASS: continue to the next task.
