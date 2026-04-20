# Search service — conventions for contributors (human or agent)

This service is **live**. The frontend at `app.internal/search` hits `/api/search`
continuously during business hours. Treat every change as an online migration.

## Hard rules

1. **No flag-day cutovers on live prod.** Any backend swap must support
   running old + new side-by-side, with the ability to flip traffic back
   without a redeploy.
2. **Migrations must be reversible.** SQL migrations, index definitions,
   and config flips all need a documented rollback.
3. **Don't break the existing `/api/search` response shape.** The frontend
   depends on `{ results: Document[], total: number }`. Field names and
   nesting are part of the contract. If you *need* to extend it, add
   fields, never rename or restructure the two existing ones.
4. **Writes must stay consistent across stores during any migration
   window.** If we are moving data to a new backend, writes should
   dual-write (or mirror via trigger) until the new backend is the
   source of truth.
5. **Existing tests under `src/api/*.test.ts` must keep passing.** Do not
   delete or skip them to make a new implementation green; fix the
   implementation instead.

## House style

- TypeScript strict mode. No `any` in new code.
- Logger: `src/lib/logger.ts`. No `console.log` in request paths.
- DB access through `src/lib/db.ts` pool. No new `new Pool()`.
- Env vars only via `process.env`, documented in `.env.example`.
- Keep handler files thin; put query logic in a `*Repo`.

## When in doubt

Surface the ambiguity in a PR description or plan doc. Examples of
things that are genuinely ambiguous and should be asked about, not
guessed:

- What defines "consistent" during a dual-write window (eventual? strict?)
- Acceptable staleness for the new backend during backfill
- Who owns the cutover decision and how we roll back
