-- Create currencies table
CREATE TABLE IF NOT EXISTS currencies (
    id TEXT PRIMARY KEY NOT NULL,
    code VARCHAR(3) NOT NULL UNIQUE,
    symbol VARCHAR(10) NOT NULL,
    exchange_rate DECIMAL(20,10) NOT NULL DEFAULT 1.0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (exchange_rate > 0)
);

-- Create index on currency code
CREATE INDEX idx_currencies_code ON currencies(code);

-- Insert default currencies
INSERT INTO currencies (id, code, symbol, exchange_rate) VALUES
    (lower(hex(randomblob(16))), 'CNY', '¥', 1.0),
    (lower(hex(randomblob(16))), 'USD', '$', 7.2),
    (lower(hex(randomblob(16))), 'EUR', '€', 7.8);
