-- Migrate all subscription data into transaction_templates, then drop the table.
-- Field mapping: next_billing_date -> next_date, destination_account_id = NULL,
-- created_at = now() (subscriptions lacks this column).

-- Step 1: Copy all subscription rows (including soft-deleted) into transaction_templates
INSERT INTO transaction_templates (
    id, name, description, amount, direction,
    source_account_id, destination_account_id,
    cycle, cycle_days, billing_day,
    next_date, start_date, end_date,
    auto_record, paused, last_transaction_id,
    created_at, updated_at, deleted_at,
    category, device_id, synced_at
)
SELECT
    id, name, description, amount, direction,
    source_account_id, NULL,
    cycle, cycle_days, billing_day,
    next_billing_date, start_date, end_date,
    auto_record, paused, last_transaction_id,
    datetime('now'), updated_at, deleted_at,
    category, device_id, synced_at
FROM subscriptions;

-- Step 2: Drop the now-redundant subscriptions table
DROP TABLE IF EXISTS subscriptions;
