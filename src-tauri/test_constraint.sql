-- Test double-entry constraint violation
-- This should fail because debit_sum != credit_sum

-- First, create a test transaction
INSERT INTO transactions (id, transaction_date, description) 
VALUES ('test-txn-001', '2026-04-07', 'Test unbalanced transaction');

-- Create a test account
INSERT INTO accounts (id, name, account_type, chart_of_account_code, currency_code, balance)
VALUES ('test-acc-001', 'Test Account 1', 'cash', '1001', 'CNY', 0.00);

INSERT INTO accounts (id, name, account_type, chart_of_account_code, currency_code, balance)
VALUES ('test-acc-002', 'Test Account 2', 'bank', '1002', 'CNY', 0.00);

-- Insert first entry (debit 100)
INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount)
VALUES ('test-entry-001', 'test-txn-001', 'test-acc-001', '1001', 100.00, NULL);

-- This should FAIL: trying to insert credit 50 (unbalanced: 100 debit != 50 credit)
INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount)
VALUES ('test-entry-002', 'test-txn-001', 'test-acc-002', '1002', NULL, 50.00);
