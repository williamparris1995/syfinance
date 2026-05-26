-- Create debt_details table (1:1 with accounts for debt-specific data)
CREATE TABLE IF NOT EXISTS debt_details (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT UNIQUE NOT NULL,
    counterparty VARCHAR(100) NOT NULL,
    interest_rate DECIMAL(5,4) NOT NULL DEFAULT 0,
    amortization_method VARCHAR(20) NOT NULL DEFAULT 'LumpSum',
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    total_principal DECIMAL(20,2) NOT NULL,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (amortization_method IN ('EqualPrincipalInterest', 'EqualPrincipal', 'LumpSum')),
    CHECK (interest_rate >= 0),
    CHECK (total_principal >= 0),
    CHECK (due_date >= start_date),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
);

CREATE INDEX idx_debt_details_account ON debt_details(account_id);
CREATE INDEX idx_debt_details_due_date ON debt_details(due_date);
CREATE INDEX idx_debt_details_deleted ON debt_details(deleted_at);

-- Create debt_payment_schedule table (1:N with debt_details)
CREATE TABLE IF NOT EXISTS debt_payment_schedule (
    id TEXT PRIMARY KEY NOT NULL,
    debt_id TEXT NOT NULL,
    payment_date DATE NOT NULL,
    principal_amount DECIMAL(20,2) NOT NULL,
    interest_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(20,2) NOT NULL,
    paid BOOLEAN NOT NULL DEFAULT 0,
    transaction_id TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (principal_amount >= 0),
    CHECK (interest_amount >= 0),
    CHECK (total_amount >= 0),
    FOREIGN KEY (debt_id) REFERENCES debt_details(id) ON DELETE CASCADE,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
);

CREATE INDEX idx_debt_payment_schedule_debt ON debt_payment_schedule(debt_id);
CREATE INDEX idx_debt_payment_schedule_date ON debt_payment_schedule(payment_date);
CREATE INDEX idx_debt_payment_schedule_paid ON debt_payment_schedule(paid);
CREATE INDEX idx_debt_payment_schedule_deleted ON debt_payment_schedule(deleted_at);
