CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  subscription_id TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL,
  region TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE refunds (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL,
  region TEXT NOT NULL,
  created_at TEXT NOT NULL
);
