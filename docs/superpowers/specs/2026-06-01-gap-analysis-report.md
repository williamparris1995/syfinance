# Gap Analysis — Detailed Report

**Date**: 2026-06-01
**Scope**: Full application code review across 16 modules
**Reference Products**: 随手记 (Suishouji), MoneyWiz, YNAB
**Reference Averages**: Data Analysis 4.7, UI/UX 4.8, Business Logic 4.5, Efficiency 4.5

---

## 1. Executive Summary

This personal finance application demonstrates a solid architectural foundation with proper double-entry bookkeeping, domain-driven design in Rust, and a well-structured React frontend. However, it lags significantly behind reference products in two critical dimensions: **Data Analysis** (gap: -3.0) and **Efficiency** (gap: -2.3). The overall weighted average across all 16 modules is **2.5 out of 5.0**, representing a gap of **-2.1** from the reference average of 4.6.

### Biggest Gaps

1. **Export (1.3)** — Returns raw JSON to the frontend with no file save, no format options, no filtering. This is the widest gap and a basic expectation for any finance app.
2. **Reminders (1.3)** — Entirely non-functional from the user's perspective. Domain model and scheduler exist in backend code, but no Tauri commands are wired, no frontend page exists, and the notification sender has no real implementation.
3. **Budget (1.5)** — Actual amounts are never populated from transactions, making budget tracking decorative rather than functional. No application service layer violates the project's own DDD architecture.
4. **Multi-currency (1.8)** — Assumes CNY everywhere. No auto-fetch rates, no historical rates, `f64` precision for financial calculations, no management UI for editing existing currencies.
5. **Tags (1.8)** — Extremely thin aggregate with no soft delete, no validation, no reporting integration, no autocomplete.

### Recommended Priorities

| Priority | Focus | Impact |
|----------|-------|--------|
| **P0 — Critical** | Wire Budget to Transactions (compute actuals) | Makes Budget functional |
| **P0 — Critical** | Build Reminders frontend + wire commands | Unlocks a completed feature |
| **P1 — High** | Add Export formats (CSV, file save dialog) | Basic user expectation |
| **P1 — High** | Fix Reports drill-down + date-aware balance sheet | Core analytical value |
| **P1 — High** | Add Transaction recurring/scheduled + templates | Major efficiency gain |
| **P2 — Medium** | Multi-currency auto-fetch + precision fix | International viability |
| **P2 — Medium** | Holdings allocation chart + dividend/split handlers | Investment completeness |
| **P3 — Low** | i18n cleanup (remove hardcoded ¥, Chinese toasts) | Quality/consistency |
| **P3 — Low** | Clean up dead code (legacy debt.rs, stub categories) | Maintainability |

---

## 2. Group 1: Core Accounting

### 2.1 Accounts

**Current State Assessment**

The Accounts module supports 10 account types (Cash, Bank, CreditCard, Investment, BorrowedOut, BorrowedIn, Prepaid, Other, Income, Expense) with an ownership model (Own/External). Full CRUD with icon/color customization, copy-to-create, 7 investment presets, and a detail panel with transaction history are implemented. The prepaid lifecycle includes top-up, bonus, consumption, balance checks, and low-balance warnings.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Account types | 10 | 15+ | 12+ | 8 |
| Multi-currency per account | Partial | Yes | Yes | Yes |
| Balance history chart | No | Yes | Yes | Yes |
| Drag-drop reorder | No | Yes | Yes | Yes |
| Account reconciliation | No | Yes | Yes | Yes |
| Import from bank | No | Yes (OCR) | Yes | Yes |
| Restore deleted | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 2** — The account page has no charts, no balance trends, no sparklines. The detail panel shows only a flat transaction history list. 随手记 shows balance trends, category breakdowns, and spending patterns per account. MoneyWiz provides account-level sparklines and performance tracking.
- **UI/UX: 3** — Functional CRUD with icon/color customization and copy-to-create. The detail panel with transaction history is useful. But missing drag-drop reorder, no restore for soft-deleted accounts, and the `ChartOfAccounts` category system is a stub (aggregate and repository exist but no Tauri commands are wired to the frontend).
- **Business Logic: 3** — The 10 account types with ownership model is well-designed. However, a critical bug exists: `get_account_balance` returns only `initial_balance` and ignores actual transactions, making balance display incorrect. The `low_balance_threshold` field is read from the database but not written during update operations.
- **Efficiency: 2** — No import, no reconciliation, no batch operations. Copy-to-create is the sole efficiency feature.

**Key Gaps (Ranked by Impact)**

1. `get_account_balance` ignores transactions — incorrect balance display (Critical)
2. No charts/trends on account page (High)
3. `low_balance_threshold` not persisted on update (High)
4. No account reconciliation workflow (Medium)
5. No import from bank/CSV (Medium)
6. No drag-drop reorder (Low)
7. Category system is a stub (Low)

**Improvement Suggestions**

- *Short-term*: Fix `get_account_balance` to sum transaction entries against initial balance. Persist `low_balance_threshold` on update. Add balance sparkline to account detail panel.
- *Long-term*: Implement reconciliation workflow. Add CSV/bank import. Wire `ChartOfAccounts` commands to the frontend for category management. Add multi-currency balance conversion view.

---

### 2.2 Transactions

**Current State Assessment**

The Transactions module enforces full double-entry bookkeeping with balanced entries. It offers simplified income/expense/transfer forms with auto-type detection, inline description editing, date range + type + account filters, optimistic updates with rollback, and copy-to-create.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Double-entry enforcement | Yes | Partial | Yes | Partial |
| Scheduled/recurring | No | Yes | Yes | Yes |
| OCR receipt scanning | No | Yes | No | No |
| Bulk operations | No | Yes | Yes | Yes |
| Category auto-suggest | No | Yes | Partial | Yes |
| Attachments/receipts | No | Yes | Yes | No |
| Amount range search | No | Yes | Yes | Yes |
| Pagination | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 2** — No charts, no spending breakdowns, no category analysis, no trends on the transactions page. It is purely a flat list with filters. Reference products show inline spending analysis, category breakdowns, and trend indicators.
- **UI/UX: 3** — The simplified form with auto-type detection (income/expense/transfer) is a good UX pattern. Inline description editing is convenient. But the advanced `TransactionForm` component exists and is hidden from the UI, meaning users cannot access full double-entry entry editing.
- **Business Logic: 4** — This is the module's strongest dimension. Full double-entry enforcement with balanced entries is mathematically correct. Optimistic updates with rollback provide good error recovery. Auto-type detection from entry patterns works well. The only notable gap is that the category field is a stub and transfers are limited to same-currency.
- **Efficiency: 2** — No recurring/scheduled transactions (a top feature in all reference products), no templates beyond copy-to-create, no bulk operations, no amount range search. Performance concern: `get_transactions_by_account` loads all transactions then filters client-side with no pagination.

**Key Gaps (Ranked by Impact)**

1. No recurring/scheduled transactions (Critical)
2. No pagination — loads all transactions (High)
3. No bulk operations (High)
4. No charts/analytics on page (Medium)
5. Category field is a stub (Medium)
6. Advanced TransactionForm hidden from UI (Medium)
7. Transfer same-currency only (Low)

**Improvement Suggestions**

- *Short-term*: Add server-side pagination to transaction queries. Expose the advanced TransactionForm via a toggle. Add spending breakdown donut chart to the page header.
- *Long-term*: Implement recurring/scheduled transactions with auto-recording (similar to the subscription scheduler pattern already in the codebase). Add batch operations (bulk delete, bulk recategorize). Implement full-text search with SQLite FTS5.

---

### 2.3 Reports

**Current State Assessment**

The Reports module provides two tabs: Balance Sheet and Income Statement. It includes 4 chart types (expense donut, income donut, monthly expense stacked bar, income vs expense grouped bar), date range presets, CSV export with BOM for Excel compatibility, and summary gradient cards.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Chart types | 4 | 20+ | 10+ | 8+ |
| Balance sheet | Partial | Yes | Yes | No |
| Income statement | Yes | Yes | Yes | Yes |
| Cash flow statement | No | Yes | Yes | No |
| Drill-down from charts | No | Yes | Yes | Yes |
| Net worth trend | No | Yes | Yes | Yes |
| Tag-based reports | No | Yes | Yes | Yes |
| Year-over-year | No | Yes | Yes | Yes |
| PDF/print | No | Yes | Yes | Yes |
| Custom date ranges | Partial | Yes | Yes | Yes |
| Category reports | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 2** — Four chart types is adequate for a basic finance app but far behind 随手记's 20+ chart types. No drill-down from any chart, no net worth trend, no cash flow statement, no tag-based reporting. The balance sheet's date picker is shown but only affects the income statement (balance sheet always shows current state), which is misleading.
- **UI/UX: 3** — Summary gradient cards and the two-tab layout are visually clean. The hardcoded `¥` symbol in all chart formatters (at least 10 instances in `ReportsPage.tsx`) means the reports are broken for any non-CNY user. No PDF/print output limits sharing.
- **Business Logic: 3** — All computation is client-side from full datasets. This is acceptable for an offline app but means every report requires loading the complete transaction history. The balance sheet date filter bug (date picker shown but ignored) is a correctness issue. No cash flow statement exists.
- **Efficiency: 3** — Date range presets (this month, last month, this quarter, this year, custom) are convenient. CSV export with BOM is well-implemented. No saved report configurations or scheduled generation.

**Key Gaps (Ranked by Impact)**

1. No drill-down from charts (High)
2. Balance sheet not date-aware — misleading UI (High)
3. No cash flow statement (High)
4. Hardcoded `¥` in all chart formatters (Medium)
5. No net worth trend over time (Medium)
6. No year-over-year comparison (Medium)
7. No PDF/print output (Low)

**Improvement Suggestions**

- *Short-term*: Fix balance sheet to be date-aware. Add click-to-drill-down on chart segments (navigate to filtered transaction list). Replace hardcoded `¥` with currency formatting utility.
- *Long-term*: Add cash flow statement. Implement net worth trend line chart. Add tag-based and category-based report tabs. Add year-over-year comparison view. Implement PDF export.

---

## 3. Group 2: Financial Management

### 3.1 Budget

**Current State Assessment**

The Budget module has a domain model with `Budget` and `BudgetItem` entities, month navigation, create/add item dialogs, overview cards showing total/used/remaining/usage rate, per-item progress bars, and delete confirmation.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Budget vs actual tracking | No (actuals empty) | Yes | Yes | Yes (core) |
| Auto-populate from transactions | No | Yes | Yes | Yes |
| Rollover unused budget | No | Yes | Yes | Yes |
| Budget templates | No | Yes | Yes | Yes |
| Copy previous month | No | Yes | Yes | Yes |
| Budget charts | No | Yes | Yes | Yes |
| Category-level budget | No | Yes | Yes | Yes |
| Goal-linked budget | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 1** — The `actual_amount` field on budget items is never populated. The budget has no connection to actual transactions. Progress bars show planned amounts against zero actuals, making them decorative. This is the module's fundamental flaw.
- **UI/UX: 2** — The visual structure (summary cards, progress bars, month navigation) is well-laid-out, but because actuals are always zero, the entire page gives false information. No edit budget after creation, no templates, no copy-to-next-month.
- **Business Logic: 2** — No application service layer exists. The `budget_commands.rs` directly imports and uses `SqliteBudgetRepository`, bypassing the application layer entirely. This violates the DDD architecture that other modules follow (Debts, Subscriptions, Holdings all have proper service layers). No update item command exists.
- **Efficiency: 1** — Creating a budget requires manual entry of every item from scratch. No templates, no auto-generation from previous months, no recurring budgets, no export. This is the least efficient module in the application.

**Key Gaps (Ranked by Impact)**

1. Actual amounts never populated — module is non-functional (Critical)
2. No application service layer — architecture violation (Critical)
3. No budget templates or copy-from-previous (High)
4. No charts/visualizations (High)
5. No edit budget after creation (Medium)
6. No rollover unused budget (Medium)
7. No category-level budget (Low)

**Improvement Suggestions**

- *Short-term*: Create `BudgetService` in the application layer. Implement actual amount computation by querying transactions for the budget period grouped by category/account. Add update budget item command. This alone would make the module functional.
- *Long-term*: Add budget templates with copy-from-previous-month. Implement rollover logic. Add budget vs actual charts (bar chart with planned/actual side by side). Integrate with Goals module for goal-linked budgets.

---

### 3.2 Debts

**Current State Assessment**

The Debts module is one of the more complete modules, with a comprehensive service layer (`debt_service.rs`), full amortization with 3 methods (equal payment, equal principal, interest-only), overdue/upcoming payment panels, create/edit/copy/delete operations, payment recording with partial support, proper double-entry for payments, a detail panel with schedule + transaction history, and zod-validated forms.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Amortization methods | 3 | 2 | 3 | N/A |
| Payment recording | Full | Full | Full | N/A |
| Partial payments | Yes | Yes | Yes | N/A |
| Early payoff calc | No | Yes | Yes | N/A |
| Debt summary dashboard | No | Yes | Yes | N/A |
| Payment reminders | No | Yes | Yes | N/A |
| Debt reduction trend | No | Yes | Yes | N/A |
| Multi-currency | No | Yes | Yes | N/A |

**Dimension Scores**

- **Data Analysis: 2** — The detail panel with amortization schedule and transaction history is good. Overdue/upcoming payment panels provide actionable information. But no summary dashboard showing total owed vs total lent, no monthly payment obligations overview, and no debt reduction trend chart.
- **UI/UX: 4** — Clean create/edit/copy/delete flow. Zod-validated forms prevent invalid input. The detail panel with tabs (schedule + transaction history) is well-organized. Overdue and upcoming payment panels provide clear visual prioritization.
- **Business Logic: 4** — The service layer is comprehensive. Three amortization methods cover standard lending scenarios. Double-entry for payments with partial payment support is correct. The main issue is two co-existing domain models: `debt.rs` contains a `Debt` struct with 76 lines, while `debt_details.rs` contains a separate `DebtDetails` struct with amortization schedule. The legacy `debt.rs` appears to be dead code that should be cleaned up.
- **Efficiency: 3** — Copy-to-create and payment recording with partial support are good. No early payoff calculator, no debt-to-budget integration, no payment reminders.

**Key Gaps (Ranked by Impact)**

1. No summary dashboard (total owed/lent, monthly obligations) (High)
2. No debt reduction trend chart (Medium)
3. Legacy `debt.rs` dead code should be cleaned up (Medium)
4. No payment reminders connected to Reminders module (Medium)
5. No early payoff calculator (Low)
6. Currency hardcoded CNY, `¥` hardcoded (Low)
7. No export functionality (Low)

**Improvement Suggestions**

- *Short-term*: Add summary cards showing total owed, total lent, monthly payment obligations. Clean up the dual debt model (remove or merge `debt.rs` into `debt_details.rs`).
- *Long-term*: Add debt reduction trend chart. Connect to Reminders module for payment reminders. Add early payoff calculator with interest savings. Integrate with Budget for monthly payment planning.

---

### 3.3 Goals

**Current State Assessment**

The Goals module supports 3 goal types (Savings, DebtPayoff, Investment) with progress percentage, auto-completion, summary cards with active/completed/overdue counts, filter tabs, and create/update progress/complete/delete operations. Goals can be linked to accounts.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Goal types | 3 | 5+ | 5+ | Yes (core) |
| Auto-sync from accounts | No | Yes | Yes | Yes |
| Projection/forecasting | No | Yes | Yes | Yes |
| Milestones | No | Yes | Yes | Yes |
| Completion celebration | No | Yes | No | No |
| Edit goal after creation | Partial | Yes | Yes | Yes |
| Goal-based reporting | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 2** — Progress percentage and summary cards with active/completed/overdue counts provide basic tracking. No projection/forecasting (how long until goal is reached at current rate), no milestones to break goals into checkpoints, no goal achievement trends.
- **UI/UX: 3** — Summary cards and filter tabs are functional. Create and update-progress work. But there is no edit goal UI (users cannot change target amount, deadline, or linked account after creation — only update progress amount). No completion celebration or feedback.
- **Business Logic: 3** — Three goal types with auto-completion and linked account support is reasonable. But no application service layer — `goal_commands.rs` calls `SqliteGoalRepository` directly, violating DDD architecture. `find_active` and `find_completed` repository methods are dead code. No auto-sync from linked account balances.
- **Efficiency: 2** — Manual progress updates only (no auto-sync from account balances). No milestones, no templates, no integration with other modules. Hardcoded Chinese toasts (`toast.error('请输入目标名称')`, `toast.error('请输入有效的目标金额')`, `toast.error('请输入有效的金额')`) violate the project's own i18n rules.

**Key Gaps (Ranked by Impact)**

1. No auto-sync from linked account balances (High)
2. No application service layer — architecture violation (High)
3. No edit goal UI after creation (Medium)
4. No projection/forecasting (Medium)
5. Hardcoded Chinese toasts — i18n violation (Medium)
6. Dead code: `find_active`/`find_completed` (Low)
7. No milestones or completion celebration (Low)

**Improvement Suggestions**

- *Short-term*: Create `GoalService` in the application layer. Add edit goal dialog. Replace hardcoded Chinese toasts with `t()` calls. Implement auto-sync from linked account balances (query account balance on page load).
- *Long-term*: Add projection/forecasting (linear regression on current savings rate). Implement milestones with notifications. Add goal-based reporting (goal achievement over time). Integrate with Budget module.

---

### 3.4 Subscriptions

**Current State Assessment**

The Subscriptions module has a full service layer, auto-record background scheduler, weekly/monthly/yearly/custom cycles, pause/resume, monthly normalization summary cards, expandable rows with transaction history, proper double-entry recording, and zod-validated forms.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Auto-record scheduler | Yes | Yes | Yes | Yes |
| Pause/resume | Yes | No | No | No |
| Custom cycles | Yes | Yes | Yes | Yes |
| Cost trend analysis | No | Yes | Yes | Yes |
| Trial period tracking | No | Yes | No | No |
| Category field | DTO only | Yes | Yes | Yes |
| Subscription reminders | No | Yes | Yes | Yes |
| Annual projection | No | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 2** — Monthly normalization summary cards (total monthly expense/income) are useful. Expandable rows with transaction history. But no cost trend analysis over time, no annual projection, no category breakdown.
- **UI/UX: 4** — Well-designed with expandable rows, pause/resume controls, and monthly normalization. The form is zod-validated. The expandable transaction history under each subscription is a good UX pattern. One of the better-looking modules.
- **Business Logic: 3** — Full service layer with auto-record background scheduler is solid. Proper double-entry recording. But the `category` field exists in the DTO but is not included in the form, making it unusable. Transaction matching uses a fragile name-prefix heuristic (`subscription.name` prefix match) that could break with edited descriptions.
- **Efficiency: 3** — Auto-record scheduler and pause/resume are good. No subscription reminders, no grouping/tagging, no multi-currency support.

**Key Gaps (Ranked by Impact)**

1. Transaction matching uses fragile name-prefix heuristic (High)
2. No cost trend analysis over time (Medium)
3. Category field in DTO but not in form (Medium)
4. No subscription reminders (Medium)
5. No annual projection (Low)
6. No grouping/tagging (Low)
7. `¥` hardcoded in amount display (Low)

**Improvement Suggestions**

- *Short-term*: Add `category` field to the subscription form. Improve transaction matching to use a `subscription_id` reference field instead of name-prefix heuristic.
- *Long-term*: Add cost trend chart (monthly subscription cost over 12 months). Implement subscription reminders (connect to Reminders module). Add annual projection card. Add grouping by category.

---

## 4. Group 3: Investment & Assets

### 4.1 Holdings

**Current State Assessment**

The Holdings module implements weighted average cost calculation, proper double-entry buy/sell, portfolio summary with P&L, sortable table with expandable trade history, inline edit/delete trades, security search with auto-create from external API, and 7 security types.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Buy/sell tracking | Yes | Yes | Yes | No |
| Dividend tracking | Enum only | Yes | Yes | No |
| Stock splits | Enum only | Yes | Yes | No |
| Lot tracking (FIFO/LIFO) | No | Yes | Yes | No |
| Allocation chart | No | Yes | Yes | No |
| Historical performance | No | Yes | Yes | No |
| Real-time quotes | Button refresh | Yes | Yes | No |
| Multi-currency | No | Yes | Yes | No |

**Dimension Scores**

- **Data Analysis: 2** — Portfolio summary with total market value, cost, and P&L is functional. Sortable table. But no allocation pie chart (by security type or individual holding), no historical performance line chart, and date range filters exist as UI state but are non-functional (filter state is saved but never applied to queries).
- **UI/UX: 3** — Sortable table with expandable trade history is good. Inline edit/delete trades is convenient. Security search with auto-create from external API is a nice feature. But hardcoded `¥` everywhere, no pagination for large portfolios, and non-functional date filters are confusing.
- **Business Logic: 3** — Weighted average cost and proper double-entry buy/sell are correct. However, `Dividend` and `Split` transaction types exist in the enum but have no handler implementations (buy and sell only). `update_holding_trade` in `holding_service.rs` uses raw SQL queries, breaking the project's own DDD pattern (other services use repository abstractions). No transaction wrapping for multi-step operations means a failed sell could leave the database in an inconsistent state.
- **Efficiency: 3** — Security search with auto-create, inline edit, and refresh prices button are good. No batch import of trades, no CSV import, no lot selection on sell.

**Key Gaps (Ranked by Impact)**

1. Dividend and Split types in enum but no handlers (High)
2. No transaction wrapping for multi-step operations — data integrity risk (High)
3. `update_holding_trade` uses raw SQL — DDD violation (Medium)
4. No allocation chart or performance chart (Medium)
5. Date range filters are non-functional UI (Medium)
6. No lot tracking (FIFO/LIFO) (Medium)
7. Hardcoded `¥` and CNY for new securities (Low)

**Improvement Suggestions**

- *Short-term*: Implement dividend and split handlers. Wrap buy/sell operations in SQL transactions. Replace raw SQL in `update_holding_trade` with repository pattern. Fix date range filters to actually apply to queries.
- *Long-term*: Add allocation pie chart (by type and by holding). Add historical performance line chart. Implement lot tracking with FIFO/LIFO selection. Replace hardcoded `¥` with currency formatting.

---

### 4.2 Prepaid

**Current State Assessment**

The Prepaid module implements a full lifecycle: create with threshold, top-up with bonus, consumption via transactions, balance checks, and low-balance alert construction. It includes a top-up dialog with preview and a detail panel with stats + tabs.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Prepaid card lifecycle | Yes | Yes | No | No |
| Top-up with bonus | Yes | Yes | No | No |
| Balance checks | Yes | Yes | No | No |
| Low-balance alert | Constructed only | Yes | No | No |
| Expiry tracking | Stored only | Yes | No | No |
| Spending trend | No | Yes | No | No |
| Balance history | No | Yes | No | No |

**Dimension Scores**

- **Data Analysis: 1** — Detail panel shows basic stats (current balance, total top-up, total consumption). No spending trend chart, no balance history over time, no usage pattern analysis. This is a unique feature that no reference product covers well, so even basic analytics would be differentiated.
- **UI/UX: 3** — The lifecycle UI is well-structured: create with threshold, top-up dialog with preview, consumption via transactions, detail panel with stats + tabs. Functional and clean.
- **Business Logic: 3** — Full lifecycle logic is implemented. But `expiry_date` is stored in the database but never checked or alerted. Low-balance alerts are constructed in code but not persisted or delivered (the alert is built but never shown to the user). No reconciliation between prepaid balance and actual card balance.
- **Efficiency: 2** — No edit/delete top-up records, no preset amounts for top-up, no source balance display during top-up (user cannot see if they have enough in the source account), no spending limits.

**Key Gaps (Ranked by Impact)**

1. Low-balance alert constructed but never shown to user (High)
2. `expiry_date` stored but never checked/alerted (High)
3. No spending trend chart or balance history (Medium)
4. No edit/delete top-up records (Medium)
5. No source balance display during top-up (Low)
6. No spending limits (Low)
7. Hardcoded `¥` in amount display (Low)

**Improvement Suggestions**

- *Short-term*: Wire low-balance alerts to the notification system. Add expiry date checking with warnings (7 days before, 1 day before). Add a simple balance history line chart.
- *Long-term*: Add edit/delete for top-up records. Implement spending limits with notifications. Add preset top-up amounts. Show source account balance during top-up.

---

### 4.3 Multi-currency

**Current State Assessment**

The Multi-currency module provides a Currency value object with validation, CRUD with exchange rates, conversion through a base currency, and add/update rate/delete hooks with a form for code/symbol/rate.

**Reference Comparison**

| Feature | This App | 随手记 | MoneyWiz | YNAB |
|---------|:---:|:---:|:---:|:---:|
| Multi-currency support | Partial | Yes | Yes | Yes |
| Auto-fetch rates | No | Yes | Yes | Yes |
| Historical rates | No | Yes | Yes | No |
| Rate trend charts | No | Yes | Yes | No |
| Currency formatting utility | No | Yes | Yes | Yes |
| Base currency concept | No (assumes CNY) | Yes | Yes | Yes |
| Precision rules | No (f64) | Yes (Decimal) | Yes | Yes |
| Management UI | Partial (add only) | Yes | Yes | Yes |

**Dimension Scores**

- **Data Analysis: 1** — No rate trends, no historical rates, no currency performance charts. The module is a flat rate management utility with zero analytical features.
- **UI/UX: 2** — The CRUD form for code/symbol/rate works for adding currencies. But there is no management UI for editing or deleting existing currencies. The form does not include a `name` field (only code and symbol). No visual rate comparison.
- **Business Logic: 3** — Currency value object with validation and conversion through base currency is architecturally sound. However, there is no base currency concept (hardcoded CNY assumption), conversion uses `f64` arithmetic (precision loss for financial calculations — 0.1 + 0.2 != 0.3), and no precision rules are defined.
- **Efficiency: 1** — No auto-fetch rates (all reference products auto-fetch from APIs), no batch rate update, no historical rate import. Every rate must be manually entered and maintained.

**Key Gaps (Ranked by Impact)**

1. No auto-fetch exchange rates from API (Critical)
2. `f64` precision for financial calculations (High)
3. No base currency concept — assumes CNY (High)
4. No edit/delete management UI (Medium)
5. No historical rates or rate trends (Medium)
6. No currency formatting utility (Medium)
7. Form missing `name` field (Low)

**Improvement Suggestions**

- *Short-term*: Replace `f64` with a fixed-point decimal type (e.g., `rust_decimal` crate). Add edit/delete currency to the management UI. Add currency formatting utility function to replace hardcoded `¥`.
- *Long-term*: Implement auto-fetch from exchange rate APIs. Add historical rate storage and trend charts. Implement proper base currency selection. Add batch rate update.

---

## 5. Group 4: System Features

### 5.1 Backup

**Current State Assessment**

The Backup module provides full backup/restore covering 9 tables, gzip compression with optional AES-256 encryption, 3 conflict strategies (skip, overwrite, keep_newer), diff comparison per table during restore, safety backup before restore, and WebDAV provider with 8 cloud presets.

**Dimension Scores**

- **Data Analysis: 3** — Diff comparison per table during restore is a strong analytical feature that most reference products lack. Backup metadata (date, size, encryption status, source device) is tracked and displayed.
- **UI/UX: 4** — Backup list with metadata, restore dialog with diff UI, and cloud config dialog with 8 WebDAV presets are well-designed. The diff comparison showing added/modified/deleted records per table is excellent.
- **Business Logic: 4** — Full backup/restore with gzip + AES-256 encryption, 3 conflict strategies, and safety backup before restore is comprehensive. The WebDAV provider is fully implemented with proper error handling.
- **Efficiency: 3** — WebDAV with 8 presets (Alibaba Cloud, Baidu, Nutstore, Nextcloud, Koofr, Synology, ownCloud, Generic WebDAV) covers the major Chinese and international options. But Dropbox, Google Drive, and OneDrive providers are stubs that return `NotConfigured`. No scheduled/auto backup, no incremental backups.

**Key Gaps (Ranked by Impact)**

1. Dropbox/Google Drive/OneDrive are stubs (Medium)
2. No scheduled/auto backup (Medium)
3. No incremental backups (Low)
4. No progress indicator for large backups (Low)
5. No backup file size management/cleanup (Low)

**Improvement Suggestions**

- *Short-term*: Add progress indicator for backup/restore operations. Implement auto-cleanup of old backups (keep last N).
- *Long-term*: Implement OAuth flows for Dropbox/Google Drive/OneDrive. Add scheduled backup with configurable frequency. Add incremental backup support.

---

### 5.2 Cloud Sync

**Current State Assessment**

Cloud Sync implements a full sync cycle: create backup, upload, download newer backup, restore with keep_newer strategy. A background scheduler runs with configurable interval and exponential backoff retry. Encryption is supported. The Settings page has a Cloud Sync section with enable/toggle/sync now/status display.

**Dimension Scores**

- **Data Analysis: 2** — Sync status display with last sync time. No sync history log, no bandwidth reporting, no analytics on sync frequency or failure rates.
- **UI/UX: 3** — Settings section with enable/toggle/sync now/status is functional. No conflict resolution UI, no detailed progress during sync.
- **Business Logic: 3** — The sync cycle is complete and the scheduler runs as a background Tokio task with backoff retry. Conflict resolution is limited to `keep_newer` timestamp strategy with no user-facing conflict resolution. The sync is essentially "upload backup, download newer, restore" — not a true incremental sync.
- **Efficiency: 2** — Sync now button and automatic interval work. No cancel operation during sync, no connectivity detection (will attempt sync offline), no selective sync, no bandwidth throttling.

**Key Gaps (Ranked by Impact)**

1. No conflict resolution UI (High)
2. No sync history log (Medium)
3. No cancel operation during sync (Medium)
4. No connectivity detection (Medium)
5. Not incremental — full backup/restore each cycle (Low)

**Improvement Suggestions**

- *Short-term*: Add sync history log with timestamps and status. Add cancel button during sync. Add connectivity detection before sync attempt.
- *Long-term*: Implement conflict resolution UI showing conflicting records. Add incremental sync (only changed records). Add selective sync (choose which tables to sync).

---

### 5.3 Encryption

**Current State Assessment**

The Encryption module implements AES-256-GCM with PBKDF2-SHA256 (100K iterations) and OS keychain integration. It provides a full setup/unlock/lock/disable lifecycle with field-level encrypt/decrypt methods available in the application service.

**Dimension Scores**

- **UI/UX: 4** — The setup/unlock/lock/disable lifecycle is clean and intuitive. OS keychain integration means users don't need to re-enter passwords. The password input dialog is well-designed.
- **Business Logic: 3** — Cryptography is solid (AES-256-GCM + PBKDF2-SHA256 with 100K iterations). OS keychain integration is the right approach. However, `unlock()` does not verify password correctness (decrypts without checking if the result is valid — a wrong password would silently produce garbage). `encrypt_field` and `decrypt_field` methods exist in `EncryptionAppService` but are not applied to any database columns — only backup files are encrypted. No key rotation, no re-encryption on password change.
- **Efficiency: 4** — OS keychain eliminates repeated password entry. Lock/unlock is fast. Once unlocked, encryption operations are transparent to the user.

**Key Gaps (Ranked by Impact)**

1. `unlock()` doesn't verify password correctness (High)
2. Field-level encryption not applied to any DB columns (High)
3. No key rotation mechanism (Medium)
4. No password strength meter (Low)
5. No re-encryption on password change (Low)

**Improvement Suggestions**

- *Short-term*: Add password verification to `unlock()` (encrypt a known test value and verify decryption). Add password strength meter to the setup dialog.
- *Long-term*: Apply field-level encryption to sensitive columns (account numbers, institution names). Implement key rotation. Add re-encryption flow for password changes.

---

### 5.4 Reminders

**Current State Assessment**

The Reminders module has a well-designed domain model with 4 types, repeat patterns, and priority levels. A scheduler with trigger and create-next-cycle logic exists with mock-based unit tests. However, no Tauri commands are wired to the frontend, no frontend page or components exist, and the notification sender has no real implementation.

**Dimension Scores**

- **UI/UX: 1** — No frontend UI exists at all. No reminder page, no hooks, no components, no Tauri commands registered in `main.rs`. The user has zero access to reminder functionality.
- **Business Logic: 2** — The domain model (`Reminder` with 4 types, repeat patterns, priority) is well-designed. The scheduler logic (`check_and_trigger_reminders`, `mark_notified`, `create_next_cycle`) is tested and works. But the scheduler is never started in `main.rs` (unlike the subscription auto-record scheduler which is started). The `NotificationSender` trait has no real implementation — `send_notification` passes through to a sender that does nothing in production.
- **Efficiency: 1** — No auto-creation from debts/bills, no snooze, no dismiss, no templates. The module is entirely non-functional from the user's perspective.

**Key Gaps (Ranked by Impact)**

1. No frontend UI — module invisible to users (Critical)
2. No Tauri commands wired — no way to interact (Critical)
3. Scheduler never started in `main.rs` (Critical)
4. No real notification delivery implementation (High)
5. No integration with debts/subscriptions for auto-creation (Medium)
6. No snooze/dismiss logic (Low)

**Improvement Suggestions**

- *Short-term*: Wire Tauri commands (create, list, update, delete, dismiss, snooze). Create a Reminders page with list/timeline view. Start the reminder scheduler as a background task in `main.rs`.
- *Long-term*: Implement native notification delivery (Windows toast notifications via Tauri). Auto-create reminders from debt payment schedules and subscription renewals. Add reminder templates.

---

### 5.5 Tags

**Current State Assessment**

Tags is a minimal module with a domain model (id, name, color), CRUD hooks (create, list, delete), and transaction linking (add/remove tag, get transaction tags).

**Dimension Scores**

- **Data Analysis: 1** — No usage counts, no tag-based reporting, no tag cloud, no analytics. Tags provide zero analytical value despite being a powerful categorization tool in reference products.
- **UI/UX: 2** — Basic create/delete/assign-to-transaction works. No update tag command (must delete and recreate), no color picker, no autocomplete when assigning tags, no dedicated tag management page.
- **Business Logic: 2** — The domain model is extremely thin (just id/name/color). No validation (empty names, duplicate names), no soft delete (hard delete only, which could orphan transaction links), no sync metadata, no hierarchy or nesting.
- **Efficiency: 2** — Create/delete/assign/remove operations work. No bulk operations, no autocomplete, no tag suggestions based on transaction patterns.

**Key Gaps (Ranked by Impact)**

1. No tag-based reporting in Reports module (High)
2. No update tag command (Medium)
3. No validation or uniqueness constraints (Medium)
4. No soft delete — hard delete risks orphaned links (Medium)
5. No autocomplete in tag assignment (Low)
6. No hierarchy or nesting (Low)

**Improvement Suggestions**

- *Short-term*: Add update tag command. Implement soft delete. Add validation (non-empty name, uniqueness). Add autocomplete when assigning tags.
- *Long-term*: Implement tag-based reporting in the Reports module. Add tag hierarchy (parent/child). Add usage counts. Add tag suggestions based on transaction patterns.

---

### 5.6 Export

**Current State Assessment**

The Export module provides a single Tauri command `export_all_data` that queries 6 tables (accounts, transactions, debts, goals, budgets, tags) and returns a JSON object with dynamic row-to-JSON conversion.

**Dimension Scores**

- **Data Analysis: 1** — Returns raw JSON with no formatting, no analysis, no transformation. Not an analytical tool.
- **UI/UX: 1** — Returns JSON to the frontend via Tauri command. No file save dialog, no format selection, no progress indicator. The user receives a JSON object in memory with no clear way to save it to disk.
- **Business Logic: 2** — Exports 6 tables with dynamic row-to-JSON conversion. Missing tables compared to backup schema (holdings, securities, subscriptions, currencies, reminders, prepaid_accounts, cloud_sync_settings). Uses raw SQL queries in the command handler (not through repository layer).
- **Efficiency: 1** — No format options (no CSV, Excel, OFX, QIF, PDF), no filtering by date range or entity type, no import functionality, no scheduled exports.

**Key Gaps (Ranked by Impact)**

1. No file save dialog — JSON only returned to frontend (Critical)
2. No CSV format — basic expectation (Critical)
3. Missing tables vs backup schema (High)
4. No filtering options (Medium)
5. No import functionality (Medium)
6. No PDF/Excel formats (Low)

**Improvement Suggestions**

- *Short-term*: Add file save dialog using Tauri's dialog API. Implement CSV export with proper encoding. Add missing tables (holdings, subscriptions, currencies, reminders).
- *Long-term*: Add Excel export (xlsx). Implement OFX/QIF import/export for bank compatibility. Add PDF report generation. Add data import from CSV/Excel.

---

### 5.7 Search

**Current State Assessment**

Global search with Cmd+K shortcut, keyboard navigation, debounced input, searches across accounts/transactions/goals, type icons, and loading/empty states.

**Dimension Scores**

- **UI/UX: 4** — The Cmd+K shortcut, keyboard navigation, debounced input, and loading/empty states are well-designed. The global search experience is smooth and responsive.
- **Business Logic: 3** — Searches 3 entity types (accounts, transactions, goals). Uses SQL LIKE for matching (no full-text search). Transaction results don't navigate to the specific record (navigates to the transactions page generally).
- **Efficiency: 3** — Fast and responsive. But limited to 3 entity types (no search for debts, subscriptions, holdings, budgets). No search history, no highlighting of matches, no suggestions/autocomplete.

**Key Gaps (Ranked by Impact)**

1. Only 3 entity types searchable (High)
2. Transaction results don't navigate to specific record (Medium)
3. No FTS — uses SQL LIKE (Medium)
4. No search history (Low)
5. No match highlighting (Low)
6. No autocomplete suggestions (Low)

**Improvement Suggestions**

- *Short-term*: Add search for all entity types (debts, subscriptions, holdings, budgets). Fix transaction navigation to scroll to specific record.
- *Long-term*: Implement SQLite FTS5 for better search performance and relevance. Add search history. Add match highlighting. Add autocomplete suggestions.

---

### 5.8 Onboarding

**Current State Assessment**

3-screen onboarding flow: choice (register or link), register (device creation with ID), or link (enter existing device ID). Includes preset investment accounts and copy-to-clipboard for account ID.

**Dimension Scores**

- **UI/UX: 3** — The 3-screen flow is clean. Preset investment accounts reduce setup friction. Copy-to-clipboard for account ID is thoughtful. But no currency selection (hardcoded CNY), no encryption prompt, no tutorial/walkthrough after onboarding completes.
- **Business Logic: 3** — Device registration flow works. Preset investment accounts auto-create. But no data import option during onboarding, no skip option (users must complete the full flow), no progress indicator.
- **Efficiency: 3** — Copy-to-clipboard saves time. Preset investment accounts reduce manual entry. But no bulk import, no template selection.

**Key Gaps (Ranked by Impact)**

1. No currency selection — hardcoded CNY (High)
2. No encryption setup prompt (Medium)
3. No tutorial/walkthrough after onboarding (Medium)
4. No data import option during setup (Low)
5. No skip option (Low)

**Improvement Suggestions**

- *Short-term*: Add currency selection screen (CNY, USD, EUR, etc. with auto-default based on locale). Add encryption setup prompt as optional step.
- *Long-term*: Add interactive tutorial/walkthrough for first-time users. Add data import option (from CSV, from other apps). Add progress indicator.

---

## 6. Cross-Cutting Analysis

### 6.1 Architecture Inconsistencies

The codebase follows DDD architecture in some modules but not others:

| Module | Service Layer | Pattern |
|--------|:---:|:---:|
| Transactions | `transaction_service.rs` | DDD |
| Debts | `debt_service.rs` | DDD |
| Holdings | `holding_service.rs` | DDD |
| Subscriptions | `subscription_service.rs` | DDD |
| Prepaid | `prepaid_service.rs` | DDD |
| Encryption | `encryption_app_service.rs` | DDD |
| **Budget** | **None** | **Commands call repo directly** |
| **Goals** | **None** | **Commands call repo directly** |
| **Tags** | **None** | **Commands call repo directly** |
| **Export** | **None** | **Raw SQL in commands** |

Budget, Goals, and Tags bypass the application layer entirely. This makes it harder to add business logic (e.g., budget actual computation, goal auto-sync) because there is no service to contain it. The Export module is the worst offender, using raw SQL queries directly in the Tauri command handler with no repository abstraction.

Additionally, `update_holding_trade` in `holding_service.rs` uses raw SQL queries despite the module having a proper service layer, suggesting a missed refactor.

### 6.2 Module Integration Gaps

Several modules exist in isolation with no cross-module integration:

1. **Budget vs Transactions**: Budget `actual_amount` is never computed from transactions. This is the single most impactful integration gap — the entire budget module is non-functional without it.

2. **Goals vs Account Balances**: Goals can be linked to accounts, but progress is never auto-synced from account balances. Users must manually update progress.

3. **Reminders vs Debts/Subscriptions**: The Reminders module is designed to support scheduling but is not connected to debt payment schedules or subscription renewals for auto-creation.

4. **Tags vs Reports**: Tags can be assigned to transactions, but the Reports module has no tag-based reporting (no spending by tag, no tag trends).

5. **Multi-currency vs All Modules**: Currency conversion exists as a standalone module but is not integrated into account balances, transaction display, reports, or holdings. The `¥` symbol is hardcoded in at least 30+ locations across the frontend.

### 6.3 i18n Gaps

The project enforces `i18next/no-literal-string` via ESLint, but several violations exist:

1. **Hardcoded `¥` symbol** — Found in `HomePage.tsx` (12+ instances), `ReportsPage.tsx` (10+ instances), `HoldingsPage.tsx` (5+ instances), `SubscriptionsPage.tsx` (4+ instances). This should use a currency formatting utility.

2. **Hardcoded Chinese toasts** — `GoalsPage.tsx` contains `toast.error('请输入目标名称')`, `toast.error('请输入有效的目标金额')`, and `toast.error('请输入有效的金额')`. These should use `t()` keys.

3. **BudgetPage.tsx** — Uses `t()` correctly for toasts (`toast.error(t('budget.nameRequired'))`), but this pattern is inconsistent across modules.

### 6.4 Currency Handling

Currency handling is the most pervasive cross-cutting issue:

1. **No base currency concept** — The system assumes CNY everywhere. There is no `base_currency` setting or user preference.
2. **`f64` for money** — Currency conversion uses floating-point arithmetic, which is inappropriate for financial calculations. The `rust_decimal` or similar fixed-point crate should be used.
3. **Hardcoded `¥`** — At least 30 instances across the frontend use literal `¥` instead of a currency formatting function.
4. **Hardcoded CNY** — New securities default to CNY. Account creation assumes CNY. Reports assume CNY.
5. **No currency formatting utility** — Each component formats amounts independently with `toLocaleString('en-US', { minimumFractionDigits: 2 })`.

### 6.5 Dead Code and Stubs

1. **Legacy `debt.rs`** — Contains a `Debt` struct separate from `debt_details.rs`. The two models co-exist but `debt.rs` appears unused.
2. **`ChartOfAccounts` aggregate** — Domain model, repository, and error types are fully implemented, but no Tauri commands are wired and no frontend uses it.
3. **Category field stub** — Transactions and Subscriptions have `category` fields in their DTOs that are non-functional.
4. **`find_active`/`find_completed` in GoalRepository** — Repository methods that are never called.
5. **Dividend/Split in Holdings enum** — Transaction type variants with no handler implementations.
6. **Dropbox/Google Drive/OneDrive backup stubs** — Provider structs exist but return `NotConfigured`.
7. **Date range filters in HoldingsPage** — UI state that is saved but never applied to queries.
8. **`encrypt_field`/`decrypt_field` in EncryptionAppService** — Methods exist but are never called.

### 6.6 Testing Gaps

Test coverage is uneven across modules:

| Module | Backend Tests | Frontend Tests |
|--------|:---:|:---:|
| Transactions | Yes (`transaction_commands.rs`, `transaction_repository.rs`) | Partial |
| Reminders | Yes (`reminder_integration_test.rs`) | None |
| Accounts | Yes (`account_commands.rs`) | Partial |
| Currency | Yes (`currency_repository.rs`) | None |
| Registration | Yes (`registration_test.rs`) | None |
| Chart of Accounts | Yes (`chart_of_accounts_repository.rs`) | None |
| Sync Scheduler | Yes (`sync_scheduler_test.rs`) | None |
| **Budget** | **None** | **None** |
| **Debts** | **None** | **None** |
| **Goals** | **None** | **None** |
| **Holdings** | **None** | **None** |
| **Subscriptions** | **None** | **None** |
| **Prepaid** | **None** | **None** |
| **Backup** | **None** | **None** |
| **Encryption** | **None** | **None** |
| **Tags** | **None** | **None** |
| **Export** | **None** | **None** |

Most financial management, investment, and system modules have zero test coverage. The most critical untested modules are Transactions (business logic), Backup (data integrity), and Encryption (security).

### 6.7 Performance Concerns

1. **No pagination** — Transaction queries load all records then filter client-side. `get_transactions_by_account` is the worst example.
2. **No server-side aggregation** — Reports compute everything client-side from full datasets.
3. **No FTS** — Search uses SQL LIKE, which requires full table scans.
4. **Full backup on every sync** — Cloud sync creates a complete backup and uploads it each cycle, with no incremental support.

---

## Appendix: Module Score Summary

| # | Module | Data Analysis | UI/UX | Business Logic | Efficiency | Average | Gap |
|---|--------|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | Accounts | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| 2 | Transactions | 2 | 3 | 4 | 2 | 2.8 | -1.8 |
| 3 | Reports | 2 | 3 | 3 | 3 | 2.8 | -1.8 |
| 4 | Budget | 1 | 2 | 2 | 1 | 1.5 | -3.1 |
| 5 | Debts | 2 | 4 | 4 | 3 | 3.3 | -1.3 |
| 6 | Goals | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| 7 | Subscriptions | 2 | 4 | 3 | 3 | 3.0 | -1.6 |
| 8 | Holdings | 2 | 3 | 3 | 3 | 2.8 | -1.8 |
| 9 | Prepaid | 1 | 3 | 3 | 2 | 2.3 | -2.3 |
| 10 | Multi-currency | 1 | 2 | 3 | 1 | 1.8 | -2.8 |
| 11 | Backup | 3 | 4 | 4 | 3 | 3.5 | -1.1 |
| 12 | Cloud Sync | 2 | 3 | 3 | 2 | 2.5 | -2.1 |
| 13 | Encryption | N/A | 4 | 3 | 4 | 3.7* | -0.9* |
| 14 | Reminders | N/A | 1 | 2 | 1 | 1.3* | -3.3* |
| 15 | Tags | 1 | 2 | 2 | 2 | 1.8 | -2.8 |
| 16 | Export | 1 | 1 | 2 | 1 | 1.3 | -3.3 |
| 17 | Search | N/A | 4 | 3 | 3 | 3.3* | -1.3* |
| 18 | Onboarding | N/A | 3 | 3 | 3 | 3.0* | -1.6* |
| | **Overall** | **1.7** | **3.0** | **3.0** | **2.2** | **2.5** | **-2.1** |

\* Averages for modules with N/A dimensions computed from applicable dimensions only.
