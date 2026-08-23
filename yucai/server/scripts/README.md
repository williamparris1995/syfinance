# scripts/

Operational SQL scripts for the YuCai server database (PostgreSQL).

## clean-before-r5-e.sql

Legacy-data cleanup required before deploying release-r5 feature E
(ent schema integrity: FK edges, composite/partial unique indexes).

The deployment's auto-migrate adds FK constraints and unique indexes;
`ADD CONSTRAINT` / `CREATE UNIQUE INDEX` fails if existing rows violate
them. The script removes:

- duplicate non-empty `users.email` (keeps newest row)
- duplicate `backups.filename` (keeps newest row)
- duplicate `budget_items (budget_id, account_id)` (keeps first row)
- duplicate `payment_schedules (debt_id, payment_date)` (keeps first row)
- orphan child rows for every new FK edge, plus pre-FK legacy
  `transaction_entries` rows written with a nil parent id

### Upgrade steps

1. stop the server
2. run the script (idempotent — safe to re-run):
   `psql "$DATABASE_URL" -f scripts/clean-before-r5-e.sql`
3. start the server — auto-migrate applies the new constraints

Take a database backup before step 2; the script deletes rows.
