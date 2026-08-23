# scripts/

Operational SQL scripts for the YuCai server database (PostgreSQL).

## clean-before-r5-e.sql

Legacy-data cleanup required before deploying release-r5 feature E
(ent schema integrity: FK edges, composite/partial unique indexes).

The deployment's auto-migrate adds FK constraints and unique indexes;
`ADD CONSTRAINT` / `CREATE UNIQUE INDEX` fails if existing rows violate
them. The script removes:

- duplicate non-empty `users.email` (keeps newest row; the loser's
  `user_identities` rows are reassigned to the keeper, except where the
  keeper already has that provider — those collide with the
  `(user_id, provider)` unique index and are deleted)
- duplicate `backups.filename` (keeps newest row)
- duplicate `budget_items (budget_id, account_id)` (keeps the row with
  the most data)
- duplicate `payment_schedules (debt_id, payment_date)` (keeps the paid
  row)
- orphan child rows for every new FK edge, plus pre-FK legacy
  `transaction_entries` rows written with a nil parent id

### Upgrade steps

1. stop the server
2. run the script (idempotent — safe to re-run):
   `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/clean-before-r5-e.sql`
3. start the server — auto-migrate applies the new constraints

Take a database backup before step 2; the script deletes rows.
