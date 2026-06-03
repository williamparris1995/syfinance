# Sprint 8-9: Performance Optimization & Tech Debt Cleanup

**Date:** 2026-06-03
**Status:** Approved
**Sprints:** 8 (performance) and 9 (tech debt)

---

## Sprint 8: Performance Optimization + Feature Completion

**Goal:** Eliminate performance bottlenecks (missing indexes, N+1 queries, client-side filtering), migrate remaining pages to paginated endpoints, wire up prepaid expiry and low-balance notifications.

### Task 26: Database Indexes

Add indexes on high-frequency query columns:

```sql
-- Transaction entries (most queried table)
CREATE INDEX IF NOT EXISTS idx_te_account_id ON transaction_entries(account_id);
CREATE INDEX IF NOT EXISTS idx_te_transaction_id ON transaction_entries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_te_deleted_at ON transaction_entries(deleted_at);

-- Transactions
CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_tx_deleted_at ON transactions(deleted_at);

-- Debt details
CREATE INDEX IF NOT EXISTS idx_dd_account_id ON debt_details(account_id);

-- Tags
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);

-- Holding transactions
CREATE INDEX IF NOT EXISTS idx_ht_account_security ON holding_transactions(account_id, security_id);
CREATE INDEX IF NOT EXISTS idx_ht_trade_date ON holding_transactions(trade_date);
```

Create as migration file `src-tauri/migrations/YYYYMMDDHHMMSS_add_performance_indexes.sql`.

### Task 27: N+1 Fix for Non-Paginated Endpoints

The paginated `find_paginated()` already uses `batch_load_entries()` + `batch_load_currencies()`. Apply the same batch loading pattern to:
- `find_all()` — replace per-transaction `load_entries()` loop with batch loading
- `find_by_date_range()` — same fix
- `get_changes_since()` — same fix

Extract `batch_load_entries()` and `batch_load_currencies()` as public methods on the repository. Modify the old query methods to collect transaction IDs, then call batch loading in 2 queries instead of N+1.

### Task 28: Server-Side Account Filtering

`get_transactions_by_account()` in `transaction_service.rs` currently:
1. Calls `find_all()` to load ALL transactions
2. Filters in-memory by matching `entries.iter().any(|e| e.account_id == account_id)`

Fix: Add a `find_by_account(account_id)` method to `TransactionRepository` that uses SQL-level filtering:
```sql
SELECT DISTINCT t.* FROM transactions t
JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
WHERE e.account_id = ? AND t.deleted_at IS NULL
ORDER BY t.transaction_date DESC, t.id DESC
```

Then `get_transactions_by_account()` calls `find_by_account()` instead of `find_all()` + in-memory filter.

### Task 29: ReportsPage + HomePage Migration

**ReportsPage:** Replace `listTransactions()` (non-paginated) with server-side aggregation:
- Add backend commands for balance sheet and income statement aggregation
- Or use `listTransactionsPaginated` with a large page size (200) and aggregate on the client side

Preferred approach: Add dedicated aggregation commands (`get_balance_sheet_data`, `get_income_statement_data`) that compute sums on the server. This avoids loading raw transactions to the browser.

**HomePage:** The dashboard shows total balance, monthly income/expenses, and upcoming payments. Replace `listTransactions()` with server-side aggregation commands.

### Task 30: Prepaid Expiry Alerts

Add a background scheduler (similar to reminder scheduler) that:
1. Runs daily (check at startup + every 24h)
2. Queries `SELECT * FROM top_up_records WHERE expiry_date IS NOT NULL AND expiry_date <= date('now', '+7 days')`
3. For each expiring record, creates a Reminder via the ReminderService
4. Deduplicates by checking if a reminder for this expiry already exists

### Task 31: Low-Balance Notification

Wire `check_low_balance_alert()` in `prepaid_service.rs`:
1. Remove `#[allow(dead_code)]`
2. Call it after each top-up or consumption transaction that changes a prepaid account's balance
3. When threshold is crossed, create a Reminder via the existing ReminderService

### Acceptance Criteria

- [ ] Database indexes added on all high-frequency columns
- [ ] `find_all()` and `find_by_date_range()` use batch loading (2 queries instead of N+1)
- [ ] `get_transactions_by_account()` uses SQL WHERE filter
- [ ] ReportsPage does not call non-paginated `listTransactions()`
- [ ] Prepaid expiry reminders created 7 days before expiry
- [ ] Low-balance reminders created when threshold is crossed

---

## Sprint 9: Tech Debt Cleanup

**Goal:** Fix all remaining i18n violations, lint errors, stale docs, and improve test coverage for core modules.

### Task 32: i18n Remaining Violations

Fix hardcoded Chinese strings in 5 files:
- `src/lib/goal.ts` — goal type labels → add keys to locales, create `getGoalTypeLabel()` that uses `t()`
- `src/lib/budget.ts` — month format → use `t('budget.monthFormat', { year, month })`
- `src/components/HoldingTradeForm.tsx` — security type labels → use `t('holding.types.stock')` etc. (keys already exist in locales)
- `src/lib/tauri/account.ts` — preset account names → add keys to locales
- `src/pages/HomePage.tsx` — `'人民币'` → use `t()`

Fix 4 raw error toasts in TransactionsPage — wrap with `getUserFriendlyError()` or `t()`.

### Task 33: Lint Fix + LIMITATIONS.md Update

- Fix `BackupPage.tsx:74` — change `catch (error)` to `catch` (remove unused binding)
- Update LIMITATIONS.md to reflect current state after 7 sprints

### Task 34: Core Module Tests

Add integration tests for the 4 most critical untested modules:
- Budget CRUD + actuals computation
- Goals CRUD + progress + auto-complete
- Holdings buy/sell + dividend/split
- Tags CRUD + soft delete + transaction association

Use existing test patterns from `src-tauri/tests/`.

### Task 35: Dead Code Triage

Review 92 `#[allow(dead_code)]` annotations:
- If item is for a planned future feature → keep annotation, ensure TODO comment explains why
- If item is genuinely dead → delete it
- Consolidate PostgreSQL repos: either document as "planned for future sync" or remove

### Task 36: TypeScript Currency Precision

Audit all `parseFloat()` / `Number()` usage for currency amounts:
- Replace with string-based arithmetic or a lightweight decimal library
- Ensure all display formatting uses `toFixed(2)` or locale-aware formatting
- At minimum, ensure no precision loss in the common add/subtract/multiply operations

### Acceptance Criteria

- [ ] Zero hardcoded Chinese strings in frontend (excluding locale files)
- [ ] `pnpm lint` passes with zero errors
- [ ] LIMITATIONS.md updated to reflect current state
- [ ] Integration tests for Budget, Goals, Holdings, Tags
- [ ] Dead code triaged with clear TODO comments
- [ ] No precision loss in frontend currency calculations

---

## Verification

```bash
pnpm type-check && pnpm lint
cd src-tauri && make check && make test
```
