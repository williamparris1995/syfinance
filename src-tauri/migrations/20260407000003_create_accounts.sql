-- Create accounts table (账户表)
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    chart_of_account_code VARCHAR(10) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment', 'loan', 'other')),
    FOREIGN KEY (chart_of_account_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT,
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

-- Create indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_chart_code ON accounts(chart_of_account_code);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);
