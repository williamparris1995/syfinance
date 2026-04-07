-- Create transaction_entries table (交易分录表)
CREATE TABLE IF NOT EXISTS transaction_entries (
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

-- Create indexes
CREATE INDEX idx_transaction_entries_transaction ON transaction_entries(transaction_id);
CREATE INDEX idx_transaction_entries_account ON transaction_entries(account_id);
CREATE INDEX idx_transaction_entries_chart_code ON transaction_entries(chart_of_account_code);
CREATE INDEX idx_transaction_entries_deleted ON transaction_entries(deleted_at);

-- Create trigger to enforce double-entry bookkeeping (debit_sum = credit_sum per transaction)
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
