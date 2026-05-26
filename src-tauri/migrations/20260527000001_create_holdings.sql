-- Migration: Create holdings system tables
-- Date: 2026-05-27
-- Description: Add securities reference table, holdings (computed from transactions),
--              and holding_transactions (append-only ledger) for asset holdings tracking

-- ============================================================================
-- Securities reference table
-- ============================================================================
CREATE TABLE IF NOT EXISTS securities (
    id TEXT PRIMARY KEY NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    exchange VARCHAR(30),
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    current_price DECIMAL(20,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (type IN ('stock', 'fund', 'etf', 'bond', 'gold', 'option', 'other')),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

CREATE INDEX idx_securities_symbol ON securities(symbol);
CREATE INDEX idx_securities_type ON securities(type);
CREATE INDEX idx_securities_deleted ON securities(deleted_at);

-- ============================================================================
-- Holdings table (computed from holding transactions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS holdings (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL,
    security_id TEXT NOT NULL,
    quantity DECIMAL(20,8) NOT NULL DEFAULT 0,
    avg_cost DECIMAL(20,4) NOT NULL DEFAULT 0,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    UNIQUE(account_id, security_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (security_id) REFERENCES securities(id) ON DELETE RESTRICT
);

CREATE INDEX idx_holdings_account ON holdings(account_id);
CREATE INDEX idx_holdings_security ON holdings(security_id);
CREATE INDEX idx_holdings_deleted ON holdings(deleted_at);

-- ============================================================================
-- Holding transactions (append-only ledger)
-- ============================================================================
CREATE TABLE IF NOT EXISTS holding_transactions (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL,
    security_id TEXT NOT NULL,
    type VARCHAR(10) NOT NULL,
    quantity DECIMAL(20,8) NOT NULL,
    price DECIMAL(20,4) NOT NULL,
    amount DECIMAL(20,2) NOT NULL,
    fee DECIMAL(20,2) NOT NULL DEFAULT 0,
    trade_date DATE NOT NULL,
    transaction_id TEXT,
    notes TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (type IN ('BUY', 'SELL', 'DIVIDEND', 'SPLIT')),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (security_id) REFERENCES securities(id) ON DELETE RESTRICT,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
);

CREATE INDEX idx_ht_account ON holding_transactions(account_id);
CREATE INDEX idx_ht_security ON holding_transactions(security_id);
CREATE INDEX idx_ht_date ON holding_transactions(trade_date);
CREATE INDEX idx_ht_deleted ON holding_transactions(deleted_at);
CREATE INDEX idx_ht_transaction ON holding_transactions(transaction_id);
