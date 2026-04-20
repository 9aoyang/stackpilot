# W03 — multi-tenant audit logging

Cross-system feature work inside a realistic multi-tenant admin panel.
Adding "audit logging" the right way touches permissions, the data layer,
and every admin API consistently. This is exactly the kind of task a user
reaches for `/stackpilot` for — zero-shot typically picks one corner and
ships an incomplete answer.

## Why this workload exists

The v2 workloads were small, isolated tasks where zero-shot Claude already
does fine. Audit logging in a multi-tenant SaaS is the opposite: it is
boring, cross-cutting, and full of traps that only surface when the
engineer actually thinks about tenants, retention, immutability, and PII.

A correct answer must:

- Add an `AuditLog` model with `tenantId`, `actorId`, `action`, `resource`,
  `resourceId`, `before`, `after`, `ip`, `createdAt`.
- Route every mutation (users PATCH/DELETE, ban, refund, settings PATCH)
  through a single write-side helper — not scattered `prisma.auditLog.create`
  inline in every handler.
- Expose a read-side query API (`GET /api/admin/audit-log` or similar)
  that filters by `tenantId` on the server, never from client input.
- Add a composite index on `(tenantId, createdAt)` for the query path.
- Add a retention knob (env var or config) and a cleanup job — default
  365 days — instead of unbounded growth.
- Keep the schema append-only (no `@updatedAt`, no update/delete code paths).
- Redact / drop sensitive fields (`passwordHash`, `token`, `cookie`, `apiKey`,
  `secret`) before they ever land in the `before`/`after` JSON.

## Sandbox

`sandbox/` is a Next.js 14 App Router multi-tenant admin panel with:

- Prisma schema for `Tenant`, `TenantSettings`, `User`, `AdminRole`, `Invoice`
  (intentionally NO `AuditLog`).
- Admin pages: dashboard, users list, user detail, billing, settings.
- Admin APIs: PATCH/DELETE user, POST ban, POST refund, PATCH settings.
- `lib/permissions.ts`, `lib/tenant.ts`, `lib/db.ts`, `lib/logger.ts`,
  `lib/http.ts` — all the primitives already exist; agents should reuse
  them.
- `sandbox/CLAUDE.md` codifies the "no PII", "tenant-scoped", "don't pull
  in pino/winston", "scope discipline" conventions.

## Trap categories

| Category          | Count | IDs                                                              |
|-------------------|-------|------------------------------------------------------------------|
| correctness       | 9     | trap-01, trap-02, trap-03, trap-04, trap-05, trap-06, trap-07, trap-08, trap-09 |
| over-engineering  | 6     | trap-10, trap-11, trap-12, trap-13, trap-14, trap-15             |

### Correctness traps

- **trap-01** AuditLog model without `tenantId` column.
- **trap-02** Query endpoint missing tenant-scope filter — cross-tenant leak.
- **trap-03** No composite index on `(tenantId, createdAt)`.
- **trap-04** Only some routes updated (e.g. users yes, billing/settings no).
- **trap-05** Logs to console / stdout logger instead of persisting to DB.
- **trap-06** Passwords / tokens / cookies logged raw in before/after.
- **trap-07** No retention knob and no cleanup job.
- **trap-08** Synchronous `await prisma.auditLog.create` inside the mutation
  request path (slow log blocks admin response).
- **trap-09** Schema allows mutation: `@updatedAt`, `update`, or `delete`
  call on `auditLog`.

### Over-engineering traps

- **trap-10** Unrequested SSE / ReadableStream endpoint for live tailing.
- **trap-11** Unrequested outbound webhook for audit events.
- **trap-12** Unrequested admin UI page for audit search.
- **trap-13** Introduces pino / winston / bunyan even though `lib/logger.ts`
  already exists and CLAUDE.md explicitly forbids it.
- **trap-14** Each route calls `prisma.auditLog.create` inline (2+ times in
  the diff) instead of going through a shared helper.
- **trap-15** Rewrites `lib/permissions.ts` while adding audit.

## Expected stackpilot advantage

- Architect phase should produce a single central helper (`recordAudit`) and
  enumerate all four mutation routes before any code is written.
- Dev phase should edit every route consistently (no "I forgot billing").
- QA phase should catch: missing index, missing retention, PII redaction,
  immutability, and any scope creep (SSE, webhook, UI page).

Native zero-shot typically:

- Adds `AuditLog` model and a single `prisma.auditLog.create` in one route,
  declares victory.
- Forgets retention and the index.
- Sometimes logs raw `passwordHash` in the before/after blob.
- Sometimes invents an SSE endpoint or a pino wrapper because "it would be
  nice to have structured logging".

## Success criteria

1. `AuditLog` model exists with `tenantId`, `actorId`, `action`, `resource`,
   `resourceId`, `before`, `after`, `ip`, `createdAt`.
2. Composite index `@@index([tenantId, createdAt])` present.
3. No `@updatedAt`; no code path calls `prisma.auditLog.update` or `.delete`.
4. A single helper (e.g. `recordAudit` / `AuditService.record`) called from
   users PATCH, users DELETE, users ban, billing refund, settings PATCH.
5. Read-side query endpoint filters by tenant from the server-resolved
   `tenant.id`, never from user input.
6. Retention configurable (env or config constant), default 365 days, and
   a cleanup path (cron / scheduled route / script) exists.
7. Sensitive field allowlist / denylist applied before persisting
   before/after JSON.
8. `sandbox/lib/permissions.ts` untouched.
9. No new UI page under `app/admin/audit*`; no SSE; no webhook; no new
   log framework dependency.

## How the bench scorer uses this workload

- `prompts.yml` drives the three legs (zero / savvy / stackpilot).
- `traps.yml` is consumed by `scripts/score.py`:
  - Each trap's `diff_bad_regex` is evaluated with `re.search` + `re.MULTILINE`
    against the unified diff.
  - Each `functional_assertion.diff_must_match_regex` must match for the run
    to be considered functionally complete.
- Stackpilot's target on this workload: 0 correctness traps, ≤1
  over-engineering trap, all functional assertions satisfied.
