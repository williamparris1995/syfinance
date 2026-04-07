-- Create chart_of_accounts table (科目表)
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id TEXT PRIMARY KEY NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    level INTEGER NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    parent_code VARCHAR(10),
    balance_direction VARCHAR(10) NOT NULL,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (account_type IN ('asset', 'liability', 'equity', 'income', 'expense')),
    CHECK (balance_direction IN ('debit', 'credit')),
    CHECK (level > 0),
    FOREIGN KEY (parent_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT
);

-- Create indexes
CREATE INDEX idx_chart_of_accounts_code ON chart_of_accounts(code);
CREATE INDEX idx_chart_of_accounts_parent ON chart_of_accounts(parent_code);
CREATE INDEX idx_chart_of_accounts_type ON chart_of_accounts(account_type);

-- Insert default chart of accounts following 中国会计准则
INSERT INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction) VALUES
    -- 资产类 (Assets) 1000-1999
    (lower(hex(randomblob(16))), '1001', '库存现金', 1, 'asset', NULL, 'debit'),
    (lower(hex(randomblob(16))), '1002', '银行存款', 1, 'asset', NULL, 'debit'),
    (lower(hex(randomblob(16))), '1012', '其他货币资金', 1, 'asset', NULL, 'debit'),
    (lower(hex(randomblob(16))), '1101', '交易性金融资产', 1, 'asset', NULL, 'debit'),
    (lower(hex(randomblob(16))), '1122', '应收账款', 1, 'asset', NULL, 'debit'),
    (lower(hex(randomblob(16))), '1221', '其他应收款', 1, 'asset', NULL, 'debit'),
    
    -- 负债类 (Liabilities) 2000-2999
    (lower(hex(randomblob(16))), '2001', '短期借款', 1, 'liability', NULL, 'credit'),
    (lower(hex(randomblob(16))), '2201', '应付账款', 1, 'liability', NULL, 'credit'),
    (lower(hex(randomblob(16))), '2202', '应付职工薪酬', 1, 'liability', NULL, 'credit'),
    (lower(hex(randomblob(16))), '2501', '长期借款', 1, 'liability', NULL, 'credit'),
    
    -- 权益类 (Equity) 3000-3999
    (lower(hex(randomblob(16))), '3001', '实收资本', 1, 'equity', NULL, 'credit'),
    (lower(hex(randomblob(16))), '3101', '资本公积', 1, 'equity', NULL, 'credit'),
    (lower(hex(randomblob(16))), '4001', '本年利润', 1, 'equity', NULL, 'credit'),
    
    -- 收入类 (Income) 4000-4999
    (lower(hex(randomblob(16))), '6001', '主营业务收入', 1, 'income', NULL, 'credit'),
    (lower(hex(randomblob(16))), '6051', '其他业务收入', 1, 'income', NULL, 'credit'),
    (lower(hex(randomblob(16))), '6111', '投资收益', 1, 'income', NULL, 'credit'),
    
    -- 支出类 (Expenses) 5000-5999
    (lower(hex(randomblob(16))), '6401', '主营业务成本', 1, 'expense', NULL, 'debit'),
    (lower(hex(randomblob(16))), '6601', '销售费用', 1, 'expense', NULL, 'debit'),
    (lower(hex(randomblob(16))), '6602', '管理费用', 1, 'expense', NULL, 'debit'),
    (lower(hex(randomblob(16))), '6603', '财务费用', 1, 'expense', NULL, 'debit');
