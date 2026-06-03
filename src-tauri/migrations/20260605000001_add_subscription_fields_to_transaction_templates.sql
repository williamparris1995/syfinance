-- Add columns that subscriptions has but transaction_templates lacks.
-- These are nullable so existing rows are unaffected.
ALTER TABLE transaction_templates ADD COLUMN category TEXT;
ALTER TABLE transaction_templates ADD COLUMN device_id TEXT;
ALTER TABLE transaction_templates ADD COLUMN synced_at TEXT;
