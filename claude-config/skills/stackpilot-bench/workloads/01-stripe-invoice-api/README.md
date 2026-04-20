# W01 — Stripe Invoice API

A single-file Next.js App Router API route task. The agent is given a blank `app/api/billing/invoices/route.ts` and must write a ~60 LOC `GET` handler that authenticates the user, calls `stripe.invoices.list()`, and returns a JSON slice.

## Why this workload matters

Real SaaS codebases are full of these small, bounded API routes. The production-good answer is boring: import the singleton, call the SDK, pass through 4-5 fields, return JSON. But current-generation models (Opus 4.5/4.6) systematically over-deliver: they bolt on retries, caches, rate limiters, zod schemas, helper extractions, and defensive try/catch — none of which the task asked for.

W01 quantifies that over-engineering bias on a task where "what was asked" is unambiguous. It also checks that the agent respects the sandbox conventions (`lib/stripe.ts` singleton, `getCurrentUserId()` auth helper) instead of reinventing them.

## Traps

Over-engineering (dominant):
- `trap-01-unrequested-retry` — retry + exponential backoff
- `trap-02-unrequested-cache` — caching layer (Map / Redis / `unstable_cache`)
- `trap-03-unrequested-ratelimit` — rate limiting middleware
- `trap-04-defensive-try-catch` — try/catch around trusted internal calls
- `trap-05-unrequested-helper` — extract single-use helper function
- `trap-06-unrequested-types` — invents `InvoiceDTO`-style interfaces
- `trap-07-redundant-comments` — comments that restate the code
- `trap-08-unrequested-validation` — zod/joi schema for query params
- `trap-09-unrequested-logging` — `console.log` / logger sprinkles

Correctness:
- `trap-10-reimplement-stripe-singleton` — `new Stripe(...)` instead of importing `@/lib/stripe`
- `trap-11-wrong-auth` — ignores `getCurrentUserId`, invents own auth

Dollar-conversion was considered but dropped: the task wording is ambiguous about cents vs. dollars, so penalising either choice would be unfair.

## Success criteria

A successful attempt:

1. Satisfies all three `functional_assertions` — `invoices.list(` is called, a `GET` handler is exported, and the `@/lib/stripe` singleton is imported.
2. Trips zero high-severity traps.
3. Trips at most one medium or low trap.
4. Output size is in the 60-120 LOC range for the target file.

The three-legged comparison (`zero` / `savvy` / `stackpilot`) should show `stackpilot` trips strictly fewer over-engineering traps than `zero` while still satisfying the functional assertions.
