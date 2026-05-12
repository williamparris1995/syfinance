-- Create transaction_operations table for Operation-based CRDT
CREATE TABLE IF NOT EXISTS transaction_operations (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL,
    operation_type VARCHAR(20) NOT NULL,
    entry_id TEXT,
    payload TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    device_id TEXT NOT NULL,
    sequence_number INTEGER NOT NULL,
    synced_at TIMESTAMP,
    CHECK (operation_type IN ('CREATE', 'ADD_ENTRY', 'UPDATE_ENTRY', 
                              'DELETE_ENTRY', 'UPDATE_DESCRIPTION')),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_transaction_operations_transaction ON transaction_operations(transaction_id);
CREATE INDEX idx_transaction_operations_device ON transaction_operations(device_id);
CREATE INDEX idx_transaction_operations_sync ON transaction_operations(synced_at);
CREATE UNIQUE INDEX idx_transaction_operations_sequence ON transaction_operations(device_id, sequence_number);
