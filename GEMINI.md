# StackPilot Gemini Extension

You have StackPilot. Treat StackPilot as the user entry. Before non-trivial
coding work, route through the relevant internal StackPilot gate before reading
files, asking clarifying questions, editing code, running commands, or claiming
completion.

## Routing

- Feature work, behavior changes, or multi-file requests: internally activate
  `stackpilot-methodology` first.
- Existing spec/design that needs an implementation plan: internally activate
  `stackpilot-planning`.
- Existing spec/plan execution: internally activate `stackpilot-plan-execution`.
- Two or more independent tasks/failures/research targets that can safely run
  concurrently: internally activate `stackpilot-parallel-agents`.
- Non-trivial implementation setup: internally activate `stackpilot-workspace`
  unless the host already provides managed isolation or the user explicitly
  chose in-place work.
- Bug fixes, failing tests, or unexpected behavior: internally activate
  `systematic-debugging` first.
- Any production code change: internally activate `tdd-development` before
  writing code.
- QA, review, or test coverage work: internally activate `qa-12-dimensions`.
- Incoming human or external code-review feedback: internally activate
  `stackpilot-review-response`.
- Architecture decisions or shared data structures: internally activate
  `architecture-review`.
- Completion, fixed, passing, ready-to-merge, or ready-for-PR claims: internally
  activate `stackpilot-completion-verification` first.
- Adding or updating StackPilot skills: internally activate
  `stackpilot-skill-authoring`.

`stackpilot-methodology` is the portable core behind the StackPilot route.
`/stackpilot` is the Claude Code host adapter and should not be copied literally
in Gemini; implement the same gates with Gemini-native tools and keep the user
experience as one StackPilot entry.

## Gemini Tool Mapping

| Skill references | Gemini CLI equivalent |
|-----------------|-----------------------|
| `Read` | `read_file` |
| `Write` | `write_file` |
| `Edit` | `replace` |
| `Bash` | `run_shell_command` |
| `Grep` | `grep_search` |
| `Glob` | `glob` |
| `TodoWrite` | `write_todos` |
| `Skill` | `activate_skill` |
| `Task` / named subagent | `@generalist` with the filled prompt, or a host-native named agent |

Do not weaken the StackPilot gates because a Claude Code-specific tool is
missing. Degrade the mechanics, not the method.
