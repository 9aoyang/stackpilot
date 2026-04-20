# W02 — Search migration, no downtime

An online backend swap. The sandbox is a ~13-file Node/TypeScript search
service already serving live traffic on `/api/search` via Postgres
`ILIKE`. The task: migrate to Meilisearch without downtime.

## Why this workload matters

v2 workloads (the earlier 01 / 02 / 03) were deliberately clear-cut and
over-engineering-dominated — they caught "adds a cache nobody asked for"
but not "ships a migration that drops live search for an hour". This
workload targets exactly the situation where the `/stackpilot`
**architect** phase should earn its keep: a task whose happy path is
easy to type (`replace ILIKE with meili.search`) but whose *correct*
answer demands enumerating dual-write windows, backfill order, rollback
paths, and consistency checks.

A zero-shot agent tends to delete the ILIKE code, swap in a Meilisearch
client, declare victory. That version:

- starts with an empty index — existing 2.4M docs are invisible
- has no way to roll back without a redeploy
- writes only to Meilisearch (or only to pg) during the cutover window
- never proves the two backends agree on the same query

A correctly-architected answer has, *at minimum*:

1. **Dual-write** (or trigger/mirror) so both stores stay in sync during
   the migration window.
2. **Backfill** (`src/jobs/indexer.ts` or a sibling) that pushes
   existing Postgres rows into Meilisearch *before* cutover.
3. **Rollback flag** — env var like `SEARCH_BACKEND=pg|meili` (or
   equivalent) so ops can route back to ILIKE without a redeploy.
4. **Consistency test** — at least one test that runs the same query
   through both backends and asserts they return the same IDs.
5. **Response shape preserved** — `{ results: Document[], total: number }`
   is untouched; no wrapping in `data` / `payload` / etc.

## Traps (15)

Correctness (migration hazards):

- `trap-01-no-dual-write` — writes go to only one backend during the window
- `trap-02-no-backfill` — no indexer code; Meili starts empty
- `trap-03-no-rollback-flag` — no env var / flag to route back to ILIKE
- `trap-04-response-shape-change` — `{results, total}` renamed or nested
- `trap-09-dropped-pg-table` — migration drops / truncates `documents`
- `trap-10-synchronous-reindex-in-request` — indexing inline on search / write
- `trap-11-no-consistency-test` — no parity test between backends
- `trap-12-hardcoded-meili-url` — `http://localhost:7700` literal in source
- `trap-14-breaking-existing-test` — deleted / skipped `search.test.ts`
- `trap-15-no-ambiguity-surfaced` — plan did not list any real ambiguity

Over-engineering:

- `trap-05-unrequested-graphql` — added a GraphQL layer
- `trap-06-unrequested-elasticsearch` — added ES alongside Meilisearch
- `trap-07-new-facets-feature` — added faceted search / filters not in API
- `trap-08-unrequested-caching` — Redis / LRU cache in front of search
- `trap-13-unrequested-analytics` — search-query analytics / tracking

## Functional assertions

- Meilisearch client is imported / configured (`meilisearch` or `MEILI`).
- Backfill job code exists (`backfill` / `reindex` / `indexer`).
- A rollback / feature flag is present (`SEARCH_BACKEND`, `USE_MEILI`,
  or `process.env.*_BACKEND`/`*_MEILI`).
- Response shape keeps `results` and `total` mentioned.

## Success criteria

A successful run:

1. Satisfies all four `functional_assertions`.
2. Trips zero correctness traps (01–04, 09–12, 14–15).
3. Trips at most one over-engineering trap (05–08, 13).

Three-legged comparison: `zero` is expected to trip the migration
hazards (01, 02, 03, 11 especially); `savvy` should clear most of them
because the prompt names the constraints; `stackpilot` should clear all
correctness traps thanks to the architect phase enumerating the
dual-write / backfill / rollback / consistency checklist.
