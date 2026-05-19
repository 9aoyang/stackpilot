# Workload 03 — Adversarial Gates

**Purpose:** Stress-test Sprint Finish Step 0.5 gates. 3 tasks, fixture deliberately includes traps that should trigger each of the three gates (criteria-not-green, CHANGELOG-missing-scope, Pattern-Candidates-pending).

**Expected outcome:** the `stackpilot` leg's Sprint Finish blocks merge with explicit gate violation messages. The `stackpilot-serial` leg does not block (criteria gate disabled, state.json disabled, Step 0.5 mostly silent).

## The 3 gate traps

### `missing-changelog` → Gate 2

The stub `sandbox/CHANGELOG.md` has an empty `## [Unreleased]` section. `user-responses.yml` does not include a "CHANGELOG" prompt response. None of the 3 tasks' `relevant_files` lists `CHANGELOG.md`. The stackpilot leg's per-task agents won't touch CHANGELOG, so commits will use conventional scopes (e.g. `feat(billing)`) but Unreleased stays empty. Gate 2 greps for the scope in Unreleased and finds nothing → blocks merge.

### `failing-criterion` → Gate 1

TASK-002's description has an intentional internal contradiction: "delete `src/billing/legacyCounter.ts` AND preserve all existing public exports of `invoiceNumbering.ts` unchanged". The criteria derived in Phase 3.6 will include both. sp-qa flags one as `fail` because deleting `legacyCounter.ts` forces removing its re-export from `invoiceNumbering.ts`. Gate 1 sees a `fail` row and blocks merge.

**IMPORTANT:** the contradiction must be preserved as authored — do NOT pre-resolve during spec authoring. The wording "preserve all existing public exports … unchanged" is intentional.

### `pending-pattern-candidate` → Gate 3 (warning, not blocking)

TASK-003 mandates a global singleton for the audit log. sp-qa flags this anti-pattern and surfaces it under `## Pattern Candidates`. Gate 3 counts these candidates and warns; does NOT block.

## Verdict input

- `gate_correctness` = triggered_gates / expected_gates (stackpilot leg only)
- For `stackpilot` leg: expected 3/3 (Gate 1 + Gate 2 fire as blockers, Gate 3 fires as warning)
- For `stackpilot-serial` leg: expected 0/3 or near-zero (gates disabled by config)
- `criteria_coverage_pct` will be < 100% on `stackpilot` leg due to the failing-criterion trap

## Sandbox layout

```
sandbox/
├── CLAUDE.md             # project rules — includes "no singletons" hint
├── CHANGELOG.md          # stub with empty Unreleased section
├── src/billing/
│   ├── rounding.ts       # TASK-001 target (does not yet exist as file in fixture? created by sp-dev)
│   ├── invoiceNumbering.ts
│   ├── legacyCounter.ts
│   ├── invoiceService.ts
│   └── auditLog.ts       # TASK-003 target
evaluator/
└── .gitkeep              # no closed-book functional check; verdict is gate_traps-based
```
