-- Disable FK checks during migration (DROP TABLE and ADD COLUMN with REFERENCES
-- would otherwise violate FK constraints on transaction_entries and transactions)
PRAGMA foreign_keys = OFF;

-- Create categories table
CREATE TABLE categories (
    id BLOB PRIMARY KEY,
    name TEXT NOT NULL,
    category_type TEXT CHECK(category_type IN ('income', 'expense')) NOT NULL,
    icon TEXT DEFAULT '💰',
    color TEXT DEFAULT '#10B981',
    parent_id BLOB REFERENCES categories(id),
    is_system BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    device_id TEXT,
    sync_vector INTEGER DEFAULT 0
);

-- Recreate chart_of_accounts table with new schema
DROP TABLE IF EXISTS chart_of_accounts;

CREATE TABLE chart_of_accounts (
    id BLOB PRIMARY KEY,
    standard TEXT CHECK(standard IN ('china_cas', 'international', 'us_gaap', 'custom')) NOT NULL,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_en TEXT,
    account_type TEXT NOT NULL,
    parent_id BLOB REFERENCES chart_of_accounts(id),
    level INTEGER CHECK(level BETWEEN 1 AND 4),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert preset categories (income)
INSERT INTO categories (id, name, category_type, icon, color, is_system, sort_order) VALUES
    (X'00000000000000000000000000000001', '工资收入', 'income', '💰', '#10B981', TRUE, 1),
    (X'00000000000000000000000000000002', '投资收益', 'income', '📈', '#3B82F6', TRUE, 2),
    (X'00000000000000000000000000000003', '兼职收入', 'income', '💼', '#8B5CF6', TRUE, 3),
    (X'00000000000000000000000000000004', '红包礼金', 'income', '🎁', '#EF4444', TRUE, 4);

-- Insert preset categories (expense)
INSERT INTO categories (id, name, category_type, icon, color, is_system, sort_order) VALUES
    (X'00000000000000000000000000000005', '餐饮', 'expense', '🍔', '#F59E0B', TRUE, 1),
    (X'00000000000000000000000000000006', '交通', 'expense', '🚗', '#06B6D4', TRUE, 2),
    (X'00000000000000000000000000000007', '住房', 'expense', '🏠', '#6366F1', TRUE, 3),
    (X'00000000000000000000000000000008', '购物', 'expense', '🛍️', '#EC4899', TRUE, 4),
    (X'00000000000000000000000000000009', '娱乐', 'expense', '🎮', '#F97316', TRUE, 5);

-- Insert preset ChartOfAccounts (China CAS)
INSERT INTO chart_of_accounts (id, standard, code, name, name_en, account_type, level) VALUES
    (X'0000000000000000000000000000000A', 'china_cas', '1001', '库存现金', 'Cash on Hand', 'Cash', 1),
    (X'0000000000000000000000000000000B', 'china_cas', '1002', '银行存款', 'Bank Deposits', 'Bank', 1),
    (X'0000000000000000000000000000000C', 'china_cas', '100201', '活期存款', 'Demand Deposits', 'Bank', 2),
    (X'0000000000000000000000000000000D', 'china_cas', '100202', '定期存款', 'Time Deposits', 'Bank', 2),
    (X'0000000000000000000000000000000E', 'china_cas', '1101', '交易性金融资产', 'Trading Financial Assets', 'Investment', 1),
    (X'0000000000000000000000000000000F', 'china_cas', '1221', '其他应收款', 'Other Receivables', 'BorrowedOut', 1),
    (X'00000000000000000000000000000010', 'china_cas', '2001', '短期借款', 'Short-term Borrowings', 'BorrowedIn', 1),
    (X'00000000000000000000000000000011', 'china_cas', '1123', '预付账款', 'Prepayments', 'Prepaid', 1);

-- Alter accounts table
ALTER TABLE accounts ADD COLUMN status TEXT DEFAULT 'active'
    CHECK(status IN ('active', 'archived', 'hidden'));
ALTER TABLE accounts ADD COLUMN opened_at TIMESTAMP;

-- Alter transactions table
ALTER TABLE transactions ADD COLUMN category_id BLOB REFERENCES categories(id) ON DELETE SET NULL;

-- Re-enable FK checks
PRAGMA foreign_keys = ON;
