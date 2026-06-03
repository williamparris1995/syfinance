-- Performance indexes for high-frequency queries

-- Transaction entries (most queried table)
CREATE INDEX IF NOT EXISTS idx_te_account_id ON transaction_entries(account_id);
CREATE INDEX IF NOT EXISTS idx_te_transaction_id ON transaction_entries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_te_deleted_at ON transaction_entries(deleted_at);

-- Transactions
CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_tx_deleted_at ON transactions(deleted_at);

-- Debt details
CREATE INDEX IF NOT EXISTS idx_dd_account_id ON debt_details(account_id);

-- Tags
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);

-- Holding transactions
CREATE INDEX IF NOT EXISTS idx_ht_account_security ON holding_transactions(account_id, security_id);
CREATE INDEX IF NOT EXISTS idx_ht_trade_date ON holding_transactions(trade_date);
