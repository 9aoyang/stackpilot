# Sandbox — Rate-limit middleware

This sandbox is a tiny Express-style API server. Authentication already works (`middleware/auth.ts` resolves a bearer token to a user id via an in-memory session map).

The next requirement is **per-user rate limiting**: a logged-in user should be allowed at most `RATE_LIMITS.perUserPerMinute` requests per `RATE_LIMITS.windowMs`. Exceeding the budget must return HTTP 429.

Supporting pieces already exist:

- `config/limits.ts` — the budget (do not add new fields).
- `lib/redis.ts` — the counter store.
- `lib/logger.ts` — structured logger.

Existing auth behaviour in `requireAuth` must keep working untouched — only the rate-limit branch is new.
