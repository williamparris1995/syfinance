-- Add real created_at column to accounts
ALTER TABLE accounts ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;