// TASK-002 target: replace this 501 stub.
// Takes { weightG, regionCode } and returns { cents, etaDays }.

const SHIP_TABLE: Record<string, { perKgCents: number; etaDays: number }> = {
  'NA': { perKgCents: 800, etaDays: 3 },
  'EU': { perKgCents: 1200, etaDays: 5 },
  'APAC': { perKgCents: 1500, etaDays: 7 },
};

export function shippingEstimate(req: { weightG: number; regionCode: string }) {
  // STUB — replace in TASK-002
  return { status: 501, error: 'not implemented' };
}
