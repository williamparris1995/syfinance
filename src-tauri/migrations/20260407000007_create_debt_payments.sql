-- Create debt_payments table (债务还款表)
CREATE TABLE IF NOT EXISTS debt_payments (
    id TEXT PRIMARY KEY NOT NULL,
    debt_id TEXT NOT NULL,
    payment_date DATE NOT NULL,
    principal_amount DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    interest_amount DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(20,2) NOT NULL,
    paid BOOLEAN NOT NULL DEFAULT 0,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (principal_amount >= 0),
    CHECK (interest_amount >= 0),
    CHECK (total_amount >= 0),
    CHECK (total_amount = principal_amount + interest_amount),
    FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE RESTRICT
);

-- Create indexes
CREATE INDEX idx_debt_payments_debt ON debt_payments(debt_id);
CREATE INDEX idx_debt_payments_date ON debt_payments(payment_date);
CREATE INDEX idx_debt_payments_paid ON debt_payments(paid);
CREATE INDEX idx_debt_payments_deleted ON debt_payments(deleted_at);
