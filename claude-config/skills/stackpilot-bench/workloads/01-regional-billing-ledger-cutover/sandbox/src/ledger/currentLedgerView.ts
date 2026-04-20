export type LegacyLedgerRow = {
  invoiceId: string;
  amountCents: number;
  currency: string;
  createdAt: string;
};

export async function readLegacyLedgerRows(): Promise<LegacyLedgerRow[]> {
  return [];
}
