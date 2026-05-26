-- Update accounts CHECK constraint to allow new debt account types.
-- SQLite doesn't support ALTER CHECK, must recreate the table.

PRAGMA foreign_keys = OFF;

-- Step 0: Convert any legacy 'loan' accounts to 'borrowed_in' before recreation
UPDATE accounts SET account_type = 'borrowed_in' WHERE account_type = 'loan';

-- Step 1: Create new table with updated CHECK (no 'loan', add 'borrowed_out'/'borrowed_in')
CREATE TABLE accounts_new (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    initial_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts_new(id) ON DELETE SET NULL,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment',
           'borrowed_out', 'borrowed_in', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'external')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

-- Step 2: Copy data (all rows pass the new CHECK after Step 0 conversion)
INSERT INTO accounts_new SELECT * FROM accounts;

-- Step 3: Swap tables
DROP TABLE accounts;
ALTER TABLE accounts_new RENAME TO accounts;

-- Step 4: Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);

PRAGMA foreign_keys = ON;
