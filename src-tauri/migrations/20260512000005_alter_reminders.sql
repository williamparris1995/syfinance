-- Migration: Enhance reminders table for notification system
-- Date: 2026-05-12
-- Description: Add fields for three-tier notification system

-- Add last_notified_at for deduplication tracking
ALTER TABLE reminders ADD COLUMN last_notified_at TIMESTAMP;

-- Add notification_count for tracking notification attempts
ALTER TABLE reminders ADD COLUMN notification_count INTEGER NOT NULL DEFAULT 0;

-- Add os_task_id for OS scheduler integration
ALTER TABLE reminders ADD COLUMN os_task_id TEXT;

-- Add priority field with default value
ALTER TABLE reminders ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL';

-- Create trigger to validate priority on INSERT
CREATE TRIGGER check_reminder_priority
BEFORE INSERT ON reminders
BEGIN
    SELECT RAISE(ABORT, 'Invalid priority')
    WHERE NEW.priority NOT IN ('LOW', 'NORMAL', 'HIGH', 'URGENT');
END;

-- Create trigger to validate priority on UPDATE
CREATE TRIGGER check_reminder_priority_update
BEFORE UPDATE ON reminders
BEGIN
    SELECT RAISE(ABORT, 'Invalid priority')
    WHERE NEW.priority NOT IN ('LOW', 'NORMAL', 'HIGH', 'URGENT');
END;
