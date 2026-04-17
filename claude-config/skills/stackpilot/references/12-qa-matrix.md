# 12-QA Scenario Coverage Matrix

Used by SKILL.md Phase 3.5 (Spec review) and Phase 4.5 (Plan review).

## Spec

For each dimension, check whether the spec adequately addresses it — mark as ✅ covered, ⚠️ partially covered, ❌ missing, or N/A:

| # | Dimension | Check against spec |
|---|-----------|-------------------|
| 1 | **Happy path** | Is the primary success flow clearly defined? |
| 2 | **Error / failure** | Are error cases and failure modes specified? |
| 3 | **Edge case** | Are boundary values and limits addressed? |
| 4 | **Abuse / invalid** | Are invalid inputs and misuse scenarios covered? |
| 5 | **Scale** | Are performance/scale considerations mentioned? |
| 6 | **Concurrent** | Are race conditions or parallel access addressed? |
| 7 | **Temporal** | Are timeouts, retries, ordering dependencies covered? |
| 8 | **Data variation** | Are different valid input shapes considered? |
| 9 | **Permission** | Are auth/access control requirements defined? |
| 10 | **Integration** | Are integration points and contracts specified? |
| 11 | **Recovery** | Is partial failure recovery behavior defined? |
| 12 | **State transition** | Are before/after states clearly described? |

## Plan (traceability check, not re-review)

Spec 12-QA already evaluated all 12 dimensions. Plan review's job is narrower: **verify scope alignment between spec and plan**. Do not re-run the 12-dimension scan — that's stackpilot asking Claude to re-derive the same conclusions it just reached.

Two checks only:

1. **Forward trace**: every spec dimension marked ✅ / ⚠️ must have at least one corresponding task in the plan. Missing → add a task.
2. **Reverse trace**: every plan task must point back to a specific spec requirement or a dimension flagged during spec 12-QA. Orphan task → scope creep, remove it.

Output: a two-column table (spec item → task ID) and any gaps in either direction. If both sides trace clean, plan review passes.
