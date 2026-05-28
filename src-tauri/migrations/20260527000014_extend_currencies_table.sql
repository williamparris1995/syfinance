-- 添加 name 列
ALTER TABLE currencies ADD COLUMN name VARCHAR(50) NOT NULL DEFAULT '';

-- 添加 is_active 列
ALTER TABLE currencies ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- 添加 created_at 列
ALTER TABLE currencies ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 添加 last_updated 列（重命名现有的 updated_at）
ALTER TABLE currencies RENAME COLUMN updated_at TO last_updated;

-- 更新现有货币的 name 字段
UPDATE currencies SET name = '人民币' WHERE code = 'CNY';
UPDATE currencies SET name = '美元' WHERE code = 'USD';
UPDATE currencies SET name = '欧元' WHERE code = 'EUR';

-- 插入新的默认货币
INSERT OR IGNORE INTO currencies (id, code, name, symbol, exchange_rate) VALUES
    (lower(hex(randomblob(16))), 'GBP', '英镑', '£', 9.20),
    (lower(hex(randomblob(16))), 'JPY', '日元', '¥', 0.048);
