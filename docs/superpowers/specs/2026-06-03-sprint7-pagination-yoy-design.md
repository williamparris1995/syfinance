# Sprint 7: Token-Based Pagination & Year-Over-Year Comparison

**Date:** 2026-06-03
**Status:** Approved
**Sprint:** 7 of 7
**Effort:** ~5 days
**Preceded by:** Sprint 6 (complete)

---

## Goal

Replace all unbounded list queries with token-based (cursor) pagination using the Connection pattern. Add year-over-year comparison to Reports. Eliminate N+1 query patterns in paginated endpoints.

---

## Task 24: Token-Based (Cursor) Pagination

### Cursor Format

Base64-encoded JSON containing the sort key values at the page boundary:

```
// Transaction cursor (decoded)
{ "transaction_date": "2026-05-15", "id": "a1b2c3d4" }

// Encoded
eyJ0cmFuc2FjdGlvbl9kYXRlIjoiMjAyNi0wNS0xNSIsImlkIjoiYTFiMmMzZDQifQ==
```

### API Response Format (Connection Pattern)

Every paginated endpoint returns:

```json
{
  "items": [...],
  "page_info": {
    "has_next_page": true,
    "has_prev_page": false,
    "next_cursor": "eyJ...",
    "prev_cursor": null
  }
}
```

### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `first` | `u32` | Page size (default 50, max 200) |
| `after` | `Option<String>` | Cursor — return items after this position |
| `before` | `Option<String>` | Cursor — return items before this position (backward paging) |

At most one of `after`/`before` may be provided. If neither is provided, returns the first page.

### SQL Pattern

```sql
-- Forward paging (after cursor), transactions sorted by date DESC, id DESC
SELECT ... FROM transactions
WHERE deleted_at IS NULL
  AND (:after IS NULL OR (transaction_date, id) < (:cursor_date, :cursor_id))
  AND (:start_date IS NULL OR transaction_date >= :start_date)
  AND (:end_date IS NULL OR transaction_date <= :end_date)
  AND (:account_id IS NULL OR id IN (
    SELECT transaction_id FROM transaction_entries WHERE account_id = :account_id
  ))
ORDER BY transaction_date DESC, id DESC
LIMIT :first + 1;
```

Fetch `first + 1` rows. If `first + 1` rows return, `has_next_page = true` and return only `first` rows. The cursor for the next page is derived from the last returned row's sort keys.

### Paginated Endpoints

| Endpoint | Filters | Cursor Keys | Notes |
|----------|---------|-------------|-------|
| `list_transactions_paginated` | date_range | `(transaction_date, id)` | Primary use case |
| `get_transactions_by_account_paginated` | account_id + date_range | `(transaction_date, id)` | Fix N+1: use SQL WHERE instead of in-memory filter |
| `list_holding_transactions_paginated` | holding_id | `(trade_date, id)` | Holding trade history |
| `get_yoy_comparison` | year1, year2 | N/A (aggregation) | Task 25 |

**Not paginated (by design):**
- `list_holdings` — typically < 50 records, no pagination needed
- `list_accounts` — typically < 20 records
- Single-record queries (`get_transaction`, `get_holding`)

### Backend Architecture

#### Rust Changes

1. **New value objects** in `domain/value_objects/`:
   - `PageInfo` struct with `has_next_page`, `has_prev_page`, `next_cursor`, `prev_cursor`
   - `PaginatedResult<T>` generic wrapper

2. **Repository trait extensions** — add paginated query methods:
   - `TransactionRepository::find_paginated(after, before, first, filters) -> PaginatedResult<Transaction>`
   - `HoldingRepository::find_transactions_paginated(after, before, first, holding_id) -> PaginatedResult<HoldingTransaction>`

3. **Service layer** — existing services call new paginated repo methods

4. **Command layer** — new Tauri commands accepting pagination params

#### N+1 Fix: Transaction Entries

Current `load_entries` issues a separate query per transaction. Fix by:
- Single query: `SELECT * FROM transaction_entries WHERE transaction_id IN (...)` after fetching the page of transactions
- Single query for currency codes: `SELECT id, currency_code FROM accounts WHERE id IN (...)`

### Frontend Architecture

#### `useCursorPagination` Hook

```typescript
interface CursorPageState<T> {
  pages: T[][];               // Data for each loaded page
  cursors: (string | null)[]; // next_cursor after each page
  currentPage: number;        // 0-indexed, derived from cursor history
  hasNextPage: boolean;
  hasPrevPage: boolean;
  isLoading: boolean;
  goNext: () => void;
  goPrev: () => void;
  goToPage: (page: number) => void;
}
```

- `goNext()` — fetch next page using `next_cursor` from current page
- `goPrev()` — navigate back using stored cursor history (no refetch needed for previously loaded pages)
- `goToPage(n)` — navigate to any previously loaded page (instant, no network)
- Pages already loaded are cached in state; only new pages trigger network requests
- Display: "第 N 页" without total (total unknown without COUNT)

#### Frontend UI Changes

- **TransactionsPage**: Replace `filteredTransactions.map()` with paginated rendering. Add page navigation bar at bottom showing "上一页 / 第 N 页 / 下一页". Page size: 50.
- **HoldingsPage**: Holding trade history (expandable rows) uses pagination with "加载更多" button.
- **ReportsPage**: Replace `listTransactions()` with server-side aggregation queries (no full dataset loading). Reports don't need cursor pagination — they need dedicated aggregation endpoints.

### Acceptance Criteria

- [ ] All transaction list endpoints support cursor pagination
- [ ] `get_transactions_by_account` uses SQL WHERE instead of in-memory filtering
- [ ] N+1 query pattern eliminated for paginated transaction loading
- [ ] Frontend transactions page shows page navigation with cursor history
- [ ] Holding trade history supports cursor pagination
- [ ] Reports page no longer loads all transactions into the browser
- [ ] Default page size: 50, max: 200
- [ ] `pnpm type-check`, `pnpm lint`, `cargo check` all pass

---

## Task 25: Year-Over-Year Comparison

### Backend

New Tauri command `get_yoy_comparison`:

**Parameters:**
- `year1: u32` (e.g., 2025)
- `year2: u32` (e.g., 2026)

**Returns:** Monthly aggregated income/expense for both years:

```json
{
  "year1": 2025,
  "year2": 2026,
  "months": [
    {
      "month": 1,
      "year1_income": "50000.00",
      "year1_expense": "35000.00",
      "year2_income": "55000.00",
      "year2_expense": "38000.00",
      "income_change_pct": 10.0,
      "expense_change_pct": 8.57
    },
    ...
  ]
}
```

**SQL:** Aggregate from transaction_entries joined with accounts (type = Income/Expense), grouped by month and year. Two passes (one per year) or a single query with CASE WHEN.

### Frontend

- Add "年度对比" tab or section to ReportsPage
- "选择年度" — two year dropdowns (current year and previous year as defaults)
- Recharts `BarChart` with grouped bars: two bars per month (one per year), color-coded
- Show change percentage as tooltip or inline label
- Separate income and expense views (toggle)

### Acceptance Criteria

- [ ] Backend `get_yoy_comparison` command returns monthly aggregation for two years
- [ ] Frontend shows grouped bar chart comparing two years side-by-side
- [ ] Change percentages displayed
- [ ] Income and expense views togglable
- [ ] `pnpm type-check`, `pnpm lint`, `cargo check` all pass

---

## Verification

After both tasks:

```bash
# Frontend
pnpm type-check
pnpm lint

# Backend
make check
make test

# Manual smoke test
pnpm tauri dev
```

---

## Risks

| Risk | Mitigation |
|------|------------|
| Cursor encoding across sort orders (date DESC vs ASC) | Cursor always encodes the current sort direction; SQL uses tuple comparison |
| Backward paging with `before` cursor | Support via reversing the sort and flipping results |
| Existing consumers of non-paginated endpoints | Keep old endpoints as-is, add new `_paginated` variants alongside |
| Transaction N+1 fix may affect other code paths | Paginated endpoints use new batched loading; old endpoints unchanged |
| Reports aggregation queries for large datasets | SQLite handles aggregation well; add indexes on transaction_date |
