# Multi-Tenant Admin Panel

B2B SaaS admin panel. Each customer ("tenant") onboards under their own workspace
and their staff/owners access this panel at `/admin/*`. We currently have ~40
tenants live in production across US and EU regions.

## Stack

- Next.js 14 App Router
- Prisma 5 on Postgres
- next-auth with JWT sessions
- Tenant resolution via subdomain -> `lib/tenant.ts`
- RBAC via `lib/permissions.ts` (roles: `OWNER`, `ADMIN`, `SUPPORT`, `MEMBER`)

## Resources managed by admins

- **Users** — list, view, PATCH profile, DELETE, POST ban
- **Billing** — view invoices, POST refund
- **Settings** — tenant-level preferences (feature flags, plan, branding)

## Current pain: compliance request

Two paying customers (enterprise tier) asked us for an **audit log** of every
admin action inside their tenant. Their security team wants to answer things
like "who banned user X on 2026-03-14?" or "show me every refund issued by
ADMIN `amy@foo.com` last quarter".

We also have SOC-2 renewal coming up and our auditor flagged the same gap:
no durable record of administrative mutations.

So far admins just do stuff and it disappears into the void. A few routes
have stray `console.log(...)` lines, but that's it — nothing queryable.

## What support needs

- A way to pull the audit trail for a tenant and filter by actor / action /
  time range / resource. API is fine; they already have an internal tool
  that calls our APIs.
- Never see another tenant's rows.
- Must survive rotation of admin staff (actor kept as id even if user is
  deleted).

## What compliance needs

- Immutable — no after-the-fact edits or deletions by admins.
- Retention configurable per deployment (default 365 days; EU region may
  demand shorter).
- No PII inside log rows (we already got dinged once for writing a raw
  session token to a debug log — see `CLAUDE.md`).

## Local dev

```
pnpm install
pnpm prisma:generate
pnpm dev
```

Subdomain routing is faked in dev via `X-Tenant-Slug` header; see
`middleware.ts`.
