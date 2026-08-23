-- clean-before-r5-e.sql
-- Legacy-data cleanup REQUIRED before deploying release-r5 feature E
-- (ent schema integrity: FK edges, composite/partial unique indexes).
--
-- Why: the deployment's auto-migrate adds FK constraints and unique indexes.
-- ADD CONSTRAINT / CREATE UNIQUE INDEX FAILS if the existing rows violate
-- them. This script removes violations first. It is pure SQL and idempotent
-- (safe to run multiple times; every statement is a delete whose select
-- set is empty on the second run).
--
-- Upgrade procedure (documented in README "Upgrade" section):
--   1. stop the server
--   2. run this script against the production database (PostgreSQL)
--   3. start the server — auto-migrate applies the new constraints
--
-- Flavored for PostgreSQL (production driver is pgx). Window functions are
-- available on PG 11+ and SQLite 3.25+, so the same file also runs on a
-- SQLite database if ever needed.
--
-- Deletion policy (per design ADR-3):
--   users.email duplicates ....... keep the NEWEST row (created_at, id);
--                                  loser identities are reassigned to the
--                                  keeper, except provider collisions
--   backups.filename duplicates .. keep the NEWEST row (created_at, id)
--   budget_items composite ....... keep the row with the most data
--   payment_schedules composite .. keep the PAID row
--   orphan child rows ............ deleted outright (no parent to keep)

BEGIN;

------------------------------------------------------------------------
-- 1. Duplicate users.email (non-empty). The new partial unique index is
--    (email) WHERE email <> '' — duplicate non-empty emails block it.
--    user_identities.user_id has an FK to users with ON DELETE NO ACTION
--    and a unique (user_id, provider) index, so losers' identities must be
--    handled first: drop identities whose provider the keeper already has
--    (collisions), reassign the rest to the keeper (preserves logins).
------------------------------------------------------------------------
WITH ranked AS (
    SELECT id, email,
           ROW_NUMBER() OVER (
               PARTITION BY email
               ORDER BY created_at DESC, id DESC
           ) AS rn
    FROM users
    WHERE email IS NOT NULL AND email <> ''
)
DELETE FROM user_identities
WHERE id IN (
    SELECT ul.id
    FROM user_identities ul
    JOIN users lu ON lu.id = ul.user_id
    JOIN ranked lr ON lr.id = lu.id AND lr.rn > 1
    JOIN ranked kr ON kr.email = lu.email AND kr.rn = 1
    JOIN user_identities uk ON uk.user_id = kr.id AND uk.provider = ul.provider
);

WITH ranked AS (
    SELECT id, email,
           ROW_NUMBER() OVER (
               PARTITION BY email
               ORDER BY created_at DESC, id DESC
           ) AS rn
    FROM users
    WHERE email IS NOT NULL AND email <> ''
)
UPDATE user_identities
SET user_id = (
    SELECT kr.id
    FROM users ku
    JOIN ranked kr ON kr.id = ku.id AND kr.rn = 1
    WHERE ku.email = (
        SELECT lu.email FROM users lu WHERE lu.id = user_identities.user_id
    )
)
WHERE user_id IN (
    SELECT lr.id FROM ranked lr WHERE lr.rn > 1
);

DELETE FROM users
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY created_at DESC, id DESC
        ) AS rn
        FROM users
        WHERE email IS NOT NULL AND email <> ''
    ) ranked
    WHERE rn > 1
);

------------------------------------------------------------------------
-- 2. Duplicate backups.filename. The new unique index on (filename)
--    blocks exact filename reuse.
------------------------------------------------------------------------
DELETE FROM backups
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (
            PARTITION BY filename
            ORDER BY created_at DESC, id DESC
        ) AS rn
        FROM backups
    ) ranked
    WHERE rn > 1
);

------------------------------------------------------------------------
-- 3. Duplicate budget_items (budget_id, account_id). The new composite
--    unique index blocks two rows budgeting the same account. The table
--    has no created_at; prefer the row carrying the most data, then id
--    ASC as the deterministic tiebreak.
------------------------------------------------------------------------
DELETE FROM budget_items
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (
            PARTITION BY budget_id, account_id
            ORDER BY planned_amount_cents DESC, actual_amount_cents DESC, id ASC
        ) AS rn
        FROM budget_items
    ) ranked
    WHERE rn > 1
);

------------------------------------------------------------------------
-- 4. Duplicate payment_schedules (debt_id, payment_date). The new
--    composite unique index blocks two installments on the same day.
--    Prefer the PAID row (payment state and transaction link survive),
--    then the higher paid amount, then id ASC.
------------------------------------------------------------------------
DELETE FROM payment_schedules
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (
            PARTITION BY debt_id, payment_date
            ORDER BY paid DESC, paid_cents DESC, id ASC
        ) AS rn
        FROM payment_schedules
    ) ranked
    WHERE rn > 1
);

------------------------------------------------------------------------
-- 5. Orphan child rows. The new FK constraints (child -> parent) fail to
--    apply while orphan rows exist.
------------------------------------------------------------------------

-- transaction_entries -> transactions
DELETE FROM transaction_entries
WHERE transaction_id IS NOT NULL
  AND transaction_id NOT IN (SELECT id FROM transactions);

-- Also drop pre-FK legacy rows that were written with a nil parent id
-- (the UpdateTransaction path stamped uuid.Nil before R5-E fixed it).
DELETE FROM transaction_entries
WHERE transaction_id = '00000000-0000-0000-0000-000000000000';

-- budget_items -> budgets
DELETE FROM budget_items
WHERE budget_id NOT IN (SELECT id FROM budgets);

-- holding_lots -> holdings (and via holdings -> securities)
DELETE FROM holding_lots
WHERE holding_id NOT IN (SELECT id FROM holdings);

-- payment_schedules -> debt_details
DELETE FROM payment_schedules
WHERE debt_id NOT IN (SELECT id FROM debt_details);

-- debt_progress_snapshots -> debt_details
DELETE FROM debt_progress_snapshots
WHERE debt_id NOT IN (SELECT id FROM debt_details);

-- goal_progress_snapshots -> goals
DELETE FROM goal_progress_snapshots
WHERE goal_id NOT IN (SELECT id FROM goals);

-- security_price_histories -> securities
DELETE FROM security_price_histories
WHERE security_id NOT IN (SELECT id FROM securities);

-- template_record_logs -> transaction_templates
DELETE FROM template_record_logs
WHERE template_id NOT IN (SELECT id FROM transaction_templates);

COMMIT;
