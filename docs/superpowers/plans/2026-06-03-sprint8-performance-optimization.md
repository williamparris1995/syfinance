# Sprint 8: Performance Optimization & Feature Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate performance bottlenecks (missing indexes, N+1 queries, client-side filtering), migrate ReportsPage/HomePage to server-side aggregation, wire up prepaid expiry and low-balance notifications.

**Architecture:** Add database indexes via migration. Refactor N+1 query methods to use existing batch-load infrastructure. Add SQL-level account filtering. Create server-side report aggregation endpoints. Add prepaid alert schedulers following existing `tokio::spawn` + `tokio::time::interval` pattern.

**Tech Stack:** Rust + SQLx + Tauri (backend), React + TanStack Query + Recharts (frontend)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/migrations/20260604000001_add_performance_indexes.sql` | Create | Database indexes for high-frequency queries |
| `src-tauri/src/infrastructure/repositories/transaction_repository.rs` | Modify | N+1 fix: refactor find_all/find_by_date_range/get_changes_since + add find_by_account |
| `src-tauri/src/domain/repositories/mod.rs` | Modify | Add find_by_account to TransactionRepository trait |
| `src-tauri/src/application/services/transaction_service.rs` | Modify | Use find_by_account instead of find_all + filter |
| `src-tauri/src/application/services/report_service.rs` | Modify | Add get_balance_sheet, get_income_statement, get_dashboard_summary |
| `src-tauri/src/presentation/tauri_commands/report_commands.rs` | Modify | Add get_balance_sheet, get_income_statement, get_dashboard_summary commands |
| `src-tauri/src/main.rs` | Modify | Register new commands + start prepaid alert schedulers |
| `src-tauri/src/application/services/prepaid_service.rs` | Modify | Wire check_low_balance_alert to persist reminders |
| `src-tauri/src/infrastructure/schedulers/mod.rs` | Create | PrepaidAlertScheduler for expiry + low-balance checks |
| `src/lib/tauri/report.ts` | Modify | Add frontend bindings for new report endpoints |
| `src/pages/ReportsPage.tsx` | Modify | Replace listTransactions with server-side aggregation |
| `src/pages/HomePage.tsx` | Modify | Replace listTransactions with get_dashboard_summary |
| `src/i18n/locales/en.json` | Modify | Add new i18n keys |
| `src/i18n/locales/zh.json` | Modify | Add new i18n keys |

---

## Task 26: Database Indexes

**Files:**
- Create: `src-tauri/migrations/20260604000001_add_performance_indexes.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Performance indexes for high-frequency queries

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

Save to `src-tauri/migrations/20260604000001_add_performance_indexes.sql`.

- [ ] **Step 2: Verify migration runs**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors

- [ ] **Step 3: Commit**

```bash
git add src-tauri/migrations/20260604000001_add_performance_indexes.sql
git commit -m "perf: add database indexes for high-frequency query columns

- Index transaction_entries on account_id, transaction_id, deleted_at
- Index transactions on transaction_date, deleted_at
- Index debt_details on account_id
- Index tags on name
- Index holding_transactions on (account_id, security_id) and trade_date

Task 26 of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 27: N+1 Fix for Non-Paginated Endpoints

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/transaction_repository.rs`

**Context:** `find_all()`, `find_by_date_range()`, and `get_changes_since()` each loop over transaction rows and call `load_entries()` per transaction. `load_entries()` in turn queries the `accounts` table per entry for currency codes. This is 2N+1 queries for N transactions.

The fix: Collect all transaction IDs first, call `batch_load_entries()` once (which already calls `batch_load_currencies()` internally), then reconstruct transactions from the batch-loaded map.

- [ ] **Step 1: Extract a helper to parse transaction row into parts**

In `transaction_repository.rs`, the row-parsing logic (extracting id, date, description, sync metadata from a row) is duplicated across `find_by_date_range`, `find_all`, and `get_changes_since`. Extract it into a private helper. Add this method inside the `impl SqliteTransactionRepository` block, after the existing `parse_sqlite_datetime` method:

```rust
    /// Parse a single SQL row into Transaction parts (everything except entries).
    /// Returns (id, transaction_date, description, SyncMetadata) or error.
    fn parse_transaction_row(row: &sqlx::sqlite::SqliteRow) -> sqlx::Result<(Uuid, NaiveDate, String, SyncMetadata)> {
        let id: String = row.try_get("id")?;
        let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let transaction_date: String = row.try_get("transaction_date")?;
        let transaction_date = NaiveDate::parse_from_str(&transaction_date, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let description: String = row.try_get("description")?;

        let updated_at: String = row.try_get("updated_at")?;
        let deleted_at: Option<String> = row.try_get("deleted_at")?;
        let device_id: String = row.try_get("device_id")?;
        let synced_at: Option<String> = row.try_get("synced_at")?;

        let updated_at_parsed = Self::parse_sqlite_datetime(&updated_at)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        let deleted_at_parsed = deleted_at
            .map(|s| Self::parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        let device_id_parsed =
            Uuid::from_str(&device_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        let synced_at_parsed = synced_at
            .map(|s| Self::parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let sync_metadata = SyncMetadata {
            updated_at: updated_at_parsed,
            deleted_at: deleted_at_parsed,
            device_id: device_id_parsed,
            synced_at: synced_at_parsed,
        };

        Ok((id, transaction_date, description, sync_metadata))
    }
```

- [ ] **Step 2: Refactor `find_all()` to use batch loading**

Replace the existing `find_all()` method body. The method signature stays the same. Find the `async fn find_all` implementation in `SqliteTransactionRepository` (around line 792) and replace its entire body with:

```rust
    async fn find_all(&self) -> sqlx::Result<Vec<Transaction>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE deleted_at IS NULL
            ORDER BY transaction_date DESC, id DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        // Parse all rows into parts (without entries)
        let parsed: Vec<(Uuid, NaiveDate, String, SyncMetadata)> = rows
            .iter()
            .map(|row| Self::parse_transaction_row(row))
            .collect::<sqlx::Result<Vec<_>>>()?;

        // Batch-load all entries in a single query
        let txn_ids: Vec<String> = parsed.iter().map(|(id, _, _, _)| id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        // Reconstruct transactions
        let transactions = parsed
            .into_iter()
            .map(|(id, transaction_date, description, sync_metadata)| {
                let entries = entries_map.get(&id).cloned().unwrap_or_default();
                Transaction::reconstitute(id, transaction_date, description, entries, sync_metadata)
            })
            .collect();

        Ok(transactions)
    }
```

- [ ] **Step 3: Refactor `find_by_date_range()` to use batch loading**

Find the `async fn find_by_date_range` implementation in `SqliteTransactionRepository` (around line 710) and replace its body with:

```rust
    async fn find_by_date_range(
        &self,
        start_date: NaiveDate,
        end_date: NaiveDate,
    ) -> sqlx::Result<Vec<Transaction>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE deleted_at IS NULL
              AND transaction_date >= ? AND transaction_date <= ?
            ORDER BY transaction_date DESC, id DESC
            "#,
        )
        .bind(start_date.to_string())
        .bind(end_date.to_string())
        .fetch_all(&self.pool)
        .await?;

        let parsed: Vec<(Uuid, NaiveDate, String, SyncMetadata)> = rows
            .iter()
            .map(|row| Self::parse_transaction_row(row))
            .collect::<sqlx::Result<Vec<_>>>()?;

        let txn_ids: Vec<String> = parsed.iter().map(|(id, _, _, _)| id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        let transactions = parsed
            .into_iter()
            .map(|(id, transaction_date, description, sync_metadata)| {
                let entries = entries_map.get(&id).cloned().unwrap_or_default();
                Transaction::reconstitute(id, transaction_date, description, entries, sync_metadata)
            })
            .collect();

        Ok(transactions)
    }
```

- [ ] **Step 4: Refactor `get_changes_since()` to use batch loading**

Find the `async fn get_changes_since` implementation in `SqliteTransactionRepository` (around line 900) and replace its body with:

```rust
    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Transaction>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE updated_at > ? AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp.to_rfc3339())
        .fetch_all(&self.pool)
        .await?;

        let parsed: Vec<(Uuid, NaiveDate, String, SyncMetadata)> = rows
            .iter()
            .map(|row| Self::parse_transaction_row(row))
            .collect::<sqlx::Result<Vec<_>>>()?;

        let txn_ids: Vec<String> = parsed.iter().map(|(id, _, _, _)| id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        let transactions = parsed
            .into_iter()
            .map(|(id, transaction_date, description, sync_metadata)| {
                let entries = entries_map.get(&id).cloned().unwrap_or_default();
                Transaction::reconstitute(id, transaction_date, description, entries, sync_metadata)
            })
            .collect();

        Ok(transactions)
    }
```

- [ ] **Step 5: Verify cargo check**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/transaction_repository.rs
git commit -m "perf: fix N+1 queries in find_all, find_by_date_range, get_changes_since

- Extract parse_transaction_row helper to reduce duplication
- Refactor find_all/find_by_date_range/get_changes_since to use batch_load_entries
- Reduces queries from 2N+1 per call to 3 total (rows + entries + currencies)

Task 27 of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 28: Server-Side Account Filtering

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs`
- Modify: `src-tauri/src/infrastructure/repositories/transaction_repository.rs`
- Modify: `src-tauri/src/application/services/transaction_service.rs`

- [ ] **Step 1: Add `find_by_account` to TransactionRepository trait**

In `src-tauri/src/domain/repositories/mod.rs`, add the new method to the `TransactionRepository` trait (after the existing `find_paginated` method, around line 95):

```rust
    async fn find_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<Transaction>>;
```

- [ ] **Step 2: Implement `find_by_account` in SqliteTransactionRepository**

In `src-tauri/src/infrastructure/repositories/transaction_repository.rs`, add the implementation after `get_changes_since`:

```rust
    async fn find_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<Transaction>> {
        let rows = sqlx::query(
            r#"
            SELECT DISTINCT t.id, t.transaction_date, t.description,
                t.updated_at, t.deleted_at, t.device_id, t.synced_at
            FROM transactions t
            JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
            WHERE e.account_id = ? AND t.deleted_at IS NULL
            ORDER BY t.transaction_date DESC, t.id DESC
            "#,
        )
        .bind(account_id.to_string())
        .fetch_all(&self.pool)
        .await?;

        let parsed: Vec<(Uuid, NaiveDate, String, SyncMetadata)> = rows
            .iter()
            .map(|row| Self::parse_transaction_row(row))
            .collect::<sqlx::Result<Vec<_>>>()?;

        let txn_ids: Vec<String> = parsed.iter().map(|(id, _, _, _)| id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        let transactions = parsed
            .into_iter()
            .map(|(id, transaction_date, description, sync_metadata)| {
                let entries = entries_map.get(&id).cloned().unwrap_or_default();
                Transaction::reconstitute(id, transaction_date, description, entries, sync_metadata)
            })
            .collect();

        Ok(transactions)
    }
```

- [ ] **Step 3: Update `get_transactions_by_account` in TransactionService**

In `src-tauri/src/application/services/transaction_service.rs`, find the `get_transactions_by_account` method (around line 224) and replace it with:

```rust
    pub async fn get_transactions_by_account(
        &self,
        account_id: Uuid,
    ) -> Result<Vec<TransactionDto>, TransactionServiceError> {
        let transactions = self.transaction_repo.find_by_account(account_id).await?;
        let dtos = transactions.into_iter().map(|t| self.to_dto(t)).collect();
        Ok(dtos)
    }
```

This replaces the old `find_all()` + in-memory filter with a single SQL query that uses `JOIN transaction_entries WHERE e.account_id = ?`.

- [ ] **Step 4: Verify cargo check**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs src-tauri/src/infrastructure/repositories/transaction_repository.rs src-tauri/src/application/services/transaction_service.rs
git commit -m "perf: add SQL-level account filtering for get_transactions_by_account

- Add find_by_account to TransactionRepository trait
- Implement with JOIN + DISTINCT in SqliteTransactionRepository
- Replace find_all() + in-memory filter in TransactionService
- Uses batch_load_entries to avoid N+1

Task 28 of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 29: ReportsPage + HomePage Migration to Server-Side Aggregation

**Files:**
- Modify: `src-tauri/src/application/services/report_service.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/report_commands.rs`
- Modify: `src-tauri/src/main.rs`
- Modify: `src/lib/tauri/report.ts`
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/pages/HomePage.tsx`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

### Part A: Backend — Report Aggregation Service

- [ ] **Step 1: Add aggregation types and methods to ReportService**

In `src-tauri/src/application/services/report_service.rs`, add the following types and methods after the existing `YoyComparison` types and before `impl ReportService`:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheetItem {
    pub account_id: String,
    pub account_name: String,
    pub account_type: String,
    pub balance: String,
    pub currency_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheet {
    pub as_of_date: String,
    pub assets: Vec<BalanceSheetItem>,
    pub liabilities: Vec<BalanceSheetItem>,
    pub total_assets: String,
    pub total_liabilities: String,
    pub equity: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatementItem {
    pub account_id: String,
    pub account_name: String,
    pub amount: String,
    pub transaction_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatement {
    pub start_date: String,
    pub end_date: String,
    pub income: Vec<IncomeStatementItem>,
    pub expenses: Vec<IncomeStatementItem>,
    pub total_income: String,
    pub total_expenses: String,
    pub net_income: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonthlyTrendItem {
    pub month: String,
    pub income: String,
    pub expenses: String,
    pub categories: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardSummary {
    pub start_date: String,
    pub end_date: String,
    pub total_income: String,
    pub total_expenses: String,
    pub net_savings: String,
    pub income_by_category: Vec<IncomeStatementItem>,
    pub expense_by_category: Vec<IncomeStatementItem>,
}
```

Then add the methods inside `impl ReportService`, after the existing `get_yoy_comparison` method:

```rust
    pub async fn get_balance_sheet(
        &self,
        as_of_date: &str,
    ) -> Result<BalanceSheet, String> {
        info!(as_of_date = as_of_date, "Computing balance sheet");

        // Compute net change per account from transactions up to as_of_date
        let rows: Vec<(String, String, String, String, String)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                a.currency_code,
                CAST(a.initial_balance + COALESCE(SUM(
                    CASE
                        WHEN e.debit_amount IS NOT NULL THEN e.debit_amount
                        WHEN e.credit_amount IS NOT NULL THEN -e.credit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as balance
            FROM accounts a
            LEFT JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            LEFT JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date <= ?1
            WHERE a.deleted_at IS NULL
            GROUP BY a.id
            ORDER BY a.name",
        )
        .bind(as_of_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute balance sheet: {}", e))?;

        let mut assets = Vec::new();
        let mut liabilities = Vec::new();
        let mut total_assets = rust_decimal::Decimal::ZERO;
        let mut total_liabilities = rust_decimal::Decimal::ZERO;

        for (id, name, account_type, currency, balance_str) in &rows {
            let balance: rust_decimal::Decimal = balance_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let is_asset = matches!(
                account_type.as_str(),
                "Cash" | "Bank" | "Investment" | "Prepaid"
            );
            let is_liability = matches!(
                account_type.as_str(),
                "CreditCard" | "BorrowedIn"
            );

            if is_asset && balance > &rust_decimal::Decimal::ZERO {
                total_assets += balance;
                assets.push(BalanceSheetItem {
                    account_id: id.clone(),
                    account_name: name.clone(),
                    account_type: account_type.clone(),
                    balance: balance.to_string(),
                    currency_code: currency.clone(),
                });
            } else if is_liability && balance < &rust_decimal::Decimal::ZERO {
                let abs_balance = -balance;
                total_liabilities += abs_balance;
                liabilities.push(BalanceSheetItem {
                    account_id: id.clone(),
                    account_name: name.clone(),
                    account_type: account_type.clone(),
                    balance: abs_balance.to_string(),
                    currency_code: currency.clone(),
                });
            }
        }

        let equity = total_assets - total_liabilities;

        Ok(BalanceSheet {
            as_of_date: as_of_date.to_string(),
            assets,
            liabilities,
            total_assets: total_assets.to_string(),
            total_liabilities: total_liabilities.to_string(),
            equity: equity.to_string(),
        })
    }

    pub async fn get_income_statement(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<IncomeStatement, String> {
        info!(start_date = start_date, end_date = end_date, "Computing income statement");

        let rows: Vec<(String, String, String, String, i64)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                CAST(COALESCE(SUM(
                    CASE
                        WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
                        WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as amount,
                COUNT(DISTINCT e.transaction_id) as tx_count
            FROM accounts a
            JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
            WHERE a.deleted_at IS NULL
              AND a.account_type IN ('income', 'expense')
              AND a.ownership = 'external'
            GROUP BY a.id
            ORDER BY a.name",
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute income statement: {}", e))?;

        let mut income = Vec::new();
        let mut expenses = Vec::new();
        let mut total_income = rust_decimal::Decimal::ZERO;
        let mut total_expenses = rust_decimal::Decimal::ZERO;

        for (id, name, account_type, amount_str, tx_count) in &rows {
            let amount: rust_decimal::Decimal = amount_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let item = IncomeStatementItem {
                account_id: id.clone(),
                account_name: name.clone(),
                amount: amount.to_string(),
                transaction_count: *tx_count,
            };
            if account_type == "income" {
                total_income += amount;
                income.push(item);
            } else if account_type == "expense" {
                total_expenses += amount;
                expenses.push(item);
            }
        }

        let net_income = total_income - total_expenses;

        Ok(IncomeStatement {
            start_date: start_date.to_string(),
            end_date: end_date.to_string(),
            income,
            expenses,
            total_income: total_income.to_string(),
            total_expenses: total_expenses.to_string(),
            net_income: net_income.to_string(),
        })
    }

    pub async fn get_dashboard_summary(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<DashboardSummary, String> {
        info!(start_date = start_date, end_date = end_date, "Computing dashboard summary");

        let rows: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                CAST(COALESCE(SUM(
                    CASE
                        WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
                        WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as amount
            FROM accounts a
            JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
            WHERE a.deleted_at IS NULL
              AND a.account_type IN ('income', 'expense')
              AND a.ownership = 'external'
            GROUP BY a.id
            ORDER BY amount DESC",
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute dashboard summary: {}", e))?;

        let mut total_income = rust_decimal::Decimal::ZERO;
        let mut total_expenses = rust_decimal::Decimal::ZERO;
        let mut income_by_category = Vec::new();
        let mut expense_by_category = Vec::new();

        for (id, name, account_type, amount_str) in &rows {
            let amount: rust_decimal::Decimal = amount_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let item = IncomeStatementItem {
                account_id: id.clone(),
                account_name: name.clone(),
                amount: amount.to_string(),
                transaction_count: 0,
            };
            if account_type == "income" {
                total_income += amount;
                income_by_category.push(item);
            } else if account_type == "expense" {
                total_expenses += amount;
                expense_by_category.push(item);
            }
        }

        let net_savings = total_income - total_expenses;

        Ok(DashboardSummary {
            start_date: start_date.to_string(),
            end_date: end_date.to_string(),
            total_income: total_income.to_string(),
            total_expenses: total_expenses.to_string(),
            net_savings: net_savings.to_string(),
            income_by_category,
            expense_by_category,
        })
    }
```

- [ ] **Step 2: Add new Tauri commands in report_commands.rs**

Replace the entire content of `src-tauri/src/presentation/tauri_commands/report_commands.rs` with:

```rust
use crate::application::services::report_service::{
    BalanceSheet, DashboardSummary, IncomeStatement, ReportService, YoyComparison,
};
use serde::Deserialize;
use sqlx::SqlitePool;
use std::sync::Arc;
use tauri::State;

pub struct ReportCommandState {
    service: Arc<ReportService>,
}

impl ReportCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            service: Arc::new(ReportService::new(Arc::new(pool))),
        }
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

#[derive(Debug, Deserialize)]
pub struct ReportDateQuery {
    pub start_date: String,
    pub end_date: String,
}

#[tauri::command]
pub async fn get_balance_sheet(
    state: State<'_, ReportCommandState>,
    as_of_date: String,
) -> Result<BalanceSheet, String> {
    state.service.get_balance_sheet(&as_of_date).await
}

#[tauri::command]
pub async fn get_income_statement(
    state: State<'_, ReportCommandState>,
    query: ReportDateQuery,
) -> Result<IncomeStatement, String> {
    state.service.get_income_statement(&query.start_date, &query.end_date).await
}

#[tauri::command]
pub async fn get_dashboard_summary(
    state: State<'_, ReportCommandState>,
    query: ReportDateQuery,
) -> Result<DashboardSummary, String> {
    state.service.get_dashboard_summary(&query.start_date, &query.end_date).await
}
```

- [ ] **Step 3: Register new commands in main.rs**

In `src-tauri/src/main.rs`, add the new commands to the `invoke_handler` macro list (after `get_yoy_comparison` around line 423):

```rust
            get_balance_sheet,
            get_income_statement,
            get_dashboard_summary,
```

Verify the import for `report_commands` at the top of main.rs includes the new types (the `use` statement already imports the module, so this should work).

- [ ] **Step 4: Verify cargo check**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors

- [ ] **Step 5: Commit backend part**

```bash
git add src-tauri/src/application/services/report_service.rs src-tauri/src/presentation/tauri_commands/report_commands.rs src-tauri/src/main.rs
git commit -m "feat(reports): add server-side aggregation for balance sheet, income statement, dashboard

- BalanceSheet: SQL aggregation of account balances as of a date
- IncomeStatement: SQL aggregation of income/expense by account with tx counts
- DashboardSummary: lightweight summary for HomePage
- New Tauri commands: get_balance_sheet, get_income_statement, get_dashboard_summary

Task 29A of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Part B: Frontend — Type Bindings + ReportsPage Migration

- [ ] **Step 6: Add frontend Tauri bindings for new report endpoints**

Replace the entire content of `src/lib/tauri/report.ts` with:

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

export interface BalanceSheetItem {
  account_id: string;
  account_name: string;
  account_type: string;
  balance: string;
  currency_code: string;
}

export interface BalanceSheet {
  as_of_date: string;
  assets: BalanceSheetItem[];
  liabilities: BalanceSheetItem[];
  total_assets: string;
  total_liabilities: string;
  equity: string;
}

export interface IncomeStatementItem {
  account_id: string;
  account_name: string;
  amount: string;
  transaction_count: number;
}

export interface IncomeStatement {
  start_date: string;
  end_date: string;
  income: IncomeStatementItem[];
  expenses: IncomeStatementItem[];
  total_income: string;
  total_expenses: string;
  net_income: string;
}

export interface DashboardSummary {
  start_date: string;
  end_date: string;
  total_income: string;
  total_expenses: string;
  net_savings: string;
  income_by_category: IncomeStatementItem[];
  expense_by_category: IncomeStatementItem[];
}

export const getYoyComparison = (year1: number, year2: number) =>
  invokeTauri<YoyComparison>('get_yoy_comparison', { year1, year2 });

export const getBalanceSheet = (asOfDate: string) =>
  invokeTauri<BalanceSheet>('get_balance_sheet', { asOfDate: asOfDate });

export const getIncomeStatement = (startDate: string, endDate: string) =>
  invokeTauri<IncomeStatement>('get_income_statement', {
    query: { start_date: startDate, end_date: endDate },
  });

export const getDashboardSummary = (startDate: string, endDate: string) =>
  invokeTauri<DashboardSummary>('get_dashboard_summary', {
    query: { start_date: startDate, end_date: endDate },
  });
```

- [ ] **Step 7: Update ReportsPage to use server-side aggregation**

In `src/pages/ReportsPage.tsx`, make the following changes:

**A. Update imports** — Replace the `listTransactions` import with the new report types. Change:
```typescript
import { getYoyComparison } from '../lib/tauri/report';
import { listTransactions, type TransactionDto } from '../lib/tauri/transaction';
```
To:
```typescript
import { getYoyComparison, getBalanceSheet, getIncomeStatement, type BalanceSheet as BalanceSheetData, type IncomeStatement as IncomeStatementData } from '../lib/tauri/report';
```

Remove the `TransactionDto` type import if no longer used.

**B. Replace data fetching** — Remove the `listTransactions` useQuery (lines 53-56). Remove the `isLoadingTransactions` variable and the `transactions` data. Replace with:

```typescript
  const { data: balanceSheet, isLoading: isLoadingBalanceSheet } = useQuery({
    queryKey: ['balance-sheet', dateRange.end],
    queryFn: () => getBalanceSheet(dateRange.end),
  });

  const { data: incomeStatement, isLoading: isLoadingIncomeStatement } = useQuery({
    queryKey: ['income-statement', dateRange.start, dateRange.end],
    queryFn: () => getIncomeStatement(dateRange.start, dateRange.end),
  });
```

**C. Remove old useMemo blocks** — Delete the `balanceSheetData` useMemo (lines 113-161) and `incomeStatementData` useMemo (lines 163-200) and `categoryTransactionCount` useMemo (lines 202-219). These are now computed server-side.

**D. Update balance sheet tab rendering** — Replace all references to `balanceSheetData.assets` with `balanceSheet?.assets ?? []`, `balanceSheetData.totalAssets` with `parseFloat(balanceSheet?.total_assets ?? '0')`, etc. Change `balanceSheetData.liabilities` to `balanceSheet?.liabilities ?? []`, `balanceSheetData.equity` to `parseFloat(balanceSheet?.equity ?? '0')`. For individual items, change `item.balance` to `parseFloat(item.balance)` and `item.currency` to `item.currency_code`.

**E. Update income statement tab rendering** — Replace references to `incomeStatementData.income` with `incomeStatement?.income ?? []`, `incomeStatementData.totalIncome` with `parseFloat(incomeStatement?.total_income ?? '0')`, etc. For items, change `item.amount` to `parseFloat(item.amount)` and `item.name` to `item.account_name`. Use `item.transaction_count` directly (no more `categoryTransactionCount` lookup).

**F. Update loading state** — Change:
```typescript
const isLoading = isLoadingAccounts || isLoadingTransactions;
```
To:
```typescript
const isLoading = isLoadingAccounts || isLoadingBalanceSheet || isLoadingIncomeStatement;
```

**G. Export functions** — The `exportBalanceSheet` and `exportIncomeStatement` functions reference the old local data. Update them to use the new server data (`balanceSheet` and `incomeStatement`). For balance sheet export:
```typescript
  const exportBalanceSheet = () => {
    if (!balanceSheet) return;
    const data: string[][] = [
      [t('reports.balanceSheet'), `${t('reports.asOf')} ${dateRange.end}`],
      [],
      [t('reports.assets')],
      [t('common.account'), t('common.balance'), t('common.currency')],
      ...balanceSheet.assets.map((item) => [item.account_name, parseFloat(item.balance).toFixed(2), item.currency_code]),
      [t('reports.totalAssets'), parseFloat(balanceSheet.total_assets).toFixed(2), ''],
      [],
      [t('reports.liabilities')],
      [t('common.account'), t('common.balance'), t('common.currency')],
      ...balanceSheet.liabilities.map((item) => [item.account_name, parseFloat(item.balance).toFixed(2), item.currency_code]),
      [t('reports.totalLiabilities'), parseFloat(balanceSheet.total_liabilities).toFixed(2), ''],
      [],
      [t('reports.equity'), parseFloat(balanceSheet.equity).toFixed(2), ''],
    ];
    downloadCSV(data, `balance-sheet-${dateRange.end}.csv`);
  };

  const exportIncomeStatement = () => {
    if (!incomeStatement) return;
    const data: string[][] = [
      [t('reports.incomeStatement'), `${dateRange.start} to ${dateRange.end}`],
      [],
      [t('reports.income')],
      [t('common.account'), t('common.amount')],
      ...incomeStatement.income.map((item) => [item.account_name, parseFloat(item.amount).toFixed(2)]),
      [t('reports.totalIncome'), parseFloat(incomeStatement.total_income).toFixed(2)],
      [],
      [t('reports.expenses')],
      [t('common.account'), t('common.amount')],
      ...incomeStatement.expenses.map((item) => [item.account_name, parseFloat(item.amount).toFixed(2)]),
      [t('reports.totalExpenses'), parseFloat(incomeStatement.total_expenses).toFixed(2)],
      [],
      [t('reports.netIncome'), parseFloat(incomeStatement.net_income).toFixed(2)],
    ];
    downloadCSV(data, `income-statement-${dateRange.start}-to-${dateRange.end}.csv`);
  };
```

- [ ] **Step 8: Update HomePage to use server-side aggregation**

In `src/pages/HomePage.tsx`, make the following changes:

**A. Update imports** — Add the dashboard summary import:
```typescript
import { getDashboardSummary } from '@/lib/tauri/report';
```
Remove or keep `listTransactions` import — keep it removed if no other code needs it.

**B. Replace transaction data fetching** — Remove the `listTransactions` useQuery (lines 42-45). Add:
```typescript
  const { data: dashboardSummary } = useQuery({
    queryKey: ['dashboard-summary', dateRange.start, dateRange.end],
    queryFn: () => getDashboardSummary(dateRange.start, dateRange.end),
  });
```

**C. Replace computed values** — Replace the `monthlyIncome`, `monthlyExpenses`, `incomeByCategory`, `expenseByCategory` useMemo (lines 101-133) with data from the server response:
```typescript
  const monthlyIncome = parseFloat(dashboardSummary?.total_income ?? '0');
  const monthlyExpenses = parseFloat(dashboardSummary?.total_expenses ?? '0');
  const incomeByCategory = (dashboardSummary?.income_by_category ?? []).map(item => ({
    name: item.account_name,
    amount: parseFloat(item.amount),
  }));
  const expenseByCategory = (dashboardSummary?.expense_by_category ?? []).map(item => ({
    name: item.account_name,
    amount: parseFloat(item.amount),
  }));
```

**D. Update loading state** — Remove `transactionsLoading` from the destructuring and replace:
```typescript
const isLoading = accountsLoading;
```

Since the dashboard data no longer depends on loading all transactions, only accounts loading matters for the initial view. The dashboard summary loads independently.

**Note:** The `monthlyTrendData` and `expenseCategories` useMemo blocks in HomePage also depend on `transactions`. For this task, keep `listTransactions` import temporarily for the trend charts, or create a server-side monthly trend endpoint in a follow-up. The critical optimization is removing `listTransactions` for the summary cards and donut charts. Mark this as a known limitation if the trend charts still need client-side data.

- [ ] **Step 9: Verify frontend builds**

Run: `pnpm type-check && pnpm lint`
Expected: No type errors, no lint errors

- [ ] **Step 10: Commit frontend part**

```bash
git add src/lib/tauri/report.ts src/pages/ReportsPage.tsx src/pages/HomePage.tsx
git commit -m "feat(reports): migrate ReportsPage and HomePage to server-side aggregation

- ReportsPage: replace listTransactions with getBalanceSheet + getIncomeStatement
- HomePage: replace listTransactions with getDashboardSummary for summary cards
- Export functions updated to use server response data
- Removes full transaction list loading from both pages

Task 29B of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 30: Prepaid Expiry Alerts

**Files:**
- Create: `src-tauri/src/infrastructure/schedulers/mod.rs`
- Create: `src-tauri/src/infrastructure/schedulers/prepaid_alert_scheduler.rs`
- Modify: `src-tauri/src/infrastructure/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create scheduler module structure**

Create `src-tauri/src/infrastructure/schedulers/mod.rs`:
```rust
pub mod prepaid_alert_scheduler;

pub use prepaid_alert_scheduler::PrepaidAlertScheduler;
```

Create `src-tauri/src/infrastructure/schedulers/prepaid_alert_scheduler.rs`:
```rust
use chrono::Utc;
use sqlx::SqlitePool;
use tracing::{error, info};
use uuid::Uuid;

use crate::domain::aggregates::reminder::{Priority, Reminder, ReminderType};
use crate::domain::repositories::ReminderRepository;
use crate::domain::value_objects::SyncMetadata;
use crate::infrastructure::repositories::SqliteReminderRepository;

/// Background scheduler that checks for expiring prepaid top-up records
/// and low-balance prepaid accounts, creating reminders as needed.
pub struct PrepaidAlertScheduler {
    pool: SqlitePool,
}

impl PrepaidAlertScheduler {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Check for prepaid top-up records expiring within 7 days.
    /// Creates a reminder for each expiring record if one doesn't already exist.
    pub async fn check_expiry_alerts(&self) -> Result<(), String> {
        info!("Checking prepaid expiry alerts");

        let repo = SqliteReminderRepository::new(self.pool.clone());

        // Find top-up records expiring within 7 days that don't already have a reminder
        // Uses actual schema columns: related_entity_id, notified, deleted_at
        let rows: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT tr.id, tr.account_id, a.name, tr.expiry_date
            FROM top_up_records tr
            JOIN accounts a ON a.id = tr.account_id
            WHERE tr.expiry_date IS NOT NULL
              AND tr.deleted_at IS NULL
              AND date(tr.expiry_date) <= date('now', '+7 days')
              AND date(tr.expiry_date) >= date('now')
              AND NOT EXISTS (
                  SELECT 1 FROM reminders r
                  WHERE r.related_entity_id = tr.account_id
                    AND r.reminder_type = '\"prepaid_low_balance\"'
                    AND r.notified = 0
                    AND r.deleted_at IS NULL
              )",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to query expiring top-up records: {}", e))?;

        for (record_id, account_id, account_name, expiry_date) in &rows {
            let account_uuid = account_id
                .parse::<Uuid>()
                .map_err(|e| format!("Invalid account_id: {}", e))?;

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::PrepaidLowBalance,
                Some(account_uuid),
                format!("Prepaid expiry: {}", account_name),
                format!(
                    "Top-up record for {} expires on {}. Record ID: {}",
                    account_name, expiry_date, record_id
                ),
                Utc::now() + chrono::Duration::hours(1),
                None,
                Priority::High,
                SyncMetadata::new(Uuid::new_v4()),
            )
            .map_err(|e| format!("Failed to create reminder: {}", e))?;

            repo.create(&reminder)
                .await
                .map_err(|e| format!("Failed to persist reminder: {}", e))?;

            info!(
                account_name = account_name,
                expiry_date = expiry_date,
                "Created expiry reminder for prepaid account"
            );
        }

        info!(count = rows.len(), "Prepaid expiry check complete");
        Ok(())
    }

    /// Check for prepaid accounts with balance below their threshold.
    pub async fn check_low_balance_alerts(&self) -> Result<(), String> {
        info!("Checking prepaid low-balance alerts");

        let repo = SqliteReminderRepository::new(self.pool.clone());

        // Find prepaid accounts with low_balance_threshold set that don't already have
        // an active low-balance reminder. Uses actual schema columns.
        let rows: Vec<(String, String, String)> = sqlx::query_as(
            "SELECT a.id, a.name, CAST(a.low_balance_threshold AS TEXT) as threshold
            FROM accounts a
            WHERE a.account_type = 'Prepaid'
              AND a.deleted_at IS NULL
              AND a.low_balance_threshold IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM reminders r
                  WHERE r.related_entity_id = a.id
                    AND r.reminder_type = '\"prepaid_low_balance\"'
                    AND r.notified = 0
                    AND r.deleted_at IS NULL
              )",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to query low-balance accounts: {}", e))?;

        for (account_id_str, account_name, threshold_str) in &rows {
            let account_id = account_id_str
                .parse::<Uuid>()
                .map_err(|e| format!("Invalid account_id: {}", e))?;

            // Compute actual balance from transactions
            let balance_row: Option<(String,)> = sqlx::query_as(
                "SELECT CAST(a.initial_balance + COALESCE(SUM(
                    CASE
                        WHEN e.debit_amount IS NOT NULL THEN e.debit_amount
                        WHEN e.credit_amount IS NOT NULL THEN -e.credit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as balance
                FROM accounts a
                LEFT JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
                LEFT JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                WHERE a.id = ?",
            )
            .bind(account_id_str)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| format!("Failed to compute balance: {}", e))?;

            let balance_str = balance_row.map(|(b,)| b).unwrap_or_else(|| "0".to_string());
            let balance: rust_decimal::Decimal =
                balance_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let threshold: rust_decimal::Decimal =
                threshold_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);

            if balance < threshold {
                let reminder = Reminder::create(
                    Uuid::new_v4(),
                    ReminderType::PrepaidLowBalance,
                    Some(account_id),
                    format!("Low balance alert: {}", account_name),
                    format!(
                        "Account {} balance ({}) is below threshold ({})",
                        account_name, balance, threshold
                    ),
                    Utc::now() + chrono::Duration::hours(1),
                    None,
                    Priority::High,
                    SyncMetadata::new(Uuid::new_v4()),
                )
                .map_err(|e| format!("Failed to create reminder: {}", e))?;

                repo.create(&reminder)
                    .await
                    .map_err(|e| format!("Failed to persist reminder: {}", e))?;

                info!(
                    account_name = account_name,
                    balance = %balance,
                    threshold = %threshold,
                    "Created low-balance reminder for prepaid account"
                );
            }
        }

        info!(candidates = rows.len(), "Prepaid low-balance check complete");
        Ok(())
    }

    /// Run all prepaid alert checks.
    pub async fn run_all_checks(&self) -> Result<(), String> {
        if let Err(e) = self.check_expiry_alerts().await {
            error!(error = %e, "Prepaid expiry alert check failed");
        }
        if let Err(e) = self.check_low_balance_alerts().await {
            error!(error = %e, "Prepaid low-balance alert check failed");
        }
        Ok(())
    }
}
```

- [ ] **Step 2: Register schedulers module in infrastructure**

In `src-tauri/src/infrastructure/mod.rs`, add:
```rust
pub mod schedulers;
```

- [ ] **Step 3: Start the scheduler in main.rs**

In `src-tauri/src/main.rs`, add the import at the top (near other infrastructure imports):
```rust
use infrastructure::schedulers::PrepaidAlertScheduler;
```

Then inside the `.setup()` closure, after the transaction template scheduler (around line 532), add:

```rust
            // Start prepaid alert scheduler (expiry + low-balance checks)
            {
                let pa_pool = pool.clone();
                tokio::spawn(async move {
                    let scheduler = PrepaidAlertScheduler::new(pa_pool);
                    // Run immediately on startup
                    if let Err(e) = scheduler.run_all_checks().await {
                        error!(error = %e, "Initial prepaid alert check failed");
                    }
                    // Then check every 24 hours
                    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(86400));
                    loop {
                        interval.tick().await;
                        if let Err(e) = scheduler.run_all_checks().await {
                            error!(error = %e, "Scheduled prepaid alert check failed");
                        }
                    }
                });
            }
            info!("Prepaid alert scheduler started (checking every 24 hours)");
```

- [ ] **Step 4: Verify cargo check**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/infrastructure/schedulers/ src-tauri/src/infrastructure/mod.rs src-tauri/src/main.rs
git commit -m "feat(prepaid): add background scheduler for expiry and low-balance alerts

- PrepaidAlertScheduler checks expiring top-up records (7 days ahead)
- Checks prepaid accounts below their low_balance_threshold
- Creates Reminder entities with deduplication via NOT EXISTS
- Runs on startup + every 24 hours via tokio::spawn

Tasks 30-31 of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 31: Wire Low-Balance Notification on Transaction

**Files:**
- Modify: `src-tauri/src/application/services/prepaid_service.rs`

**Context:** The `check_low_balance_alert` method in `PrepaidService` already constructs a `Reminder` but does not persist it. Additionally, the background scheduler (Task 30) handles periodic checks. This task removes the `#[allow(dead_code)]` annotation and updates the comment to reflect that the background scheduler handles this now.

- [ ] **Step 1: Update check_low_balance_alert annotation**

In `src-tauri/src/application/services/prepaid_service.rs`, find `check_low_balance_alert` (around line 292). Remove the `#[allow(dead_code)]` and the `// TODO` comment. Update the doc comment:

Change:
```rust
    /// Checks if a prepaid account's balance has fallen below its low balance threshold.
    /// Returns a Reminder if the balance is below threshold, or None otherwise.
    ///
    /// Note: This method constructs but does NOT persist the reminder. The caller is
    /// responsible for persisting it via a ReminderRepository. Full reminder persistence
    /// integration will be added when the ReminderRepository is wired into PrepaidService.
    // TODO: will be used when low-balance notifications are implemented
    #[allow(dead_code)]
```

To:
```rust
    /// Checks if a prepaid account's balance has fallen below its low balance threshold.
    /// Returns a Reminder if the balance is below threshold, or None otherwise.
    ///
    /// Note: This method constructs but does NOT persist the reminder. Low-balance
    /// checking is handled by the PrepaidAlertScheduler which runs periodically.
```

- [ ] **Step 2: Verify cargo check**

Run: `cd src-tauri && cargo check`
Expected: Compiles without errors. The `check_low_balance_alert` may still show as dead code since it's not called directly; if so, add `#[allow(dead_code)]` back with an updated comment explaining it's available for ad-hoc use.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/services/prepaid_service.rs
git commit -m "refactor(prepaid): update check_low_balance_alert doc, remove TODO

- Remove dead_code suppression and TODO comment
- Update doc to clarify PrepaidAlertScheduler handles periodic checks
- Method remains available for ad-hoc invocations

Task 31 of Sprint 8.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final Verification

```bash
# Frontend
pnpm type-check
pnpm lint

# Backend
cd src-tauri && make check && make test

# Full app
pnpm tauri dev
```

### Acceptance Criteria Checklist

- [ ] Database indexes added on all high-frequency columns
- [ ] `find_all()` and `find_by_date_range()` use batch loading (3 queries instead of 2N+1)
- [ ] `get_transactions_by_account()` uses SQL JOIN + WHERE filter
- [ ] ReportsPage calls getBalanceSheet + getIncomeStatement (no listTransactions)
- [ ] HomePage calls getDashboardSummary for summary cards (no listTransactions for metrics)
- [ ] Prepaid expiry reminders created 7 days before expiry via background scheduler
- [ ] Low-balance reminders created when threshold is crossed via background scheduler
