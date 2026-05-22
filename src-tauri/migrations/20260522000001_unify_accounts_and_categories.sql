-- Migration: Unify accounts and categories
-- Drops categories table, merges data into accounts,
-- removes category_id from transaction_entries

PRAGMA foreign_keys = OFF;

-- ============================================================================
-- STEP 1: Add new columns to accounts
-- ============================================================================

ALTER TABLE accounts ADD COLUMN ownership VARCHAR(10) NOT NULL DEFAULT 'own';
ALTER TABLE accounts ADD COLUMN icon VARCHAR(10) NOT NULL DEFAULT '📁';
ALTER TABLE accounts ADD COLUMN color VARCHAR(7) NOT NULL DEFAULT '#6B7280';
ALTER TABLE accounts ADD COLUMN chart_code VARCHAR(10);
ALTER TABLE accounts ADD COLUMN parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 2: Migrate categories → accounts (ownership = 'external')
-- ============================================================================

INSERT INTO accounts (id, name, account_type, currency_code, balance,
                      ownership, icon, color, chart_code, parent_id,
                      deleted_at, updated_at, device_id, synced_at)
SELECT
    id,
    name,
    CASE category_type WHEN 'income' THEN 'income' WHEN 'expense' THEN 'expense' END,
    'CNY',
    0.00,
    'external',
    icon,
    color,
    chart_code,
    parent_id,
    deleted_at,
    updated_at,
    device_id,
    synced_at
FROM categories;

-- ============================================================================
-- STEP 3: Drop categories table
-- ============================================================================

DROP TABLE categories;

-- ============================================================================
-- STEP 4: Recreate transaction_entries without category_id
-- ============================================================================

CREATE TABLE transaction_entries_backup AS SELECT * FROM transaction_entries;

DROP TABLE transaction_entries;

CREATE TABLE transaction_entries (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    chart_of_account_code VARCHAR(10) NOT NULL,
    debit_amount DECIMAL(20,2),
    credit_amount DECIMAL(20,2),
    note TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (
        (debit_amount IS NULL AND credit_amount IS NOT NULL AND credit_amount >= 0) OR
        (debit_amount IS NOT NULL AND debit_amount >= 0 AND credit_amount IS NULL)
    ),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY (chart_of_account_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT
);

INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code,
                                  debit_amount, credit_amount, note,
                                  deleted_at, updated_at, device_id, synced_at)
SELECT id, transaction_id, account_id, chart_of_account_code,
       debit_amount, credit_amount, note,
       deleted_at, updated_at, device_id, synced_at
FROM transaction_entries_backup;

DROP TABLE transaction_entries_backup;

-- Recreate indexes
CREATE INDEX idx_transaction_entries_transaction ON transaction_entries(transaction_id);
CREATE INDEX idx_transaction_entries_account ON transaction_entries(account_id);
CREATE INDEX idx_transaction_entries_chart_code ON transaction_entries(chart_of_account_code);
CREATE INDEX idx_transaction_entries_deleted ON transaction_entries(deleted_at);

-- Recreate double-entry triggers
CREATE TRIGGER enforce_double_entry_insert
BEFORE INSERT ON transaction_entries
BEGIN
    SELECT RAISE(ABORT, 'Double-entry violation: debit sum must equal credit sum')
    WHERE (
        SELECT
            COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND deleted_at IS NULL
    ) + COALESCE(NEW.debit_amount, 0) - COALESCE(NEW.credit_amount, 0) != 0
    AND (
        SELECT COUNT(*)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND deleted_at IS NULL
    ) >= 1;
END;

CREATE TRIGGER enforce_double_entry_update
BEFORE UPDATE ON transaction_entries
BEGIN
    SELECT RAISE(ABORT, 'Double-entry violation: debit sum must equal credit sum')
    WHERE (
        SELECT
            COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND id != NEW.id
          AND deleted_at IS NULL
    ) + COALESCE(NEW.debit_amount, 0) - COALESCE(NEW.credit_amount, 0) != 0
    AND NEW.deleted_at IS NULL
    AND (
        SELECT COUNT(*)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND id != NEW.id
          AND deleted_at IS NULL
    ) >= 1;
END;

-- ============================================================================
-- STEP 5: Recreate accounts with extended CHECK constraint
-- ============================================================================

-- Update accounts CHECK constraint for new types
-- SQLite doesn't support ALTER CHECK, so recreate table
CREATE TABLE accounts_backup AS SELECT * FROM accounts;

DROP TABLE accounts;

CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
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
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment', 'loan', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'external')),
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

PRAGMA foreign_keys = ON;
