import assert from "node:assert/strict";
import test from "node:test";
import { read } from "../helpers/read-file.mjs";

test("backfill is a cursor based job, not a request-path full table scan", () => {
  const source = read("src/jobs/backfillLedger.ts");
  assert.match(source, /cursor|lastSeen|afterId/i);
  assert.match(source, /batch|take|limit/i);
  assert.doesNotMatch(source, /findMany\s*\(\s*\{\s*\}\s*\)|SELECT \* FROM invoices/i);
});
