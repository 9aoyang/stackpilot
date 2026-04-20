# W02 — Rate-limit middleware

A medium-complexity, multi-file change against an existing Express-style auth middleware. The agent is given:

- `sandbox/middleware/auth.ts` — a working `requireAuth` implementation that extracts a bearer token, validates an in-memory session, and populates `req.userId`.
- `sandbox/middleware/auth.test.ts` — existing jest tests for the auth happy-path and 401 cases.
- `sandbox/config/limits.ts` — the single-source-of-truth budget: `perUserPerMinute: 60`, `windowMs: 60000`.
- `sandbox/lib/redis.ts` — a Promise-returning stub client (`get / incr / expire / pttl`).
- `sandbox/lib/logger.ts` — a structured logger (`info / warn / error`).
- `sandbox/CLAUDE.md` — conventions: use the logger, return 429 with `{error, retryAfter}`, co-located tests, scope discipline.

The task is to add **per-user** rate limiting inline in `requireAuth`, reusing the existing config / redis / logger. Expected delta: ~120–180 LOC across `middleware/auth.ts`, `middleware/auth.test.ts`, and at most one import edit elsewhere.

## Why this workload matters

Medium-complexity multi-file work is /stackpilot's sweet spot — and the native-Claude failure mode on tasks like this is **scope creep and over-abstraction**: "while I'm here I'll also extract a `RateLimiter` class, add burst config for the future, wrap redis in try/catch, and write a middleware composer." W02 is calibrated to catch that behaviour without penalising legitimate engineering judgment.

The correct answer is boring: ~20 new lines in `requireAuth`, one `logger.warn` call, one new `describe` block in the existing test file.

## Traps

Over-engineering (dominant theme):
- `trap-01-unrequested-abstraction` — generic `RateLimiter` / `TokenBucket` / `SlidingWindow` class
- `trap-02-future-config` — adds `perEndpoint`, `burst`, `tiers`, etc. to the config for future flexibility
- `trap-03-refactor-existing-auth` — rewrites the bearer-parsing / session-lookup path that already works
- `trap-04-add-metrics` — prom-client / statsd / opentelemetry counters
- `trap-05-extract-helper` — new `middleware/rateLimit.ts` or `rate-limit/index.ts` file instead of inline
- `trap-06-unrequested-types` — `RateLimitResult` / `RateLimitOptions` / `ThrottleResult` interfaces
- `trap-11-unrequested-docs` — JSDoc `@param` / `@returns` on internal helpers
- `trap-12-defensive-try-catch` — `catch (e) { throw e }` around redis calls
- `trap-13-unrequested-middleware-chain` — `compose()` / `pipeline()` / `applyMiddleware()` abstraction

Correctness:
- `trap-07-console-log` — `console.*` instead of `lib/logger.ts`
- `trap-08-wrong-status-code` — 500 / 403 instead of 429
- `trap-09-not-per-user` — keys the counter by IP / `x-forwarded-for` instead of `userId`
- `trap-10-missing-retry-after` — 429 body without `retryAfter`

## Success criteria

A successful attempt:

1. Satisfies all five `functional_assertions`:
   - `middleware/auth.ts` is the file touched
   - HTTP 429 appears in the diff
   - The counter key uses `userId` (not `req.ip`)
   - `redis.get` / `redis.incr` / `redis.expire` / `redis.multi` is called
   - At least one new `describe` / `it` mentions rate / limit / 429 / throttl
2. Trips zero correctness traps (07, 08, 09, 10).
3. Trips at most one medium or low over-engineering trap.
4. Keeps the original `requireAuth` auth logic untouched (no removal of the bearer / session / expiry branches).

The three-legged comparison (`zero` / `savvy` / `stackpilot`) should show `stackpilot` trips strictly fewer over-engineering traps than `zero` while still satisfying every functional assertion — this workload is explicitly designed to showcase where architect → dev → qa beats a single unstructured prompt.
