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

## Plan

For each dimension, check whether the **tasks** cover each scenario:

| # | Dimension | Check against plan |
|---|-----------|-------------------|
| 1 | **Happy path** | Is there a task for the primary success flow? |
| 2 | **Error / failure** | Are error handling tasks included? |
| 3 | **Edge case** | Do tasks cover boundary/edge conditions? |
| 4 | **Abuse / invalid** | Are input validation tasks present? |
| 5 | **Scale** | Are performance-related tasks included if needed? |
| 6 | **Concurrent** | Are concurrency-safe implementations planned? |
| 7 | **Temporal** | Are timeout/retry tasks included if needed? |
| 8 | **Data variation** | Do tasks handle multiple input shapes? |
| 9 | **Permission** | Are auth/permission tasks included? |
| 10 | **Integration** | Are integration/contract tasks present? |
| 11 | **Recovery** | Are rollback/cleanup tasks included? |
| 12 | **State transition** | Do tasks verify state before/after? |
