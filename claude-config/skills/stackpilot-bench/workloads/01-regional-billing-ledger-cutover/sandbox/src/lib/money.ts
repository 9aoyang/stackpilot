export type Currency = "USD" | "EUR" | "JPY";

export function assertCents(amountCents: number): number {
  if (!Number.isInteger(amountCents)) {
    throw new Error("money must be stored as integer cents");
  }
  return amountCents;
}
