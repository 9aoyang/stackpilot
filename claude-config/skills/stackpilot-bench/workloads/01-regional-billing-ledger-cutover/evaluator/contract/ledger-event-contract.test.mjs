import assert from "node:assert/strict";
import test from "node:test";
import { sourceMatching } from "../helpers/read-file.mjs";

test("ledger event writer has v2 regional idempotent schema and sanitized payload", () => {
  const source = sourceMatching((filePath, text) => {
    if (/legacyLedger\.ts$/.test(filePath)) return false;
    if (/^src\/api\//.test(filePath)) return false;
    return /ledger/i.test(filePath) || /LedgerEvent|billingLedger|regionalLedger|writeLedger/i.test(text);
  })
    .map(({ path, text }) => `\n// ${path}\n${text}`)
    .join("\n");

  assert.match(source, /ledger/i, "a non-legacy ledger implementation must exist");
  assert.match(source, /schemaVersion/);
  assert.match(source, /idempotencyKey|dedupeKey/);
  assert.match(source, /region/);
  assert.match(source, /currency/);
  assert.match(source, /amountCents/);
  assert.match(source, /sanitize|redact|safePayload/);
  assert.doesNotMatch(source, /customerEmail|paymentMethod|cardLast4|rawPayload|stripePayload|payload\s*:\s*event\b/i);
});
