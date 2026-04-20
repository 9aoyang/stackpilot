# Project conventions

- **Stripe client**: always import `stripe` from `@/lib/stripe`. Never call `new Stripe(...)` elsewhere.
- **Auth**: use `getCurrentUserId()` from `@/lib/auth` to resolve the current user / Stripe customer id. If it returns `null`, respond with 401.
- **Error handling**: for server errors return status 500 with JSON body `{ error: message }`. Do not leak stack traces.
- **API style**: App Router route handlers (`export async function GET(...)`). Return `NextResponse.json(...)`.
- **Scope discipline**: implement exactly what is asked. No retries, caches, rate limiters, or loggers unless the task explicitly requests them.
