# Subscription / Recurring Transactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add subscription/recurring transaction support with auto-recording, notifications, and a full CRUD UI.

**Architecture:** New `subscriptions` table stores recurring rules. A background scheduler (reusing ReminderScheduler pattern) checks for due subscriptions every 5 minutes, auto-creates double-entry transactions, and sends notifications. Frontend follows HoldingsPage pattern with expandable transaction history.

**Tech Stack:** Rust (sqlx, Tauri), React (TypeScript, TanStack Query, react-hook-form, zod, shadcn/ui)

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `src-tauri/migrations/20260527000013_create_subscriptions.sql` | DDL for subscriptions table |
| `src-tauri/src/domain/aggregates/subscription.rs` | Domain model + cycle calculation |
| `src-tauri/src/infrastructure/repositories/subscription_repository.rs` | SQLite CRUD for subscriptions |
| `src-tauri/src/application/dtos/subscription_dto.rs` | DTOs for create/update/list/filter |
| `src-tauri/src/application/services/subscription_service.rs` | Business logic + auto-recording |
| `src-tauri/src/presentation/tauri_commands/subscription_commands.rs` | Tauri commands + AppState |
| `src/lib/tauri/subscription.ts` | Frontend API client |
| `src/components/SubscriptionForm.tsx` | Create/edit form (Sheet) |
| `src/pages/SubscriptionsPage.tsx` | List page with filters/sort/expand |

### Modified files

| File | Change |
|------|--------|
| `src-tauri/src/domain/aggregates/mod.rs` | Add `pub mod subscription` |
| `src-tauri/src/domain/repositories/mod.rs` | Add `SubscriptionRepository` trait |
| `src-tauri/src/infrastructure/repositories/mod.rs` | Add `subscription_repository` module |
| `src-tauri/src/application/dtos/mod.rs` | Re-export subscription DTOs |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | Add subscription_commands module |
| `src-tauri/src/main.rs` | Register commands + scheduler |
| `src/router.tsx` | Add subscriptions route |
| `src/components/layout/Sidebar.tsx` | Add nav item |
| `src/i18n/locales/zh.json` | Chinese translations |
| `src/i18n/locales/en.json` | English translations |

---

### Task 1: Migration — create subscriptions table

**Files:**
- Create: `src-tauri/migrations/20260527000013_create_subscriptions.sql`

- [ ] **Step 1: Create migration file**

```sql
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    amount TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('expense', 'income')),
    cycle TEXT NOT NULL CHECK (cycle IN ('weekly', 'monthly', 'yearly', 'custom')),
    cycle_days INTEGER,
    billing_day INTEGER,
    next_billing_date TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    auto_record INTEGER NOT NULL DEFAULT 1,
    paused INTEGER NOT NULL DEFAULT 0,
    source_account_id TEXT NOT NULL,
    category TEXT,
    description TEXT,
    last_transaction_id TEXT,
    deleted_at TEXT,
    updated_at TEXT NOT NULL,
    device_id TEXT,
    synced_at TEXT,
    FOREIGN KEY (source_account_id) REFERENCES accounts(id)
);
```

- [ ] **Step 2: Touch main.rs to force recompile**

Run: `touch src-tauri/src/main.rs`

- [ ] **Step 3: Build to verify migration compiles**

Run: `cd src-tauri && cargo build`
Expected: SUCCESS

- [ ] **Step 4: Commit**

```bash
git add src-tauri/migrations/20260527000013_create_subscriptions.sql
git commit -m "feat(subscription): add subscriptions table migration"
```

---

### Task 2: Domain — Subscription aggregate

**Files:**
- Create: `src-tauri/src/domain/aggregates/subscription.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`

- [ ] **Step 1: Create subscription domain model**

Create `src-tauri/src/domain/aggregates/subscription.rs`:

```rust
use chrono::{Datelike, Months, NaiveDate};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SubscriptionCycle {
    Weekly,
    Monthly,
    Yearly,
    Custom { days: u32 },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SubscriptionDirection {
    Expense,
    Income,
}

#[derive(Debug, Clone)]
pub struct Subscription {
    pub id: Uuid,
    pub name: String,
    pub amount: Decimal,
    pub direction: SubscriptionDirection,
    pub cycle: SubscriptionCycle,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub source_account_id: Uuid,
    pub category: Option<String>,
    pub description: Option<String>,
    pub last_transaction_id: Option<Uuid>,
}

impl Subscription {
    pub fn is_due(&self, today: NaiveDate) -> bool {
        !self.paused
            && self.next_billing_date <= today
            && self.end_date.map_or(true, |end| today <= end)
    }

    pub fn calculate_next_billing_date(&self) -> Option<NaiveDate> {
        match &self.cycle {
            SubscriptionCycle::Weekly => self.next_billing_date.checked_add_days(chrono::Days::new(7)),
            SubscriptionCycle::Monthly => self.next_billing_date.checked_add_months(Months::new(1)),
            SubscriptionCycle::Yearly => self.next_billing_date.checked_add_months(Months::new(12)),
            SubscriptionCycle::Custom { days } => self.next_billing_date.checked_add_days(chrono::Days::new(*days as u64)),
        }
    }

    pub fn advance_to_next(&mut self) {
        if let Some(next) = self.calculate_next_billing_date() {
            self.next_billing_date = next;
        }
    }

    pub fn pause(&mut self) {
        self.paused = true;
    }

    pub fn resume(&mut self) {
        self.paused = false;
    }
}
```

- [ ] **Step 2: Register in aggregates/mod.rs**

Add to `src-tauri/src/domain/aggregates/mod.rs`:
```rust
pub mod subscription;
```
And add to the `pub use` block:
```rust
pub use subscription::{Subscription, SubscriptionCycle, SubscriptionDirection};
```

- [ ] **Step 3: Build to verify**

Run: `cd src-tauri && cargo build`

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/domain/aggregates/subscription.rs src-tauri/src/domain/aggregates/mod.rs
git commit -m "feat(subscription): add Subscription domain aggregate"
```

---

### Task 3: Repository — SubscriptionRepository trait + SQLite impl

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/subscription_repository.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs`
- Modify: `src-tauri/src/infrastructure/repositories/mod.rs`

- [ ] **Step 1: Add SubscriptionRepository trait to domain/repositories/mod.rs**

Add after the existing `HoldingRepository` trait (after line ~131):

```rust
mod subscription_repository;
pub use subscription_repository::SubscriptionRepository;
```

Then add the trait (before the closing of the file):

```rust
#[allow(async_fn_in_trait, dead_code)]
pub trait SubscriptionRepository: Send + Sync {
    async fn create(&self, subscription: &Subscription) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Subscription>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Subscription>>;
    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<Subscription>>;
    async fn update(&self, subscription: &Subscription) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
    async fn update_next_billing_date(&self, id: Uuid, next_date: NaiveDate, last_tx_id: Option<Uuid>) -> sqlx::Result<bool>;
    async fn set_paused(&self, id: Uuid, paused: bool) -> sqlx::Result<bool>;
}
```

Also add `use chrono::NaiveDate;` to imports if not present (already imported via `use chrono::{DateTime, NaiveDate, Utc};`) and `use crate::domain::aggregates::subscription::Subscription;`.

- [ ] **Step 2: Create SQLite repository**

Create `src-tauri/src/infrastructure/repositories/subscription_repository.rs`:

```rust
use crate::domain::aggregates::subscription::{Subscription, SubscriptionCycle, SubscriptionDirection};
use crate::domain::repositories::SubscriptionRepository;
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteSubscriptionRepository { pool: SqlitePool }

impl SqliteSubscriptionRepository {
    pub fn new(pool: SqlitePool) -> Self { Self { pool } }

    fn row_to_subscription(row: &sqlx::sqlite::SqliteRow) -> Result<Subscription, sqlx::Error> {
        let cycle_str: String = row.try_get("cycle")?;
        let cycle = match cycle_str.as_str() {
            "weekly" => SubscriptionCycle::Weekly,
            "monthly" => SubscriptionCycle::Monthly,
            "yearly" => SubscriptionCycle::Yearly,
            "custom" => {
                let days: Option<i32> = row.try_get("cycle_days")?;
                SubscriptionCycle::Custom { days: days.unwrap_or(30) as u32 }
            }
            _ => return Err(sqlx::Error::Decode(format!("invalid cycle: {}", cycle_str).into())),
        };

        let dir_str: String = row.try_get("direction")?;
        let direction = match dir_str.as_str() {
            "expense" => SubscriptionDirection::Expense,
            "income" => SubscriptionDirection::Income,
            _ => return Err(sqlx::Error::Decode(format!("invalid direction: {}", dir_str).into())),
        };

        Ok(Subscription {
            id: Uuid::parse_str(&row.try_get::<String, _>("id")?).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            name: row.try_get("name")?,
            amount: Decimal::from_str(&row.try_get::<String, _>("amount")?).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            direction,
            cycle,
            billing_day: row.try_get::<Option<i32>, _>("billing_day")?.map(|d| d as u8),
            next_billing_date: NaiveDate::parse_from_str(&row.try_get::<String, _>("next_billing_date")?, "%Y-%m-%d").map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            start_date: NaiveDate::parse_from_str(&row.try_get::<String, _>("start_date")?, "%Y-%m-%d").map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            end_date: row.try_get::<Option<String>, _>("end_date")?.map(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d")).transpose().map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            auto_record: row.try_get::<i32, _>("auto_record")? != 0,
            paused: row.try_get::<i32, _>("paused")? != 0,
            source_account_id: Uuid::parse_str(&row.try_get::<String, _>("source_account_id")?).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            category: row.try_get("category")?,
            description: row.try_get("description")?,
            last_transaction_id: row.try_get::<Option<String>, _>("last_transaction_id")?.map(|s| Uuid::parse_str(&s)).transpose().map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
        })
    }
}

impl SubscriptionRepository for SqliteSubscriptionRepository {
    async fn create(&self, s: &Subscription) -> sqlx::Result<()> {
        let (cycle_str, cycle_days) = match &s.cycle {
            SubscriptionCycle::Weekly => ("weekly", None),
            SubscriptionCycle::Monthly => ("monthly", None),
            SubscriptionCycle::Yearly => ("yearly", None),
            SubscriptionCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        sqlx::query(
            "INSERT INTO subscriptions (id, name, amount, direction, cycle, cycle_days, billing_day, next_billing_date, start_date, end_date, auto_record, paused, source_account_id, category, description, last_transaction_id, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(s.id.to_string()).bind(&s.name).bind(s.amount.to_string())
        .bind(match s.direction { SubscriptionDirection::Expense => "expense", SubscriptionDirection::Income => "income" })
        .bind(cycle_str).bind(cycle_days).bind(s.billing_day.map(|d| d as i32))
        .bind(s.next_billing_date.to_string()).bind(s.start_date.to_string())
        .bind(s.end_date.map(|d| d.to_string()))
        .bind(s.auto_record as i32).bind(s.paused as i32)
        .bind(s.source_account_id.to_string())
        .bind(&s.category).bind(&s.description)
        .bind(s.last_transaction_id.map(|id| id.to_string()))
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Subscription>> {
        let row = sqlx::query(
            "SELECT *, CAST(amount AS TEXT) as amount FROM subscriptions WHERE id = ? AND deleted_at IS NULL"
        ).bind(id.to_string()).fetch_optional(&self.pool).await?;
        row.map(|r| Self::row_to_subscription(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Subscription>> {
        let rows = sqlx::query(
            "SELECT *, CAST(amount AS TEXT) as amount FROM subscriptions WHERE deleted_at IS NULL ORDER BY next_billing_date ASC"
        ).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_subscription(r)).collect()
    }

    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<Subscription>> {
        let rows = sqlx::query(
            "SELECT *, CAST(amount AS TEXT) as amount FROM subscriptions
             WHERE next_billing_date <= ? AND auto_record = 1 AND paused = 0 AND deleted_at IS NULL"
        ).bind(today.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_subscription(r)).collect()
    }

    async fn update(&self, s: &Subscription) -> sqlx::Result<bool> {
        let (cycle_str, cycle_days) = match &s.cycle {
            SubscriptionCycle::Weekly => ("weekly", None),
            SubscriptionCycle::Monthly => ("monthly", None),
            SubscriptionCycle::Yearly => ("yearly", None),
            SubscriptionCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        let r = sqlx::query(
            "UPDATE subscriptions SET name=?, amount=?, direction=?, cycle=?, cycle_days=?, billing_day=?, next_billing_date=?, start_date=?, end_date=?, auto_record=?, category=?, description=?, updated_at=?
             WHERE id=? AND deleted_at IS NULL"
        )
        .bind(&s.name).bind(s.amount.to_string())
        .bind(match s.direction { SubscriptionDirection::Expense => "expense", SubscriptionDirection::Income => "income" })
        .bind(cycle_str).bind(cycle_days).bind(s.billing_day.map(|d| d as i32))
        .bind(s.next_billing_date.to_string()).bind(s.start_date.to_string())
        .bind(s.end_date.map(|d| d.to_string()))
        .bind(s.auto_record as i32).bind(&s.category).bind(&s.description)
        .bind(Utc::now().to_rfc3339()).bind(s.id.to_string())
        .execute(&self.pool).await?;
        Ok(r.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query("UPDATE subscriptions SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
            .bind(Utc::now().to_rfc3339()).bind(id.to_string())
            .execute(&self.pool).await?;
        Ok(r.rows_affected() > 0)
    }

    async fn update_next_billing_date(&self, id: Uuid, next_date: NaiveDate, last_tx_id: Option<Uuid>) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE subscriptions SET next_billing_date=?, last_transaction_id=?, updated_at=? WHERE id=? AND deleted_at IS NULL"
        ).bind(next_date.to_string()).bind(last_tx_id.map(|id| id.to_string()))
        .bind(Utc::now().to_rfc3339()).bind(id.to_string())
        .execute(&self.pool).await?;
        Ok(r.rows_affected() > 0)
    }

    async fn set_paused(&self, id: Uuid, paused: bool) -> sqlx::Result<bool> {
        let r = sqlx::query("UPDATE subscriptions SET paused=?, updated_at=? WHERE id=? AND deleted_at IS NULL")
            .bind(paused as i32).bind(Utc::now().to_rfc3339()).bind(id.to_string())
            .execute(&self.pool).await?;
        Ok(r.rows_affected() > 0)
    }
}
```

- [ ] **Step 3: Register in infrastructure/repositories/mod.rs**

Add:
```rust
pub mod subscription_repository;
pub use subscription_repository::SqliteSubscriptionRepository;
```

- [ ] **Step 4: Build**

Run: `cd src-tauri && cargo build`

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs src-tauri/src/infrastructure/repositories/subscription_repository.rs src-tauri/src/infrastructure/repositories/mod.rs
git commit -m "feat(subscription): add SubscriptionRepository trait and SQLite impl"
```

---

### Task 4: DTOs — subscription DTOs

**Files:**
- Create: `src-tauri/src/application/dtos/subscription_dto.rs`
- Modify: `src-tauri/src/application/dtos/mod.rs`

- [ ] **Step 1: Create DTO file**

Create `src-tauri/src/application/dtos/subscription_dto.rs`:

```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSubscriptionDto {
    pub name: String,
    pub amount: Decimal,
    pub direction: String,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub source_account_id: Uuid,
    pub category: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateSubscriptionDto {
    pub id: Uuid,
    pub name: Option<String>,
    pub amount: Option<Decimal>,
    pub direction: Option<String>,
    pub cycle: Option<String>,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub source_account_id: Option<Uuid>,
    pub category: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionDto {
    pub id: Uuid,
    pub name: String,
    pub amount: Decimal,
    pub direction: String,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub source_account_id: Uuid,
    pub source_account_name: String,
    pub currency_code: String,
    pub category: Option<String>,
    pub description: Option<String>,
    pub last_transaction_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionFilters {
    pub direction: Option<String>,
    pub cycle: Option<String>,
    pub paused: Option<bool>,
}
```

- [ ] **Step 2: Register in dtos/mod.rs**

Add to `src-tauri/src/application/dtos/mod.rs`:
```rust
pub mod subscription_dto;
pub use subscription_dto::{CreateSubscriptionDto, SubscriptionDto, SubscriptionFilters, UpdateSubscriptionDto};
```

- [ ] **Step 3: Build**

Run: `cd src-tauri && cargo build`

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/dtos/subscription_dto.rs src-tauri/src/application/dtos/mod.rs
git commit -m "feat(subscription): add subscription DTOs"
```

---

### Task 5: Service — SubscriptionService business logic

**Files:**
- Create: `src-tauri/src/application/services/subscription_service.rs`

This is the largest task. The service handles CRUD, filtering, auto-recording, and transaction lookup.

- [ ] **Step 1: Create SubscriptionService**

Create `src-tauri/src/application/services/subscription_service.rs`:

```rust
use crate::application::dtos::{CreateSubscriptionDto, SubscriptionDto, SubscriptionFilters, UpdateSubscriptionDto};
use crate::domain::aggregates::subscription::{Subscription, SubscriptionCycle, SubscriptionDirection};
use crate::domain::aggregates::Transaction;
use crate::domain::repositories::{AccountRepository, SubscriptionRepository, TransactionRepository};
use crate::domain::value_objects::{Money, SyncMetadata, TransactionEntry};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteSubscriptionRepository, SqliteTransactionRepository,
};
use chrono::Utc;
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

pub struct SubscriptionService {
    subscription_repo: Arc<SqliteSubscriptionRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    transaction_repo: Arc<SqliteTransactionRepository>,
}

#[derive(Debug)]
pub enum SubscriptionServiceError {
    NotFound(Uuid),
    AccountNotFound(Uuid),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for SubscriptionServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "subscription not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for SubscriptionServiceError {}
impl From<sqlx::Error> for SubscriptionServiceError {
    fn from(err: sqlx::Error) -> Self { Self::RepositoryError(err.to_string()) }
}

impl SubscriptionService {
    pub fn new(
        subscription_repo: Arc<SqliteSubscriptionRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self { subscription_repo, account_repo, transaction_repo }
    }

    pub async fn create(&self, dto: CreateSubscriptionDto) -> Result<Uuid, SubscriptionServiceError> {
        let account = self.account_repo.find_by_id(dto.source_account_id).await?
            .ok_or(SubscriptionServiceError::AccountNotFound(dto.source_account_id))?;

        let cycle = parse_cycle(&dto.cycle, dto.cycle_days)?;
        let direction = parse_direction(&dto.direction)?;

        let subscription = Subscription {
            id: Uuid::new_v4(),
            name: dto.name,
            amount: dto.amount,
            direction,
            cycle,
            billing_day: dto.billing_day,
            next_billing_date: dto.next_billing_date,
            start_date: dto.start_date,
            end_date: dto.end_date,
            auto_record: dto.auto_record.unwrap_or(true),
            paused: false,
            source_account_id: dto.source_account_id,
            category: dto.category,
            description: dto.description,
            last_transaction_id: None,
        };

        self.subscription_repo.create(&subscription).await?;
        Ok(subscription.id)
    }

    pub async fn list(&self, filters: SubscriptionFilters) -> Result<Vec<SubscriptionDto>, SubscriptionServiceError> {
        let all = self.subscription_repo.find_all().await?;
        let mut dtos = Vec::new();
        for s in all {
            if let Some(ref dir) = filters.direction {
                if direction_to_str(&s.direction) != *dir { continue; }
            }
            if let Some(ref cyc) = filters.cycle {
                if cycle_to_str(&s.cycle) != *cyc { continue; }
            }
            if let Some(paused) = filters.paused {
                if s.paused != paused { continue; }
            }

            let account = self.account_repo.find_by_id(s.source_account_id).await?;
            dtos.push(SubscriptionDto {
                id: s.id,
                name: s.name.clone(),
                amount: s.amount,
                direction: direction_to_str(&s.direction),
                cycle: cycle_to_str(&s.cycle),
                cycle_days: match &s.cycle { SubscriptionCycle::Custom { days } => Some(*days), _ => None },
                billing_day: s.billing_day,
                next_billing_date: s.next_billing_date,
                start_date: s.start_date,
                end_date: s.end_date,
                auto_record: s.auto_record,
                paused: s.paused,
                source_account_id: s.source_account_id,
                source_account_name: account.as_ref().map(|a| a.name.clone()).unwrap_or_default(),
                currency_code: account.as_ref().map(|a| a.currency_code.clone()).unwrap_or_default(),
                category: s.category.clone(),
                description: s.description.clone(),
                last_transaction_id: s.last_transaction_id,
            });
        }
        Ok(dtos)
    }

    pub async fn get_by_id(&self, id: Uuid) -> Result<SubscriptionDto, SubscriptionServiceError> {
        let s = self.subscription_repo.find_by_id(id).await?
            .ok_or(SubscriptionServiceError::NotFound(id))?;
        let account = self.account_repo.find_by_id(s.source_account_id).await?;
        Ok(SubscriptionDto {
            id: s.id,
            name: s.name.clone(),
            amount: s.amount,
            direction: direction_to_str(&s.direction),
            cycle: cycle_to_str(&s.cycle),
            cycle_days: match &s.cycle { SubscriptionCycle::Custom { days } => Some(*days), _ => None },
            billing_day: s.billing_day,
            next_billing_date: s.next_billing_date,
            start_date: s.start_date,
            end_date: s.end_date,
            auto_record: s.auto_record,
            paused: s.paused,
            source_account_id: s.source_account_id,
            source_account_name: account.as_ref().map(|a| a.name.clone()).unwrap_or_default(),
            currency_code: account.as_ref().map(|a| a.currency_code.clone()).unwrap_or_default(),
            category: s.category.clone(),
            description: s.description.clone(),
            last_transaction_id: s.last_transaction_id,
        })
    }

    pub async fn update(&self, dto: UpdateSubscriptionDto) -> Result<(), SubscriptionServiceError> {
        let mut s = self.subscription_repo.find_by_id(dto.id).await?
            .ok_or(SubscriptionServiceError::NotFound(dto.id))?;

        if let Some(name) = dto.name { s.name = name; }
        if let Some(amount) = dto.amount { s.amount = amount; }
        if let Some(ref dir) = dto.direction { s.direction = parse_direction(dir)?; }
        if let Some(ref cyc) = dto.cycle { s.cycle = parse_cycle(cyc, dto.cycle_days)?; }
        if dto.billing_day.is_some() { s.billing_day = dto.billing_day; }
        if let Some(nbd) = dto.next_billing_date { s.next_billing_date = nbd; }
        if dto.end_date.is_some() { s.end_date = dto.end_date; }
        if let Some(ar) = dto.auto_record { s.auto_record = ar; }
        if let Some(aid) = dto.source_account_id {
            self.account_repo.find_by_id(aid).await?.ok_or(SubscriptionServiceError::AccountNotFound(aid))?;
            s.source_account_id = aid;
        }
        if dto.category.is_some() { s.category = dto.category; }
        if dto.description.is_some() { s.description = dto.description; }

        self.subscription_repo.update(&s).await?;
        Ok(())
    }

    pub async fn delete(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.soft_delete(id).await?;
        Ok(())
    }

    pub async fn pause(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.set_paused(id, true).await?;
        Ok(())
    }

    pub async fn resume(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.set_paused(id, false).await?;
        Ok(())
    }

    pub async fn process_due_subscriptions(&self, today: chrono::NaiveDate) -> Result<usize, SubscriptionServiceError> {
        let due = self.subscription_repo.find_due(today).await?;
        let mut processed = 0;
        for s in &due {
            if let Err(e) = self.record_subscription(s).await {
                tracing::error!("Failed to process subscription {}: {}", s.id, e);
                continue;
            }
            let mut updated = s.clone();
            updated.advance_to_next();
            self.subscription_repo.update_next_billing_date(
                updated.id, updated.next_billing_date, updated.last_transaction_id,
            ).await?;
            processed += 1;
        }
        Ok(processed)
    }

    async fn record_subscription(&self, s: &Subscription) -> Result<Uuid, SubscriptionServiceError> {
        let account = self.account_repo.find_by_id(s.source_account_id).await?
            .ok_or(SubscriptionServiceError::AccountNotFound(s.source_account_id))?;

        let txn_id = Uuid::new_v4();
        let desc = format!("{} - {}", s.name, s.next_billing_date);

        let entries = match s.direction {
            SubscriptionDirection::Expense => {
                let amount_money = Money::new(s.amount, &account.currency_code)
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(s.source_account_id, "5401", Some(amount_money), None, &s.name)
                        .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(s.source_account_id, "1002", None, Some(amount_money), &desc)
                        .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                ]
            }
            SubscriptionDirection::Income => {
                let amount_money = Money::new(s.amount, &account.currency_code)
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(s.source_account_id, "1002", Some(amount_money), None, &desc)
                        .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(s.source_account_id, "4201", None, Some(amount_money), &s.name)
                        .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                ]
            }
        };

        let transaction = Transaction::new(txn_id, s.next_billing_date, desc, entries, SyncMetadata::new(Uuid::new_v4()))
            .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;
        Ok(txn_id)
    }

    pub async fn list_transactions(&self, subscription_id: Uuid) -> Result<Vec<crate::application::dtos::TransactionDto>, SubscriptionServiceError> {
        let s = self.subscription_repo.find_by_id(subscription_id).await?
            .ok_or(SubscriptionServiceError::NotFound(subscription_id))?;
        let all_txns = self.transaction_repo.find_all().await?;
        let prefix = format!("{} - ", s.name);
        let matching: Vec<_> = all_txns.into_iter()
            .filter(|t| t.description.starts_with(&prefix))
            .collect();

        let mut dtos = Vec::new();
        for txn in matching {
            let entries = self.transaction_repo.find_entries_by_transaction_id(txn.id).await?;
            dtos.push(crate::application::dtos::TransactionDto {
                id: txn.id,
                transaction_date: txn.transaction_date,
                description: txn.description,
                entries: entries.into_iter().map(|e| crate::application::dtos::TransactionEntryDto {
                    id: e.id,
                    account_id: e.account_id,
                    chart_of_account_code: e.chart_of_account_code,
                    debit_amount: e.debit_amount.map(|m| m.amount.to_string()).unwrap_or_default(),
                    credit_amount: e.credit_amount.map(|m| m.amount.to_string()).unwrap_or_default(),
                    note: e.note.unwrap_or_default(),
                }).collect(),
            });
        }
        Ok(dtos)
    }
}

fn parse_cycle(s: &str, days: Option<u32>) -> Result<SubscriptionCycle, SubscriptionServiceError> {
    match s {
        "weekly" => Ok(SubscriptionCycle::Weekly),
        "monthly" => Ok(SubscriptionCycle::Monthly),
        "yearly" => Ok(SubscriptionCycle::Yearly),
        "custom" => Ok(SubscriptionCycle::Custom { days: days.unwrap_or(30) }),
        _ => Err(SubscriptionServiceError::ValidationError(format!("invalid cycle: {s}"))),
    }
}

fn parse_direction(s: &str) -> Result<SubscriptionDirection, SubscriptionServiceError> {
    match s {
        "expense" => Ok(SubscriptionDirection::Expense),
        "income" => Ok(SubscriptionDirection::Income),
        _ => Err(SubscriptionServiceError::ValidationError(format!("invalid direction: {s}"))),
    }
}

fn direction_to_str(d: &SubscriptionDirection) -> String {
    match d { SubscriptionDirection::Expense => "expense".into(), SubscriptionDirection::Income => "income".into() }
}

fn cycle_to_str(c: &SubscriptionCycle) -> String {
    match c { SubscriptionCycle::Weekly => "weekly".into(), SubscriptionCycle::Monthly => "monthly".into(), SubscriptionCycle::Yearly => "yearly".into(), SubscriptionCycle::Custom {..} => "custom".into() }
}
```

**Important note:** `list_transactions` uses `self.transaction_repo.find_entries_by_transaction_id()`. This method must exist on the `TransactionRepository`. Check if it does — if not, add it as a new trait method + implementation in `transaction_repository.rs`.

- [ ] **Step 2: Build**

Run: `cd src-tauri && cargo build`

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/services/subscription_service.rs
git commit -m "feat(subscription): add SubscriptionService with CRUD and auto-recording"
```

---

### Task 6: Tauri commands — expose subscription operations

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/subscription_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create subscription commands**

Create `src-tauri/src/presentation/tauri_commands/subscription_commands.rs`:

```rust
use crate::application::dtos::{CreateSubscriptionDto, SubscriptionDto, SubscriptionFilters, UpdateSubscriptionDto};
use crate::application::services::subscription_service::{SubscriptionService, SubscriptionServiceError};
use crate::application::dtos::TransactionDto;
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteSubscriptionRepository, SqliteTransactionRepository,
};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

pub struct SubscriptionCommandState {
    pool: SqlitePool,
    subscription_service: SubscriptionService,
}

impl SubscriptionCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let subscription_repo = Arc::new(SqliteSubscriptionRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        Self {
            subscription_service: SubscriptionService::new(subscription_repo, account_repo, transaction_repo),
            pool,
        }
    }

    pub fn service(&self) -> &SubscriptionService { &self.subscription_service }
    pub fn pool(&self) -> &SqlitePool { &self.pool }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<SubscriptionCommandState> {
    Ok(SubscriptionCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn create_subscription(state: State<'_, SubscriptionCommandState>, dto: CreateSubscriptionDto) -> Result<String, String> {
    state.service().create(dto).await.map(|id| id.to_string()).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_subscriptions(state: State<'_, SubscriptionCommandState>, filters: Option<SubscriptionFilters>) -> Result<Vec<SubscriptionDto>, String> {
    let filters = filters.unwrap_or(SubscriptionFilters { direction: None, cycle: None, paused: None });
    state.service().list(filters).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_subscription(state: State<'_, SubscriptionCommandState>, id: String) -> Result<SubscriptionDto, String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().get_by_id(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_subscription(state: State<'_, SubscriptionCommandState>, dto: UpdateSubscriptionDto) -> Result<(), String> {
    state.service().update(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_subscription(state: State<'_, SubscriptionCommandState>, id: String) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().delete(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn pause_subscription(state: State<'_, SubscriptionCommandState>, id: String) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().pause(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn resume_subscription(state: State<'_, SubscriptionCommandState>, id: String) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().resume(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_subscription_transactions(state: State<'_, SubscriptionCommandState>, subscription_id: String) -> Result<Vec<TransactionDto>, String> {
    let id = Uuid::parse_str(&subscription_id).map_err(|e| e.to_string())?;
    state.service().list_transactions(id).await.map_err(|e| e.to_string())
}
```

- [ ] **Step 2: Register in commands/mod.rs**

Add to `src-tauri/src/presentation/tauri_commands/mod.rs`:
```rust
pub mod subscription_commands;
pub use subscription_commands::{
    create_subscription, create_default_state_from_pool, delete_subscription, get_subscription,
    list_subscription_transactions, list_subscriptions, pause_subscription, resume_subscription,
    update_subscription, SubscriptionCommandState,
};
```

- [ ] **Step 3: Register in main.rs**

Add to imports:
```rust
use presentation::tauri_commands::subscription_commands::{
    create_subscription, create_default_state_from_pool as create_subscription_default_state,
    delete_subscription, get_subscription, list_subscription_transactions, list_subscriptions,
    pause_subscription, resume_subscription, update_subscription,
    SubscriptionCommandState,
};
```

Add state initialization (after `let prepaid_state = ...`):
```rust
    let subscription_state: SubscriptionCommandState = create_subscription_default_state(pool.clone())
        .await
        .expect("failed to initialize subscription command state");
```

Add `.manage(subscription_state)` after `.manage(prepaid_state)`.

Add all 8 commands to `generate_handler![]`:
```
            create_subscription,
            list_subscriptions,
            get_subscription,
            update_subscription,
            delete_subscription,
            pause_subscription,
            resume_subscription,
            list_subscription_transactions,
```

Add scheduler in `.setup()` block after the reminder scheduler:
```rust
            // Start subscription auto-record scheduler
            let sub_service = subscription_state.service().clone();
            // NOTE: SubscriptionService is not Clone — instead use the pool to create a new service
            let sub_pool = pool.clone();
            tokio::spawn(async move {
                let sub_repo = Arc::new(SqliteSubscriptionRepository::new(sub_pool.clone()));
                let sub_acc_repo = Arc::new(SqliteAccountRepository::new(sub_pool.clone()));
                let sub_tx_repo = Arc::new(SqliteTransactionRepository::new(sub_pool.clone()));
                let sub_svc = SubscriptionService::new(sub_repo, sub_acc_repo, sub_tx_repo);
                let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300));
                loop {
                    interval.tick().await;
                    let today = chrono::Utc::now().date_naive();
                    if let Err(e) = sub_svc.process_due_subscriptions(today).await {
                        error!("Failed to process subscriptions: {}", e);
                    }
                }
            });
            info!("Subscription scheduler started (checking every 5 minutes)");
```

Add necessary imports at the top of main.rs:
```rust
use crate::application::services::subscription_service::SubscriptionService;
use crate::infrastructure::repositories::SqliteSubscriptionRepository;
```

- [ ] **Step 4: Build**

Run: `cd src-tauri && cargo build`

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/subscription_commands.rs src-tauri/src/presentation/tauri_commands/mod.rs src-tauri/src/main.rs
git commit -m "feat(subscription): add Tauri commands and scheduler integration"
```

---

### Task 7: Frontend API — subscription client

**Files:**
- Create: `src/lib/tauri/subscription.ts`

- [ ] **Step 1: Create API client**

Create `src/lib/tauri/subscription.ts`:

```typescript
import { invokeTauri } from '../tauri';

export interface CreateSubscriptionDto {
  name: string;
  amount: number;
  direction: 'expense' | 'income';
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_billing_date: string;
  start_date: string;
  end_date?: string | null;
  auto_record?: boolean;
  source_account_id: string;
  category?: string | null;
  description?: string | null;
}

export interface UpdateSubscriptionDto {
  id: string;
  name?: string;
  amount?: number;
  direction?: 'expense' | 'income';
  cycle?: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_billing_date?: string;
  end_date?: string | null;
  auto_record?: boolean;
  source_account_id?: string;
  category?: string | null;
  description?: string | null;
}

export interface SubscriptionDto {
  id: string;
  name: string;
  amount: number;
  direction: 'expense' | 'income';
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days: number | null;
  billing_day: number | null;
  next_billing_date: string;
  start_date: string;
  end_date: string | null;
  auto_record: boolean;
  paused: boolean;
  source_account_id: string;
  source_account_name: string;
  currency_code: string;
  category: string | null;
  description: string | null;
  last_transaction_id: string | null;
}

export interface SubscriptionFilters {
  direction?: string | null;
  cycle?: string | null;
  paused?: boolean | null;
}

export const createSubscription = (dto: CreateSubscriptionDto) =>
  invokeTauri<string>('create_subscription', { dto });

export const listSubscriptions = (filters?: SubscriptionFilters) =>
  invokeTauri<SubscriptionDto[]>('list_subscriptions', { filters: filters || null });

export const getSubscription = (id: string) =>
  invokeTauri<SubscriptionDto>('get_subscription', { id });

export const updateSubscription = (dto: UpdateSubscriptionDto) =>
  invokeTauri<void>('update_subscription', { dto });

export const deleteSubscription = (id: string) =>
  invokeTauri<void>('delete_subscription', { id });

export const pauseSubscription = (id: string) =>
  invokeTauri<void>('pause_subscription', { id });

export const resumeSubscription = (id: string) =>
  invokeTauri<void>('resume_subscription', { id });

export const listSubscriptionTransactions = (subscriptionId: string) =>
  invokeTauri<any[]>('list_subscription_transactions', { subscriptionId });
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/tauri/subscription.ts
git commit -m "feat(subscription): add frontend API client"
```

---

### Task 8: Frontend i18n + routing + navigation

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/router.tsx`
- Modify: `src/components/layout/Sidebar.tsx`

- [ ] **Step 1: Add Chinese translations**

Add to `zh.json` in the `"nav"` section:
```json
"subscriptions": "订阅"
```

Add a new `"subscription"` section:
```json
"subscription": {
  "title": "周期账单",
  "newSubscription": "新建订阅",
  "noSubscriptions": "还没有订阅",
  "firstSubscription": "记录第一个订阅",
  "createSuccess": "订阅创建成功",
  "updateSuccess": "订阅已更新",
  "deleteSuccess": "订阅已删除",
  "name": "名称",
  "amount": "金额",
  "direction": "方向",
  "expense": "支出",
  "income": "收入",
  "cycle": "周期",
  "weekly": "每周",
  "monthly": "每月",
  "yearly": "每年",
  "custom": "自定义",
  "cycleDays": "周期天数",
  "billingDay": "扣款日",
  "nextBillingDate": "下次扣款日",
  "startDate": "开始日期",
  "endDate": "结束日期",
  "autoRecord": "自动记账",
  "sourceAccount": "付款账户",
  "receiveAccount": "收款账户",
  "category": "分类",
  "description": "描述",
  "paused": "已暂停",
  "active": "活跃",
  "pause": "暂停",
  "resume": "恢复",
  "edit": "编辑",
  "delete": "删除",
  "all": "全部",
  "allCycles": "全部周期",
  "activeSubscriptions": "活跃订阅",
  "monthlyExpense": "本月订阅支出",
  "monthlyIncome": "本月订阅收入",
  "nextBilling": "最近扣款",
  "transactionHistory": "交易记录",
  "noTransactions": "暂无交易记录",
  "pausedLabel": "暂停中"
}
```

- [ ] **Step 2: Add English translations**

Add to `en.json` in the `"nav"` section:
```json
"subscriptions": "Subscriptions"
```

Add a new `"subscription"` section:
```json
"subscription": {
  "title": "Recurring Bills",
  "newSubscription": "New Subscription",
  "noSubscriptions": "No subscriptions yet",
  "firstSubscription": "Create your first subscription",
  "createSuccess": "Subscription created",
  "updateSuccess": "Subscription updated",
  "deleteSuccess": "Subscription deleted",
  "name": "Name",
  "amount": "Amount",
  "direction": "Direction",
  "expense": "Expense",
  "income": "Income",
  "cycle": "Cycle",
  "weekly": "Weekly",
  "monthly": "Monthly",
  "yearly": "Yearly",
  "custom": "Custom",
  "cycleDays": "Cycle Days",
  "billingDay": "Billing Day",
  "nextBillingDate": "Next Billing",
  "startDate": "Start Date",
  "endDate": "End Date",
  "autoRecord": "Auto Record",
  "sourceAccount": "Payment Account",
  "receiveAccount": "Receive Account",
  "category": "Category",
  "description": "Description",
  "paused": "Paused",
  "active": "Active",
  "pause": "Pause",
  "resume": "Resume",
  "edit": "Edit",
  "delete": "Delete",
  "all": "All",
  "allCycles": "All Cycles",
  "activeSubscriptions": "Active Subscriptions",
  "monthlyExpense": "Monthly Expense",
  "monthlyIncome": "Monthly Income",
  "nextBilling": "Next Billing",
  "transactionHistory": "Transaction History",
  "noTransactions": "No transactions yet",
  "pausedLabel": "Paused"
}
```

- [ ] **Step 3: Add route in router.tsx**

Import the page:
```typescript
import { SubscriptionsPage } from './pages/SubscriptionsPage';
```

Add route:
```typescript
const subscriptionsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'subscriptions',
  component: SubscriptionsPage,
});
```

Add to route tree:
```typescript
subscriptionsRoute,
```

- [ ] **Step 4: Add nav item in Sidebar.tsx**

Import icon:
```typescript
import { CalendarClock } from 'lucide-react';
```

Add after the holdings nav item:
```tsx
<SidebarMenuItem to="/subscriptions" label={t('nav.subscriptions')} icon={CalendarClock} />
```

- [ ] **Step 5: Verify TypeScript compiles**

Run: `npx tsc --noEmit`

- [ ] **Step 6: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json src/router.tsx src/components/layout/Sidebar.tsx
git commit -m "feat(subscription): add i18n, routing, and navigation"
```

---

### Task 9: Frontend UI — SubscriptionForm component

**Files:**
- Create: `src/components/SubscriptionForm.tsx`

- [ ] **Step 1: Create SubscriptionForm**

Create `src/components/SubscriptionForm.tsx`. This follows the DebtForm pattern — a form component rendered inside a Sheet, using react-hook-form + zod.

The form should have these fields:
- name (text, required)
- amount (number, required, ¥ prefix)
- direction (expense/income pill toggle)
- cycle (Select: weekly/monthly/yearly/custom)
- cycle_days (number, shown only when cycle=custom)
- billing_day (number, shown only when cycle=monthly or yearly)
- source_account_id (Select, filtered to non-deleted accounts)
- auto_record (Switch toggle, default true)
- next_billing_date (date, required)
- start_date (date, required, default today)
- end_date (date, optional)
- description (textarea, optional)

The component accepts props: `onSubmit`, `onCancel`, `initialValues?`, `isLoading`.

Use the same visual style as existing forms:
- `h-9` inputs, `text-xs uppercase tracking-wider text-muted-foreground` labels
- Money container with ¥ prefix for amount
- Pill toggle for direction (rounded-full bg-muted with bg-background active state)
- Submit button `variant="default-gradient"`, cancel `variant="outline"`

- [ ] **Step 2: Commit**

```bash
git add src/components/SubscriptionForm.tsx
git commit -m "feat(subscription): add SubscriptionForm component"
```

---

### Task 10: Frontend UI — SubscriptionsPage

**Files:**
- Create: `src/pages/SubscriptionsPage.tsx`

- [ ] **Step 1: Create SubscriptionsPage**

Create `src/pages/SubscriptionsPage.tsx`. This follows the HoldingsPage pattern:

**Summary cards** (top, 3 columns):
- 本月订阅支出 (sum of expense subscriptions' amount)
- 本月订阅收入 (sum of income subscriptions' amount)
- 活跃订阅数 (count of non-paused)

**Filter bar**:
- Cycle filter: Select (全部/每周/每月/每年/自定义)
- Direction toggle: Button group (全部/支出/收入)
- Search: Input

**Table** (same Table component as holdings):
- Columns: 名称, 金额, 周期, 方向, 下次扣款日, 状态, 操作
- Sort by: next_billing_date / amount / name
- Expandable rows (ChevronRight/ChevronDown) showing transaction history

**Actions per row**:
- 暂停/恢复 (pause/resume toggle)
- 编辑 (opens Sheet with SubscriptionForm)
- 删除 (confirmation inline)

**Create button** (top right): Opens Sheet with SubscriptionForm

Use `useQuery` for `listSubscriptions` and `useMutation` for create/update/delete/pause/resume with `queryClient.invalidateQueries`.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit`

- [ ] **Step 3: Commit**

```bash
git add src/pages/SubscriptionsPage.tsx
git commit -m "feat(subscription): add SubscriptionsPage with filters, sort, expand"
```

---

### Task 11: Verification

- [ ] **Step 1: Build Rust backend**

Run: `cd src-tauri && cargo build`
Expected: SUCCESS

- [ ] **Step 2: Build frontend**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 3: Launch app**

Run: `npm run tauri dev`

- [ ] **Step 4: Test create subscription**

Create a monthly expense subscription (e.g. Netflix ¥68, monthly, auto-record on).

- [ ] **Step 5: Verify subscription appears in list**

Check the SubscriptionsPage shows the new subscription with correct details.

- [ ] **Step 6: Test pause/resume**

Pause the subscription, verify it shows "已暂停" status. Resume it.

- [ ] **Step 7: Test edit**

Edit the subscription name/amount, verify changes persist.

- [ ] **Step 8: Test delete**

Delete a subscription, verify it disappears from the list.

- [ ] **Step 9: Test expand transaction history**

Click on a subscription row to expand and view any generated transactions (if auto-record has triggered or if manually created).
