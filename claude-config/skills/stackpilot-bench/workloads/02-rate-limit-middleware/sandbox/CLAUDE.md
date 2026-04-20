# Project conventions

- **Logging**: use `lib/logger.ts` (`logger.info/warn/error`). Never use `console.*` directly.
- **Redis**: import `redis` from `lib/redis.ts`. Do not instantiate a new client.
- **Errors**: respond with status 429 for rate-limit exceeded. Body shape: `{ error, retryAfter }` where `retryAfter` is seconds until the window resets.
- **Tests**: jest, co-located `*.test.ts` files next to the code under test.
- **Scope discipline**: implement exactly what the task asks. No metrics, no per-endpoint configs, no helper extraction unless the middleware is reused from more than one call site.
