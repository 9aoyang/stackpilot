# Workload 02 sandbox — project rules

This is a synthetic benchmark fixture. It does not reflect any real codebase.

## Stack

- Node.js + native TypeScript (no transpile step; `.ts` files run via `node --experimental-strip-types`).
- Pure functions only. No database, no network, no external services.
- Tests use Node's built-in `node:test` module.

## Rules

- All three wave-1 endpoints (`pricingQuote`, `shippingEstimate`, `inventoryCheck`) must be **pure functions** reading from local in-memory tables. No I/O.
- The integration test must call all three endpoints sequentially and assert the aggregate shape.
- Return `cents` as integer (no floats).
- No `console.log` in production code.
