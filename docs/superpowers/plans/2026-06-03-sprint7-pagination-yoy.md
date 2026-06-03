# Sprint 7: Token-Based Pagination & YoY Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all unbounded list queries with token-based cursor pagination (Connection pattern). Fix N+1 queries. Add year-over-year comparison to Reports.

**Architecture:** Add paginated variants alongside existing endpoints. Cursor = base64(JSON({sort_keys})). Backend: new repo methods + service methods + commands. Frontend: `useCursorPagination` hook + page navigation UI. Reports: dedicated aggregation endpoints replacing full-dataset loading.

**Tech Stack:** Rust + SQLx + Tauri (backend), React + TanStack Query + Recharts (frontend)

---

## Task 24A: Backend — Cursor Pagination Infrastructure

**Files:**
- Create: `src-tauri/src/domain/value_objects/pagination.rs`
- Modify: `src-tauri/src/domain/value_objects/mod.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs`
- Modify: `src-tauri/src/infrastructure/repositories/transaction_repository.rs`
- Modify: `src-tauri/src/infrastructure/repositories/holding_repository.rs`

### Step 1: Create pagination value objects

Create `src-tauri/src/domain/value_objects/pagination.rs`:

```rust
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use serde::{Deserialize, Serialize};

/// Pagination request parameters.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginationParams {
    /// Number of items per page (default 50, max 200).
    pub first: u32,
    /// Cursor to fetch items after this position (forward paging).
    pub after: Option<String>,
    /// Cursor to fetch items before this position (backward paging).
    pub before: Option<String>,
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            first: 50,
            after: None,
            before: None,
        }
    }
}

impl PaginationParams {
    pub fn capped_first(&self) -> i64 {
        self.first.min(200) as i64
    }
}

/// Information about pagination state in a response.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageInfo {
    pub has_next_page: bool,
    pub has_prev_page: bool,
    pub next_cursor: Option<String>,
    pub prev_cursor: Option<String>,
}

/// A paginated result wrapping items with page info.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedResult<T> {
    pub items: Vec<T>,
    pub page_info: PageInfo,
}

/// A cursor based on sort key values.
/// For transactions: { "transaction_date": "...", "id": "..." }
/// For holding trades: { "trade_date": "...", "id": "..." }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SortCursor {
    pub keys: Vec<(String, String)>, // (column_name, value)
}

impl SortCursor {
    pub fn encode(&self) -> Result<String, String> {
        let json = serde_json::to_string(&self.keys)
            .map_err(|e| format!("Failed to serialize cursor: {}", e))?;
        Ok(BASE64.encode(json.as_bytes()))
    }

    pub fn decode(encoded: &str) -> Result<Self, String> {
        let bytes = BASE64.decode(encoded)
            .map_err(|e| format!("Invalid cursor encoding: {}", e))?;
        let keys: Vec<(String, String)> = serde_json::from_slice(&bytes)
            .map_err(|e| format!("Invalid cursor format: {}", e))?;
        Ok(Self { keys })
    }

    /// Get a value by column name.
    pub fn get(&self, column: &str) -> Option<&str> {
        self.keys.iter().find(|(k, _)| k == column).map(|(_, v)| v.as_str())
    }
}

/// Build a cursor from a row's sort key values.
pub fn build_cursor(pairs: Vec<(&str, String)>) -> Option<String> {
    let cursor = SortCursor {
        keys: pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect(),
    };
    cursor.encode().ok()
}
```

Register in `src-tauri/src/domain/value_objects/mod.rs`:
Add `pub mod pagination;` and `pub use pagination::{PaginationParams, PageInfo, PaginatedResult, SortCursor, build_cursor};`

Add `base64` to `src-tauri/Cargo.toml` if not already present.

- [ ] **Step 1 complete**

### Step 2: Add paginated methods to TransactionRepository trait

In `src-tauri/src/domain/repositories/mod.rs`, add to `TransactionRepository` trait:

```rust
use crate::domain::value_objects::pagination::PaginatedResult;

// Add to TransactionRepository trait:
async fn find_paginated(
    &self,
    first: i64,
    after: Option<&str>,
    before: Option<&str>,
    account_id: Option<Uuid>,
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
) -> sqlx::Result<PaginatedResult<Transaction>>;
```

- [ ] **Step 2 complete**

### Step 3: Implement paginated transaction query

In `src-tauri/src/infrastructure/repositories/transaction_repository.rs`, implement `find_paginated`.

The SQL pattern for forward paging (after cursor):

```sql
SELECT id, transaction_date, description, updated_at, deleted_at, device_id, synced_at
FROM transactions
WHERE deleted_at IS NULL
  AND (:start_date IS NULL OR transaction_date >= :start_date)
  AND (:end_date IS NULL OR transaction_date <= :end_date)
  AND (:account_filter = 0 OR id IN (
    SELECT DISTINCT transaction_id FROM transaction_entries WHERE account_id = :account_id
  ))
  AND (:after_date IS NULL OR (transaction_date, id) < (:cursor_date, :cursor_id))
ORDER BY transaction_date DESC, id DESC
LIMIT :limit
```

Key implementation details:
- Decode cursor via `SortCursor::decode(cursor_string)`
- Extract `transaction_date` and `id` from cursor keys
- Build dynamic WHERE clause based on which filters are present
- Fetch `first + 1` rows to determine `has_next_page`
- If `first + 1` rows returned, return only `first` rows and set `has_next_page = true`
- Build `next_cursor` from the last returned row's `(transaction_date, id)`
- For backward paging (`before` cursor), reverse the sort direction, fetch, then reverse results
- After fetching the page of transaction rows, batch-load entries using a single `SELECT * FROM transaction_entries WHERE transaction_id IN (...)` query
- Batch-load currency codes using a single `SELECT id, currency_code FROM accounts WHERE id IN (...)` query

This fixes the N+1 problem: instead of `N` queries for entries, it's now 1 query for entries + 1 query for currencies, regardless of page size.

- [ ] **Step 3 complete**

### Step 4: Add paginated method to HoldingRepository trait

In `src-tauri/src/domain/repositories/mod.rs`, add to `HoldingRepository` trait:

```rust
async fn find_transactions_paginated(
    &self,
    holding_id: Uuid,
    first: i64,
    after: Option<&str>,
    before: Option<&str>,
) -> sqlx::Result<PaginatedResult<HoldingTransaction>>;
```

- [ ] **Step 4 complete**

### Step 5: Implement paginated holding transaction query

In `src-tauri/src/infrastructure/repositories/holding_repository.rs`, implement `find_transactions_paginated`.

Same pattern as transactions but:
- Sort key: `(trade_date, id)` — `ORDER BY trade_date DESC, id DESC`
- Filter: `WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL`
- First resolve `holding_id` → `(account_id, security_id)` as current code does

- [ ] **Step 5 complete**

### Step 6: Verify cargo check

```bash
cd src-tauri && cargo check
```

- [ ] **Step 6 complete**

### Step 7: Commit Task 24A

```bash
git add -A
git commit -m "feat(pagination): add cursor-based pagination infrastructure

- Create PaginationParams, PageInfo, PaginatedResult, SortCursor types
- Add find_paginated to TransactionRepository with SQL-level filtering
- Add find_transactions_paginated to HoldingRepository
- Fix N+1: batch-load entries and currency codes in single queries
- Cursor = base64(JSON(sort_keys)), Connection pattern

Task 24A of Sprint 7.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 7 complete**

---

## Task 24B: Backend — Paginated Service + Commands

**Files:**
- Modify: `src-tauri/src/application/services/transaction_service.rs`
- Modify: `src-tauri/src/application/services/holding_service.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/transaction_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/holding_commands.rs`
- Modify: `src-tauri/src/main.rs` (register new commands)

### Step 1: Add paginated service methods

In `transaction_service.rs`, add:

```rust
pub async fn list_transactions_paginated(
    &self,
    params: PaginationParams,
    account_id: Option<Uuid>,
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
) -> Result<PaginatedResult<TransactionDto>, TransactionServiceError> {
    let result = self.transaction_repo.find_paginated(
        params.capped_first(),
        params.after.as_deref(),
        params.before.as_deref(),
        account_id,
        start_date,
        end_date,
    ).await?;
    // Map items to DTOs
    Ok(PaginatedResult {
        items: result.items.into_iter().map(|t| self.to_dto(t)).collect(),
        page_info: result.page_info,
    })
}
```

In `holding_service.rs`, add:

```rust
pub async fn list_holding_transactions_paginated(
    &self,
    holding_id: Uuid,
    params: PaginationParams,
) -> Result<PaginatedResult<HoldingTransactionDto>, HoldingServiceError> {
    let result = self.holding_repo.find_transactions_paginated(
        holding_id,
        params.capped_first(),
        params.after.as_deref(),
        params.before.as_deref(),
    ).await?;
    Ok(PaginatedResult {
        items: result.items.into_iter().map(|t| HoldingTransactionDto { /* fields */ }).collect(),
        page_info: result.page_info,
    })
}
```

- [ ] **Step 1 complete**

### Step 2: Add paginated Tauri commands

In `transaction_commands.rs`, add new commands (keep existing ones unchanged):

```rust
use crate::domain::value_objects::pagination::PaginationParams;

#[derive(Debug, Deserialize)]
pub struct PaginatedTransactionQuery {
    pub first: Option<u32>,
    pub after: Option<String>,
    pub before: Option<String>,
    pub account_id: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

#[tauri::command]
pub async fn list_transactions_paginated(
    state: State<'_, TransactionCommandState>,
    query: PaginatedTransactionQuery,
) -> Result<PaginatedResult<TransactionDto>, String> {
    let params = PaginationParams {
        first: query.first.unwrap_or(50),
        after: query.after,
        before: query.before,
    };
    let account_id = query.account_id
        .map(|s| Uuid::parse_str(&s))
        .transpose()
        .map_err(|e| format!("Invalid account_id: {}", e))?;
    let start_date = query.start_date
        .map(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d"))
        .transpose()
        .map_err(|e| format!("Invalid start_date: {}", e))?;
    let end_date = query.end_date
        .map(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d"))
        .transpose()
        .map_err(|e| format!("Invalid end_date: {}", e))?;

    state.service()
        .list_transactions_paginated(params, account_id, start_date, end_date)
        .await
        .map_err(|e| e.to_string())
}
```

In `holding_commands.rs`, add:

```rust
#[tauri::command]
pub async fn list_holding_transactions_paginated(
    state: State<'_, AppState>,
    holding_id: Uuid,
    first: Option<u32>,
    after: Option<String>,
    before: Option<String>,
) -> Result<PaginatedResult<HoldingTransactionDto>, String> {
    let params = PaginationParams {
        first: first.unwrap_or(50),
        after,
        before,
    };
    state.service()
        .list_holding_transactions_paginated(holding_id, params)
        .await
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2 complete**

### Step 3: Register new commands in main.rs

Add to the `invoke_handler` macro in `main.rs`:
- `list_transactions_paginated`
- `list_holding_transactions_paginated`

Also update imports in main.rs to include the new commands.

- [ ] **Step 3 complete**

### Step 4: Verify cargo check

```bash
cd src-tauri && cargo check
```

- [ ] **Step 4 complete**

### Step 5: Commit Task 24B

```bash
git add -A
git commit -m "feat(pagination): add paginated service methods and Tauri commands

- TransactionService::list_transactions_paginated with cursor + filters
- HoldingService::list_holding_transactions_paginated
- New Tauri commands: list_transactions_paginated, list_holding_transactions_paginated
- Old endpoints preserved for backward compatibility

Task 24B of Sprint 7.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5 complete**

---

## Task 24C: Frontend — Cursor Pagination Hook + UI

**Files:**
- Create: `src/hooks/useCursorPagination.ts`
- Modify: `src/lib/tauri/transaction.ts`
- Modify: `src/lib/tauri/holding.ts`
- Modify: `src/pages/TransactionsPage.tsx`
- Modify: `src/pages/HoldingsPage.tsx`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

### Step 1: Add frontend Tauri bindings for paginated endpoints

In `src/lib/tauri/transaction.ts`, add:

```typescript
export interface PageInfo {
  has_next_page: boolean;
  has_prev_page: boolean;
  next_cursor: string | null;
  prev_cursor: string | null;
}

export interface PaginatedResult<T> {
  items: T[];
  page_info: PageInfo;
}

export interface PaginatedTransactionQuery {
  first?: number;
  after?: string;
  before?: string;
  accountId?: string;
  startDate?: string;
  endDate?: string;
}

export const listTransactionsPaginated = (query: PaginatedTransactionQuery) =>
  invokeTauri<PaginatedResult<TransactionDto>>('list_transactions_paginated', { query });
```

In `src/lib/tauri/holding.ts`, add:

```typescript
export const listHoldingTransactionsPaginated = (
  holdingId: string,
  first?: number,
  after?: string,
  before?: string,
) =>
  invokeTauri<PaginatedResult<HoldingTransactionDto>>(
    'list_holding_transactions_paginated',
    { holdingId, first, after, before },
  );
```

- [ ] **Step 1 complete**

### Step 2: Create useCursorPagination hook

Create `src/hooks/useCursorPagination.ts`:

```typescript
import { useState, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';

interface PageInfo {
  has_next_page: boolean;
  has_prev_page: boolean;
  next_cursor: string | null;
  prev_cursor: string | null;
}

interface PaginatedResult<T> {
  items: T[];
  page_info: PageInfo;
}

interface FetcherFn<T> {
  (cursor: string | undefined, direction: 'forward' | 'backward'): Promise<PaginatedResult<T>>;
}

interface CursorPageState<T> {
  pages: T[][];
  pageInfos: PageInfo[];
  currentPage: number;
}

export function useCursorPagination<T>(
  queryKey: unknown[],
  fetcher: FetcherFn<T>,
  options?: { enabled?: boolean; pageSize?: number },
) {
  const [state, setState] = useState<CursorPageState<T>>({
    pages: [],
    pageInfos: [],
    currentPage: 0,
  });

  const enabled = options?.enabled !== false;

  // Fetch current page
  const currentCursor =
    state.currentPage === 0
      ? undefined
      : state.pageInfos[state.currentPage - 1]?.next_cursor ?? undefined;

  const direction = 'forward' as const;

  const { isLoading, isFetching } = useQuery({
    queryKey: [...queryKey, state.currentPage, currentCursor],
    queryFn: async () => {
      // If page already loaded, return cached
      if (state.pages[state.currentPage]) {
        return { items: state.pages[state.currentPage], page_info: state.pageInfos[state.currentPage] };
      }
      const result = await fetcher(currentCursor, direction);
      setState((prev) => {
        const newPages = [...prev.pages];
        const newPageInfos = [...prev.pageInfos];
        newPages[state.currentPage] = result.items;
        newPageInfos[state.currentPage] = result.page_info;
        return { ...prev, pages: newPages, pageInfos: newPageInfos };
      });
      return result;
    },
    enabled,
    staleTime: 5 * 60 * 1000,
  });

  const currentItems = state.pages[state.currentPage] ?? [];
  const currentPageInfo = state.pageInfos[state.currentPage];

  const goNext = useCallback(() => {
    if (currentPageInfo?.has_next_page) {
      setState((prev) => ({ ...prev, currentPage: prev.currentPage + 1 }));
    }
  }, [currentPageInfo?.has_next_page]);

  const goPrev = useCallback(() => {
    setState((prev) => ({ ...prev, currentPage: Math.max(0, prev.currentPage - 1) }) );
  }, []);

  const goToPage = useCallback((page: number) => {
    setState((prev) => {
      if (page >= 0 && page < prev.pages.length) {
        return { ...prev, currentPage: page };
      }
      return prev;
    });
  }, []);

  const reset = useCallback(() => {
    setState({ pages: [], pageInfos: [], currentPage: 0 });
  }, []);

  return {
    items: currentItems,
    isLoading: isLoading || isFetching,
    currentPage: state.currentPage,
    totalPages: state.pages.length || 1,
    hasNextPage: currentPageInfo?.has_next_page ?? false,
    hasPrevPage: state.currentPage > 0,
    goNext,
    goPrev,
    goToPage,
    reset,
  };
}
```

- [ ] **Step 2 complete**

### Step 3: Update TransactionsPage to use pagination

In `src/pages/TransactionsPage.tsx`:

Replace the `useQuery` data fetching (lines ~156-164) with `useCursorPagination`:

```typescript
const {
  items: transactions,
  isLoading,
  currentPage,
  totalPages,
  hasNextPage,
  hasPrevPage,
  goNext,
  goPrev,
  goToPage,
  reset: resetPagination,
} = useCursorPagination(
  ['transactions', dateRange.start, dateRange.end],
  async (cursor, _direction) => {
    return listTransactionsPaginated({
      first: 50,
      after: cursor,
      startDate: dateRange.start || undefined,
      endDate: dateRange.end || undefined,
    });
  },
);
```

Add pagination controls at the bottom of the table (after the `</Table>` closing tag):

```tsx
<div className="flex items-center justify-between px-2 py-3 border-t">
  <div className="text-sm text-muted-foreground">
    {t('transactions.pageInfo', { page: currentPage + 1, total: totalPages })}
  </div>
  <div className="flex items-center gap-2">
    <Button
      variant="outline"
      size="sm"
      onClick={goPrev}
      disabled={!hasPrevPage}
    >
      {t('common.previous')}
    </Button>
    {Array.from({ length: totalPages }, (_, i) => (
      <Button
        key={i}
        variant={i === currentPage ? 'default' : 'outline'}
        size="sm"
        className="w-8 h-8 p-0"
        onClick={() => goToPage(i)}
      >
        {i + 1}
      </Button>
    ))}
    <Button
      variant="outline"
      size="sm"
      onClick={goNext}
      disabled={!hasNextPage}
    >
      {t('common.next')}
    </Button>
  </div>
</div>
```

Remove client-side `filteredTransactions` useMemo that filters the full dataset. Instead, filtering should eventually move to backend query params. For now, keep type/account/search filtering client-side on the current page's items.

Reset pagination when date range changes:
```typescript
// Reset pagination when filters change
useEffect(() => {
  resetPagination();
}, [dateRange.start, dateRange.end]);
```

- [ ] **Step 3 complete**

### Step 4: Update HoldingsPage trade history pagination

In `src/pages/HoldingsPage.tsx`, update the trade history query to use pagination:

```typescript
const {
  items: tradeHistory,
  isLoading: isLoadingTrades,
  hasNextPage: hasMoreTrades,
  goNext: loadMoreTrades,
} = useCursorPagination(
  ['holding-trades', expandedHoldingId],
  async (cursor) => {
    return listHoldingTransactionsPaginated(expandedHoldingId!, 20, cursor ?? undefined);
  },
  { enabled: !!expandedHoldingId },
);
```

Add a "Load More" button at the bottom of the trade history section:

```tsx
{hasMoreTrades && (
  <Button
    variant="ghost"
    size="sm"
    className="w-full mt-2"
    onClick={loadMoreTrades}
  >
    {t('common.loadMore')}
  </Button>
)}
```

- [ ] **Step 4 complete**

### Step 5: Add i18n keys for pagination

Add to `en.json`:
```json
"previous": "Previous",
"next": "Next",
"loadMore": "Load More",
"pageInfo": "Page {{page}} of {{total}}"
```

Add to `zh.json`:
```json
"previous": "上一页",
"next": "下一页",
"loadMore": "加载更多",
"pageInfo": "第 {{page}} 页 / 共 {{total}} 页"
```

Under `"transactions"` namespace in `en.json`:
```json
"pageInfo": "Page {{page}} of {{total}}"
```

Under `"transactions"` in `zh.json`:
```json
"pageInfo": "第 {{page}} 页 / 共 {{total}} 页"
```

- [ ] **Step 5 complete**

### Step 6: Verify frontend

```bash
pnpm type-check && pnpm lint
```

- [ ] **Step 6 complete**

### Step 7: Commit Task 24C

```bash
git add -A
git commit -m "feat(pagination): add frontend cursor pagination with page navigation

- Create useCursorPagination hook with cursor history and page number display
- Add PaginatedResult types to Tauri bindings
- Update TransactionsPage with cursor-based page navigation
- Update HoldingsPage trade history with load-more pagination
- Add pagination i18n keys to both locale files

Task 24C of Sprint 7.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 7 complete**

---

## Task 25: Year-Over-Year Comparison

**Files:**
- Create: `src-tauri/src/application/services/report_service.rs`
- Modify: `src-tauri/src/application/services/mod.rs`
- Create: `src-tauri/src/presentation/tauri_commands/report_commands.rs`
- Modify: `src-tauri/src/main.rs`
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/lib/tauri/report.ts` (new file)
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

### Step 1: Create report_service.rs

Create `src-tauri/src/application/services/report_service.rs` with a `get_yoy_comparison` method:

```rust
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::sync::Arc;
use tracing::info;

pub struct ReportService {
    pool: Arc<SqlitePool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YoyMonthData {
    pub month: u32,
    pub year1_income: String,
    pub year1_expense: String,
    pub year2_income: String,
    pub year2_expense: String,
    pub income_change_pct: Option<f64>,
    pub expense_change_pct: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YoyComparison {
    pub year1: u32,
    pub year2: u32,
    pub months: Vec<YoyMonthData>,
}

impl ReportService {
    pub fn new(pool: Arc<SqlitePool>) -> Self {
        Self { pool }
    }

    pub async fn get_yoy_comparison(&self, year1: u32, year2: u32) -> Result<YoyComparison, String> {
        info!(year1 = year1, year2 = year2, "Computing YoY comparison");

        // Single query aggregating income/expense by month for both years
        let rows: Vec<(i32, i32, String, String)> = sqlx::query_as(
            "SELECT
                CAST(strftime('%Y', t.transaction_date) AS INTEGER) as yr,
                CAST(strftime('%m', t.transaction_date) AS INTEGER) as mo,
                CAST(COALESCE(SUM(CASE
                    WHEN e.debit_amount IS NOT NULL AND a.account_type = 'Expense' THEN e.debit_amount
                    WHEN e.credit_amount IS NOT NULL AND a.account_type = 'Income' THEN e.credit_amount
                    ELSE 0
                END), 0) AS TEXT) as income,
                CAST(COALESCE(SUM(CASE
                    WHEN e.debit_amount IS NOT NULL AND a.account_type = 'Expense' THEN e.debit_amount
                    ELSE 0
                END), 0) AS TEXT) as expense
            FROM transactions t
            JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
            JOIN accounts a ON e.account_id = a.id
            WHERE t.deleted_at IS NULL
              AND (CAST(strftime('%Y', t.transaction_date) AS INTEGER) = ? OR CAST(strftime('%Y', t.transaction_date) AS INTEGER) = ?)
            GROUP BY yr, mo
            ORDER BY mo"
        )
        .bind(year1 as i32)
        .bind(year2 as i32)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute YoY data: {}", e))?;

        // Build months array (1-12), filling missing months with zeros
        let mut months = Vec::new();
        for mo in 1..=12 {
            let y1_row = rows.iter().find(|(yr, m, _, _)| *yr == year1 as i32 && *m == mo);
            let y2_row = rows.iter().find(|(yr, m, _, _)| *yr == year2 as i32 && *m == mo);

            let y1_income: f64 = y1_row.map(|(_, _, inc, _)| inc.parse().unwrap_or(0.0)).unwrap_or(0.0);
            let y1_expense: f64 = y1_row.map(|(_, _, _, exp)| exp.parse().unwrap_or(0.0)).unwrap_or(0.0);
            let y2_income: f64 = y2_row.map(|(_, _, inc, _)| inc.parse().unwrap_or(0.0)).unwrap_or(0.0);
            let y2_expense: f64 = y2_row.map(|(_, _, _, exp)| exp.parse().unwrap_or(0.0)).unwrap_or(0.0);

            let income_change = if y1_income > 0.0 { Some((y2_income - y1_income) / y1_income * 100.0) } else { None };
            let expense_change = if y1_expense > 0.0 { Some((y2_expense - y1_expense) / y1_expense * 100.0) } else { None };

            months.push(YoyMonthData {
                month: mo as u32,
                year1_income: format!("{:.2}", y1_income),
                year1_expense: format!("{:.2}", y1_expense),
                year2_income: format!("{:.2}", y2_income),
                year2_expense: format!("{:.2}", y2_expense),
                income_change_pct: income_change,
                expense_change_pct: expense_change,
            });
        }

        Ok(YoyComparison { year1, year2, months })
    }
}
```

Register in `mod.rs` and create Tauri command.

- [ ] **Step 1 complete**

### Step 2: Create report Tauri commands

Create `src-tauri/src/presentation/tauri_commands/report_commands.rs`:

```rust
use crate::application::services::report_service::{ReportService, YoyComparison};
use sqlx::SqlitePool;
use std::sync::Arc;
use tauri::State;

pub struct ReportCommandState {
    service: Arc<ReportService>,
}

impl ReportCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self { service: Arc::new(ReportService::new(Arc::new(pool))) }
    }
}

#[tauri::command]
pub async fn get_yoy_comparison(
    state: State<'_, ReportCommandState>,
    year1: u32,
    year2: u32,
) -> Result<YoyComparison, String> {
    state.service.get_yoy_comparison(year1, year2).await
}
```

Register in `main.rs`: add state creation and command to `invoke_handler`.

- [ ] **Step 2 complete**

### Step 3: Add frontend Tauri binding

Create `src/lib/tauri/report.ts`:

```typescript
import { invokeTauri } from '../tauri';

export interface YoyMonthData {
  month: number;
  year1_income: string;
  year1_expense: string;
  year2_income: string;
  year2_expense: string;
  income_change_pct: number | null;
  expense_change_pct: number | null;
}

export interface YoyComparison {
  year1: number;
  year2: number;
  months: YoyMonthData[];
}

export const getYoyComparison = (year1: number, year2: number) =>
  invokeTauri<YoyComparison>('get_yoy_comparison', { year1, year2 });
```

- [ ] **Step 3 complete**

### Step 4: Add YoY comparison to ReportsPage

In `src/pages/ReportsPage.tsx`, add a new tab/section "Year-over-Year":

1. Add state for selected years:
```typescript
const [yoyYear1, setYoyYear1] = useState(new Date().getFullYear() - 1);
const [yoyYear2, setYoyYear2] = useState(new Date().getFullYear());
```

2. Add data fetching:
```typescript
const { data: yoyData, isLoading: isLoadingYoy } = useQuery({
  queryKey: ['yoy-comparison', yoyYear1, yoyYear2],
  queryFn: () => getYoyComparison(yoyYear1, yoyYear2),
});
```

3. Add a grouped bar chart using Recharts:
```tsx
<ResponsiveContainer width="100%" height={400}>
  <BarChart data={yoyData?.months}>
    <CartesianGrid strokeDasharray="3 3" />
    <XAxis dataKey="month" tickFormatter={(m) => `${m}月`} />
    <YAxis />
    <Tooltip />
    <Legend />
    <Bar dataKey="year1_expense" name={`${yoyYear1}`} fill="#94a3b8" />
    <Bar dataKey="year2_expense" name={`${yoyYear2}`} fill="#3b82f6" />
  </BarChart>
</ResponsiveContainer>
```

4. Add year selectors (two Select dropdowns) and an income/expense toggle.

5. Add i18n keys for the new section.

- [ ] **Step 4 complete**

### Step 5: Verify and commit

```bash
pnpm type-check && pnpm lint && cd src-tauri && cargo check
```

```bash
git add -A
git commit -m "feat(reports): add year-over-year comparison with grouped bar chart

- Create ReportService with get_yoy_comparison aggregation query
- New Tauri command get_yoy_comparison
- Frontend YoY comparison section in ReportsPage
- Grouped bar chart comparing monthly income/expense across two years
- Shows percentage change between years

Task 25 of Sprint 7.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5 complete**

---

## Final Verification

```bash
# Frontend
pnpm type-check
pnpm lint

# Backend
make check
make test

# Full app
pnpm tauri dev
```
