import assert from "node:assert/strict";
import test from "node:test";
import { exists, read } from "../helpers/read-file.mjs";

test("ledger event writer has v2 regional idempotent schema and sanitized payload", () => {
  assert.equal(exists("src/ledger/events.ts"), true, "src/ledger/events.ts must exist");
  const source = read("src/ledger/events.ts");
  assert.match(source, /schemaVersion/);
  assert.match(source, /idempotencyKey|dedupeKey/);
  assert.match(source, /region/);
  assert.match(source, /currency/);
  assert.match(source, /amountCents/);
  assert.match(source, /sanitize|redact|safePayload/);
  assert.doesNotMatch(source, /customerEmail|paymentMethod|cardLast4|rawPayload|stripePayload/);
});
