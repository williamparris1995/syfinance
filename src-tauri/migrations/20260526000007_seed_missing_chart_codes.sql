-- Seed missing chart of accounts codes used by new account types

INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    -- 1221: 其他应收款 (for BorrowedOut receivable tracking)
    ('coa-1221', '1221', '其他应收款', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    -- 1101: 交易性金融资产 (for Investment tracking)
    ('coa-1101', '1101', '交易性金融资产', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    -- 2501: 长期借款 (for long-term borrowings)
    ('coa-2501', '2501', '长期借款', 2, 'liability', '2000', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));
