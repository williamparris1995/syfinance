-- Auto backup settings (singleton row)
CREATE TABLE IF NOT EXISTS auto_backup_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    interval_hours INTEGER NOT NULL DEFAULT 24,
    max_backups INTEGER NOT NULL DEFAULT 5,
    last_backup_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed the singleton row
INSERT OR IGNORE INTO auto_backup_settings (id, enabled, interval_hours, max_backups)
VALUES (1, FALSE, 24, 5);
