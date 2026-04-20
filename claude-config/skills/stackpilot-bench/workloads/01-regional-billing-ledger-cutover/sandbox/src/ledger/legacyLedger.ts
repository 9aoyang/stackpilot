/**
 * Deprecated: incident-response read shim for old audit rows.
 *
 * Do not use for new billing writes. It has no region, no schema version, and
 * no idempotency key.
 */
export async function writeLegacyLedger(_entry: unknown): Promise<void> {
  throw new Error("legacyLedger is deprecated for new writes");
}
