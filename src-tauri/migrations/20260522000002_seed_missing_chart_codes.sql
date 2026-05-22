-- Migration: Add missing chart_of_account codes
-- Categories migrated to accounts reference these codes which don't exist in
-- the original chart_of_accounts seed, causing FK violations on transaction_entries.

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-4901', '4901', '其他收入', 2, 'income', '4000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5901', '5901', '其他支出', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));
