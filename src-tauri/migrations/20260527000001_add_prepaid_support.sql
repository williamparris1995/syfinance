-- Migration: Add prepaid account support
-- 1. accounts 表新增 low_balance_threshold 列
ALTER TABLE accounts ADD COLUMN low_balance_threshold TEXT;

-- 2. 创建 top_up_records 扩展表
CREATE TABLE IF NOT EXISTS top_up_records (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    transaction_id TEXT REFERENCES transactions(id),
    paid_amount TEXT NOT NULL,
    bonus_amount TEXT NOT NULL DEFAULT '0',
    total_credited TEXT NOT NULL,
    top_up_date TEXT NOT NULL,
    expiry_date TEXT,
    source_account_id TEXT NOT NULL REFERENCES accounts(id),
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
);

-- 3. chart_of_accounts 新增科目
-- 1123 预付账款 (L2)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-1123', '1123', '预付账款', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- 1123 L3 子科目
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-112301', '112301', '储值卡', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-112302', '112302', '平台余额', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-112303', '112303', '话费', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- 490101 赠送/优惠收入 (L3)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-490101', '490101', '赠送/优惠收入', 3, 'income', '4901', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));
