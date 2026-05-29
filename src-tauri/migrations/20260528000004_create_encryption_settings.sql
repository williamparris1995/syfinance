CREATE TABLE IF NOT EXISTS encryption_settings (
    salt TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
