-- Seed comprehensive chart of accounts based on IFRS / CAS personal finance needs
-- Reference: IAS 1, IFRS 9, CAS 企业会计准则

-- ============================================================================
-- Assets (1000-1999): 资产类
-- ============================================================================

-- Level 2: Current assets (流动资产)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    -- Monetary assets
    ('coa-1121', '1121', '应收利息', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-1122', '1122', '应收股利', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),

    -- Non-current assets (非流动资产)
    ('coa-1501', '1501', '持有至到期投资', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-1511', '1511', '长期股权投资', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-1531', '1531', '长期应收款', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-1601', '1601', '固定资产', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-1701', '1701', '无形资产', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- ============================================================================
-- Liabilities (2000-2999): 负债类
-- ============================================================================

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    -- Current liabilities (流动负债)
    ('coa-2101', '2101', '交易性金融负债', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-2231', '2231', '应付利息', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-2241', '2241', '其他应付款', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),

    -- Non-current liabilities (非流动负债)
    ('coa-2502', '2502', '应付债券', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-2701', '2701', '长期应付款', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-2801', '2801', '预计负债', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- ============================================================================
-- Equity (3000-3999): 权益类
-- ============================================================================

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-3001', '3001', '实收资本', 2, 'equity', '3000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-3002', '3002', '资本公积', 2, 'equity', '3000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-3101', '3101', '本年利润', 2, 'equity', '3000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-3102', '3102', '利润分配', 2, 'equity', '3000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-3201', '3201', '初始资金', 2, 'equity', '3000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- ============================================================================
-- Income (4000-4999): 收入类
-- ============================================================================

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-4201', '4201', '利息收入', 2, 'income', '4000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-4301', '4301', '投资收益', 2, 'income', '4000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-4401', '4401', '其他业务收入', 2, 'income', '4000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-4501', '4501', '营业外收入', 2, 'income', '4000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- ============================================================================
-- Expenses (5000-5999): 费用类
-- ============================================================================

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-5101', '5101', '利息支出', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5301', '5301', '管理费用', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5501', '5501', '保险费用', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5601', '5601', '税费', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5701', '5701', '捐赠支出', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-5801', '5801', '营业外支出', 2, 'expense', '5000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));
