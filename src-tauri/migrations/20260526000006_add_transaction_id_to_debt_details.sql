ALTER TABLE debt_details ADD COLUMN transaction_id TEXT REFERENCES transactions(id) ON DELETE SET NULL;
