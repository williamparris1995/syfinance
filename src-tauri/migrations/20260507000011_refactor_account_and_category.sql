-- Migration: Refactor Account model and introduce Category
-- Date: 2026-05-07
-- Description: 
--   1. Remove chart_of_account_code from accounts (breaking change)
--   2. Add credit card/loan fields to accounts
--   3. Create categories table for income/expense classification
--   4. Add category_id to transaction_entries

-- ============================================================================
-- STEP 1: Create categories table
-- ============================================================================

CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    category_type VARCHAR(20) NOT NULL,
    chart_code VARCHAR(10) NOT NULL,
    parent_id TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (category_type IN ('income', 'expense')),
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
    -- Note: chart_code is for reference only, no FK constraint to allow flexibility
);

CREATE INDEX idx_categories_type ON categories(category_type);
CREATE INDEX idx_categories_chart_code ON categories(chart_code);
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_deleted ON categories(deleted_at);

-- ============================================================================
-- STEP 2: Seed default categories
-- ============================================================================

-- Income categories (收入分类)
INSERT INTO categories (id, name, icon, color, category_type, chart_code, parent_id, updated_at) VALUES
('cat-income-salary', '工资收入', '💰', '#10B981', 'income', '4001', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-income-bonus', '奖金', '🎁', '#10B981', 'income', '4001', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-income-investment', '投资收益', '📈', '#10B981', 'income', '4101', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-income-other', '其他收入', '💵', '#10B981', 'income', '4901', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- Expense categories (支出分类)
INSERT INTO categories (id, name, icon, color, category_type, chart_code, parent_id, updated_at) VALUES
('cat-expense-food', '餐饮', '🍔', '#EF4444', 'expense', '5401', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-transport', '交通', '🚗', '#F59E0B', 'expense', '5402', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-shopping', '购物', '🛍️', '#EC4899', 'expense', '5403', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-entertainment', '娱乐', '🎮', '#8B5CF6', 'expense', '5404', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-housing', '住房', '🏠', '#3B82F6', 'expense', '5405', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-healthcare', '医疗', '🏥', '#06B6D4', 'expense', '5406', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-education', '教育', '📚', '#14B8A6', 'expense', '5407', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-utilities', '水电煤', '💡', '#84CC16', 'expense', '5408', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now')),
('cat-expense-other', '其他支出', '📦', '#6B7280', 'expense', '5901', NULL, strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- ============================================================================
-- STEP 3: Backup existing accounts data
-- ============================================================================

-- Create temporary backup table
CREATE TABLE accounts_backup AS SELECT * FROM accounts;

-- ============================================================================
-- STEP 4: Recreate accounts table without chart_of_account_code
-- ============================================================================

-- Drop the old accounts table (this will fail if there are foreign key constraints)
-- We need to use PRAGMA foreign_keys=OFF temporarily
PRAGMA foreign_keys=OFF;

DROP TABLE accounts;

-- Recreate accounts table with new schema
CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    -- New fields for credit cards and loans
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    -- Sync metadata
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment', 'loan', 'other')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

-- Restore data from backup (excluding chart_of_account_code)
INSERT INTO accounts (id, name, account_type, currency_code, balance, deleted_at, updated_at, device_id, synced_at)
SELECT id, name, account_type, currency_code, balance, deleted_at, updated_at, device_id, synced_at
FROM accounts_backup;

-- Drop backup table
DROP TABLE accounts_backup;

-- Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);

-- Re-enable foreign keys
PRAGMA foreign_keys=ON;

-- ============================================================================
-- STEP 5: Add category_id to transaction_entries
-- ============================================================================

-- Add category_id column (nullable for backward compatibility)
ALTER TABLE transaction_entries ADD COLUMN category_id TEXT;

-- Add foreign key constraint (SQLite doesn't support ALTER TABLE ADD CONSTRAINT)
-- We need to recreate the table

-- Backup transaction_entries
CREATE TABLE transaction_entries_backup AS SELECT * FROM transaction_entries;

-- Drop old table
PRAGMA foreign_keys=OFF;
DROP TABLE transaction_entries;

-- Recreate with category_id
CREATE TABLE transaction_entries (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    chart_of_account_code VARCHAR(10) NOT NULL,
    category_id TEXT,
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
    FOREIGN KEY (chart_of_account_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- Restore data
INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount, note, deleted_at, updated_at, device_id, synced_at)
SELECT id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount, note, deleted_at, updated_at, device_id, synced_at
FROM transaction_entries_backup;

-- Drop backup
DROP TABLE transaction_entries_backup;

-- Recreate indexes
CREATE INDEX idx_transaction_entries_transaction ON transaction_entries(transaction_id);
CREATE INDEX idx_transaction_entries_account ON transaction_entries(account_id);
CREATE INDEX idx_transaction_entries_chart_code ON transaction_entries(chart_of_account_code);
CREATE INDEX idx_transaction_entries_category ON transaction_entries(category_id);
CREATE INDEX idx_transaction_entries_deleted ON transaction_entries(deleted_at);

-- Recreate triggers
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

-- Re-enable foreign keys
PRAGMA foreign_keys=ON;

-- ============================================================================
-- Migration complete
-- ============================================================================
