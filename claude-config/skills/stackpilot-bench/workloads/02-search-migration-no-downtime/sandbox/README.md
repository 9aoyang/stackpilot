# search-service

Internal full-text search over the `documents` table. Backs
`app.internal/search` and the `/api/search` endpoint consumed by the web
app, the desktop client, and three internal Slack bots.

## Current state (prod)

- **Storage**: Postgres, single `documents` table (~2.4M rows, ~9 GB).
- **Search**: `ILIKE '%' || $1 || '%'` over `title` and `body`, with a
  composite `btree_gin` index on `(title, body)`. Good enough while the
  corpus was small; p95 is now ~850ms and climbing.
- **Write path**: documents are created / updated via the internal
  ingest service writing directly to Postgres. This service only reads.
- **Response contract**: `{ results: Document[], total: number }`. The
  frontend pages by `limit` + `offset`.

## Why we want Meilisearch

1. **Typo tolerance** — users search "invocie" and expect "invoice".
   ILIKE cannot do this without extra extensions.
2. **Relevance ranking** — ILIKE just returns all matches; we want hits
   in `title` to beat hits in `body`, and shorter docs to win ties.
3. **Latency** — Meilisearch returns in ~15ms for corpora this size
   based on the spike in `docs/2026-03-meili-spike.md`.

## Migration constraints (read before touching search code)

- The frontend is hitting `/api/search` *right now*. No downtime, no
  flag-day cutover. See `CLAUDE.md` for the hard rules.
- Data in Postgres is the source of truth until we say otherwise.
- We need to be able to roll back to ILIKE via an env-var flip, not a
  redeploy.

## Run it

```
cp .env.example .env
# bring up your own postgres, point DATABASE_URL at it
npm install
npm run migrate
npm run dev
```

## Layout

```
src/
  api/search.ts         Express handler — current ILIKE path
  api/search.test.ts    Existing tests, must keep passing
  lib/db.ts             pg Pool singleton
  lib/logger.ts         Structured logger
  models/Document.ts    Document type
  models/DocumentRepo.ts ILIKE query implementation
  jobs/indexer.ts       Placeholder for future backfill / indexer
  server.ts             Express bootstrap
migrations/
  001_create_documents.sql
```
