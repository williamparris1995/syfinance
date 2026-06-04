-- Fix missing UNIQUE constraint on chart_of_accounts.code
-- The 20260604000002 migration recreated chart_of_accounts but omitted UNIQUE on code,
-- causing "foreign key mismatch" on transaction_entries referencing chart_of_accounts(code).

-- SQLite cannot ADD UNIQUE via ALTER TABLE, so create unique index instead
CREATE UNIQUE INDEX IF NOT EXISTS idx_chart_of_accounts_code_unique ON chart_of_accounts(code);

-- Also recreate the non-unique index for lookups
CREATE INDEX IF NOT EXISTS idx_chart_of_accounts_code ON chart_of_accounts(code);
