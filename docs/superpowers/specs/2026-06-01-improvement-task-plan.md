# Improvement Task Plan — Sprint Roadmap

**Date:** 2026-06-01
**Status:** Approved
**Based on:** Gap analysis report (`2026-06-01-gap-analysis-report.md`) and action plan (`2026-06-01-gap-analysis-action-plan.md`)
**Total:** 25 tasks across 7 Sprints (2 weeks each, ~69 days total effort)

---

## Sprint Overview

| Sprint | Phase | Tasks | Effort | Key Deliverables |
|--------|-------|:-----:|:------:|------------------|
| **Sprint 1** | P0 Critical Fixes | 5 | ~12 days | Data accuracy, Budget functional, Export usable |
| **Sprint 2** | P1 Transaction & Reports | 3 | ~13 days | Recurring transactions, report drill-down, balance trends |
| **Sprint 3** | P1 Reminders & Investment | 4 | ~12 days | Reminders system, dividends/splits, dynamic currency, auto FX |
| **Sprint 4** | P2 Budget/Goals & Batch | 4 | ~11 days | Budget templates, goal editing, batch ops, OAuth providers |
| **Sprint 5** | P2 Search & Sync | 4 | ~11 days | Auto backup, full-text search, sync conflict UI, tag management |
| **Sprint 6** | P3 Code Quality | 3 | ~5 days | i18n cleanup, dead code removal, architecture consistency |
| **Sprint 7** | P3 Performance & Reports | 2 | ~5 days | Pagination, year-over-year comparison |
| **Total** | — | **25** | **~69 days** | **~14 weeks** |

---

## Sprint 1: P0 Critical Fixes (~12 days)

**Goal:** Fix all data accuracy bugs and make non-functional modules work.

### Task 1: Fix `get_account_balance` returning only initial_balance

- **Module:** Accounts
- **Dimension:** Business Logic
- **Current state:** `get_account_balance` in `account_service.rs` returns `initial_balance` only, ignoring transaction entries. Balance display is incorrect for individual account queries.
- **Target state:** Returns `initial_balance + sum(debit_amount) - sum(credit_amount)` from transaction entries for that account.
- **Approach:** Reuse the same computation logic from `list_accounts_with_balances` which already computes balances correctly. Extract into a shared helper method.
- **Effort:** S (<1 day)
- **Files:** `src-tauri/src/application/services/account_service.rs`, `src-tauri/src/infrastructure/account_repository.rs`

### Task 2: Persist `low_balance_threshold` on account update

- **Module:** Accounts
- **Dimension:** Business Logic
- **Current state:** Backend `UpdateAccountDto` in `account_dto.rs` lacks `low_balance_threshold` field. Frontend sends it but backend silently drops it on update.
- **Target state:** `low_balance_threshold` is included in `UpdateAccountDto`, passed through the repository UPDATE query, and persisted correctly.
- **Approach:** Add `low_balance_threshold: Option<Decimal>` to `UpdateAccountDto`, update the repository's SQL query to include the column in SET clause.
- **Effort:** S (<1 day)
- **Files:** `src-tauri/src/application/dtos/account_dto.rs`, `src-tauri/src/infrastructure/repositories/account_repository.rs`

### Task 3: Fix encryption unlock not verifying password

- **Module:** Encryption
- **Dimension:** Business Logic
- **Current state:** `unlock()` in `encryption_app_service.rs` derives a key from the password and loads it into memory unconditionally. No verification that the password is correct — a wrong password will silently produce a key that fails later during decryption.
- **Target state:** `unlock()` verifies the password by attempting to decrypt a known verification token before accepting. Reject wrong passwords immediately.
- **Approach:** During `setup()`, encrypt a fixed verification string and store it in `encryption_settings` table. During `unlock()`, attempt to decrypt the verification string; reject if decryption fails.
- **Effort:** M (1-3 days)
- **Files:** `src-tauri/src/application/services/encryption_app_service.rs`, `src-tauri/migrations/` (new migration for verification token column)

### Task 4: Wire Budget actual amounts to transaction data

- **Module:** Budget
- **Dimension:** Business Logic + Data Analysis
- **Current state:** `actual_amount` on budget items is always zero. No transaction integration exists. Budget tracking is decorative rather than functional. No application service layer — commands call the repository directly.
- **Target state:** A new `BudgetService` computes actual spending per budget category from transactions for the budget month. Actual amounts are populated on page load. Budget progress bars reflect real spending.
- **Approach:** Create `application/services/budget_service.rs` with a `compute_budget_actuals(budget_id)` method. Query transactions by date range matching the budget month, group by `category_account_id`, sum amounts, and call `update_actual_amount` on each budget item. Refactor existing Tauri commands to go through this service instead of calling the repository directly.
- **Effort:** L (3-5 days)
- **Files:** Create `src-tauri/src/application/services/budget_service.rs`, modify `src-tauri/src/presentation/tauri_commands/budget_commands.rs`, frontend `src/pages/BudgetPage.tsx`, `src/hooks/useBudget.ts`

### Task 5: Make Export produce downloadable CSV files

- **Module:** Export
- **Dimension:** UI/UX + Efficiency
- **Current state:** `export_all_data` Tauri command returns JSON to the frontend. No file save dialog, no CSV format, no download mechanism. User gets a JSON object in memory.
- **Target state:** Generates a CSV file with proper formatting. Uses Tauri's file save dialog to let user choose save location. Supports exporting accounts, transactions, and other data as CSV.
- **Approach:** Add CSV serialization in Rust (using `csv` crate). Use Tauri's `dialog::FileDialogBuilder` for save location. Return success/error status. Add a "Download CSV" button to SettingsPage or a dedicated Export section.
- **Effort:** M (1-3 days)
- **Files:** `src-tauri/src/presentation/tauri_commands/export_commands.rs`, `src-tauri/Cargo.toml` (add csv crate), frontend `src/pages/SettingsPage.tsx` or new export section

**Sprint 1 Acceptance Criteria:**
- [ ] `get_account_balance` returns correct computed balance
- [ ] `low_balance_threshold` persists on account update
- [ ] Encryption rejects wrong passwords on unlock
- [ ] Budget actual amounts reflect real transaction data
- [ ] Export generates downloadable CSV files

---

## Sprint 2: P1 Transaction & Reports (~13 days)

**Goal:** Improve core daily-use experience with recurring transactions, report drill-down, and balance visualization.

### Task 6: Add recurring/scheduled transactions

- **Module:** Transactions
- **Dimension:** Efficiency
- **Current state:** No recurring transaction support. Users must manually re-enter transactions that repeat weekly/monthly/yearly.
- **Target state:** Users can create recurring templates with schedule (weekly/monthly/yearly) that auto-generate transactions on schedule. Templates are manageable (edit, pause, delete).
- **Approach:** Create `TransactionTemplate` entity with schedule fields similar to `Subscription`. Add background scheduler (similar to subscription auto-record pattern). Template UI in transaction form with "Make Recurring" option. Management page for templates.
- **Effort:** L (3-5 days)
- **Files:** Create domain aggregate, repository, service, Tauri commands; frontend form + management

### Task 7: Reports drill-down + date-aware balance sheet

- **Module:** Reports
- **Dimension:** Data Analysis
- **Current state:** Balance sheet is not date-aware (shows current snapshot regardless of date picker). Date picker only affects income statement tab. No drill-down from chart segments to filtered transaction lists.
- **Target state:** Balance sheet respects the selected date range. Clicking on chart segments or table rows navigates to the filtered transaction list for that category and time period.
- **Approach:** Compute balance sheet from transactions up to the end of the selected date range (instead of current snapshot). Add onClick handlers to recharts components that navigate to `/transactions` with appropriate filters (account, date range). Use TanStack Router's search params for filter state.
- **Effort:** M (1-3 days)
- **Files:** `src/pages/ReportsPage.tsx`, `src/pages/TransactionsPage.tsx` (accept filter params)

### Task 8: Add balance history sparklines to Accounts

- **Module:** Accounts
- **Dimension:** Data Analysis
- **Current state:** No charts or trend visualizations on the account page. The detail panel shows only a flat transaction history list.
- **Target state:** Mini sparkline chart showing balance trend over the last 30 days per account, visible in the accounts list and detail panel.
- **Approach:** Add a backend method to compute daily running balances for an account over a date range. Use recharts `Sparkline` or a simple SVG line chart in the accounts table and detail panel.
- **Effort:** M (1-3 days)
- **Files:** Backend: new query in account_repository; Frontend: `src/pages/AccountsPage.tsx`, `src/components/AccountDetailPanel.tsx`

**Sprint 2 Acceptance Criteria:**
- [ ] Recurring transactions auto-generate on schedule
- [ ] Balance sheet respects date range selection
- [ ] Clicking chart segments navigates to filtered transactions
- [ ] Account list shows 30-day balance sparklines

---

## Sprint 3: P1 Reminders & Investment (~12 days)

**Goal:** Complete the reminders system, add investment analytics, fix currency handling across the app.

### Task 9: Build Reminders frontend + wire commands

- **Module:** Reminders
- **Dimension:** UI/UX + Efficiency
- **Current state:** Backend domain model + scheduler logic exist, but no Tauri commands are wired to the frontend, no UI exists, and the scheduler is never started in `main.rs`.
- **Target state:** Reminder management page with CRUD, scheduler running as background task, OS notification dispatch (Windows toast), auto-creation from debt due dates.
- **Approach:** Add Tauri commands for reminder CRUD (create, list, update, delete, snooze, dismiss). Create `RemindersPage.tsx` with list, create, edit UI. Start `ReminderScheduler` in `main.rs` as a Tokio background task. Implement `NotificationSender` for Windows using `winrt-notification` or `tauri::api::notification`.
- **Effort:** L (3-5 days)
- **Files:** `src-tauri/src/presentation/tauri_commands/` (new reminder_commands.rs), `src-tauri/src/main.rs`, frontend `src/pages/RemindersPage.tsx`, `src/hooks/useReminder.ts`, `src/lib/tauri/reminder.ts`

### Task 10: Holdings allocation chart + dividend/split handlers

- **Module:** Holdings
- **Dimension:** Data Analysis + Business Logic
- **Current state:** No allocation visualization. `Dividend` and `Split` types exist in `HoldingTransactionType` enum but have no `apply_dividend()`/`apply_split()` handlers.
- **Target state:** Pie chart showing portfolio allocation by security type. `record_dividend()` and `record_split()` service methods with proper double-entry and holding updates.
- **Approach:** Add `apply_dividend()` and `apply_split()` methods to `Holding` aggregate. Add `record_dividend()` and `record_split()` to `HoldingService` with proper double-entry transactions. Add recharts `PieChart` to `HoldingsPage.tsx` showing allocation by security type.
- **Effort:** L (3-5 days)
- **Files:** `src-tauri/src/domain/aggregates/holding.rs`, `src-tauri/src/application/services/holding_service.rs`, `src/pages/HoldingsPage.tsx`

### Task 11: Fix hardcoded currency symbols (¥ → dynamic)

- **Module:** Cross-cutting
- **Dimension:** UI/UX + Business Logic
- **Current state:** 30+ places across the frontend use hardcoded "¥" symbol instead of the account's actual currency symbol. Multi-currency accounts display incorrect symbols.
- **Target state:** All currency display uses the account's `currency_code` → symbol lookup via a shared utility.
- **Approach:** Create a shared `formatAmount(amount: number, currencyCode: string)` utility or `useCurrencySymbol(code: string)` hook that maps currency codes to symbols. Search and replace all hardcoded "¥" instances across all frontend files.
- **Effort:** M (1-3 days)
- **Files:** Create `src/lib/currency.ts` utility; modify all pages/components with hardcoded "¥"

### Task 12: Multi-currency auto-fetch exchange rates

- **Module:** Multi-currency
- **Dimension:** Efficiency + Business Logic
- **Current state:** All exchange rates must be manually entered. Conversion uses `f64` with precision loss for financial calculations. No auto-fetch from external APIs.
- **Target state:** Auto-fetch rates from a free API (ECB or similar). Use `Decimal` for precision in conversion logic. Configurable auto-fetch interval.
- **Approach:** Add an exchange rate fetcher service in Rust using `reqwest` to call ECB's free daily rate API. Convert `f64` conversion logic to `Decimal`. Add a "Refresh Rates" button and configurable auto-fetch interval in currency settings.
- **Effort:** M (1-3 days)
- **Files:** `src-tauri/src/infrastructure/currency_repository.rs`, new rate fetcher service, `src-tauri/Cargo.toml` (add reqwest if not present)

**Sprint 3 Acceptance Criteria:**
- [ ] Reminders page with full CRUD, background scheduler running, OS notifications work
- [ ] Holdings page shows allocation pie chart
- [ ] Dividend and split transactions record correctly with double-entry
- [ ] No hardcoded ¥ symbols remain in the codebase
- [ ] Exchange rates auto-fetch from external API

---

## Sprint 4: P2 Budget/Goals & Batch (~11 days)

**Goal:** Polish budget and goals modules, add batch operations, enable OAuth cloud providers.

### Task 13: Budget template / copy-to-next-month

- **Module:** Budget
- **Dimension:** Efficiency
- **Current state:** Users must manually create each month's budget from scratch with no reuse.
- **Target state:** One-click "Copy from previous month" button that duplicates the previous month's budget structure as a new month's starting template.
- **Approach:** Add `clone_budget_to_month(source_id, target_month)` method to BudgetService. Button on BudgetPage that finds the most recent budget and clones it.
- **Effort:** M (1-3 days)
- **Files:** `src-tauri/src/application/services/budget_service.rs`, `src/pages/BudgetPage.tsx`

### Task 14: Goals edit UI + auto-sync from account balances

- **Module:** Goals
- **Dimension:** UI/UX + Business Logic
- **Current state:** Goals can be created, have progress added, be completed, or be deleted — but never edited (no change to name, target, deadline, type after creation). Progress is purely manual despite `linked_account_id` field existing.
- **Target state:** Edit dialog for all goal fields. Automatic periodic sync of `current_amount` from linked account balance.
- **Approach:** Add edit dialog to GoalsPage (reuse create dialog in edit mode). Add a `sync_goal_progress(goal_id)` method that reads the linked account's current balance and updates `current_amount`.
- **Effort:** M (1-3 days)
- **Files:** `src/pages/GoalsPage.tsx`, `src-tauri/src/presentation/tauri_commands/goal_commands.rs`

### Task 15: Bulk transaction operations

- **Module:** Transactions
- **Dimension:** Efficiency
- **Current state:** Transactions can only be operated on one at a time. No multi-select, no batch delete, no bulk categorize or tag.
- **Target state:** Multi-select checkboxes on transaction list. Bulk actions: delete, assign tag, change category. Confirmation dialog before batch execution.
- **Approach:** Add selection state to TransactionsPage with checkboxes. Add batch Tauri commands (`batch_delete_transactions`, `batch_tag_transactions`). Show confirmation dialog with count of affected items.
- **Effort:** M (1-3 days)
- **Files:** `src/pages/TransactionsPage.tsx`, new batch commands in `src-tauri/src/presentation/tauri_commands/transaction_commands.rs`

### Task 16: Implement OAuth for Dropbox/Google Drive/OneDrive backup

- **Module:** Backup
- **Dimension:** Efficiency
- **Current state:** Three OAuth cloud providers (Dropbox, Google Drive, OneDrive) are stubs that return `CloudError::NotConfigured`. OAuth "Authorize" button shows "not implemented" toast.
- **Target state:** Full OAuth 2.0 authorization flow for all three providers. Users can authenticate, authorize, and use these providers for backup/sync.
- **Approach:** Implement OAuth 2.0 PKCE flow using Tauri's `shell.open()` for browser redirect and a local HTTP server for callback. Store tokens securely. Implement upload/download/list methods for each provider using their REST APIs.
- **Effort:** L (3-5 days)
- **Files:** `src-tauri/src/infrastructure/backup/dropbox_provider.rs`, `google_drive_provider.rs`, `onedrive_provider.rs`, `src/components/CloudConfigDialog.tsx`

**Sprint 4 Acceptance Criteria:**
- [ ] One-click budget copy from previous month works
- [ ] Goals can be edited after creation
- [ ] Goal progress auto-syncs from linked account
- [ ] Multi-select + batch operations on transactions
- [ ] Dropbox/Google Drive/OneDrive OAuth flow completes and backup works

---

## Sprint 5: P2 Search & Sync (~11 days)

**Goal:** Complete infrastructure features — auto backup, advanced search, sync conflict resolution, tag management.

### Task 17: Add scheduled automatic backup

- **Module:** Backup
- **Dimension:** Efficiency
- **Current state:** Backups are manual only (click button). No scheduled/automatic backup creation.
- **Target state:** Configurable automatic backup schedule (daily/weekly). Background task creates backups on schedule. Setting persisted in backup configuration.
- **Approach:** Add a Tokio background task similar to the subscription scheduler. Add `auto_backup_enabled` and `auto_backup_interval` to backup settings. Create backup on schedule, keep last N backups, auto-cleanup old ones.
- **Effort:** S (<1 day)
- **Files:** `src-tauri/src/main.rs`, `src-tauri/src/infrastructure/backup/backup_service.rs`

### Task 18: Add FTS full-text search

- **Module:** Search
- **Dimension:** Business Logic
- **Current state:** Search uses SQL `LIKE '%query%'` on 3 entity types. No word stems, no typo tolerance, no CJK tokenization, no relevance ranking.
- **Target state:** SQLite FTS5 virtual table with proper tokenization. Search across all entity types (not just 3). Relevance-ranked results. Support for Chinese character search.
- **Approach:** Create FTS5 virtual tables for each searchable entity. Add a `search_index` migration. Implement a tokenizer that handles CJK characters (use SQLite's unicode61 tokenizer with tokenchars). Rebuild index on entity changes. Update search commands to query FTS tables.
- **Effort:** M (1-3 days)
- **Files:** New migration for FTS tables, `src-tauri/src/presentation/tauri_commands/search_commands.rs`

### Task 19: Cloud sync conflict resolution UI

- **Module:** Cloud Sync
- **Dimension:** UI/UX
- **Current state:** Conflict resolution is limited to automatic `keep_newer` strategy with no user visibility or choice.
- **Target state:** When conflicts are detected, show a UI listing each conflict with local and remote versions. User can choose per-item whether to keep local, use remote, or keep newer.
- **Approach:** Add a `list_sync_conflicts()` command that returns detected conflicts. Create a `SyncConflictDialog` component showing each conflict with diff and resolution options. Apply chosen resolutions during sync.
- **Effort:** M (1-3 days)
- **Files:** `src-tauri/src/infrastructure/sync/cloud_sync_service.rs`, new `src/components/SyncConflictDialog.tsx`, `src/pages/SettingsPage.tsx`

### Task 20: Tags management page + update + soft delete

- **Module:** Tags
- **Dimension:** UI/UX + Business Logic
- **Current state:** Tags have create/delete/assign-to-transaction only. No update (rename, recolor), no management page, no soft delete, no validation. Extremely thin domain model.
- **Target state:** Dedicated tag management section with list, create, edit (name/color), delete. Soft delete with `deleted_at`. Proper validation (name length, color format, uniqueness).
- **Approach:** Add `update_tag` and `soft_delete_tag` to repository and commands. Create a tag management section (in SettingsPage or as a standalone page). Add `name` length validation (1-50 chars), `color` hex format validation, and soft delete support.
- **Effort:** S (<1 day)
- **Files:** `src-tauri/src/domain/aggregates/tag.rs` (add validation, soft delete), `src-tauri/src/presentation/tauri_commands/tag_commands.rs`, frontend tag management section

**Sprint 5 Acceptance Criteria:**
- [ ] Auto-backup runs on configured schedule
- [ ] Full-text search works across all entity types with CJK support
- [ ] Sync conflicts shown in UI with per-item resolution choice
- [ ] Tags can be renamed, recolored, soft-deleted from a management page

---

## Sprint 6: P3 Code Quality (~5 days)

**Goal:** Eliminate all i18n violations, remove dead code, enforce consistent architecture.

### Task 21: i18n — Replace hardcoded Chinese toasts with translation keys

- **Module:** Cross-cutting
- **Dimension:** UI/UX
- **Current state:** `useBudget.ts`, `useGoal.ts`, and other hooks contain hardcoded Chinese toast messages (e.g., `"预算创建成功"`, `"请输入目标名称"`). ESLint rule `i18next/no-literal-string` should catch these but some leak through.
- **Target state:** All toast messages use `t('key')` with keys in both `en.json` and `zh.json` locale files.
- **Approach:** Audit all hooks and components for Chinese string literals. Add new i18n keys to both locale files. Replace all instances with `t()` calls.
- **Effort:** S (<1 day)
- **Files:** `src/hooks/useBudget.ts`, `src/hooks/useGoal.ts`, `src/hooks/useCurrency.ts`, `src/i18n/locales/en.json`, `src/i18n/locales/zh.json`

### Task 22: Clean up dead code (legacy debt.rs, stub categories)

- **Module:** Debts
- **Dimension:** Business Logic
- **Current state:** Two co-existing domain models: `debt.rs` (legacy, unused) and `debt_details.rs` (active). Category system has been fully implemented in the account-module-redesign sprint. `find_active`/`find_completed` repo methods on goals are dead code.
- **Target state:** Remove `debt.rs` aggregate. Remove any remaining legacy category stub references. Remove unused repository methods.
- **Approach:** Delete `src-tauri/src/domain/aggregates/debt.rs`. Verify category implementation is complete (see account-module-redesign spec). Remove dead repository methods on GoalRepository.
- **Effort:** S (<1 day)
- **Files:** Delete `src-tauri/src/domain/aggregates/debt.rs`, clean `src-tauri/src/application/dtos/`, `src/components/TransactionForm.tsx`

### Task 23: Budget/Goals add application service layer

- **Module:** Budget/Goals
- **Dimension:** Business Logic
- **Current state:** Budget and Goals Tauri commands call repositories directly, bypassing the application service layer used by all other modules (Debts, Subscriptions, Holdings all have proper services).
- **Target state:** Both modules have a proper application service layer between Tauri commands and repositories, consistent with the project's DDD architecture.
- **Approach:** Create `budget_service.rs` (partially done in Sprint 1 Task 4) and `goal_service.rs`. Move business logic from command handlers into services. Refactor commands to call services instead of repositories.
- **Effort:** M (1-3 days)
- **Files:** Create `src-tauri/src/application/services/goal_service.rs`, modify `src-tauri/src/presentation/tauri_commands/goal_commands.rs`, `budget_commands.rs`

**Sprint 6 Acceptance Criteria:**
- [ ] No Chinese string literals in frontend hooks/components (all use `t()`)
- [ ] `debt.rs` removed, category stubs cleaned
- [ ] Budget and Goals commands go through service layer

---

## Sprint 7: P3 Performance & Reports (~5 days)

**Goal:** Optimize for scale and add advanced reporting.

### Task 24: Transactions/Holdings add pagination

- **Module:** Transactions/Holdings
- **Dimension:** Efficiency
- **Current state:** All transactions and holdings are loaded into memory at once. `get_transactions_by_account` loads ALL transactions then filters in memory. No pagination on any list endpoint.
- **Target state:** Cursor-based pagination on transaction and holding list endpoints. UI shows "Load more" or page navigation. Backend queries use LIMIT/OFFSET.
- **Approach:** Add `limit` and `offset` (or `cursor`) parameters to list queries in repositories. Update frontend to request pages. Add "Load more" button or infinite scroll to transaction and holdings pages.
- **Effort:** M (1-3 days)
- **Files:** Repository traits and implementations for transactions/holdings, `src/pages/TransactionsPage.tsx`, `src/pages/HoldingsPage.tsx`

### Task 25: Reports add year-over-year comparison

- **Module:** Reports
- **Dimension:** Data Analysis
- **Current state:** No ability to overlay or compare the same period across different years. No trend analysis beyond the current monthly charts.
- **Target state:** Side-by-side or overlay comparison of income/expenses for the same period across two years. Trend line showing multi-year patterns.
- **Approach:** Add a "Compare with" date range selector on ReportsPage. Fetch data for both periods and render as grouped bar chart or dual line chart. Show percentage change between periods.
- **Effort:** M (1-3 days)
- **Files:** `src/pages/ReportsPage.tsx`, backend query for multi-period data

**Sprint 7 Acceptance Criteria:**
- [ ] Transactions page loads data in pages (no full-table load)
- [ ] Holdings page supports pagination
- [ ] Reports show year-over-year comparison chart

---

## Dependencies Between Tasks

```
Sprint 1 (P0) ── no dependencies, all independent
  Task 4 (Budget actuals) ── creates BudgetService, reused in Sprint 4 Task 13 (templates)
Sprint 2 (P1)
  Task 6 (Recurring) ── independent
  Task 7 (Reports) ── independent
  Task 8 (Sparklines) ── benefits from Task 1 fix (correct balance)
Sprint 3 (P1)
  Task 9 (Reminders) ── independent
  Task 10 (Holdings) ── independent
  Task 11 (Currency symbols) ── independent, cross-cutting
  Task 12 (Auto FX rates) ── independent
Sprint 4 (P2)
  Task 13 (Budget templates) ── depends on Task 4 (BudgetService must exist)
  Task 14 (Goals edit) ── independent
  Task 15 (Batch ops) ── independent
  Task 16 (OAuth) ── independent
Sprint 5 (P2)
  Task 17 (Auto backup) ── independent
  Task 18 (FTS) ── independent
  Task 19 (Sync UI) ── independent
  Task 20 (Tags) ── independent
Sprint 6 (P3)
  Task 21 (i18n) ── independent
  Task 22 (Dead code) ── independent
  Task 23 (Service layer) ── Task 4 already creates BudgetService; this creates GoalService
Sprint 7 (P3)
  Task 24 (Pagination) ── independent
  Task 25 (YoY) ── benefits from Task 7 (drill-down charts infrastructure)
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Budget-Transaction integration complex (Task 4) | Sprint 1 delay | Start early, simplify to monthly aggregation first |
| OAuth implementation (Task 16) varies per provider | Sprint 4 scope creep | Implement one provider at a time; Dropbox first (simplest API) |
| FTS CJK tokenization (Task 18) may need ICU | Sprint 5 complexity | Use unicode61 tokenizer as baseline; test with real Chinese data |
| Recurring transactions (Task 6) may conflict with subscriptions | Duplicate features | Reuse Subscription's scheduler pattern; keep as separate module initially |
