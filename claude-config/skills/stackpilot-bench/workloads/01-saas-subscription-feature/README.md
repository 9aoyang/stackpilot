# W01-new — SaaS subscription feature (ambiguous multi-file task)

A realistic Next.js 14 App Router SaaS sandbox (~16 files, ~470 LOC) missing its billing stack. The agent is asked to "add subscription management" with a prompt that contains deliberate, product-shaped ambiguity: how to onboard ~500 existing free-tier users, what "enterprise plan next month" actually means, grace periods, downgrade behaviour.

## Why this workload matters

The previous v2 workloads failed because they were too prescriptive: a clear single-page prompt like "implement GET handler with these 5 fields" is something frontier models handle at ~97/100 zero-shot, and no real user would reach for /stackpilot for that kind of task.

W01-new targets the regime where /stackpilot actually earns its cost: an **underspecified, multi-file, architecturally-loaded** request. The right answer is not to implement everything — it's to:

- Ask clarifying questions, OR propose a staged plan, OR explicitly list the assumptions being made
- Ship a minimal correct slice first (personal tier + checkout + webhook), NOT enterprise
- NOT over-engineer enterprise / RBAC / multi-tenant abstractions before the personal-tier flow works

The workload is calibrated so that zero-shot Claude reliably hallucinates enterprise scope, seat tables, RBAC, admin dashboards, or deletes the free tier — while a stackpilot-orchestrated run should stage the work and surface the open questions instead.

## Sandbox layout

```
sandbox/
  CLAUDE.md                 conventions: don't break free-tier users, errors return {error,code}, subscription on relation not boolean
  README.md                 product state: ~500 free users, paid launch next sprint, enterprise interest appeared
  package.json              next 14 + prisma + next-auth + stripe
  tsconfig.json
  prisma/schema.prisma      User + Account + Session + VerificationToken; no subscription tables yet
  lib/
    db.ts                   prisma singleton
    stripe.ts               stripe singleton (apiVersion pinned)
    auth.ts                 NextAuth config (email + Google), PrismaAdapter
  app/
    layout.tsx              root shell
    page.tsx                marketing home, renders PricingCard (Free / Personal / Team)
    dashboard/page.tsx      authed landing
    signin/page.tsx         magic link + Google
    api/auth/[...nextauth]/route.ts
    api/user/route.ts       GET current user (returns {error,code})
  components/PricingCard.tsx  UNWIRED static pricing card
  tests/README.md             empty, just a note
```

## Prompt legs

- **zero** — one-sentence, intentionally ambiguous. "Add subscription management to this SaaS. We need to onboard existing free users, plan on launching an enterprise plan next month." This is what a non-savvy user would type; it tests how the agent reacts to genuine product ambiguity.
- **savvy** — still the same task, but with better framing: read the docs first, scope tight to personal tier, surface open questions for enterprise.
- **stackpilot** — the savvy prompt plus "Run full /stackpilot methodology: architect → dev → qa."

## Expected behaviour per leg

| Leg | Expected outcome |
| --- | --- |
| `zero` | Likely trips several over-engineering traps (enterprise upfront, RBAC, admin dashboard). May trip correctness traps (migrating existing users, no idempotency, hardcoded price id). May silently pick an interpretation of "enterprise" instead of flagging the ambiguity. |
| `savvy` | Resists most over-engineering traps because scope is named. Can still miss architectural ones (webhook idempotency, non-nullable plan on User, immediate cancel). |
| `stackpilot` | The architect pass should catch nearly all of these — it explicitly lists open questions, proposes a staged plan, and rejects enterprise scope. sp-dev ships the minimal slice; sp-qa flags anything that slipped past. |

## Traps (15 total)

Over-engineering (7):
- `trap-01-built-enterprise-upfront` — Organization / Workspace / Seat prisma models
- `trap-02-role-based-access-early` — Role model, permissions, hasRole/requireRole helpers
- `trap-05-unrequested-yearly-discount` — promo codes, coupons, discount logic
- `trap-06-unrequested-multitenant` — tenantId / tenant scoping on models
- `trap-07-unrequested-seat-billing` — per-seat billing infrastructure
- `trap-13-unrequested-admin-dashboard` — admin routes / admin UI
- `trap-14-unrequested-usage-based` — usage metering / createUsageRecord

Correctness (8):
- `trap-03-migrated-existing-users` — mass `updateMany` on User to trial / paid
- `trap-04-deleted-free-tier` — `user.delete` / DELETE FROM User
- `trap-08-skipped-ambiguity` — silently adds "enterprise" as an executable plan value
- `trap-09-hardcoded-stripe-price-id` — literal `price_xxxxxxxxxxx` in source
- `trap-10-no-webhook-idempotency` — webhook reaches DB write after `constructEvent` without an `event.id` / dedupe check
- `trap-11-no-subscription-schema` — `isPaid Boolean` on User instead of a Subscription relation
- `trap-12-missing-grace-period` — `stripe.subscriptions.cancel` (immediate) instead of `update { cancel_at_period_end: true }`
- `trap-15-ignored-existing-users` — adds non-nullable subscription field on User with no `@default` and no backfill

## Functional assertions (must all pass)

1. `prisma/schema.prisma` is touched.
2. A webhook route is created (`api/webhook*` or `webhooks/stripe`).
3. `stripe.checkout.sessions.create` (or a `createCheckoutSession` helper) is present.
4. The `@/lib/stripe` singleton is imported (no `new Stripe(...)` reinvention).

## Success signal

A successful run shows `stackpilot` tripping strictly fewer traps than `zero` while satisfying all four functional assertions. Against a known-good minimal implementation, all 15 traps are avoided — confirming the regex set is conservative (no false positives on the correct answer).
