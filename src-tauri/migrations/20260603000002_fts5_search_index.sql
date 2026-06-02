-- Create FTS5 virtual tables for full-text search
-- Using content= and content_rowid= for external content mode

CREATE VIRTUAL TABLE IF NOT EXISTS fts_accounts USING fts5(
    name,
    content='accounts',
    content_rowid='rowid',
    tokenize='unicode61'
);

CREATE VIRTUAL TABLE IF NOT EXISTS fts_transactions USING fts5(
    description,
    content='transactions',
    content_rowid='rowid',
    tokenize='unicode61'
);

CREATE VIRTUAL TABLE IF NOT EXISTS fts_debts USING fts5(
    counterparty,
    content='debt_details',
    content_rowid='rowid',
    tokenize='unicode61'
);

CREATE VIRTUAL TABLE IF NOT EXISTS fts_goals USING fts5(
    name,
    content='goals',
    content_rowid='rowid',
    tokenize='unicode61'
);

CREATE VIRTUAL TABLE IF NOT EXISTS fts_tags USING fts5(
    name,
    content='tags',
    content_rowid='rowid',
    tokenize='unicode61'
);

-- Triggers to keep FTS index in sync

-- Accounts
CREATE TRIGGER IF NOT EXISTS fts_accounts_ai AFTER INSERT ON accounts BEGIN
    INSERT INTO fts_accounts(rowid, name) VALUES (new.rowid, new.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_accounts_ad AFTER DELETE ON accounts BEGIN
    INSERT INTO fts_accounts(fts_accounts, rowid, name) VALUES('delete', old.rowid, old.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_accounts_au AFTER UPDATE ON accounts BEGIN
    INSERT INTO fts_accounts(fts_accounts, rowid, name) VALUES('delete', old.rowid, old.name);
    INSERT INTO fts_accounts(rowid, name) VALUES (new.rowid, new.name);
END;

-- Transactions
CREATE TRIGGER IF NOT EXISTS fts_transactions_ai AFTER INSERT ON transactions BEGIN
    INSERT INTO fts_transactions(rowid, description) VALUES (new.rowid, new.description);
END;
CREATE TRIGGER IF NOT EXISTS fts_transactions_ad AFTER DELETE ON transactions BEGIN
    INSERT INTO fts_transactions(fts_transactions, rowid, description) VALUES('delete', old.rowid, old.description);
END;
CREATE TRIGGER IF NOT EXISTS fts_transactions_au AFTER UPDATE ON transactions BEGIN
    INSERT INTO fts_transactions(fts_transactions, rowid, description) VALUES('delete', old.rowid, old.description);
    INSERT INTO fts_transactions(rowid, description) VALUES (new.rowid, new.description);
END;

-- Debts (debt_details)
CREATE TRIGGER IF NOT EXISTS fts_debts_ai AFTER INSERT ON debt_details BEGIN
    INSERT INTO fts_debts(rowid, counterparty) VALUES (new.rowid, new.counterparty);
END;
CREATE TRIGGER IF NOT EXISTS fts_debts_ad AFTER DELETE ON debt_details BEGIN
    INSERT INTO fts_debts(fts_debts, rowid, counterparty) VALUES('delete', old.rowid, old.counterparty);
END;
CREATE TRIGGER IF NOT EXISTS fts_debts_au AFTER UPDATE ON debt_details BEGIN
    INSERT INTO fts_debts(fts_debts, rowid, counterparty) VALUES('delete', old.rowid, old.counterparty);
    INSERT INTO fts_debts(rowid, counterparty) VALUES (new.rowid, new.counterparty);
END;

-- Goals
CREATE TRIGGER IF NOT EXISTS fts_goals_ai AFTER INSERT ON goals BEGIN
    INSERT INTO fts_goals(rowid, name) VALUES (new.rowid, new.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_goals_ad AFTER DELETE ON goals BEGIN
    INSERT INTO fts_goals(fts_goals, rowid, name) VALUES('delete', old.rowid, old.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_goals_au AFTER UPDATE ON goals BEGIN
    INSERT INTO fts_goals(fts_goals, rowid, name) VALUES('delete', old.rowid, old.name);
    INSERT INTO fts_goals(rowid, name) VALUES (new.rowid, new.name);
END;

-- Tags
CREATE TRIGGER IF NOT EXISTS fts_tags_ai AFTER INSERT ON tags BEGIN
    INSERT INTO fts_tags(rowid, name) VALUES (new.rowid, new.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_tags_ad AFTER DELETE ON tags BEGIN
    INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.rowid, old.name);
END;
CREATE TRIGGER IF NOT EXISTS fts_tags_au AFTER UPDATE ON tags BEGIN
    INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.rowid, old.name);
    INSERT INTO fts_tags(rowid, name) VALUES (new.rowid, new.name);
END;
