-- Migrate existing debts/debt_payments data to unified model.
-- Only runs if old tables still exist (i.e., migration from pre-unified schema).

-- Check if old debts table exists before running (safe for fresh installs)
-- SQLite doesn't support conditional DDL, so we use INSERT OR IGNORE patterns.

-- Step 1: Create accounts from debts
INSERT OR IGNORE INTO accounts (id, name, account_type, currency_code, balance, ownership, icon,
                                color, chart_code, deleted_at, updated_at, device_id)
SELECT
    lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
    substr(lower(hex(randomblob(2))), 2) || '-' ||
    substr('89ab', (abs(random()) % 4) + 1, 1) ||
    substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))) as id,
    d.counterparty,
    CASE d.debt_type
        WHEN 'borrowed_out' THEN 'borrowed_out'
        WHEN 'borrowed_in' THEN 'borrowed_in'
        WHEN 'credit_card' THEN 'credit_card'
        WHEN 'loan' THEN 'loan'
        ELSE 'other'
    END,
    COALESCE(d.currency_code, 'CNY'),
    COALESCE(d.principal, 0),
    'own',
    '💰',
    '#6B7280',
    CASE d.debt_type
        WHEN 'borrowed_out' THEN '1221'
        WHEN 'borrowed_in' THEN '2001'
        WHEN 'credit_card' THEN '2202'
        WHEN 'loan' THEN '2501'
        ELSE '2001'
    END,
    d.deleted_at,
    COALESCE(d.updated_at, CURRENT_TIMESTAMP),
    d.device_id
FROM debts d
WHERE d.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM debt_details dd WHERE dd.counterparty = d.counterparty);

-- Step 2: Create debt_details linked to the new accounts
INSERT OR IGNORE INTO debt_details (id, account_id, counterparty, interest_rate,
                                    amortization_method, start_date, due_date,
                                    total_principal, updated_at, device_id)
SELECT
    lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
    substr(lower(hex(randomblob(2))), 2) || '-' ||
    substr('89ab', (abs(random()) % 4) + 1, 1) ||
    substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))) as id,
    a.id,
    d.counterparty,
    COALESCE(d.interest_rate, 0),
    CASE
        WHEN d.payment_method = 'equal_payment' THEN 'EqualPrincipalInterest'
        WHEN d.payment_method = 'equal_principal' THEN 'EqualPrincipal'
        ELSE 'LumpSum'
    END,
    d.start_date,
    COALESCE(d.due_date, date(d.start_date, '+1 year')),
    COALESCE(d.principal, 0),
    COALESCE(d.updated_at, CURRENT_TIMESTAMP),
    d.device_id
FROM debts d
JOIN accounts a ON a.name = d.counterparty AND a.ownership = 'own'
WHERE d.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM debt_details dd WHERE dd.account_id = a.id);

-- Step 3: Migrate payment schedules
INSERT OR IGNORE INTO debt_payment_schedule (id, debt_id, payment_date, principal_amount,
                                              interest_amount, total_amount, paid,
                                              transaction_id, updated_at, device_id)
SELECT
    dp.id,
    dd.id,
    dp.payment_date,
    dp.principal_amount,
    COALESCE(dp.interest_amount, 0),
    dp.total_amount,
    dp.paid,
    NULL,
    COALESCE(dp.updated_at, CURRENT_TIMESTAMP),
    dp.device_id
FROM debt_payments dp
JOIN debts d ON d.id = dp.debt_id
JOIN accounts a ON a.name = d.counterparty AND a.ownership = 'own'
JOIN debt_details dd ON dd.account_id = a.id
WHERE dp.deleted_at IS NULL;
