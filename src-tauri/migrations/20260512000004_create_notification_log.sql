-- Create notification_log table (通知日志表)
CREATE TABLE IF NOT EXISTS notification_log (
    id TEXT PRIMARY KEY NOT NULL,
    reminder_id TEXT NOT NULL,
    notification_type VARCHAR(20) NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    CHECK (notification_type IN ('IN_APP', 'OS_NATIVE', 'CLOUD_PUSH')),
    CHECK (status IN ('SUCCESS', 'FAILED', 'DISMISSED')),
    FOREIGN KEY (reminder_id) REFERENCES reminders(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_notification_log_reminder ON notification_log(reminder_id);
CREATE INDEX idx_notification_log_sent ON notification_log(sent_at);
