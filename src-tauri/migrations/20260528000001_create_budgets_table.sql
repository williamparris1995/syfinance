-- src-tauri/migrations/20260528000001_create_budgets_table.sql
-- 预算表
CREATE TABLE IF NOT EXISTS budgets (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    month VARCHAR(7) NOT NULL, -- 格式: YYYY-MM
    total_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    UNIQUE(month, currency_code)
);

-- 预算项表
CREATE TABLE IF NOT EXISTS budget_items (
    id TEXT PRIMARY KEY NOT NULL,
    budget_id TEXT NOT NULL,
    category_account_id TEXT NOT NULL, -- 关联到 Expense 类型的账户
    planned_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    actual_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE,
    FOREIGN KEY (category_account_id) REFERENCES accounts(id),
    UNIQUE(budget_id, category_account_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month);
CREATE INDEX IF NOT EXISTS idx_budget_items_budget_id ON budget_items(budget_id);
CREATE INDEX IF NOT EXISTS idx_budget_items_category ON budget_items(category_account_id);
