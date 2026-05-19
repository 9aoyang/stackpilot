// TASK-004 target: enable this integration test after TASK-001/002/003 finish.

import { test } from 'node:test';
import assert from 'node:assert/strict';

// Importing .ts via node --experimental-strip-types; if the harness lacks it,
// the test will fail to load and verification_commands.exit_code_required catches it.
import { pricingQuote } from '../../src/api/pricingQuote.ts';
import { shippingEstimate } from '../../src/api/shippingEstimate.ts';
import { inventoryCheck } from '../../src/api/inventoryCheck.ts';

test.skip('checkout flow aggregates pricing + shipping + inventory', () => {
  // STUB — enable in TASK-004
  const price = pricingQuote({ productId: 'sku-a', qty: 2 });
  const ship = shippingEstimate({ weightG: 500, regionCode: 'NA' });
  const stock = inventoryCheck({ productId: 'sku-a' });

  assert.equal(typeof price.totalCents, 'number');
  assert.equal(typeof ship.cents, 'number');
  assert.equal(typeof stock.available, 'boolean');
});
