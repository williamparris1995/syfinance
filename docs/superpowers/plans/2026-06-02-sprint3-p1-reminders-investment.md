# Sprint 3: P1 Reminders & Investment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the reminders system, add investment analytics (allocation chart + dividend/split), replace all hardcoded currency symbols, and add auto-fetch exchange rates.

**Architecture:** Task 9 adds frontend CRUD for reminders (backend already complete). Task 10 extends holdings domain + adds recharts PieChart. Task 11 is a cross-cutting find-and-replace. Task 12 adds a rate fetcher service using reqwest (already in Cargo.toml).

**Tech Stack:** Rust (Tauri 2.x, SQLx, reqwest), SQLite, React (TypeScript, TanStack Query, recharts)

---

### Task 9: Build Reminders frontend + wire commands (L)

**Context:** The entire backend pipeline is complete and running: domain model, repository, scheduler, notification service, background task in main.rs. Only Tauri commands + frontend UI are missing.

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/reminder_commands.rs`
- Modify: `src-tauri/src/main.rs` (register commands)
- Create: `src/lib/tauri/reminder.ts`
- Create: `src/hooks/useReminder.ts`
- Create: `src/pages/RemindersPage.tsx`
- Modify: `src/components/layout/Sidebar.tsx` (add nav link)
- Modify: `src/router.tsx` (add route)
- Modify: `src/i18n/locales/en.json` and `zh.json`

**Steps:**
1. Create `reminder_commands.rs` with CRUD commands: `list_reminders`, `get_reminder`, `create_reminder`, `update_reminder`, `delete_reminder`, `complete_reminder` (marks as notified)
2. Register all commands in main.rs invoke_handler
3. Create frontend Tauri bridge `src/lib/tauri/reminder.ts`
4. Create React Query hooks `src/hooks/useReminder.ts`
5. Create `RemindersPage.tsx` with:
   - Summary cards: total, active, overdue, completed today
   - Filter tabs: All / Active / Completed
   - Table: title, type (badge), remind_at, priority (color), repeat pattern, status, actions
   - Create/Edit via Sheet: title, description, type selector, related entity, remind_at datetime picker, repeat pattern, priority selector
   - Complete/Dismiss button per row
   - Delete confirmation
6. Add "Reminders" nav item to Sidebar (use Bell icon, place between Debts and Holdings)
7. Add route in router.tsx
8. Add i18n keys to both locale files
9. Verify: `cargo check` + `pnpm type-check`
10. Commit

---

### Task 10: Holdings allocation chart + dividend/split handlers (L)

**Files:**
- Modify: `src-tauri/src/domain/aggregates/holding.rs` (add apply_dividend, apply_split)
- Modify: `src-tauri/src/application/services/holding_service.rs` (add record_dividend, record_split)
- Modify: `src/pages/HoldingsPage.tsx` (add allocation PieChart)

**Steps:**
1. Add `apply_dividend(cash_per_share, total_amount)` method to `Holding` — does NOT change quantity/avg_cost (dividends are cash distributions, not position changes)
2. Add `apply_split(ratio)` method to `Holding` — multiplies quantity by ratio, divides avg_cost by ratio
3. Add `record_dividend(dto)` to `HoldingService`:
   - Creates HoldingTransaction with Dividend type
   - Creates double-entry Transaction: Debit bank (cash received), Credit income account (dividend income 4201/420101)
4. Add `record_split(dto)` to `HoldingService`:
   - Creates HoldingTransaction with Split type
   - Calls `apply_split(ratio)` on the Holding
   - No double-entry Transaction needed (split is just a quantity/cost adjustment)
5. Add Tauri commands: `record_dividend`, `record_split`
6. Register in main.rs
7. Add frontend bridge + hooks
8. Add "Dividend" and "Split" buttons per holding row in HoldingsPage
9. Add allocation PieChart below summary cards using recharts
10. Add i18n keys
11. Verify: `cargo check` + `pnpm type-check`
12. Commit

---

### Task 11: Fix hardcoded currency symbols — ¥ → dynamic (M)

**Context:** 68 occurrences of hardcoded ¥ across 16 files. `src/lib/currency.ts` already has `formatCurrency()` and `formatCurrencyWithDto()`. `AccountsPage.tsx` shows the correct pattern.

**Files:** 16 files with hardcoded ¥ (see exploration results)

**Steps:**
1. Create a shared `useCurrencySymbol(currencyCode)` utility or extend `formatCurrency` usage
2. For each file with hardcoded ¥:
   - Pages (HoldingsPage, HomePage, ReportsPage, SubscriptionsPage, TransactionTemplatesPage): Replace `¥{amount}` with `formatCurrency(amount, account?.currency_code || 'CNY')`
   - Components (AccountForm, SimpleTransactionForm, DebtForm, TopUpDialog, etc.): Replace hardcoded symbol maps with `getCurrencySymbol(currencyCode)` or `formatCurrency()`
   - If component doesn't have access to currency code, pass it as prop
3. Remove local symbol maps (`{ CNY: '¥', USD: '$' }`) and use the shared utility
4. Verify: `pnpm type-check` + `pnpm lint`
5. Commit

---

### Task 12: Multi-currency auto-fetch exchange rates (M)

**Context:** `reqwest` already in Cargo.toml. Conversion logic exists in currency_commands.rs using CNY as base.

**Files:**
- Create: `src-tauri/src/infrastructure/currency_rate_fetcher.rs`
- Modify: `src-tauri/src/infrastructure/mod.rs` (register module)
- Modify: `src-tauri/src/presentation/tauri_commands/currency_commands.rs` (add fetch_rates command)
- Modify: `src-tauri/src/main.rs` (register command)
- Modify: `src/hooks/useCurrency.ts` (add fetchRates mutation)
- Modify: `src/components/CurrencyForm.tsx` or CurrencyPage (add Refresh button)

**Steps:**
1. Create `currency_rate_fetcher.rs` with:
   - `fetch_rates_from_ecb() -> Result<HashMap<String, Decimal>>` — fetches ECB daily rates (free, no API key)
   - `update_rates_in_db(pool, rates) -> Result<usize>` — updates exchange_rate column for each currency
2. Register module
3. Add `fetch_exchange_rates` Tauri command in currency_commands.rs
4. Register in main.rs
5. Add `useFetchExchangeRates` mutation hook
6. Add "Refresh Rates" button near currency management
7. Add i18n keys
8. Verify: `cargo check` + `pnpm type-check`
9. Commit
