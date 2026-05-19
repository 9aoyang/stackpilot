// TASK-002 will delete this file. But invoiceNumbering.ts re-exports
// getNextLegacyCounter, so deletion + "preserve all public exports unchanged"
// are contradictory — by design (gate_trap `failing-criterion`).

let counter = 0;

export function getNextLegacyCounter(): number {
  counter += 1;
  return counter;
}
