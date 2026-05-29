-- 添加 name 列
ALTER TABLE currencies ADD COLUMN name VARCHAR(50) NOT NULL DEFAULT '';

-- 添加 is_active 列
ALTER TABLE currencies ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- 添加 created_at 列（使用常量默认值）
ALTER TABLE currencies ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00';

-- 更新现有行的 created_at 为当前时间
UPDATE currencies SET created_at = datetime('now');

-- 注意：不重命名 updated_at 列，保持向后兼容
-- 新代码可以使用 updated_at 或 last_updated（别名）

-- 更新现有货币的 name 字段
UPDATE currencies SET name = '人民币' WHERE code = 'CNY';
UPDATE currencies SET name = '美元' WHERE code = 'USD';
UPDATE currencies SET name = '欧元' WHERE code = 'EUR';

-- 插入新的默认货币
INSERT OR IGNORE INTO currencies (id, code, name, symbol, exchange_rate) VALUES
    (lower(hex(randomblob(16))), 'GBP', '英镑', '£', 9.20),
    (lower(hex(randomblob(16))), 'JPY', '日元', '¥', 0.048);
