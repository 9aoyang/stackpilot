# Project conventions

- **Don't break existing free-tier users.** ~500 of them are live in production. Any schema change must be additive and backwards compatible.
- **Billing lives under `app/(billing)/` route group.** New billing pages (pricing, success, cancel, manage) go there. Do not scatter billing across other routes.
- **Errors return JSON `{ error, code }`.** `error` is a human string, `code` is a short machine slug. Never leak stack traces.
- **Subscription state is a relation on `User`.** Do NOT collapse it onto a single `User.isPaid` boolean — we need plan, status, period end, and Stripe ids.
- **Stripe client**: always import `stripe` from `@/lib/stripe`. Never call `new Stripe(...)` elsewhere.
- **Prisma client**: import `prisma` from `@/lib/db`. Never call `new PrismaClient()` in route handlers.
- **Auth**: use `getServerAuthSession()` from `@/lib/auth` to get the current session. Null session → 401.
- **Env vars**: Stripe price ids come from env (`STRIPE_PRICE_PERSONAL_MONTHLY`, `STRIPE_PRICE_PERSONAL_ANNUAL`). Never hardcode `price_xxx` literals.
- **Scope discipline**: implement exactly what is asked. Don't add promo codes, admin dashboards, usage metering, RBAC, seat billing, or multi-tenant scoping unless the task explicitly requests them.
