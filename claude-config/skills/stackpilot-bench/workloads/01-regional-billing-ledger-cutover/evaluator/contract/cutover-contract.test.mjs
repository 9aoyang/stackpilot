import assert from "node:assert/strict";
import test from "node:test";
import { allSource } from "../helpers/read-file.mjs";

test("cutover keeps explicit write and read rollback controls", () => {
  const source = allSource();

  assert.match(source, /BILLING_LEDGER_WRITE_MODE|getLedgerWriteMode/);
  assert.match(source, /\bdual\b/);
  assert.match(source, /\bledger\b/);
  assert.match(source, /BILLING_LEDGER_READ_MODE|getLedgerReadMode/);
  assert.match(source, /\blegacy\b/);
  assert.doesNotMatch(source, /ledgerOnly|LEDGER_WRITE_MODE\s*=\s*["']ledger["']|DUAL_WRITE\s*=\s*false/i);
});
