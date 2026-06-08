# YuCai UI Redesign — P2 Transaction Module Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Restyle the transaction module using YuCai patterns — PageShell/PageHeader, StatCard summaries, FilterBar, improved table styling, dedicated detail page, and restyled form page.

**Architecture:** Transactions stay as a Table (better for dense list data). Apply YuCai visual language: StatCard for period summaries, FilterBar for type/date filtering, DataCard-styled table container. Replace TransactionDetailPage placeholder with HeroCard + DetailTwoCol. Restyle NewTransactionPage.

**Spec:** `docs/superpowers/specs/2026-06-08-yucai-ui-redesign-design.md`

---

## Task 1: Restyle TransactionsPage

**File:** `src/pages/TransactionsPage.tsx`

### Changes
1. Outer wrapper: `<div className="p-4 sm:p-6">` → `<PageShell>`
2. Page header: inline header → `<PageHeader>` with create button
3. Summary: Add 3 StatCards above the table (total income, total expense, net for period)
4. Type filter: inline buttons → `<FilterBar>` for expense/income/transfer/all
5. Date range: keep existing date range selector but style with YuCai rounded pills
6. Table container: wrap in `rounded-[14px] border border-border bg-card overflow-hidden`
7. Table header: style with `bg-muted/50` background, YuCai font sizes
8. Table rows: add hover:bg-muted/30, smoother borders
9. Multi-select: keep all batch operations
10. Inline edit: keep all inline editing functionality
11. Click row → navigate to `/transactions/$transactionId` (in addition to edit button)
12. Account filters: keep MultiSelect components
13. Pagination: keep as-is

### What stays unchanged
- ALL data fetching, pagination, cursor logic
- ALL mutations (edit, delete, batch delete)
- ALL filtering/sorting logic
- SimpleTransactionForm in Sheet for edit/copy
- Multi-select and batch operations
- Date range computation
- getTransactionType, getTransactionAmount helpers
- Search functionality

### Commit
```
feat(transactions): restyle list page with YuCai patterns, StatCard summaries, FilterBar
```

## Task 2: Implement TransactionDetailPage

**File:** `src/pages/TransactionDetailPage.tsx`

Replace placeholder with full detail page using HeroCard + StatCards + DetailTwoCol.

Structure:
- HeroCard: transaction description as name, date as subtitle, amount as hero balance (colored by type)
- 4 StatCards: date, type (income/expense/transfer), accounts involved, entry count
- DetailTwoCol: Left = entry details table (debit/credit entries). Right = metadata sidebar (created_at, updated_at, description)

### Commit
```
feat(transactions): implement detail page with HeroCard, StatCards, entry details
```

## Task 3: Restyle NewTransactionPage

**File:** `src/pages/NewTransactionPage.tsx`

Replace wrapper with `<PageShell narrow>` + `<PageHeader>` + `<FormCard>`. Remove back button.

### Commit
```
feat(transactions): restyle form page with PageShell, PageHeader, FormCard
```
