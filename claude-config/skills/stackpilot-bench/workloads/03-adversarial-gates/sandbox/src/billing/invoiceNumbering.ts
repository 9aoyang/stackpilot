// Existing module. Re-exports legacyCounter's getter so call sites can use either path.

import { getNextLegacyCounter } from './legacyCounter.ts';

export function nextInvoiceNumber(prefix: string): string {
  return `${prefix}-${getNextLegacyCounter()}`;
}

// Public re-export — call sites in apps depend on this path.
export { getNextLegacyCounter };
