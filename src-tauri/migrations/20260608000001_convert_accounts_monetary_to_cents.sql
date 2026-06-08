-- Convert monetary columns in accounts from DECIMAL/TEXT to INTEGER cents.
-- SQLite stores DECIMAL as TEXT. We convert: 1234.56 -> 123456 (integer cents).
-- interest_rate stays as TEXT (it is a percentage rate, not a monetary amount).
-- Uses the standard SQLite migration pattern: create new table, copy with conversion,
-- drop old, rename.

-- Step 1: Create new table with INTEGER monetary columns
CREATE TABLE accounts_new (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    initial_balance INTEGER NOT NULL DEFAULT 0,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit INTEGER,
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    low_balance_threshold INTEGER,
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived', 'hidden')),
    opened_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment',
           'borrowed_out', 'borrowed_in', 'prepaid', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'liability', 'external')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

-- Step 2: Copy data with monetary conversion (TEXT -> INTEGER cents)
-- initial_balance: NOT NULL, direct conversion
-- credit_limit: nullable, wrap with CASE for NULL preservation
-- low_balance_threshold: nullable, wrap with CASE for NULL preservation
INSERT INTO accounts_new (
    id, name, account_type, currency_code, initial_balance,
    ownership, icon, color, chart_code, parent_id,
    account_number, institution, credit_limit,
    billing_day, payment_due_day, interest_rate,
    deleted_at, updated_at, device_id, synced_at,
    version, low_balance_threshold, status, opened_at, created_at
)
SELECT
    id, name, account_type, currency_code,
    CAST(ROUND(CAST(initial_balance AS REAL) * 100) AS INTEGER),
    ownership, icon, color, chart_code, parent_id,
    account_number, institution,
    CASE WHEN credit_limit IS NOT NULL THEN CAST(ROUND(CAST(credit_limit AS REAL) * 100) AS INTEGER) ELSE NULL END,
    billing_day, payment_due_day, interest_rate,
    deleted_at, updated_at, device_id, synced_at,
    version,
    CASE WHEN low_balance_threshold IS NOT NULL THEN CAST(ROUND(CAST(low_balance_threshold AS REAL) * 100) AS INTEGER) ELSE NULL END,
    status, opened_at, created_at
FROM accounts;

-- Step 3: Drop old table
DROP TABLE accounts;

-- Step 4: Rename new table
ALTER TABLE accounts_new RENAME TO accounts;

-- Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);
