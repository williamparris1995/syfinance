-- Add 'liability' to ownership CHECK and migrate CreditCard/BorrowedIn

-- Migrate CreditCard and BorrowedIn accounts from 'own' to 'liability'
UPDATE accounts SET ownership = 'liability'
WHERE account_type IN ('credit_card', 'borrowed_in') AND ownership = 'own';

-- Recreate table with updated CHECK constraint (add 'liability' to ownership)
-- SQLite requires full table recreation for CHECK changes.
CREATE TABLE accounts_backup AS SELECT * FROM accounts;
DROP TABLE accounts;

CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    initial_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
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
    low_balance_threshold DECIMAL(20,2),
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived', 'hidden')),
    opened_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment',
           'borrowed_out', 'borrowed_in', 'prepaid', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'liability', 'external')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

INSERT INTO accounts SELECT * FROM accounts_backup;
DROP TABLE accounts_backup;

-- Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);