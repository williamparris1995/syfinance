CREATE TABLE IF NOT EXISTS cloud_settings (
    provider TEXT NOT NULL,
    server_url TEXT,
    port INTEGER,
    username TEXT,
    password TEXT,
    remote_path TEXT,
    access_token TEXT,
    refresh_token TEXT,
    auto_upload TEXT NOT NULL DEFAULT 'on_backup',
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_upload_at TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
