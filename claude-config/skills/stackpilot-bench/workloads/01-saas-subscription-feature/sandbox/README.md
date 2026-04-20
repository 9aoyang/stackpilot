# Lumen — SaaS sandbox

Lumen is a live B2C SaaS (note-taking + AI summarisation). The product launched six months ago on a pure free tier.

## Current state

- ~500 free-tier users in production (see `prisma/schema.prisma` — `User` model, no subscription fields yet).
- Stripe account is set up (test + live keys in env), but nothing charges customers yet.
- The marketing site already shows a pricing page (`components/PricingCard.tsx`) with two tiers — **Personal** and **Team** — but the buttons are unwired placeholders.
- Auth is NextAuth (email magic link + Google), session stored in DB via Prisma adapter.

## Near-term plan

- **This sprint**: launch paid Personal tier (monthly + annual) so we can start collecting revenue. Checkout + webhook + minimal "manage subscription" entry point.
- **Next month (tentative)**: a few inbound leads have asked about an "enterprise" or "team" plan. Pricing, seat model, SLA, contract all TBD. We have NOT committed to shipping this yet.
- **Free tier stays.** It is our top-of-funnel. Existing free-tier users should not feel anything change on launch day.

## Things that are deliberately undecided

- How to onboard the 500 existing users into the new subscription data model (grandfather as "free forever"? opt-in upgrade prompt? silent backfill?).
- What "enterprise" actually means (org/team entity? per-seat billing? annual invoice only? custom SLA?).
- Grace period on cancellation / past-due.
- Downgrade data retention (Team → Personal, Personal → Free).

These are open product questions, not implementation details. Flag them; don't silently pick an interpretation.

## Repo layout

```
app/                  Next.js App Router
  api/auth/           NextAuth handler
  api/user/           current user endpoint
  dashboard/          authed landing
  signin/             magic link + Google
lib/
  auth.ts             NextAuth config
  db.ts               prisma singleton
  stripe.ts           stripe singleton
components/
  PricingCard.tsx     existing, unwired
prisma/
  schema.prisma       User + Session + VerificationToken
tests/                (empty)
```
