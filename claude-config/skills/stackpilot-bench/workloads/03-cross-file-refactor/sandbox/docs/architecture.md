# Architecture — stackpilot Agent Pipeline

## Agent Pipeline

```
/stackpilot
  ├── sp-architect   (task decomposition)
  ├── sp-dev         (TDD implementation)
  ├── sp-qa          (4-stage review)
  │     ├── Stage 1 Functional Review
  │     ├── Stage 2 Code Quality Review
  │     ├── Stage 3 Security Review
  │     └── Stage 4 Consistency Audit
  └── sp-docs        (documentation sync)
```

## Key Invariants

- Each stage gate must pass before the next agent is dispatched.
- Stage 4 Consistency Audit must cover every file touched by the diff.
- No merge to main without a clean sp-qa report.
