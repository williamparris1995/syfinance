# Unified Account Model — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge categories into accounts with ownership dimension, resolving the Uuid::nil() FK violation and unifying the data model.

**Architecture:** Accounts absorb categories via ownership flag (own/external), icon, color, and chart_code fields. Transaction entries always reference real accounts — no more sentinel UUIDs. Statistics filter by ownership.

**Tech Stack:** Rust/Tauri v2 backend (sqlx, SQLite), React/TypeScript frontend (Zod, react-hook-form, @tanstack/react-query)

---

### Task 1: Write the schema migration

**Files:**
- Create: `src-tauri/migrations/20260522000001_unify_accounts_and_categories.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- Migration: Unify accounts and categories
-- Drops categories table, merges data into accounts,
-- removes category_id from transaction_entries

PRAGMA foreign_keys = OFF;

-- ============================================================================
-- STEP 1: Add new columns to accounts
-- ============================================================================

ALTER TABLE accounts ADD COLUMN ownership VARCHAR(10) NOT NULL DEFAULT 'own';
ALTER TABLE accounts ADD COLUMN icon VARCHAR(10) NOT NULL DEFAULT '📁';
ALTER TABLE accounts ADD COLUMN color VARCHAR(7) NOT NULL DEFAULT '#6B7280';
ALTER TABLE accounts ADD COLUMN chart_code VARCHAR(10);
ALTER TABLE accounts ADD COLUMN parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 2: Migrate categories → accounts (ownership = 'external')
-- ============================================================================

INSERT INTO accounts (id, name, account_type, currency_code, balance,
                      ownership, icon, color, chart_code, parent_id,
                      deleted_at, updated_at, device_id, synced_at)
SELECT
    id,
    name,
    CASE category_type WHEN 'income' THEN 'income' WHEN 'expense' THEN 'expense' END,
    'CNY',
    0.00,
    'external',
    icon,
    color,
    chart_code,
    parent_id,
    deleted_at,
    updated_at,
    device_id,
    synced_at
FROM categories;

-- ============================================================================
-- STEP 3: Drop categories table
-- ============================================================================

DROP TABLE categories;

-- ============================================================================
-- STEP 4: Recreate transaction_entries without category_id
-- ============================================================================

CREATE TABLE transaction_entries_backup AS SELECT * FROM transaction_entries;

DROP TABLE transaction_entries;

CREATE TABLE transaction_entries (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    chart_of_account_code VARCHAR(10) NOT NULL,
    debit_amount DECIMAL(20,2),
    credit_amount DECIMAL(20,2),
    note TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (
        (debit_amount IS NULL AND credit_amount IS NOT NULL AND credit_amount >= 0) OR
        (debit_amount IS NOT NULL AND debit_amount >= 0 AND credit_amount IS NULL)
    ),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY (chart_of_account_code) REFERENCES chart_of_accounts(code) ON DELETE RESTRICT
);

INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code,
                                  debit_amount, credit_amount, note,
                                  deleted_at, updated_at, device_id, synced_at)
SELECT id, transaction_id, account_id, chart_of_account_code,
       debit_amount, credit_amount, note,
       deleted_at, updated_at, device_id, synced_at
FROM transaction_entries_backup;

DROP TABLE transaction_entries_backup;

-- Recreate indexes
CREATE INDEX idx_transaction_entries_transaction ON transaction_entries(transaction_id);
CREATE INDEX idx_transaction_entries_account ON transaction_entries(account_id);
CREATE INDEX idx_transaction_entries_chart_code ON transaction_entries(chart_of_account_code);
CREATE INDEX idx_transaction_entries_deleted ON transaction_entries(deleted_at);

-- Recreate double-entry triggers
CREATE TRIGGER enforce_double_entry_insert
BEFORE INSERT ON transaction_entries
BEGIN
    SELECT RAISE(ABORT, 'Double-entry violation: debit sum must equal credit sum')
    WHERE (
        SELECT
            COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND deleted_at IS NULL
    ) + COALESCE(NEW.debit_amount, 0) - COALESCE(NEW.credit_amount, 0) != 0
    AND (
        SELECT COUNT(*)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND deleted_at IS NULL
    ) >= 1;
END;

CREATE TRIGGER enforce_double_entry_update
BEFORE UPDATE ON transaction_entries
BEGIN
    SELECT RAISE(ABORT, 'Double-entry violation: debit sum must equal credit sum')
    WHERE (
        SELECT
            COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND id != NEW.id
          AND deleted_at IS NULL
    ) + COALESCE(NEW.debit_amount, 0) - COALESCE(NEW.credit_amount, 0) != 0
    AND NEW.deleted_at IS NULL
    AND (
        SELECT COUNT(*)
        FROM transaction_entries
        WHERE transaction_id = NEW.transaction_id
          AND id != NEW.id
          AND deleted_at IS NULL
    ) >= 1;
END;

-- Update accounts CHECK constraint for new types
-- SQLite doesn't support ALTER CHECK, so recreate table
CREATE TABLE accounts_backup AS SELECT * FROM accounts;

DROP TABLE accounts;

CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment', 'loan', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'external')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

INSERT INTO accounts SELECT * FROM accounts_backup;

DROP TABLE accounts_backup;

-- Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);

PRAGMA foreign_keys = ON;
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260522000001_unify_accounts_and_categories.sql
git commit -m "feat: add migration to unify accounts and categories"
```

---

### Task 2: Add Ownership enum and extend AccountType

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs`

- [ ] **Step 1: Add Ownership enum and extend AccountType**

Replace the `AccountType` enum (lines 7-15) with:

```rust
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    Loan,
    Other,
    Income,
    Expense,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum Ownership {
    #[serde(rename = "own")]
    Own,
    #[serde(rename = "external")]
    External,
}
```

Update `Display` impl for `AccountType`, add new variants:

```rust
impl fmt::Display for AccountType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cash => write!(f, "cash"),
            Self::Bank => write!(f, "bank"),
            Self::CreditCard => write!(f, "credit_card"),
            Self::Investment => write!(f, "investment"),
            Self::Loan => write!(f, "loan"),
            Self::Other => write!(f, "other"),
            Self::Income => write!(f, "income"),
            Self::Expense => write!(f, "expense"),
        }
    }
}
```

- [ ] **Step 2: Add new fields to Account struct**

Replace the Account struct (starting at line 88) with:

```rust
#[derive(Debug, Clone)]
pub struct Account {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub ownership: Ownership,
    pub currency_code: String,
    pub balance: Money,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Money>,
    pub billing_day: Option<u8>,
    pub payment_due_day: Option<u8>,
    pub interest_rate: Option<Decimal>,
    pub sync_metadata: SyncMetadata,
    pub(crate) pending_events: Vec<AccountEvent>,
}
```

- [ ] **Step 3: Update Account::new() signature**

Replace `Account::new()` (lines 105-144) with:

```rust
impl Account {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: Uuid,
        name: impl Into<String>,
        account_type: AccountType,
        ownership: Ownership,
        currency: &Currency,
        balance: Money,
        icon: impl Into<String>,
        color: impl Into<String>,
        chart_code: Option<String>,
        parent_id: Option<Uuid>,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, AccountError> {
        let name = name.into().trim().to_string();
        let icon = icon.into().trim().to_string();
        let color = color.into().trim().to_string();

        if name.is_empty() {
            return Err(AccountError::EmptyName);
        }

        validate_balance(&account_type, &currency.code, &balance)?;

        let mut account = Self {
            id,
            name,
            account_type: account_type.clone(),
            ownership,
            currency_code: currency.code.clone(),
            balance,
            icon,
            color,
            chart_code,
            parent_id,
            account_number: None,
            institution: None,
            credit_limit: None,
            billing_day: None,
            payment_due_day: None,
            interest_rate: None,
            sync_metadata,
            pending_events: Vec::new(),
        };

        account.pending_events.push(AccountEvent::AccountCreated {
            account_id: account.id,
            account_type,
        });

        Ok(account)
    }
```

- [ ] **Step 4: Update Account tests to pass new params**

For each test's `Account::new()` call, add the new params:
```rust
Account::new(
    Uuid::new_v4(),
    "Wallet",
    AccountType::Cash,
    Ownership::Own,        // new
    &currency("CNY"),
    money(100, "CNY"),
    "💰",                   // new: icon
    "#10B981",             // new: color
    None,                   // new: chart_code
    None,                   // new: parent_id
    metadata(),
)
```

Apply to all test cases in the `mod tests` block. For credit card tests, use appropriate icon/color. For loan tests, use appropriate icon/color. For external-type tests, use `Ownership::External`.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/aggregates/account.rs
git commit -m "feat: add Ownership enum and extend AccountType/Account for unified model"
```

---

### Task 3: Remove category_id from TransactionEntry

**Files:**
- Modify: `src-tauri/src/domain/value_objects/transaction_entry.rs`

- [ ] **Step 1: Remove category_id field**

Remove `pub category_id: Option<String>` from the struct (line 31). Remove `category_id: Option<String>` param from `new()` (line 41). Remove `category_id,` from the initializer (line 50).

Updated struct:
```rust
pub struct TransactionEntry {
    pub id: Uuid,
    pub account_id: Uuid,
    pub chart_of_account_code: String,
    pub debit_amount: Option<Money>,
    pub credit_amount: Option<Money>,
    pub note: String,
}
```

Updated constructor:
```rust
pub fn new(
    account_id: Uuid,
    chart_of_account_code: impl Into<String>,
    debit_amount: Option<Money>,
    credit_amount: Option<Money>,
    note: impl Into<String>,
) -> Result<Self, TransactionEntryError> {
    let entry = Self {
        id: Uuid::new_v4(),
        account_id,
        chart_of_account_code: chart_of_account_code.into().trim().to_string(),
        debit_amount,
        credit_amount,
        note: note.into().trim().to_string(),
    };
    entry.validate()?;
    Ok(entry)
}
```

- [ ] **Step 2: Update all test calls to remove category_id param**

In the test module (line 97 onward), all `TransactionEntry::new()` calls pass `None` or `Some(...)` for category_id. Remove that argument from each call:
```rust
// Before:
TransactionEntry::new(Uuid::new_v4(), "1002", None, None, None, "invalid");
// After:
TransactionEntry::new(Uuid::new_v4(), "1002", None, None, "invalid");
```

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/domain/value_objects/transaction_entry.rs
git commit -m "feat: remove category_id from TransactionEntry"
```

---

### Task 4: Remove Category aggregate and repository trait

**Files:**
- Delete: `src-tauri/src/domain/aggregates/category.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs`

- [ ] **Step 1: Remove category from mod.rs**

In `src-tauri/src/domain/aggregates/mod.rs`, remove:
```rust
pub mod category;              // line 2
pub use category::{Category, CategoryError, CategoryType};  // line 9
```

- [ ] **Step 2: Remove CategoryRepository trait**

In `src-tauri/src/domain/repositories/mod.rs`, remove `Category, CategoryType,` from imports (line 5) and remove the `CategoryRepository` trait definition (lines 89-103).

- [ ] **Step 3: Delete category.rs**

```bash
rm src-tauri/src/domain/aggregates/category.rs
```

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/domain/
git commit -m "feat: remove Category aggregate and CategoryRepository trait"
```

---

### Task 5: Update DTOs — SimpleIncomeDto, SimpleExpenseDto

**Files:**
- Modify: `src-tauri/src/application/dtos/simple_transaction_dto.rs`
- Modify: `src-tauri/src/application/dtos/transaction_dto.rs`

- [ ] **Step 1: Rewrite simple_transaction_dto.rs**

Replace the entire file content:

```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleIncomeDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub debit_account_id: Uuid,
    pub credit_account_id: Uuid,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleExpenseDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub debit_account_id: Uuid,
    pub credit_account_id: Uuid,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleTransferDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,
    pub description: String,
}
```

- [ ] **Step 2: Update transaction_dto.rs — remove category_id**

In `src-tauri/src/application/dtos/transaction_dto.rs`:

Remove `pub category_id: Option<String>` from `CreateTransactionEntryDto` (line 10).
Remove `pub category_id: String` from `SimpleIncomeDto` (line 31) — NOTE: this DTO may be removed if only simple_transaction_dto.rs is used. Check if it's still referenced.
Remove `pub category_id: String` from `SimpleExpenseDto` (line 42).
Remove `pub category_id: Option<String>` from `TransactionEntryDto` (line 62).

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/dtos/
git commit -m "feat: update transaction DTOs — remove category_id, add dual account params"
```

---

### Task 6: Update Account DTOs

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs`

- [ ] **Step 1: Add new fields to CreateAccountDto**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAccountDto {
    pub name: String,
    pub account_type: AccountType,
    pub ownership: Ownership,
    pub currency_code: String,
    pub initial_balance: Decimal,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    // existing optional fields unchanged:
    // account_number, institution, credit_limit, billing_day, payment_due_day, interest_rate
}
```

- [ ] **Step 2: Add new fields to AccountDto**

Add to the struct (after `account_type`):
```rust
pub ownership: Ownership,
pub icon: String,
pub color: String,
pub chart_code: Option<String>,
pub parent_id: Option<Uuid>,
```

Update the `From<Account> for AccountDto` impl to map the new fields:
```rust
ownership: account.ownership,
icon: account.icon,
color: account.color,
chart_code: account.chart_code,
parent_id: account.parent_id,
```

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/dtos/account_dto.rs
git commit -m "feat: add ownership/icon/color/chart_code/parent_id to account DTOs"
```

---

### Task 7: Remove Category DTOs and service mod references

**Files:**
- Delete: `src-tauri/src/application/dtos/category_dto.rs`
- Modify: `src-tauri/src/application/dtos/mod.rs`
- Modify: `src-tauri/src/application/services/mod.rs`

- [ ] **Step 1: Remove category_dto module declaration**

In `mod.rs`, remove:
```rust
pub mod category_dto;
pub use category_dto::{CategoryDto, CreateCategoryDto, UpdateCategoryDto};
```

- [ ] **Step 2: Remove category_service module declaration**

In `src-tauri/src/application/services/mod.rs`, remove:
```rust
pub mod category_service;
pub use category_service::{CategoryService, CategoryServiceError};
```

- [ ] **Step 3: Delete files**

```bash
rm src-tauri/src/application/dtos/category_dto.rs
rm src-tauri/src/application/services/category_service.rs
```

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/
git commit -m "feat: remove category DTOs and service"
```

---

### Task 8: Remove CategoryRepository implementation

**Files:**
- Delete: `src-tauri/src/infrastructure/repositories/category_repository.rs`
- Modify: `src-tauri/src/infrastructure/repositories/mod.rs`

- [ ] **Step 1: Remove category_repository from mod.rs**

In `src-tauri/src/infrastructure/repositories/mod.rs`, remove the module declaration and re-export for `SqliteCategoryRepository`.

- [ ] **Step 2: Delete the file**

```bash
rm src-tauri/src/infrastructure/repositories/category_repository.rs
```

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/
git commit -m "feat: remove SqliteCategoryRepository"
```

---

### Task 9: Refactor TransactionService — remove category dependency

**Files:**
- Modify: `src-tauri/src/application/services/transaction_service.rs`

- [ ] **Step 1: Remove category_repo from struct and constructor**

Remove `category_repo: Arc<SqliteCategoryRepository>` from `TransactionService` struct. Remove `category_repo` from `new()` params. Remove `SqliteCategoryRepository` import. Remove `CategoryRepository` from domain imports.

- [ ] **Step 2: Remove CategoryNotFound from error enum**

Remove `CategoryNotFound(String)` variant. Remove its Display impl arm.

- [ ] **Step 3: Rewrite create_income**

Replace lines 225-294 with:

```rust
pub async fn create_income(
    &self,
    dto: SimpleIncomeDto,
) -> Result<Uuid, TransactionServiceError> {
    let debit_account = self
        .account_repo
        .find_by_id(dto.debit_account_id)
        .await?
        .ok_or(TransactionServiceError::AccountNotFound(dto.debit_account_id))?;

    let credit_account = self
        .account_repo
        .find_by_id(dto.credit_account_id)
        .await?
        .ok_or(TransactionServiceError::AccountNotFound(dto.credit_account_id))?;

    let money = Money::new(dto.amount, &debit_account.currency_code)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let chart_code = credit_account.chart_code.as_deref().unwrap_or("4001");

    let debit_entry = TransactionEntry::new(
        debit_account.id,
        chart_code,
        Some(money.clone()),
        None,
        &dto.description,
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let credit_entry = TransactionEntry::new(
        credit_account.id,
        chart_code,
        None,
        Some(money),
        &dto.description,
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let transaction = Transaction::new(
        Uuid::new_v4(),
        dto.date,
        dto.description.clone(),
        vec![debit_entry, credit_entry],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    self.transaction_repo.create(&transaction).await?;

    let mut debit_account = debit_account;
    let new_balance = debit_account
        .balance
        .add(&Money::new(dto.amount, &debit_account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
    debit_account
        .update_balance(new_balance)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
    self.account_repo.update(&debit_account).await?;

    Ok(transaction.id)
}
```

- [ ] **Step 4: Rewrite create_expense**

Replace lines 296-365 with:

```rust
pub async fn create_expense(
    &self,
    dto: SimpleExpenseDto,
) -> Result<Uuid, TransactionServiceError> {
    let debit_account = self
        .account_repo
        .find_by_id(dto.debit_account_id)
        .await?
        .ok_or(TransactionServiceError::AccountNotFound(dto.debit_account_id))?;

    let credit_account = self
        .account_repo
        .find_by_id(dto.credit_account_id)
        .await?
        .ok_or(TransactionServiceError::AccountNotFound(dto.credit_account_id))?;

    let money = Money::new(dto.amount, &credit_account.currency_code)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let chart_code = debit_account.chart_code.as_deref().unwrap_or("5401");

    let debit_entry = TransactionEntry::new(
        debit_account.id,
        chart_code,
        Some(money.clone()),
        None,
        &dto.description,
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let credit_entry = TransactionEntry::new(
        credit_account.id,
        chart_code,
        None,
        Some(money),
        &dto.description,
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    let transaction = Transaction::new(
        Uuid::new_v4(),
        dto.date,
        dto.description.clone(),
        vec![debit_entry, credit_entry],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

    self.transaction_repo.create(&transaction).await?;

    let mut credit_account = credit_account;
    let new_balance = credit_account
        .balance
        .subtract(&Money::new(dto.amount, &credit_account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
    credit_account
        .update_balance(new_balance)
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
    self.account_repo.update(&credit_account).await?;

    Ok(transaction.id)
}
```

- [ ] **Step 5: Update create_transaction (manual) entry builder**

On lines 93-99, update `TransactionEntry::new()` call — remove `entry_dto.category_id.clone()`:

```rust
let entry = TransactionEntry::new(
    entry_dto.account_id,
    &entry_dto.chart_of_account_code,
    debit_amount,
    credit_amount,
    entry_dto.memo.as_deref().unwrap_or(""),
)
```

- [ ] **Step 6: Update list/get transaction DTO builders**

Search for all `category_id:` field references in the file (lines ~209, ~519-700), replace with `category_id: None` or remove if the field is gone from the DTO.

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/application/services/transaction_service.rs
git commit -m "feat: refactor TransactionService — use dual accounts, remove category dependency"
```

---

### Task 10: Refactor TransactionCommands

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/transaction_commands.rs`

- [ ] **Step 1: Remove SqliteCategoryRepository**

Remove `SqliteCategoryRepository` from imports (line 6). Remove `category_repo` creation from `from_pool()` (lines 62, 66). Update `TransactionService::new()` call to remove `category_repo` param (lines 63-67):

```rust
pub fn from_pool(pool: sqlx::SqlitePool) -> Self {
    let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
    let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
    Self::from_service(TransactionService::new(
        transaction_repo,
        account_repo,
    ))
}
```

- [ ] **Step 2: Update create_simple_income command**

Replace lines 165-194 with:

```rust
#[tauri::command]
pub async fn create_simple_income(
    state: State<'_, TransactionCommandState>,
    debit_account_id: String,
    credit_account_id: String,
    amount: String,
    date: String,
    description: String,
) -> Result<String, String> {
    use crate::application::dtos::SimpleIncomeDto;

    let amount = parse_amount(&amount)?;
    let date = parse_date(&date)?;
    let debit_account_id = parse_uuid(&debit_account_id, "debit_account_id")?;
    let credit_account_id = parse_uuid(&credit_account_id, "credit_account_id")?;

    let dto = SimpleIncomeDto {
        debit_account_id,
        credit_account_id,
        amount,
        date,
        description,
    };

    state
        .service()
        .create_income(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 3: Update create_simple_expense command**

Replace lines 196-225 with:

```rust
#[tauri::command]
pub async fn create_simple_expense(
    state: State<'_, TransactionCommandState>,
    debit_account_id: String,
    credit_account_id: String,
    amount: String,
    date: String,
    description: String,
) -> Result<String, String> {
    use crate::application::dtos::SimpleExpenseDto;

    let amount = parse_amount(&amount)?;
    let date = parse_date(&date)?;
    let debit_account_id = parse_uuid(&debit_account_id, "debit_account_id")?;
    let credit_account_id = parse_uuid(&credit_account_id, "credit_account_id")?;

    let dto = SimpleExpenseDto {
        debit_account_id,
        credit_account_id,
        amount,
        date,
        description,
    };

    state
        .service()
        .create_expense(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/transaction_commands.rs
git commit -m "feat: update transaction commands — dual account params, remove category"
```

---

### Task 11: Remove CategoryCommands and update main.rs

**Files:**
- Delete: `src-tauri/src/presentation/tauri_commands/category_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Remove category_commands from mod.rs**

Remove `pub mod category_commands;` and all category-related re-exports.

- [ ] **Step 2: Delete category_commands.rs**

```bash
rm src-tauri/src/presentation/tauri_commands/category_commands.rs
```

- [ ] **Step 3: Update main.rs**

Remove category imports (lines 20-22):
```rust
// Remove these lines:
category_commands::{
    create_category, delete_category, get_category, list_categories, list_categories_by_type,
    update_category, CategoryAppState,
},
```

Remove `CategoryAppState` instantiation (line 102):
```rust
// Remove:
let category_state = CategoryAppState::from_pool(pool.clone());
```

Remove `.manage(category_state)` (line 135).

Remove category commands from `invoke_handler` (lines 146-151):
```rust
// Remove: create_category, update_category, delete_category,
//         get_category, list_categories, list_categories_by_type,
```

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/ src-tauri/src/main.rs
git commit -m "feat: remove category commands and state from main"
```

---

### Task 12: Update AccountService for new fields and ownership filtering

**Files:**
- Modify: `src-tauri/src/application/services/account_service.rs`

- [ ] **Step 1: Update create_account to pass new params to Account::new()**

Replace the `Account::new()` call (lines 35-42) in `create_account()`:

```rust
let account = Account::new(
    Uuid::new_v4(),
    dto.name,
    dto.account_type,
    dto.ownership,
    &currency,
    balance,
    dto.icon,
    dto.color,
    dto.chart_code,
    dto.parent_id,
    SyncMetadata::new(Uuid::new_v4()),
)?;
```

Import `Ownership` at the top of the file:
```rust
use crate::domain::aggregates::{Account, AccountError, Ownership};
```

- [ ] **Step 2: Add list_accounts_by_ownership method**

Add to `impl AccountService` after `list_accounts()`:

```rust
pub async fn list_accounts_by_ownership(
    &self,
    ownership: Ownership,
) -> Result<Vec<AccountDto>, AccountServiceError> {
    let accounts = self.account_repo.find_by_ownership(&ownership).await?;
    Ok(accounts.into_iter().map(AccountDto::from).collect())
}
```

- [ ] **Step 3: Update test CreateAccountDto structs**

In the test module, every `CreateAccountDto { ... }` instantiation needs new fields. For example, the test `test_create_account_success` (line 277-282):

```rust
let dto = CreateAccountDto {
    name: "Checking Account".to_string(),
    account_type: AccountType::Bank,
    ownership: Ownership::Own,
    currency_code: "CNY".to_string(),
    initial_balance: Decimal::new(10000, 2),
    icon: "💰".to_string(),
    color: "#10B981".to_string(),
    chart_code: None,
    parent_id: None,
};
```

Update all other test `CreateAccountDto` instances similarly.

- [ ] **Step 4: Update MockAccountRepository**

Add `find_by_ownership` method to the mock repo (add after `find_by_type` at line ~185):

```rust
async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>> {
    Ok(self
        .accounts
        .lock()
        .unwrap()
        .values()
        .filter(|a| a.ownership == *ownership)
        .cloned()
        .collect())
}
```

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/application/services/account_service.rs
git commit -m "feat: update AccountService — new fields, ownership filtering"
```

---

### Task 13: Update AccountRepository for new columns and ownership queries

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs` (AccountRepository trait)
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs` (SqliteAccountRepository)

- [ ] **Step 1: Add find_by_ownership to AccountRepository trait**

In `src-tauri/src/domain/repositories/mod.rs`, add to the `AccountRepository` trait (after `find_by_type`):

```rust
async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>>;
```

Add `Ownership` to imports from aggregates (line 4-6):
```rust
use crate::domain::aggregates::{
    Account, AccountType, ChartOfAccounts, ChartOfAccountsType, Ownership, Transaction,
};
```

Remove `Category, CategoryType,` from the same import (these no longer exist after Task 4).

- [ ] **Step 2: Update row_to_account to read new columns**

In `account_repository.rs`, update `row_to_account()` to read ownership, icon, color, chart_code, parent_id. Add after reading `account_type` (line ~41):

```rust
let ownership_str: String = row.try_get("ownership")?;
let ownership = match ownership_str.as_str() {
    "own" => Ownership::Own,
    "external" => Ownership::External,
    _ => return Err(sqlx::Error::Decode(
        format!("Invalid ownership: {}", ownership_str).into(),
    )),
};

let icon: String = row.try_get("icon")?;
let color: String = row.try_get("color")?;
let chart_code: Option<String> = row.try_get("chart_code")?;
let parent_id_str: Option<String> = row.try_get("parent_id")?;
let parent_id = parent_id_str
    .map(|s| Uuid::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e))))
    .transpose()?;
```

Update the `Account` struct constructor at the end of `row_to_account()` (line 116-131) to include new fields:

```rust
Ok(Account {
    id,
    name,
    account_type,
    ownership,
    currency_code,
    balance,
    icon,
    color,
    chart_code,
    parent_id,
    account_number,
    institution,
    credit_limit,
    billing_day,
    payment_due_day,
    interest_rate,
    sync_metadata,
    pending_events: Vec::new(),
})
```

- [ ] **Step 3: Update INSERT query**

Update `create()` (lines 135-166) to include new columns:

```rust
sqlx::query(
    r#"
    INSERT INTO accounts (
        id, name, account_type, ownership, currency_code, balance,
        icon, color, chart_code, parent_id,
        account_number, institution, credit_limit, billing_day, 
        payment_due_day, interest_rate,
        updated_at, deleted_at, device_id, synced_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    "#,
)
.bind(account.id.to_string())
.bind(&account.name)
.bind(account.account_type.to_string())
.bind(account.ownership.to_string())  // new
.bind(&account.currency_code)
.bind(account.balance.amount.to_string())
.bind(&account.icon)                  // new
.bind(&account.color)                 // new
.bind(&account.chart_code)            // new
.bind(account.parent_id.map(|id| id.to_string())) // new
.bind(&account.account_number)
.bind(&account.institution)
.bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
.bind(account.billing_day.map(|d| d as i64))
.bind(account.payment_due_day.map(|d| d as i64))
.bind(account.interest_rate.map(|r| r.to_string()))
.bind(account.sync_metadata.updated_at.to_rfc3339())
.bind(account.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
.bind(account.sync_metadata.device_id.to_string())
.bind(account.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
.execute(&self.pool)
.await?;
```

- [ ] **Step 4: Update all SELECT queries**

Every SELECT query in the repo must include the new columns. Add to each SELECT (in `find_by_id`, `find_all`, `find_by_type`, `find_all_including_deleted`, `get_changes_since`):

```sql
SELECT 
    id, name, account_type, ownership, currency_code, 
    CAST(balance AS TEXT) AS balance,
    icon, color, chart_code, parent_id,
    account_number, institution, 
    CAST(credit_limit AS TEXT) AS credit_limit,
    billing_day, payment_due_day, 
    CAST(interest_rate AS TEXT) AS interest_rate,
    updated_at, deleted_at, device_id, synced_at
```

- [ ] **Step 5: Add find_by_ownership implementation**

Add after `find_by_type()`:

```rust
async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>> {
    let rows = sqlx::query(
        r#"
        SELECT 
            id, name, account_type, ownership, currency_code, 
            CAST(balance AS TEXT) AS balance,
            icon, color, chart_code, parent_id,
            account_number, institution, 
            CAST(credit_limit AS TEXT) AS credit_limit,
            billing_day, payment_due_day, 
            CAST(interest_rate AS TEXT) AS interest_rate,
            updated_at, deleted_at, device_id, synced_at
        FROM accounts
        WHERE ownership = ? AND deleted_at IS NULL
        ORDER BY name ASC
        "#,
    )
    .bind(ownership.to_string())
    .fetch_all(&self.pool)
    .await?;

    rows.iter().map(Self::row_to_account).collect()
}
```

Add `Display` impl for `Ownership` (in `account.rs`):
```rust
impl fmt::Display for Ownership {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Own => write!(f, "own"),
            Self::External => write!(f, "external"),
        }
    }
}
```

- [ ] **Step 6: Update test setup_db() schema**

In `setup_test_db()` (line 357-380), add the new columns to the CREATE TABLE:

```sql
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    currency_code VARCHAR(3) NOT NULL,
    balance DECIMAL(20,2) NOT NULL,
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(10,6),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP
)
```

- [ ] **Step 7: Update create_test_account helper**

Update `create_test_account()` (line 385-399) to pass new params:

```rust
fn create_test_account(name: &str, account_type: AccountType, balance: Decimal) -> Account {
    let currency = Currency::new("USD", "$", Decimal::ONE).unwrap();
    let money = Money::new(balance, "USD").unwrap();
    let sync_metadata = SyncMetadata::new(Uuid::new_v4());

    Account::new(
        Uuid::new_v4(),
        name,
        account_type,
        Ownership::Own,
        &currency,
        money,
        "💰",
        "#10B981",
        None,
        None,
        sync_metadata,
    )
    .unwrap()
}
```

- [ ] **Step 8: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs src-tauri/src/infrastructure/repositories/account_repository.rs src-tauri/src/domain/aggregates/account.rs
git commit -m "feat: update AccountRepository for new columns and ownership queries"
```

---

### Task 14: Update AccountCommands for new params

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/account_commands.rs`

- [ ] **Step 1: Add list_accounts_by_ownership command**

```rust
#[tauri::command]
pub async fn list_accounts_by_ownership(
    state: State<'_, AppState>,
    ownership: Ownership,
) -> Result<Vec<AccountDto>, String> {
    state
        .service()
        .list_accounts_by_ownership(ownership)
        .await
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2: Register in main.rs invoke_handler**

Add `list_accounts_by_ownership` to the handler.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/account_commands.rs src-tauri/src/main.rs
git commit -m "feat: add list_accounts_by_ownership command"
```

---

### Task 15: Frontend API layer — remove category, update transactions

**Files:**
- Delete: `src/lib/tauri/category.ts`
- Modify: `src/lib/api/transactions.ts`
- Modify: `src/lib/tauri/account.ts`

- [ ] **Step 1: Update SimpleIncomeRequest and SimpleExpenseRequest**

In `src/lib/api/transactions.ts`, replace:

```typescript
export interface SimpleIncomeRequest {
  debitAccountId: string;
  creditAccountId: string;
  amount: string;
  date: string;
  description: string;
}

export interface SimpleExpenseRequest {
  debitAccountId: string;
  creditAccountId: string;
  amount: string;
  date: string;
  description: string;
}
```

- [ ] **Step 2: Update API functions**

```typescript
export async function createSimpleIncome(
  request: SimpleIncomeRequest
): Promise<string> {
  return invoke<string>('create_simple_income', {
    debitAccountId: request.debitAccountId,
    creditAccountId: request.creditAccountId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}

export async function createSimpleExpense(
  request: SimpleExpenseRequest
): Promise<string> {
  return invoke<string>('create_simple_expense', {
    debitAccountId: request.debitAccountId,
    creditAccountId: request.creditAccountId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}
```

- [ ] **Step 3: Update account.ts types**

Add to `AccountDto` interface:
```typescript
ownership: 'own' | 'external';
icon: string;
color: string;
chart_code?: string;
parent_id?: string;
```

Extend `AccountType`:
```typescript
type AccountType = 'Cash' | 'Bank' | 'CreditCard' | 'Investment' | 'Loan' | 'Other' | 'Income' | 'Expense';
```

Add to `CreateAccountDto`:
```typescript
ownership: 'own' | 'external';
icon: string;
color: string;
chart_code?: string;
parent_id?: string;
```

Add `listAccountsByOwnership`:
```typescript
export const listAccountsByOwnership = (ownership: 'own' | 'external') =>
  invokeTauri<AccountDto[]>('list_accounts_by_ownership', { ownership });
```

- [ ] **Step 4: Delete category.ts**

```bash
rm src/lib/tauri/category.ts
```

- [ ] **Step 5: Commit**

```bash
git add src/lib/
git commit -m "feat: update frontend API — remove category, add dual account params and ownership"
```

---

### Task 16: Refactor SimpleTransactionForm

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

- [ ] **Step 1: Remove Category interface and props**

Remove local `Category` interface (lines 28-34). Replace `categories: Category[]` prop with `externalAccounts: Account[]` (filtered to `ownership === 'external'` by the parent page).

Update `TransactionFormData`:
```typescript
export interface TransactionFormData {
  type: 'income' | 'expense' | 'transfer';
  date: Date;
  amount: string;
  debitAccountId?: string;
  creditAccountId?: string;
  fromAccountId?: string;
  toAccountId?: string;
  description: string;
}
```

- [ ] **Step 2: Replace category state with external account state**

Replace `categoryId`/`effectiveCategoryId`/`filteredCategories` with:
```typescript
const [externalAccountId, setExternalAccountId] = useState(
  () => externalAccounts.filter(a => a.account_type === 'Expense')[0]?.id || ''
);

const filteredExternalAccounts = useMemo(
  () => externalAccounts.filter(a =>
    type === 'expense' ? a.account_type === 'Expense' : a.account_type === 'Income'
  ),
  [externalAccounts, type]
);
```

- [ ] **Step 3: Update form rendering**

For income/expense, render two selectors:

Expense mode:
```
[贷方: 自己账户 (credit)] → [借方: 外部账户 (debit)]
```

Income mode:
```
[借方: 自己账户 (debit)] → [贷方: 外部账户 (credit)]
```

Replace the current single-column category/account section (lines 249-285) with dual selectors that filter accounts by ownership.

- [ ] **Step 4: Update handleSubmit**

Expense:
```typescript
await createSimpleExpense({
  debitAccountId: externalAccountId,
  creditAccountId: accountId,
  amount,
  date: dateStr,
  description,
});
```

Income:
```typescript
await createSimpleIncome({
  debitAccountId: accountId,
  creditAccountId: externalAccountId,
  amount,
  date: dateStr,
  description,
});
```

- [ ] **Step 5: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat: refactor SimpleTransactionForm — dual account selectors"
```

---

### Task 17: Update AccountForm for ownership, icon, color

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Extend Zod schema**

Add ownership, icon, color fields:
```typescript
ownership: z.enum(['own', 'external']),
icon: z.string().min(1, 'Icon is required'),
color: z.string().min(1, 'Color is required'),
chart_code: z.string().optional(),
parent_id: z.string().optional(),
```

Extend account_type enum to include `'Income' | 'Expense'`.

- [ ] **Step 2: Add ownership toggle to form UI**

Add a pill toggle at the top of the form:
```tsx
<FormField name="ownership" render={({ field }) => (
  <div className="flex gap-2">
    <Button type="button" variant={field.value === 'own' ? 'default' : 'outline'}
            onClick={() => field.onChange('own')}>
      🏠 自己账户
    </Button>
    <Button type="button" variant={field.value === 'external' ? 'default' : 'outline'}
            onClick={() => field.onChange('external')}>
      🌐 外部账户
    </Button>
  </div>
)} />
```

- [ ] **Step 3: Add icon and color fields**

Add emoji input and color swatch picker fields. Adjust account_type options based on ownership value.

- [ ] **Step 4: Dynamically adjust account_type options**

When `ownership === 'external'`, show only `Income` and `Expense`. When `ownership === 'own'`, show `Cash, Bank, CreditCard, Investment, Loan, Other`.

- [ ] **Step 5: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: add ownership/icon/color fields to AccountForm"
```

---

### Task 18: Update page components (HomePage, ReportsPage, TransactionsPage, NewTransactionPage)

**Files:**
- Modify: `src/pages/HomePage.tsx`
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/pages/TransactionsPage.tsx`
- Modify: `src/pages/NewTransactionPage.tsx`

- [ ] **Step 1: Update HomePage.tsx**

Remove `listCategories` import. Replace category-based classification logic with account-based:
```typescript
// Before: entry.category_id → categories.find()
// After: entry.account_id → accounts.find(a => a.id === entry.account_id)
// Filter: a.ownership === 'own' for net worth
```

- [ ] **Step 2: Update ReportsPage.tsx**

Remove `listCategories` import and `useQuery(['categories'])`. Replace category grouping logic in income statement with external account grouping (`ownership === 'external'`).

- [ ] **Step 3: Update TransactionsPage.tsx and NewTransactionPage.tsx**

Remove `listCategories` import and `categories` query. Add `listAccountsByOwnership('external')` query. Pass `externalAccounts` prop instead of `categories` to `SimpleTransactionForm`.

- [ ] **Step 4: Commit**

```bash
git add src/pages/
git commit -m "feat: update pages — replace categories with ownership-filtered accounts"
```

---

### Task 19: Update i18n keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Replace "category" keys with "external account" keys**

Replace `"category": "Category"` with `"externalAccount": "External Account"` in en.json.
Replace `"category": "分类"` with `"externalAccount": "外部账户"` in zh.json.
Add new keys for `creditAccount`/`debitAccount` labels.

- [ ] **Step 2: Commit**

```bash
git add src/i18n/
git commit -m "feat: update i18n keys for unified account model"
```

---

### Task 20: Update test files

**Files:**
- Modify: `src/components/__tests__/TransactionForm.test.tsx`
- Modify: `src/components/__tests__/AccountForm.test.tsx`
- Modify: `src-tauri/tests/transaction_commands.rs` (if exists)
- Modify: `src-tauri/tests/transaction_repository.rs` (if exists)

- [ ] **Step 1: Remove category mocks from TransactionForm test**

Remove `vi.mock('@/lib/tauri/category', ...)`. Update form props to use `externalAccounts` instead of `categories`.

- [ ] **Step 2: Update AccountForm test**

Add ownership/icon/color to test data and assertions.

- [ ] **Step 3: Update Rust tests**

In backend tests, update `TransactionEntry::new()` calls to remove category_id. Update `Account::new()` calls to add new params.

- [ ] **Step 4: Commit**

```bash
git add src/components/__tests__/ src-tauri/tests/
git commit -m "test: update tests for unified account model"
```

---

### Task 21: Verify build and fix compilation errors

- [ ] **Step 1: Run cargo check**

```bash
cargo check --manifest-path src-tauri/Cargo.toml 2>&1
```

Fix any compilation errors — check for remaining references to `category` in the codebase:
```bash
rg -i "category" src-tauri/src/ --type rust
```

- [ ] **Step 2: Run TypeScript type-check**

```bash
npx tsc --noEmit 2>&1
```

- [ ] **Step 3: Run frontend build**

```bash
npx vite build 2>&1
```

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "chore: fix compilation errors after unified model migration"
```
