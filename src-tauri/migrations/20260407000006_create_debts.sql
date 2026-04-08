-- Create debts table (债务表)
CREATE TABLE IF NOT EXISTS debts (
    id TEXT PRIMARY KEY NOT NULL,
    debt_type VARCHAR(20) NOT NULL,
    counterparty VARCHAR(100) NOT NULL,
    principal DECIMAL(20,2) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    interest_rate DECIMAL(5,4),
    start_date DATE NOT NULL,
    due_date DATE,
    payment_method VARCHAR(20),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (debt_type IN ('borrowed_out', 'borrowed_in', 'credit_card', 'loan')),
    CHECK (principal >= 0),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    CHECK (payment_method IS NULL OR payment_method IN ('equal_principal', 'equal_payment', 'bullet', 'custom'))
);

-- Create indexes
CREATE INDEX idx_debts_type ON debts(debt_type);
CREATE INDEX idx_debts_due_date ON debts(due_date);
CREATE INDEX idx_debts_deleted ON debts(deleted_at);
