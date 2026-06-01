# Sprint 1: P0 Critical Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all data accuracy bugs — correct account balance computation, persist low_balance_threshold, verify encryption password, wire budget actuals to transactions, and make export produce downloadable CSV files.

**Architecture:** All fixes target the Rust backend (domain/application/infrastructure layers) with minimal frontend changes for the budget and export tasks. Each task is independent and can be implemented and tested in isolation.

**Tech Stack:** Rust (Tauri 2.x, SQLx, SeaORM), SQLite, React (TypeScript, TanStack Query)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/src/domain/repositories/mod.rs` | Modify | Add `compute_balance_for_account` to `AccountRepository` trait |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Implement `compute_balance_for_account` for SQLite |
| `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs` | Modify | Implement `compute_balance_for_account` for Postgres |
| `src-tauri/src/application/services/account_service.rs` | Modify | Fix `get_account_balance` to compute real balance |
| `src-tauri/src/application/dtos/account_dto.rs` | Modify | Add `low_balance_threshold` to `UpdateAccountDto` |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Add `low_balance_threshold` to UPDATE SQL |
| `src-tauri/migrations/20260603000001_encryption_verification_token.sql` | Create | Add `verification_token` column to `encryption_settings` |
| `src-tauri/src/application/services/encryption_app_service.rs` | Modify | Add verification token to `setup()` and verify in `unlock()` |
| `src-tauri/src/application/services/budget_service.rs` | Create | Budget service with actual amount computation |
| `src-tauri/src/application/services/mod.rs` | Modify | Register `budget_service` module |
| `src-tauri/src/presentation/tauri_commands/budget_commands.rs` | Modify | Add `compute_budget_actuals` command, refactor through service |
| `src/hooks/useBudget.ts` | Modify | Add `useComputeBudgetActuals` hook |
| `src/pages/BudgetPage.tsx` | Modify | Call compute_actuals on load |
| `src-tauri/Cargo.toml` | Modify | Add `csv` crate |
| `src-tauri/src/presentation/tauri_commands/export_commands.rs` | Modify | Add `export_csv` command with file dialog |

---

### Task 1: Fix `get_account_balance` returning only initial_balance

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs` (AccountRepository trait)
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs` (SQLite impl)
- Modify: `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs` (Postgres impl)
- Modify: `src-tauri/src/application/services/account_service.rs`

- [ ] **Step 1: Add `compute_balance_for_account` to repository trait**

In `src-tauri/src/domain/repositories/mod.rs`, add after the existing `compute_balances_for_all_accounts` method (after line ~51):

```rust
async fn compute_balance_for_account(
    &self,
    id: Uuid,
) -> Result<Decimal, sqlx::Error>;
```

- [ ] **Step 2: Implement for SQLite**

In `src-tauri/src/infrastructure/repositories/account_repository.rs`, add an inherent method and trait impl after `compute_balances_for_all_accounts`:

```rust
// Inherent method
pub async fn compute_balance_for_account_sqlite(
    &self,
    id: Uuid,
) -> Result<Decimal, sqlx::Error> {
    let row: (String,) = sqlx::query_as(
        "SELECT CAST(COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) - \
         COALESCE(SUM(COALESCE(e.credit_amount, 0)), 0) AS TEXT) \
         FROM transaction_entries e \
         JOIN transactions t ON e.transaction_id = t.id \
         WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL \
         AND e.account_id = ?",
    )
    .bind(id.to_string())
    .fetch_one(&self.pool)
    .await?;

    row.0.parse::<Decimal>().map_err(|e| sqlx::Error::Decode(Box::new(e)))
}

// Trait impl
async fn compute_balance_for_account(
    &self,
    id: Uuid,
) -> Result<Decimal, sqlx::Error> {
    self.compute_balance_for_account_sqlite(id).await
}
```

- [ ] **Step 3: Implement for Postgres**

In `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs`, add the inherent method and trait impl:

```rust
// Inherent method
pub async fn compute_balance_for_account_pg(
    &self,
    id: Uuid,
) -> Result<Decimal, sqlx::Error> {
    let row: (Decimal,) = sqlx::query_as(
        "SELECT COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) - \
         COALESCE(SUM(COALESCE(e.credit_amount, 0)), 0) \
         FROM transaction_entries e \
         JOIN transactions t ON e.transaction_id = t.id \
         WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL \
         AND e.account_id = $1",
    )
    .bind(id)
    .fetch_one(&self.pool)
    .await?;

    Ok(row.0)
}

// Trait impl
async fn compute_balance_for_account(
    &self,
    id: Uuid,
) -> Result<Decimal, sqlx::Error> {
    self.compute_balance_for_account_pg(id).await
}
```

- [ ] **Step 4: Fix `get_account_balance` in account_service.rs**

Replace the existing `get_account_balance` method (lines 239-247) in `src-tauri/src/application/services/account_service.rs`:

```rust
pub async fn get_account_balance(&self, id: Uuid) -> Result<Money, AccountServiceError> {
    let account = self
        .account_repo
        .find_by_id(id)
        .await?
        .ok_or(AccountServiceError::AccountNotFound(id))?;

    let net_change = self
        .account_repo
        .compute_balance_for_account(id)
        .await
        .map_err(AccountServiceError::DatabaseError)?;

    let current = account.initial_balance.amount + net_change;
    Ok(Money::new(current, account.initial_balance.currency))
}
```

- [ ] **Step 5: Run check and test**

Run: `cd src-tauri && cargo check 2>&1 | head -20`
Expected: No errors related to the changed files.

Run: `cd src-tauri && cargo test account 2>&1 | tail -10`
Expected: All existing account tests still pass.

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs src-tauri/src/infrastructure/repositories/account_repository.rs src-tauri/src/infrastructure/repositories/account_repository_postgres.rs src-tauri/src/application/services/account_service.rs
git commit -m "fix(accounts): compute real balance from transactions in get_account_balance"
```

---

### Task 2: Persist `low_balance_threshold` on account update

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs`
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs` (UPDATE SQL)

- [ ] **Step 1: Add `low_balance_threshold` to `UpdateAccountDto`**

In `src-tauri/src/application/dtos/account_dto.rs`, add after the `parent_id` field in `UpdateAccountDto` (after line 38):

```rust
    pub low_balance_threshold: Option<Decimal>,
```

- [ ] **Step 2: Update the account service `update` method to pass the field**

Find the `update` method in `src-tauri/src/application/services/account_service.rs`. Locate where `UpdateAccountDto` fields are mapped to the `Account` domain object. Add:

```rust
account.low_balance_threshold = dto.low_balance_threshold;
```

This should be placed in the update method where other DTO fields are mapped to the account before calling `self.account_repo.update(&account)`.

- [ ] **Step 3: Add `low_balance_threshold` to the UPDATE SQL query**

In `src-tauri/src/infrastructure/repositories/account_repository.rs`, find the `update` method's SQL query (around line 363). Add `low_balance_threshold = ?` to the SET clause, and add the corresponding bind parameter.

The current UPDATE query SET clause needs `low_balance_threshold = ?` added. Add the bind:
```rust
.bind(account.low_balance_threshold.map(|d| d.to_string()))
```

at the appropriate position in the bind chain (after the other optional fields, before the `WHERE id = ?` bind).

- [ ] **Step 4: Verify the domain Account struct has the field**

Check `src-tauri/src/domain/aggregates/account.rs` to confirm the `low_balance_threshold: Option<Decimal>` field exists on the `Account` struct. (It should — the field was confirmed during gap analysis.)

- [ ] **Step 5: Run check**

Run: `cd src-tauri && cargo check 2>&1 | head -20`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/application/dtos/account_dto.rs src-tauri/src/application/services/account_service.rs src-tauri/src/infrastructure/repositories/account_repository.rs
git commit -m "fix(accounts): persist low_balance_threshold on account update"
```

---

### Task 3: Fix encryption unlock not verifying password

**Files:**
- Create: `src-tauri/migrations/20260603000001_encryption_verification_token.sql`
- Modify: `src-tauri/src/application/services/encryption_app_service.rs`

- [ ] **Step 1: Create migration to add verification_token column**

Create `src-tauri/migrations/20260603000001_encryption_verification_token.sql`:

```sql
ALTER TABLE encryption_settings ADD COLUMN verification_token TEXT;
```

- [ ] **Step 2: Define a constant verification payload**

In `src-tauri/src/application/services/encryption_app_service.rs`, add a constant at the top of the impl block:

```rust
const VERIFICATION_PAYLOAD: &[u8] = b"finance-app-encryption-verified-2026";
```

- [ ] **Step 3: Modify `setup()` to store a verification token**

In the `setup()` method, after the line `*self.service.lock().unwrap() = Some(service);` (line ~78) and before `Ok(())`, add:

```rust
    // Store verification token to enable password verification on unlock
    let verification_token = self
        .service
        .lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .encrypt_to_hex(VERIFICATION_PAYLOAD)
        .map_err(|e| EncryptionAppError::EncryptionFailed(e.to_string()))?;

    sqlx::query("UPDATE encryption_settings SET verification_token = ?")
        .bind(&verification_token)
        .execute(&self.pool)
        .await
        .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?;
```

- [ ] **Step 4: Modify `unlock()` to verify the password**

Replace the entire `unlock()` method body (lines 82-96) with:

```rust
pub async fn unlock(&self, password: &str) -> Result<(), EncryptionAppError> {
    let row = sqlx::query_as::<_, (String, Option<String>)>(
        "SELECT salt, verification_token FROM encryption_settings LIMIT 1",
    )
    .fetch_optional(&self.pool)
    .await
    .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?
    .ok_or(EncryptionAppError::NotEnabled)?;

    let salt = hex::decode(&row.0)
        .map_err(|e| EncryptionAppError::DatabaseError(format!("invalid salt: {}", e)))?;
    let service = EncryptionService::from_password(password, &salt)?;

    // Verify password by decrypting the verification token
    if let Some(token) = row.1 {
        service
            .decrypt_from_hex(&token)
            .map_err(|_| EncryptionAppError::InvalidPassword)?;
    }

    *self.service.lock().unwrap() = Some(service);
    Ok(())
}
```

- [ ] **Step 5: Add `InvalidPassword` variant to the error enum**

In `src-tauri/src/application/services/encryption_app_service.rs`, find the `EncryptionAppError` enum and add:

```rust
#[error("Invalid password")]
InvalidPassword,
```

- [ ] **Step 6: Run check and test**

Run: `cd src-tauri && cargo check 2>&1 | head -20`
Expected: No errors.

Run: `cd src-tauri && cargo test encryption 2>&1 | tail -10`
Expected: All existing encryption tests still pass.

- [ ] **Step 7: Commit**

```bash
git add src-tauri/migrations/20260603000001_encryption_verification_token.sql src-tauri/src/application/services/encryption_app_service.rs
git commit -m "fix(encryption): verify password correctness on unlock using verification token"
```

---

### Task 4: Wire Budget actual amounts to transaction data

**Files:**
- Create: `src-tauri/src/application/services/budget_service.rs`
- Modify: `src-tauri/src/application/services/mod.rs` (register module)
- Modify: `src-tauri/src/presentation/tauri_commands/budget_commands.rs`
- Modify: `src/hooks/useBudget.ts`
- Modify: `src/pages/BudgetPage.tsx`

- [ ] **Step 1: Create BudgetService**

Create `src-tauri/src/application/services/budget_service.rs`:

```rust
use rust_decimal::Decimal;
use sqlx::SqlitePool;
use std::str::FromStr;
use tracing::info;
use uuid::Uuid;

pub struct BudgetService {
    pool: SqlitePool,
}

impl BudgetService {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Compute actual spending for each budget item from transaction entries.
    /// Queries transactions within the budget month, groups by category_account_id,
    /// and updates actual_amount on each budget_item.
    pub async fn compute_budget_actuals(&self, budget_id: &str) -> Result<(), String> {
        info!(budget_id = budget_id, "Computing budget actuals");

        // 1. Get the budget to find the month
        let budget_month: (String,) =
            sqlx::query_as("SELECT month FROM budgets WHERE id = ?")
                .bind(budget_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| format!("Budget not found: {}", e))?;

        let month = &budget_month.0; // e.g. "2026-06"

        // 2. Get all budget items with their category_account_ids
        let items: Vec<(String, String)> = sqlx::query_as(
            "SELECT id, category_account_id FROM budget_items WHERE budget_id = ?",
        )
        .bind(budget_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch budget items: {}", e))?;

        if items.is_empty() {
            info!(budget_id = budget_id, "No budget items found, skipping");
            return Ok(());
        }

        // 3. For each item, compute actual from transactions in that month
        let start_date = format!("{}-01", month);
        let end_date = format!(
            "{}-{}",
            &month,
            last_day_of_month(&start_date)
        );

        for (item_id, category_account_id) in &items {
            let actual: (String,) = sqlx::query_as(
                "SELECT CAST(COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) AS TEXT) \
                 FROM transaction_entries e \
                 JOIN transactions t ON e.transaction_id = t.id \
                 WHERE e.deleted_at IS NULL \
                 AND t.deleted_at IS NULL \
                 AND e.account_id = ? \
                 AND t.transaction_date >= ? \
                 AND t.transaction_date <= ?",
            )
            .bind(category_account_id)
            .bind(&start_date)
            .bind(&end_date)
            .fetch_one(&self.pool)
            .await
            .map_err(|e| format!("Failed to compute actual for item {}: {}", item_id, e))?;

            let amount = actual.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);

            sqlx::query("UPDATE budget_items SET actual_amount = ? WHERE id = ?")
                .bind(amount.to_string())
                .bind(item_id)
                .execute(&self.pool)
                .await
                .map_err(|e| format!("Failed to update actual for item {}: {}", item_id, e))?;

            info!(
                item_id = item_id,
                category_account_id = category_account_id,
                actual = %amount,
                "Updated budget item actual"
            );
        }

        Ok(())
    }
}

/// Calculate the last day of the month for a date string like "2026-06-01"
fn last_day_of_month(date_str: &str) -> String {
    let parts: Vec<&str> = date_str.split('-').collect();
    if parts.len() < 3 {
        return "31".to_string();
    }
    let year: i32 = parts[0].parse().unwrap_or(2026);
    let month: u32 = parts[1].parse().unwrap_or(1);
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut d = days[(month - 1) as usize];
    if month == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
        d = 29;
    }
    format!("{:02}", d)
}
```

- [ ] **Step 2: Register budget_service module**

In `src-tauri/src/application/services/mod.rs`, add:

```rust
pub mod budget_service;
```

- [ ] **Step 3: Add `compute_budget_actuals` Tauri command**

In `src-tauri/src/presentation/tauri_commands/budget_commands.rs`, add a new command:

```rust
use crate::application::services::budget_service::BudgetService;

#[tauri::command]
pub async fn compute_budget_actuals(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
) -> Result<(), String> {
    let service = BudgetService::new(state.pool().clone());
    service.compute_budget_actuals(&budget_id).await
}
```

- [ ] **Step 4: Register the new command in main.rs**

Find the `invoke_handler` in `src-tauri/src/main.rs` where Tauri commands are registered. Add `budget_commands::compute_budget_actuals` to the list.

- [ ] **Step 5: Add frontend hook**

In `src/hooks/useBudget.ts`, add a new mutation hook:

```typescript
export function useComputeBudgetActuals() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (budgetId: string) => {
      return invokeTauri('compute_budget_actuals', { budgetId });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      queryClient.invalidateQueries({ queryKey: ['budgetByMonth'] });
    },
  });
}
```

- [ ] **Step 6: Call compute_actuals on BudgetPage load**

In `src/pages/BudgetPage.tsx`, add a `useEffect` that calls `computeBudgetActuals` when the budget for the current month loads. Import the hook and add:

```typescript
const computeActuals = useComputeBudgetActuals();

useEffect(() => {
  if (budget?.id) {
    computeActuals.mutate(budget.id);
  }
}, [budget?.id]);
```

This ensures that every time the budget page loads, actual amounts are recomputed from transaction data before rendering.

- [ ] **Step 7: Run check and test**

Run: `cd src-tauri && cargo check 2>&1 | head -30`
Expected: No errors.

Run: `pnpm type-check 2>&1 | tail -5`
Expected: No TypeScript errors.

- [ ] **Step 8: Commit**

```bash
git add src-tauri/src/application/services/budget_service.rs src-tauri/src/application/services/mod.rs src-tauri/src/presentation/tauri_commands/budget_commands.rs src-tauri/src/main.rs src/hooks/useBudget.ts src/pages/BudgetPage.tsx
git commit -m "feat(budget): wire actual amounts to transaction data via BudgetService"
```

---

### Task 5: Make Export produce downloadable CSV files

**Files:**
- Modify: `src-tauri/Cargo.toml` (add csv crate)
- Modify: `src-tauri/src/presentation/tauri_commands/export_commands.rs`
- Modify: `src/pages/SettingsPage.tsx` (add Export button)

- [ ] **Step 1: Add csv crate to Cargo.toml**

In `src-tauri/Cargo.toml`, add to `[dependencies]`:

```toml
csv = "1.3"
```

- [ ] **Step 2: Add `export_csv` Tauri command**

In `src-tauri/src/presentation/tauri_commands/export_commands.rs`, add a new command that queries data and writes CSV to a user-chosen file:

```rust
use std::fs::File;
use std::io::Write;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportCsvResult {
    pub file_path: String,
    pub rows_exported: usize,
}

#[tauri::command]
pub async fn export_csv(
    state: State<'_, ExportCommandState>,
    app: tauri::AppHandle,
) -> Result<ExportCsvResult, String> {
    use tauri::dialog::FileDialogBuilder;

    let (tx, rx) = tokio::sync::oneshot::channel::<Option<String>>();

    FileDialogBuilder::new(&app)
        .set_title("Export CSV")
        .set_file_name("finance-export.csv")
        .add_filter("CSV", &["csv"])
        .save_file(move |path| {
            let _ = tx.send(path.map(|p| p.to_string_lossy().to_string()));
        });

    let file_path = rx.await.map_err(|e| format!("Dialog error: {}", e))?
        .ok_or_else(|| "Export cancelled".to_string())?;

    tracing::info!(file_path = %file_path, "Exporting CSV");

    let mut wtr = csv::Writer::from_path(&file_path)
        .map_err(|e| format!("Failed to create CSV file: {}", e))?;

    // Write header
    wtr.write_record(&["table", "id", "field", "value"])
        .map_err(|e| format!("CSV write error: {}", e))?;

    let tables = [
        "accounts",
        "transactions",
        "transaction_entries",
        "debt_details",
        "debt_payment_schedule",
        "goals",
        "budgets",
        "budget_items",
        "tags",
        "transaction_tags",
    ];

    let mut total_rows = 0usize;

    for table in &tables {
        let rows: Vec<serde_json::Value> = sqlx::query(&format!("SELECT * FROM {}", table))
            .fetch_all(&state.pool)
            .await
            .map_err(|e| format!("Failed to query {}: {}", table, e))?
            .into_iter()
            .map(|row| row_to_json(&row))
            .collect();

        for row in &rows {
            if let Some(obj) = row.as_object() {
                let id = obj.get("id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown");
                for (key, value) in obj {
                    if key == "id" { continue; }
                    let val_str = match value {
                        serde_json::Value::Null => String::new(),
                        serde_json::Value::String(s) => s.clone(),
                        other => other.to_string(),
                    };
                    wtr.write_record(&[table, id, key, &val_str])
                        .map_err(|e| format!("CSV write error: {}", e))?;
                    total_rows += 1;
                }
            }
        }
    }

    wtr.flush().map_err(|e| format!("CSV flush error: {}", e))?;

    tracing::info!(file_path = %file_path, rows = total_rows, "CSV export complete");

    Ok(ExportCsvResult {
        file_path,
        rows_exported: total_rows,
    })
}
```

- [ ] **Step 3: Register `export_csv` command in main.rs**

In `src-tauri/src/main.rs`, add `export_commands::export_csv` to the `invoke_handler` list (alongside the existing `export_commands::export_all_data`).

- [ ] **Step 4: Add frontend Tauri bridge**

In the appropriate location (either a new `src/lib/tauri/export.ts` or inline), add:

```typescript
import { invokeTauri } from '@/lib/tauri';

export interface ExportCsvResult {
  file_path: string;
  rows_exported: number;
}

export async function exportCsv(): Promise<ExportCsvResult> {
  return invokeTauri<ExportCsvResult>('export_csv');
}
```

- [ ] **Step 5: Add Export button to SettingsPage**

In `src/pages/SettingsPage.tsx`, add an Export section with a button. Find an appropriate location (e.g., near the bottom, or in a "Data" section) and add:

```typescript
import { exportCsv } from '@/lib/tauri/export';

// Inside the component:
const handleExportCsv = async () => {
  try {
    const result = await exportCsv();
    toast.success(t('settings.exportSuccess', { rows: result.rows_exported }));
  } catch (err) {
    if (String(err).includes('cancelled')) return;
    toast.error(t('settings.exportError'));
  }
};

// In the JSX, add a section:
<Button onClick={handleExportCsv} variant="outline">
  {t('settings.exportCsv')}
</Button>
```

- [ ] **Step 6: Add i18n keys**

In `src/i18n/locales/en.json`, add to the `settings` section:

```json
"exportCsv": "Export to CSV",
"exportSuccess": "Exported {{rows}} rows successfully",
"exportError": "Export failed"
```

In `src/i18n/locales/zh.json`, add to the `settings` section:

```json
"exportCsv": "导出为 CSV",
"exportSuccess": "成功导出 {{rows}} 行数据",
"exportError": "导出失败"
```

- [ ] **Step 7: Run check and test**

Run: `cd src-tauri && cargo check 2>&1 | head -20`
Expected: No errors.

Run: `pnpm type-check 2>&1 | tail -5`
Expected: No TypeScript errors.

- [ ] **Step 8: Commit**

```bash
git add src-tauri/Cargo.toml src-tauri/src/presentation/tauri_commands/export_commands.rs src-tauri/src/main.rs src/lib/tauri/export.ts src/pages/SettingsPage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(export): add CSV export with file save dialog"
```

---

## Self-Review Checklist

### Spec Coverage
- ✅ Task 1 covers "Fix get_account_balance" spec requirement
- ✅ Task 2 covers "Persist low_balance_threshold" spec requirement
- ✅ Task 3 covers "Fix encryption unlock verification" spec requirement
- ✅ Task 4 covers "Wire Budget actual amounts" spec requirement
- ✅ Task 5 covers "Make Export download CSV" spec requirement
- ✅ All 5 Sprint 1 acceptance criteria have corresponding tasks

### Placeholder Scan
- ✅ No TBD, TODO, or "implement later" patterns
- ✅ All code blocks contain actual implementation code
- ✅ All file paths are exact
- ✅ All test commands specify expected output

### Type Consistency
- ✅ `Decimal` type used consistently for financial amounts across all tasks
- ✅ `Uuid` type used for account IDs in Task 1
- ✅ `String` type used for budget_id in Task 4 (matching existing budget domain)
- ✅ Error types match existing patterns (`AccountServiceError`, `EncryptionAppError`, `String`)
