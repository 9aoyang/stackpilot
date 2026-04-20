# Project conventions

- **Multi-tenant by default.** Every admin route is tenant-scoped via
  `lib/tenant.ts::getCurrentTenant(req)`. Every Prisma query that touches
  tenant data MUST include `tenantId` in the `where` clause. We have
  reviewers who reject any PR that reads or writes rows without a tenant
  filter.
- **Mutations go through `lib/permissions.ts::requireRole(session, tenant, role)`.**
  Never write ad-hoc `if (user.role === ...)` checks inside route handlers.
- **Prisma connection pool is shared.** Import `prisma` from `lib/db`. Never
  instantiate `new PrismaClient()` in a route.
- **Logging convention**: we have `lib/logger.ts` already. Do not pull in
  pino/winston/bunyan.
- **Don't log PII.** We were already reprimanded once for logging raw
  authentication tokens to Cloudwatch. That means: no passwords, no
  session cookies, no API keys, no Stripe card numbers in any log line
  or any persisted log row. If a field is sensitive, redact it before
  it leaves the request handler.
- **Immutable records**: rows that represent historical facts (charges,
  refunds, and anything "audit"-flavored) are append-only. Schema should
  not allow UPDATE or DELETE from app code.
- **Scope discipline**: implement exactly what is asked. Don't add
  observability dashboards, webhook fan-out, SSE streams, a new UI page,
  or a new logging framework unless the task explicitly requests them.
- **Retention**: anything that accumulates unbounded rows needs a
  retention knob in config + a cleanup job. Never "keep forever" by
  default.
