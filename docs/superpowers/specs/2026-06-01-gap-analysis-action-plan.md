# Gap Analysis Action Plan

**Date**: 2026-06-01
**Project**: Personal Finance Desktop App (Tauri 2.x, Rust + React, DDD Architecture)
**Purpose**: Prioritized remediation plan based on gap analysis findings across five dimensions (UI/UX, Efficiency, Business Logic, Data Analysis, Cross-cutting).

---

## Summary

| Priority | Count | Est. Total Effort |
|----------|-------|-------------------|
| P0 Critical | 5 | ~12 days |
| P1 High | 7 | ~25 days |
| P2 Medium | 8 | ~22 days |
| P3 Low | 5 | ~10 days |
| **Total** | **25** | **~69 days** |

---

## P0 — Critical (Data loss risks, broken features)

### P0-1: Fix get_account_balance returning only initial_balance
- **Module**: Accounts
- **Dimension**: Business Logic
- **Current state**: `get_account_balance` in `account_service.rs` returns `initial_balance` only, ignoring all transaction entries. Any code that relies on this method (balance checks, low-balance alerts) operates on stale data.
- **Target state**: Returns `initial_balance + sum(debits) - sum(credits)` computed from transaction entries, matching the correct logic already present in `list_accounts_with_balances`.
- **Approach**: Extract the balance computation logic from `list_accounts_with_balances` into a shared helper method. Reuse it in `get_account_balance` so both code paths produce identical results.
- **Effort**: S

### P0-2: Persist low_balance_threshold on account update
- **Module**: Accounts
- **Dimension**: Business Logic
- **Current state**: `UpdateAccountDto` in `account_dto.rs` lacks the `low_balance_threshold` field. The frontend sends it on account edit, but the backend silently drops it, so the value is never saved after initial creation.
- **Target state**: `low_balance_threshold` is included in `UpdateAccountDto` and persisted through the repository UPDATE query on every account update.
- **Approach**: Add `low_balance_threshold: Option<Decimal>` to `UpdateAccountDto`, propagate it through the service layer to the repository, and add the column to the existing UPDATE SQL query.
- **Effort**: S

### P0-3: Fix encryption unlock not verifying password
- **Module**: Encryption
- **Dimension**: Business Logic
- **Current state**: `unlock()` derives a key from the supplied password and loads it unconditionally. There is no verification step, so an incorrect password is accepted silently, leading to decryption failures on actual encrypted data later.
- **Target state**: Password correctness is verified before the key is accepted. An incorrect password returns a clear error immediately.
- **Approach**: Store an encrypted verification token during initial encryption setup. During `unlock()`, attempt to decrypt this token with the derived key; reject the unlock if decryption fails. This follows the standard "known plaintext" verification pattern.
- **Effort**: M

### P0-4: Wire Budget actual amounts to transactions
- **Module**: Budget
- **Dimension**: Business Logic + Data Analysis
- **Current state**: `actual_amount` on every budget item is always zero. There is no integration between the Budget module and the Transaction module, so users cannot compare planned vs. actual spending.
- **Target state**: `actual_amount` is automatically computed from transactions matching the budget item's category and date range. The budget view shows accurate planned-vs-actual comparison.
- **Approach**: Create a `compute_budget_actuals` method on a new `BudgetService` that queries transactions by date range and `category_account_id`, sums debits, and updates `actual_amount` on each budget item. Call this method on budget page load and after transaction creation/edit.
- **Effort**: L

### P0-5: Make Export actually produce downloadable files
- **Module**: Export
- **Dimension**: UI/UX + Efficiency
- **Current state**: The export endpoint returns raw JSON to the frontend. There is no file save dialog and no CSV format option, making the feature effectively unusable for end users.
- **Target state**: Users select a save location via a native file dialog, choose CSV or JSON format, and receive a properly formatted file written to disk.
- **Approach**: Use Tauri's `dialog::save_file()` API for save location selection. Implement CSV conversion in Rust (using the `csv` crate). Write the file to the chosen path and return the path to the frontend for confirmation toast.
- **Effort**: M

---

## P1 — High (Core experience significantly behind competitors)

### P1-1: Add recurring/scheduled transactions
- **Module**: Transactions
- **Dimension**: Efficiency
- **Current state**: No support for recurring transactions. Users must manually re-enter rent, salary, loan payments, and other regular items every period.
- **Target state**: Users can create recurring transaction templates (weekly, monthly, yearly) that auto-generate transactions on schedule, with a background scheduler checking and creating due instances.
- **Approach**: Create a `TransactionTemplate` entity with schedule fields (frequency, interval, start/end dates, next_due_date). Add a background Tokio scheduler (similar to the existing subscription auto-record pattern) that checks for due templates and creates corresponding transactions.
- **Effort**: L

### P1-2: Add Reports drill-down and fix date-aware balance sheet
- **Module**: Reports
- **Dimension**: Data Analysis
- **Current state**: The balance sheet is not date-aware; it always shows the current snapshot regardless of the date picker selection. No drill-down from charts to underlying transactions.
- **Target state**: Balance sheet respects the selected date range, computing account balances from transactions up to the end date. Clicking chart segments navigates to filtered transaction lists.
- **Approach**: Compute the balance sheet from transaction entries up to the selected end date instead of using current balances. Add `onClick` handlers to recharts components that navigate to the transactions page with pre-applied date and account/category filters.
- **Effort**: M

### P1-3: Add balance history sparklines to Accounts
- **Module**: Accounts
- **Dimension**: Data Analysis
- **Current state**: The accounts page shows only current balance as a number. No trend visualization exists, making it hard to spot spending patterns at a glance.
- **Target state**: Each account card displays a mini sparkline showing balance trend over the last 30 days, giving users an instant visual summary of account activity.
- **Approach**: Add a backend query that computes daily balance snapshots from transactions for the last 30 days. On the frontend, render a recharts `Sparkline` component on each account card using this data.
- **Effort**: M

### P1-4: Build Reminders frontend + wire commands
- **Module**: Reminders
- **Dimension**: UI/UX + Efficiency
- **Current state**: The backend has a complete domain model and scheduler implementation, but there is no frontend UI, no Tauri IPC commands to bridge them, and the scheduler is never started in `main.rs`.
- **Target state**: A fully functional Reminders page with CRUD operations. The scheduler runs in the background and fires OS-level notifications on Windows when reminders are due.
- **Approach**: Add Tauri commands for reminder CRUD operations (create, list, update, delete). Create a `RemindersPage` component with forms and list views. Start the existing scheduler in `main.rs`. Implement `NotificationSender` using Windows toast notifications via `winrt_notification` or `tauri-plugin-notification`.
- **Effort**: L

### P1-5: Add Holdings allocation chart + dividend/split handlers
- **Module**: Holdings
- **Dimension**: Data Analysis + Business Logic
- **Current state**: No portfolio allocation visualization exists. The `Dividend` and `Split` enum variants are defined in the domain model but have no handler logic, so users cannot record these common corporate actions.
- **Target state**: A pie chart showing portfolio allocation by security type. Users can record dividends and stock splits, which correctly adjust holding quantities and cost bases.
- **Approach**: Add a recharts `PieChart` component that aggregates holdings by security type and displays allocation percentages. Implement `apply_dividend()` and `apply_split()` methods on the `Holding` aggregate with correct cost basis and quantity adjustments. Add service methods and Tauri commands for the UI to invoke them.
- **Effort**: L

### P1-6: Fix hardcoded currency symbols
- **Module**: Cross-cutting
- **Dimension**: UI/UX + Business Logic
- **Current state**: Over 30 places across the frontend hardcode the "CNY" symbol as a literal string instead of looking up the account's actual currency, so multi-currency accounts display incorrect symbols.
- **Target state**: All currency display uses a centralized lookup from `currency_code` to its symbol, respecting each account's configured currency.
- **Approach**: Create a shared `useCurrencySymbol()` hook and/or a `formatAmount(amount, currencyCode)` utility function. Replace all hardcoded currency symbol instances across the codebase. Add a currency symbol map (USD=$, CNY=¥, EUR=€, etc.) in a shared constants file.
- **Effort**: M

### P1-7: Add multi-currency auto-fetch exchange rates
- **Module**: Multi-currency
- **Dimension**: Efficiency + Business Logic
- **Current state**: All exchange rates must be entered manually. Currency conversion logic uses `f64` floating-point, which introduces rounding errors in financial calculations.
- **Target state**: Exchange rates auto-fetch from a free API on a configurable schedule. All conversion arithmetic uses `Decimal` for exact precision.
- **Approach**: Add an exchange rate fetcher service that calls a free API (e.g., ECB, exchangerate.host) on a daily schedule. Convert all `f64` rate fields to `Decimal` in the domain and infrastructure layers. Store fetched rates in a new `exchange_rates` table with timestamps.
- **Effort**: M

---

## P2 — Medium (Nice-to-have improvements)

### P2-1: Add budget template / copy-to-next-month
- **Module**: Budget
- **Dimension**: Efficiency
- **Current state**: Users must recreate budget items from scratch each month with no way to carry forward the previous month's structure.
- **Target state**: Users can copy an existing month's budget as a template for the next month, preserving categories and planned amounts while resetting actuals to zero.
- **Approach**: Add a "Copy to next month" action on the budget page. Backend endpoint accepts source month and target month, clones budget items with the new date range and zeroed actuals.
- **Effort**: M

### P2-2: Add Goals edit UI + auto-sync from account balances
- **Module**: Goals
- **Dimension**: UI/UX + Business Logic
- **Current state**: Goals can be created but not edited after creation. Current amounts are set manually and never synced with actual account balances.
- **Target state**: Goals have a full edit form. Current amounts can optionally auto-sync from linked account balances, reflecting real-time progress.
- **Approach**: Add edit form to `GoalsPage` with react-hook-form. Add an `auto_sync` flag on goals; when enabled, a service method queries the linked account's current balance and updates the goal's current amount on page load.
- **Effort**: M

### P2-3: Add bulk transaction operations
- **Module**: Transactions
- **Dimension**: Efficiency
- **Current state**: Transactions can only be edited or deleted one at a time, making cleanup and categorization of imported data tedious.
- **Target state**: Users can select multiple transactions and perform batch operations: delete, re-categorize, tag, or mark as reconciled.
- **Approach**: Add multi-select support to the transaction list (checkbox column). Backend endpoints accept arrays of transaction IDs. Use SQL `IN` clauses for batch updates within a transaction for atomicity.
- **Effort**: M

### P2-4: Implement OAuth for Dropbox/Google Drive/OneDrive backup
- **Module**: Backup
- **Dimension**: Efficiency
- **Current state**: Cloud backup destinations require manual token management. No OAuth flow exists, so users cannot easily connect their cloud storage accounts.
- **Target state**: One-click OAuth flows for Dropbox, Google Drive, and OneDrive. Tokens are securely stored and auto-refreshed.
- **Approach**: Use Tauri's `tauri-plugin-oauth` or open system browser for OAuth flows. Implement token storage in the encrypted store. Add refresh token handling for each provider.
- **Effort**: L

### P2-5: Add scheduled/automatic backup
- **Module**: Backup
- **Dimension**: Efficiency
- **Current state**: Backups must be triggered manually. Users who forget to back up risk data loss between manual backups.
- **Target state**: Users can configure automatic backup on a schedule (daily, weekly). Backups run in the background without user interaction.
- **Approach**: Add backup schedule configuration to Settings. Use the existing Tokio scheduler infrastructure to run backup jobs at configured intervals. Store last-backup timestamp and show status on settings page.
- **Effort**: S

### P2-6: Add FTS (full-text search)
- **Module**: Search
- **Dimension**: Business Logic
- **Current state**: No global search capability. Users must navigate to individual modules to find specific transactions, accounts, or notes.
- **Target state**: A global search bar that returns results across transactions, accounts, budgets, and notes using SQLite FTS5.
- **Approach**: Create an FTS5 virtual table indexing transaction notes, account names, budget categories, and tags. Add a search Tauri command that queries the FTS index and returns ranked, typed results. Add a global search bar component in the app header.
- **Effort**: M

### P2-7: Add cloud sync conflict resolution UI
- **Module**: Cloud Sync
- **Dimension**: UI/UX
- **Current state**: Cloud sync infrastructure exists but conflicts are resolved silently (last-write-wins), with no visibility or user control over resolution.
- **Target state**: When sync conflicts occur, users see a resolution UI showing both versions and can choose which to keep.
- **Approach**: Detect conflicts by comparing version vectors. Build a modal component showing field-by-field diffs of conflicting records. User selects winner per field or per record. Selected resolution is written back and version vector is merged.
- **Effort**: M

### P2-8: Add Tags management page + update + soft delete
- **Module**: Tags
- **Dimension**: UI/UX + Business Logic
- **Current state**: Tags can be created and listed, but there is no dedicated management page, no edit/update capability, and no soft delete (only hard delete).
- **Target state**: A Tags management page with full CRUD including edit and soft delete (tombstone pattern consistent with other entities).
- **Approach**: Create `TagsManagementPage` with list, create, edit forms. Add update Tauri command. Change delete to set `deleted_at` timestamp instead of removing the row, consistent with the app's soft-delete pattern.
- **Effort**: S

---

## P3 — Low (Quality and consistency)

### P3-1: i18n: Replace hardcoded Chinese toast messages with i18n keys
- **Module**: Cross-cutting
- **Dimension**: UI/UX
- **Current state**: Several toast/notification messages contain hardcoded Chinese strings instead of `t()` calls, violating the ESLint `i18next/no-literal-string` rule and breaking language switching.
- **Target state**: All user-facing strings in toasts and notifications use `t('key')` with entries in both `en.json` and `zh.json`.
- **Approach**: Audit all toast calls for hardcoded strings. Extract to i18n keys, add translations to both locale files. Run `pnpm lint` to verify no violations remain.
- **Effort**: S

### P3-2: Clean up dead code (legacy debt.rs, stub category system)
- **Module**: Debts
- **Dimension**: Business Logic
- **Current state**: A legacy `debt.rs` module and a stub category system remain in the codebase, adding confusion and dead maintenance burden.
- **Target state**: Dead code removed. Active debt functionality lives in the proper DDD structure. Category system either fully implemented or cleanly removed.
- **Approach**: Identify all references to legacy debt types and stub category code. Migrate any active logic to the current DDD modules. Remove unreferenced dead code. Run full test suite to confirm no regressions.
- **Effort**: S

### P3-3: Add application service layer to Budget and Goals modules
- **Module**: Budget / Goals
- **Dimension**: Business Logic
- **Current state**: Budget and Goals modules skip the application service layer; presentation code calls domain/repositories directly, violating the DDD layering convention used by other modules.
- **Target state**: Both modules have proper application service classes following the same pattern as AccountService and TransactionService.
- **Approach**: Create `BudgetService` and `GoalService` in the application layer. Move business logic (validation, computation, coordination) from presentation handlers into these services. Thin the Tauri command handlers to simple delegation calls.
- **Effort**: M

### P3-4: Add pagination to Transactions and Holdings
- **Module**: Transactions / Holdings
- **Dimension**: Efficiency
- **Current state**: Transactions and Holdings pages load all records at once. Performance degrades as data grows, with no pagination or virtual scrolling.
- **Target state**: Both pages use cursor-based or offset pagination, loading data in pages of 50-100 items with infinite scroll or page controls.
- **Approach**: Add `limit`/`offset` parameters to the relevant list queries in Rust. Implement infinite scroll on the frontend using TanStack Query's `useInfiniteQuery`. Show a loading indicator during fetch.
- **Effort**: M

### P3-5: Add year-over-year comparison to Reports
- **Module**: Reports
- **Dimension**: Data Analysis
- **Current state**: Reports show data for a single period only. No comparative analysis across years is available.
- **Target state**: Income/expense reports support year-over-year comparison with side-by-side charts and percentage change indicators.
- **Approach**: Add a comparison mode toggle to the reports page. Query two date ranges (current and prior year), compute delta percentages. Render a grouped bar chart with current vs. prior year and a delta column.
- **Effort**: M

---

## Quick Wins (Highest impact-to-effort ratio)

These items require minimal effort but deliver outsized user value. Tackle these first for immediate improvement.

| Item | Effort | Impact | Why |
|------|--------|--------|-----|
| P0-1: Fix get_account_balance | S | Critical | All balance-dependent features are wrong until this is fixed |
| P0-2: Persist low_balance_threshold | S | Critical | Data silently lost on every account edit |
| P2-5: Add scheduled/automatic backup | S | High | Prevents data loss with zero ongoing user effort |
| P2-8: Add Tags management page | S | Medium | Completes a partially built feature with minimal work |
| P3-1: Replace hardcoded Chinese toasts | S | Medium | Quick i18n compliance fix, unblocks language switching |
| P3-2: Clean up dead code | S | Medium | Reduces confusion and maintenance burden immediately |
