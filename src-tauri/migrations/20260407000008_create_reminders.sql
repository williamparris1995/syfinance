-- Create reminders table (提醒表)
CREATE TABLE IF NOT EXISTS reminders (
    id TEXT PRIMARY KEY NOT NULL,
    reminder_type VARCHAR(20) NOT NULL,
    related_entity_id TEXT,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    remind_at TIMESTAMP NOT NULL,
    repeat_pattern VARCHAR(50),
    notified BOOLEAN NOT NULL DEFAULT 0,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (reminder_type IN ('debt_payment', 'bill_due', 'custom'))
);

-- Create indexes
CREATE INDEX idx_reminders_type ON reminders(reminder_type);
CREATE INDEX idx_reminders_remind_at ON reminders(remind_at);
CREATE INDEX idx_reminders_notified ON reminders(notified);
CREATE INDEX idx_reminders_deleted ON reminders(deleted_at);
