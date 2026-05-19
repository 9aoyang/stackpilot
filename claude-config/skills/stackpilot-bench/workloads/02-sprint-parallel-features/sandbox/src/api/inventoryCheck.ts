// TASK-003 target: replace this 501 stub.
// Takes { productId } and returns { available, qty }.

const INVENTORY_TABLE: Record<string, number> = {
  'sku-a': 42,
  'sku-b': 0,
  'sku-c': 7,
};

export function inventoryCheck(req: { productId: string }) {
  // STUB — replace in TASK-003
  return { status: 501, error: 'not implemented' };
}
