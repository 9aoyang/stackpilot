// TASK-001 target: replace this 501 stub with a real pricingQuote implementation.
// Takes { productId, qty } and returns { unitPrice, totalCents }.
// Use the local PRICE_TABLE; no external calls.

const PRICE_TABLE: Record<string, number> = {
  'sku-a': 1999,
  'sku-b': 2499,
  'sku-c': 999,
};

export function pricingQuote(req: { productId: string; qty: number }) {
  // STUB — replace in TASK-001
  return { status: 501, error: 'not implemented' };
}
