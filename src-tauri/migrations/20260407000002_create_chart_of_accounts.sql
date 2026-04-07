-- Create chart_of_accounts table (科目表)
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id TEXT PRIMARY KEY NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    level INTEGER NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    parent_code VARCHAR(10),
    balance_direction VARCHAR(10) NOT NULL,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (account_type IN ('asset', 'liability', 'equity', 'income', 'expense')),
    CHECK (balance_direction IN ('debit', 'credit')),
    CHECK (level > 0),
    FOREIGN KEY (parent_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT
);

-- Create indexes
CREATE INDEX idx_chart_of_accounts_code ON chart_of_accounts(code);
CREATE INDEX idx_chart_of_accounts_parent ON chart_of_accounts(parent_code);
CREATE INDEX idx_chart_of_accounts_type ON chart_of_accounts(account_type);
