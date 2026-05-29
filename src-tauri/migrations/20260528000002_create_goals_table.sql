-- src-tauri/migrations/20260528000002_create_goals_table.sql
-- 目标表
CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    goal_type VARCHAR(20) NOT NULL, -- 'savings', 'debt_payoff', 'investment'
    target_amount DECIMAL(20,10) NOT NULL,
    current_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    deadline DATE,
    linked_account_id TEXT, -- 关联的账户 ID
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    FOREIGN KEY (linked_account_id) REFERENCES accounts(id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_goals_type ON goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_goals_completed ON goals(is_completed);
CREATE INDEX IF NOT EXISTS idx_goals_deadline ON goals(deadline);
