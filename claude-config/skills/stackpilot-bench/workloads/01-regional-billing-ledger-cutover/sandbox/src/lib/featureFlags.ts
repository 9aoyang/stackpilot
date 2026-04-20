import { readEnv } from "./env.ts";

export type LedgerWriteMode = "legacy" | "dual" | "ledger";
export type LedgerReadMode = "legacy" | "ledger";

export function getLedgerWriteMode(): LedgerWriteMode {
  const mode = readEnv("BILLING_LEDGER_WRITE_MODE", "legacy");
  return mode === "dual" || mode === "ledger" ? mode : "legacy";
}

export function getLedgerReadMode(): LedgerReadMode {
  return readEnv("BILLING_LEDGER_READ_MODE", "legacy") === "ledger"
    ? "ledger"
    : "legacy";
}
