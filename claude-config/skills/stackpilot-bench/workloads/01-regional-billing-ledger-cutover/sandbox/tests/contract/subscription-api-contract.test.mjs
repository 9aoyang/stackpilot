import assert from "node:assert/strict";
import test from "node:test";
import { read } from "../helpers/read-file.mjs";

test("subscription API keeps the public response contract", () => {
  const source = read("src/billing/subscriptionService.ts") + "\n" + read("src/api/subscription.ts");
  assert.match(source, /plan/);
  assert.match(source, /status/);
  assert.match(source, /currentPeriodEnd/);
  assert.match(source, /cancelAtPeriodEnd/);
  assert.doesNotMatch(source, /ledger(Event|Entries|Rows)|journal|events:/i);
});
