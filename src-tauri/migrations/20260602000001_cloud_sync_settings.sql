-- Cloud sync settings (singleton row)
CREATE TABLE IF NOT EXISTS cloud_sync_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    interval_minutes INTEGER NOT NULL DEFAULT 30,
    last_sync_at TEXT,
    last_sync_status TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed the singleton row
INSERT OR IGNORE INTO cloud_sync_settings (id, auto_sync_enabled, interval_minutes)
VALUES (1, FALSE, 30);
