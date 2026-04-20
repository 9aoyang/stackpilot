/**
 * Placeholder job. The real implementation must backfill historical invoice
 * rows into v2 regional ledger events without locking the full invoice table.
 */
export async function backfillLedger() {
  throw new Error("not implemented");
}
