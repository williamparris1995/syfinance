# Gap Analysis — Module Scores

**Date**: 2026-06-01
**Reference Average**: Data Analysis 4.7, UI/UX 4.8, Business Logic 4.5, Efficiency 4.5
**Scale**: 5 = matches/exceeds reference products, 1 = missing or non-functional

---

## Scoring Summary Table

### Group 1: Core Accounting

| Module | Data Analysis | UI/UX | Business Logic | Efficiency | Average | Gap |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|
| Accounts | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| Transactions | 2 | 3 | 4 | 2 | 2.8 | -1.8 |
| Reports | 2 | 3 | 3 | 3 | 2.8 | -1.8 |

### Group 2: Financial Management

| Module | Data Analysis | UI/UX | Business Logic | Efficiency | Average | Gap |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|
| Budget | 1 | 2 | 2 | 1 | 1.5 | -3.1 |
| Debts | 2 | 4 | 4 | 3 | 3.3 | -1.3 |
| Goals | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| Subscriptions | 2 | 4 | 3 | 3 | 3.0 | -1.6 |

### Group 3: Investment & Assets

| Module | Data Analysis | UI/UX | Business Logic | Efficiency | Average | Gap |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|
| Holdings | 2 | 3 | 3 | 3 | 2.8 | -1.8 |
| Prepaid | 1 | 3 | 3 | 2 | 2.3 | -2.3 |
| Multi-currency | 1 | 2 | 3 | 1 | 1.8 | -2.8 |

### Group 4: System Features

| Module | Data Analysis | UI/UX | Business Logic | Efficiency | Average | Gap |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|
| Backup | 3 | 4 | 4 | 3 | 3.5 | -1.1 |
| Cloud Sync | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| Encryption | N/A | 4 | 3 | 4 | 3.7* | -0.9* |
| Reminders | N/A | 1 | 2 | 1 | 1.3* | -3.3* |
| Tags | 1 | 2 | 2 | 2 | 1.8 | -2.8 |
| Export | 1 | 1 | 2 | 1 | 1.3 | -3.3 |
| Search | N/A | 4 | 3 | 3 | 3.3* | -1.3* |
| Onboarding | N/A | 3 | 3 | 3 | 3.0* | -1.6* |

\* Averages for N/A modules are computed from applicable dimensions only. Gap is against the reference average of those same dimensions.

### Overall Averages

| Group | Data Analysis | UI/UX | Business Logic | Efficiency | Overall |
|-------|:---:|:---:|:---:|:---:|:---:|
| Core Accounting | 2.0 | 3.0 | 3.3 | 2.3 | 2.7 |
| Financial Management | 1.8 | 3.3 | 3.0 | 2.3 | 2.6 |
| Investment & Assets | 1.3 | 2.7 | 3.0 | 2.0 | 2.3 |
| System Features | 1.6 | 2.8 | 2.8 | 2.3 | 2.4 |
| **All Modules** | **1.7** | **3.0** | **3.0** | **2.2** | **2.5** |
| **Reference Average** | **4.7** | **4.8** | **4.5** | **4.5** | **4.6** |
| **Gap** | **-3.0** | **-1.8** | **-1.5** | **-2.3** | **-2.1** |

---

## Detailed Scores

### Accounts
- **Data Analysis: 2** — No charts or trend visualizations on the account page. No balance history sparklines. No multi-currency conversion view. The only "analysis" is the transaction history list in the detail panel.
- **UI/UX: 3** — Functional CRUD with icon/color customization and detail panel. Copy-to-create works. Missing drag-drop reorder, no restore for soft-deleted accounts, category system is a stub (`ChartOfAccounts` aggregate exists but has no commands wired in).
- **Business Logic: 3** — 10 account types with ownership model is solid. However, `get_account_balance` returns only `initial_balance` (ignores transactions), `low_balance_threshold` is not persisted on update, and account update does not write `low_balance_threshold` to the database.
- **Efficiency: 2** — No import functionality, no reconciliation, no batch operations. Copy-to-create is the only efficiency feature. Category assignment is non-functional.

### Transactions
- **Data Analysis: 2** — No charts or analytics on the transactions page. No spending breakdowns, no category analysis, no trend views. The page is a flat list with filters.
- **UI/UX: 3** — Simplified income/expense/transfer forms with auto-type detection are good. Inline description editing and date range/type/account filters work. But the advanced `TransactionForm` is hidden from the UI, and there are no visual breakdowns.
- **Business Logic: 4** — Full double-entry enforcement with balanced entries is the strongest aspect. Optimistic updates with rollback. Proper entry-level tracking. Category field is a stub. Transfer limited to same currency.
- **Efficiency: 2** — No recurring/scheduled transactions, no templates beyond copy-to-create, no bulk operations, no amount range search, no pagination (all transactions loaded then filtered client-side). Search on the transactions page is limited to type/date/account.

### Reports
- **Data Analysis: 2** — Four chart types (expense donut, income donut, monthly stacked bar, income vs expense grouped bar) with date range presets and CSV export. No cash flow statement, no drill-down from charts, no net worth trend, no year-over-year comparison, no tag/category reports, no chart of accounts report. Balance sheet is not date-aware (date picker shown but only affects income statement).
- **UI/UX: 3** — Summary gradient cards and tab-based layout (balance sheet + income statement) are clean. But hardcoded `¥` symbol in all formatters, no PDF/print output, and no interactive drill-down make it feel static.
- **Business Logic: 3** — All computation is client-side from full datasets (no server-side aggregation), which is correct for an offline app but limits scalability. Balance sheet date filter is broken (only affects income statement). No cash flow statement at all.
- **Efficiency: 3** — Date range presets and CSV export with BOM are functional. No saved report configurations, no scheduled report generation, no email/notifications for reports.

### Budget
- **Data Analysis: 1** — No charts, no visualizations, no budget vs actual tracking. The `actual_amount` field on budget items is never populated (no transaction integration at all). The module is essentially a static list of planned amounts with no connection to real spending.
- **UI/UX: 2** — Month navigation, create/add item dialogs, overview cards with totals, and per-item progress bars exist. But progress bars show planned vs nothing (actuals are zero), so they are decorative. No edit budget after creation, no budget templates, no copy-to-next-month.
- **Business Logic: 2** — No application service layer — commands call the repository directly, violating the DDD architecture used by other modules (Debts, Subscriptions, Holdings all have proper service layers). No update item command. Actual amounts are never computed from transactions.
- **Efficiency: 1** — No templates, no auto-generation from previous month, no recurring budgets, no export. Creating a budget requires manual entry of every item from scratch each month.

### Debts
- **Data Analysis: 2** — Detail panel with payment schedule and transaction history. Overdue/upcoming payment panels. But no summary dashboard showing total owed/lent, monthly payment obligations, or debt reduction trends over time.
- **UI/UX: 4** — Clean create/edit/copy/delete flow with zod-validated forms. Detail panel with amortization schedule + transaction history tabs. Overdue and upcoming payment panels. This is one of the more polished modules.
- **Business Logic: 4** — Comprehensive service layer with full amortization (3 methods: equal payment, equal principal, interest-only). Proper double-entry for payments with partial payment support. However, two co-existing domain models exist (`debt.rs` and `debt_details.rs`) where the legacy `debt.rs` contains a separate `Debt` struct that appears to be dead code.
- **Efficiency: 3** — Copy-to-create, payment recording with partial support, amortization calculation. No early payoff calculator, no debt-to-budget integration, no payment reminders connected.

### Goals
- **Data Analysis: 2** — Progress percentage and summary cards with active/completed/overdue counts. Filter tabs. No projection/forecasting, no milestones, no completion trends.
- **UI/UX: 3** — Summary cards and filter tabs are functional. Create/update progress/complete/delete operations work. But no edit goal UI after creation (can only update progress, not change target amount or deadline), no completion celebration.
- **Business Logic: 3** — Three goal types (Savings/DebtPayoff/Investment) with auto-completion and linked account support. But no application service layer — commands call repository directly. `find_active` and `find_completed` repo methods exist but are dead code. No auto-sync from linked account balances.
- **Efficiency: 2** — No auto-sync from account balances (manual progress updates only), no milestones to break goals into steps, no templates, no integration with other modules. Hardcoded Chinese toast messages (`toast.error('请输入目标名称')`, `toast.error('请输入有效的目标金额')`).

### Subscriptions
- **Data Analysis: 2** — Monthly normalization summary cards showing total expense/income. Expandable rows with transaction history. No cost trend analysis over time, no annual projection, no category breakdown.
- **UI/UX: 4** — Well-designed with expandable rows, zod-validated form, pause/resume controls. Monthly normalization is a thoughtful UX touch. One of the better-looking modules.
- **Business Logic: 3** — Full service layer with auto-record background scheduler. Weekly/monthly/yearly/custom cycles work. Proper double-entry recording. But `category` field exists in DTO but not in form, transaction matching uses a fragile name-prefix heuristic, and no trial period tracking.
- **Efficiency: 3** — Auto-record scheduler and pause/resume are good. No subscription reminders, no grouping/tagging, no multi-currency support, no batch operations.

### Holdings
- **Data Analysis: 2** — Portfolio summary with total market value, cost, and P&L. Sortable table. No allocation pie chart, no historical performance line chart, no sector/type breakdown. Date range filters exist as UI state but are non-functional.
- **UI/UX: 3** — Sortable table with expandable trade history. Inline edit/delete trades. Security search with auto-create from external API. 7 security types. But hardcoded `¥` everywhere, no pagination for large portfolios.
- **Business Logic: 3** — Weighted average cost calculation and proper double-entry buy/sell are solid. `Dividend` and `Split` types exist in the enum but have no handlers. No lot tracking (FIFO/LIFO/LIFO). `update_holding_trade` uses raw SQL queries in the service layer, breaking the DDD pattern. No transaction wrapping for multi-step operations.
- **Efficiency: 3** — Security search with auto-create, inline edit, refresh prices button. No batch import of trades, no CSV import, no lot selection on sell.

### Prepaid
- **Data Analysis: 1** — Detail panel with stats (balance, total top-up, total consumption). No spending trend chart, no balance history over time, no usage patterns.
- **UI/UX: 3** — Full lifecycle UI: create with threshold, top-up dialog with preview, consumption via transactions, detail panel with stats + tabs. Clean and functional.
- **Business Logic: 3** — Full lifecycle: create with threshold, top-up with bonus, consumption via transactions, balance checks, low-balance alert construction. But `expiry_date` is stored but never checked/alerted, low-balance alert is constructed but not persisted or delivered, and no reconciliation.
- **Efficiency: 2** — No edit/delete top-up records, no preset amounts, no source balance display during top-up, no spending limits, no batch operations.

### Multi-currency
- **Data Analysis: 1** — No rate trends, no historical rates, no currency performance charts. The module is purely a rate management utility with no analytical features.
- **UI/UX: 2** — CRUD form with code/symbol/rate works. But no management UI for edit/delete of existing currencies, no name field in the form, no visual rate comparison. The form is minimal.
- **Business Logic: 3** — Currency value object with validation, conversion through base currency. But no base currency concept (assumes CNY), conversion uses `f64` (precision loss for financial calculations), no precision rules, no activate/deactivate logic.
- **Efficiency: 1** — No auto-fetch rates, no batch rate update, no historical rate import, no API integration. Every rate must be manually entered and maintained.

### Backup
- **Data Analysis: 3** — Diff comparison per table during restore is a strong analytical feature. Backup metadata (date, size, encryption status) is tracked. No backup history trends or storage analytics.
- **UI/UX: 4** — Backup list with metadata, restore dialog with diff UI, cloud config dialog with 8 WebDAV presets. The diff comparison UI is well-designed. Missing progress indicator and backup preview.
- **Business Logic: 4** — Full backup/restore with 9 tables, gzip + optional AES-256 encryption, 3 conflict strategies, safety backup before restore. Solid implementation. Dropbox/Google Drive/OneDrive are stubs returning `NotConfigured`.
- **Efficiency: 3** — WebDAV with presets is convenient. No scheduled/auto backup, no incremental backups, no file size management, no cleanup policies.

### Cloud Sync
- **Data Analysis: 2** — Sync status display with last sync time. No sync history log, no bandwidth reporting, no analytics on sync operations.
- **UI/UX: 3** — Settings page section with enable/toggle/sync now/status. Functional but minimal. No conflict resolution UI, no detailed sync progress.
- **Business Logic: 3** — Full sync cycle implemented (create backup, upload, download newer, restore with keep_newer). Background scheduler with configurable interval and backoff retry exists. Encryption-aware. But conflict resolution is limited to `keep_newer` strategy with no UI for resolving conflicts.
- **Efficiency: 2** — Sync now button works. No cancel operation, no connectivity detection, no selective sync, no bandwidth throttling.

### Encryption
- **Data Analysis: N/A** — Not applicable to this module.
- **UI/UX: 4** — Setup/unlock/lock/disable lifecycle is clean. OS keychain integration is transparent to the user. Password input dialog works well.
- **Business Logic: 3** — AES-256-GCM + PBKDF2-SHA256 (100K iterations) + OS keychain is solid cryptography. But `unlock()` doesn't verify password correctness (decrypts without checking if the result is valid), `encrypt_field`/`decrypt_field` methods exist but are not applied to any database columns (only backup files are encrypted), no key rotation, no re-encryption on password change.
- **Efficiency: 4** — OS keychain eliminates repeated password entry. Lock/unlock is fast. Once unlocked, encryption is transparent.

### Reminders
- **Data Analysis: N/A** — Not applicable to this module.
- **UI/UX: 1** — No frontend UI at all. No reminder page, no hooks, no components, no Tauri commands wired to the frontend. The module exists only as backend domain/infrastructure code.
- **Business Logic: 2** — Domain model with 4 types + repeat patterns + priority is well-designed. Scheduler logic with trigger and create-next-cycle works in tests. But no periodic invocation daemon (the scheduler is never started in `main.rs`), notification dispatch is a pass-through to a sender that has no real implementation, no snooze/dismiss logic.
- **Efficiency: 1** — No auto-creation from debts/bills, no snooze, no templates, no bulk dismiss. The module is entirely non-functional from the user's perspective.

### Tags
- **Data Analysis: 1** — No usage counts, no tag-based reporting, no tag cloud, no analytics. Tags are a flat list with no analytical value.
- **UI/UX: 2** — Basic create/delete/assign-to-transaction works. No update tag command, no color picker, no autocomplete when assigning tags, no tag management page (tags are managed inline).
- **Business Logic: 2** — Minimal domain model (id/name/color). No validation, no soft delete (hard delete only), no sync metadata, no hierarchy or nesting, no uniqueness constraint. Extremely thin compared to other aggregates.
- **Efficiency: 2** — Create/delete/assign/remove operations work. No bulk operations, no autocomplete, no tag suggestions based on transaction patterns, no import/export.

### Export
- **Data Analysis: 1** — Returns raw JSON data with no formatting, no analysis, no transformation. No filtering, no aggregation, no report generation.
- **UI/UX: 1** — No file output — returns JSON to the frontend via Tauri command. No file save dialog, no progress indicator, no format selection. The user gets a JSON object in memory.
- **Business Logic: 2** — Exports 6 tables (accounts, transactions, debts, goals, budgets, tags) via dynamic row-to-JSON conversion. Missing tables compared to the backup schema (holdings, subscriptions, currencies, reminders, etc.). No data validation during export.
- **Efficiency: 1** — No format options (no CSV, Excel, OFX, QIF, PDF), no filtering by date range or entity type, no import functionality, no scheduled exports.

### Search
- **Data Analysis: N/A** — Not applicable to this module.
- **UI/UX: 4** — Cmd+K shortcut, keyboard navigation, debounced input, type icons, loading/empty states. Well-designed global search experience.
- **Business Logic: 3** — Searches accounts, transactions, and goals. Uses SQL LIKE (no full-text search). Transactions search doesn't navigate to the specific record. Only 3 entity types indexed.
- **Efficiency: 3** — Fast and responsive. But no search history, no advanced filters, no highlighting of matches, no suggestions/autocomplete.

### Onboarding
- **Data Analysis: N/A** — Not applicable to this module.
- **UI/UX: 3** — 3-screen flow (choice, register or link) is clean. Preset investment accounts and copy-to-clipboard account ID are thoughtful. But no currency selection (hardcoded CNY), no encryption prompt, no tutorial/walkthrough after onboarding.
- **Business Logic: 3** — Device registration flow works. Preset investment accounts auto-create. But no data import option during onboarding, no skip option (users must complete the flow), no progress indicator.
- **Efficiency: 3** — Copy-to-clipboard for account ID saves time. Preset investment accounts reduce setup friction. But no bulk import, no template selection, no way to skip and configure later.

---

## Priority Ranking (by gap size, largest first)

| Rank | Module | Average | Gap | Priority |
|------|--------|:---:|:---:|:---:|
| 1 | Export | 1.3 | -3.3 | Critical |
| 2 | Reminders | 1.3* | -3.3* | Critical |
| 3 | Budget | 1.5 | -3.1 | Critical |
| 4 | Multi-currency | 1.8 | -2.8 | High |
| 5 | Tags | 1.8 | -2.8 | High |
| 6 | Prepaid | 2.3 | -2.3 | High |
| 7 | Accounts | 2.5 | -2.1 | High |
| 8 | Goals | 2.5 | -2.1 | High |
| 9 | Cloud Sync | 2.5 | -2.1 | Medium |
| 10 | Transactions | 2.8 | -1.8 | Medium |
| 11 | Reports | 2.8 | -1.8 | Medium |
| 12 | Holdings | 2.8 | -1.8 | Medium |
| 13 | Subscriptions | 3.0 | -1.6 | Medium |
| 14 | Debts | 3.3 | -1.3 | Low |
| 15 | Backup | 3.5 | -1.1 | Low |
| 16 | Encryption | 3.7* | -0.9* | Low |

\* Averages for modules with N/A dimensions are computed from applicable dimensions only.
