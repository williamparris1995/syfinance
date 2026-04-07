-- Seed standard 中国会计准则 (Chinese Accounting Standards) accounts

-- Level 1 accounts (一级科目)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES 
    ('coa-1000', '1000', '资产', 1, 'asset', NULL, 'debit', datetime('now')),
    ('coa-2000', '2000', '负债', 1, 'liability', NULL, 'credit', datetime('now')),
    ('coa-3000', '3000', '权益', 1, 'equity', NULL, 'credit', datetime('now')),
    ('coa-4000', '4000', '收入', 1, 'income', NULL, 'credit', datetime('now')),
    ('coa-5000', '5000', '支出', 1, 'expense', NULL, 'debit', datetime('now'));

-- Level 2 accounts (二级科目) - Common ones for personal finance
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES 
    -- Assets
    ('coa-1001', '1001', '库存现金', 2, 'asset', '1000', 'debit', datetime('now')),
    ('coa-1002', '1002', '银行存款', 2, 'asset', '1000', 'debit', datetime('now')),
    ('coa-1012', '1012', '其他货币资金', 2, 'asset', '1000', 'debit', datetime('now')),
    
    -- Liabilities
    ('coa-2001', '2001', '短期借款', 2, 'liability', '2000', 'credit', datetime('now')),
    ('coa-2201', '2201', '应付账款', 2, 'liability', '2000', 'credit', datetime('now')),
    
    -- Income
    ('coa-4001', '4001', '主营业务收入', 2, 'income', '4000', 'credit', datetime('now')),
    
    -- Expenses
    ('coa-5001', '5001', '主营业务成本', 2, 'expense', '5000', 'debit', datetime('now')),
    ('coa-5201', '5201', '财务费用', 2, 'expense', '5000', 'debit', datetime('now'));
