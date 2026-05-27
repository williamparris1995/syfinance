# 储值消费功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有双记账系统中支持储值账户（先充值、后消费），包含超额校验和低余额预警。

**Architecture:** 采用账户扩展模式（方案A），对齐 `debt_details` 的设计模式。新增 `Prepaid` 账户类型到 `accounts` 表，新增 `top_up_records` 扩展表记录充值明细。充值复用转账交易，消费复用支出交易，余额计算复用现有 `compute_balances_for_all_accounts`。

**Tech Stack:** Rust + sqlx + SQLite (后端), React + TypeScript + TanStack Query + shadcn/ui (前端), Tauri 2.x (桌面壳)

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `src-tauri/migrations/20260527000001_add_prepaid_support.sql` | 数据库迁移：accounts 新增列、创建 top_up_records 表、新增科目 |
| `src-tauri/src/domain/value_objects/top_up_record.rs` | 充值记录值对象 |
| `src-tauri/src/domain/repositories/prepaid_repository.rs` | 预付仓库 trait |
| `src-tauri/src/infrastructure/repositories/prepaid_repository.rs` | SQLite 实现 |
| `src-tauri/src/application/dtos/prepaid_dto.rs` | 请求/响应 DTO |
| `src-tauri/src/application/services/prepaid_service.rs` | 核心业务逻辑 |
| `src-tauri/src/presentation/tauri_commands/prepaid_commands.rs` | Tauri 命令 |
| `src/lib/tauri/prepaid.ts` | 前端 API 类型 + invoke 函数 |
| `src/components/TopUpDialog.tsx` | 充值对话框组件 |
| `src/components/PrepaidDetailPanel.tsx` | 储值明细面板组件 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src-tauri/src/domain/aggregates/account.rs` | AccountType 新增 Prepaid 变体，Account 新增 low_balance_threshold 字段 |
| `src-tauri/src/domain/aggregates/mod.rs` | 导出 TopUpRecord |
| `src-tauri/src/domain/value_objects/mod.rs` | 新增 top_up_record 模块 |
| `src-tauri/src/domain/repositories/mod.rs` | 新增 prepaid_repository 模块 |
| `src-tauri/src/domain/aggregates/reminder.rs` | ReminderType 新增 PrepaidLowBalance 变体 |
| `src-tauri/src/infrastructure/repositories/mod.rs` | 新增 prepaid_repository 导出 |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | row_to_account 新增 prepaid 类型解析和 low_balance_threshold 字段 |
| `src-tauri/src/application/dtos/mod.rs` | 新增 prepaid_dto 模块 |
| `src-tauri/src/application/services/mod.rs` | 新增 prepaid_service 模块 |
| `src-tauri/src/application/services/transaction_service.rs` | create_expense 新增 prepaid 余额校验 |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | 新增 prepaid_commands 导出 |
| `src-tauri/src/main.rs` | 注册 prepaid 状态和命令 |
| `src/lib/tauri/account.ts` | AccountType 新增 Prepaid，新增 prepaid 相关类型 |
| `src/lib/tauri/index.ts` | 导出 prepaid 模块 |
| `src/components/AccountForm.tsx` | 新增 prepaid 类型选项和 low_balance_threshold 字段 |
| `src/components/SimpleTransactionForm.tsx` | 支出类型支持 prepaid 账户作为付款来源 |
| `src/pages/AccountsPage.tsx` | 储值账户卡片样式（余额、低余额警告、充值/明细按钮） |
| `src/lib/api/transactions.ts` | SimpleExpenseRequest 适配（确保 creditAccountId 支持 prepaid） |

---

## Task 1: 数据库迁移

**Files:**
- Create: `src-tauri/migrations/20260527000001_add_prepaid_support.sql`

- [ ] **Step 1: 编写迁移 SQL**

```sql
-- Migration: Add prepaid account support
-- 1. accounts 表新增 low_balance_threshold 列
ALTER TABLE accounts ADD COLUMN low_balance_threshold TEXT;

-- 2. 创建 top_up_records 扩展表
CREATE TABLE IF NOT EXISTS top_up_records (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    transaction_id TEXT REFERENCES transactions(id),
    paid_amount TEXT NOT NULL,
    bonus_amount TEXT NOT NULL DEFAULT '0',
    total_credited TEXT NOT NULL,
    top_up_date TEXT NOT NULL,
    expiry_date TEXT,
    source_account_id TEXT NOT NULL REFERENCES accounts(id),
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
);

-- 3. chart_of_accounts 新增科目
-- 1123 预付账款 (L2)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-1123', '1123', '预付账款', 2, 'asset', '1000', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- 1123 L3 子科目
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-112301', '112301', '储值卡', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-112302', '112302', '平台余额', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now')),
    ('coa-112303', '112303', '话费', 3, 'asset', '1123', 'debit', strftime('%Y-%m-%d %H:%M:%S', 'now'));

-- 490101 赠送/优惠收入 (L3)
INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
VALUES
    ('coa-490101', '490101', '赠送/优惠收入', 3, 'income', '4901', 'credit', strftime('%Y-%m-%d %H:%M:%S', 'now'));
```

- [ ] **Step 2: 验证迁移语法**

Run: `cd src-tauri && cargo build 2>&1 | head -20`
Expected: 编译成功（sqlx migrate 在运行时执行，编译不检查 SQL 内容）

- [ ] **Step 3: Commit**

```bash
git add src-tauri/migrations/20260527000001_add_prepaid_support.sql
git commit -m "feat(prepaid): add database migration for prepaid account support"
```

---

## Task 2: Domain 层 — AccountType + TopUpRecord + ReminderType

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs`
- Modify: `src-tauri/src/domain/aggregates/reminder.rs`
- Create: `src-tauri/src/domain/value_objects/top_up_record.rs`
- Modify: `src-tauri/src/domain/value_objects/mod.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`

- [ ] **Step 1: AccountType 新增 Prepaid**

在 `src-tauri/src/domain/aggregates/account.rs` 中：

`AccountType` 枚举新增变体：
```rust
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    BorrowedOut,
    BorrowedIn,
    Other,
    Income,
    Expense,
    Prepaid,  // 新增
}
```

`Display` impl 新增分支：
```rust
Self::Prepaid => write!(f, "prepaid"),
```

`Account` struct 新增字段（在 `interest_rate` 之后）：
```rust
pub low_balance_threshold: Option<Decimal>,
```

`Account::new()` 方法参数新增 `low_balance_threshold: Option<Decimal>`，在构造的 Self 中赋值。

`validate_balance()` 方法中，Prepaid 账户不应允许负余额，与 Cash/Bank/Investment/BorrowedOut 同组：
```rust
AccountType::Prepaid => {} // 与 Cash 等同组，不允许负余额
```

找到 `validate_balance` 中检查非负余额的 match 分支，将 `AccountType::Prepaid` 加入。

- [ ] **Step 2: ReminderType 新增 PrepaidLowBalance**

在 `src-tauri/src/domain/aggregates/reminder.rs` 中：

`ReminderType` 枚举新增：
```rust
pub enum ReminderType {
    DebtPayment,
    BillDue,
    Custom,
    PrepaidLowBalance,  // 新增
}
```

`as_str()` 新增：
```rust
Self::PrepaidLowBalance => "prepaid_low_balance",
```

`FromStr` 新增：
```rust
"prepaid_low_balance" => Ok(Self::PrepaidLowBalance),
```

- [ ] **Step 3: 创建 TopUpRecord 值对象**

创建 `src-tauri/src/domain/value_objects/top_up_record.rs`：
```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRecord {
    pub id: Uuid,
    pub account_id: Uuid,
    pub transaction_id: Option<Uuid>,
    pub paid_amount: Decimal,
    pub bonus_amount: Decimal,
    pub total_credited: Decimal,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub source_account_id: Uuid,
    pub description: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl TopUpRecord {
    pub fn new(
        id: Uuid,
        account_id: Uuid,
        transaction_id: Option<Uuid>,
        paid_amount: Decimal,
        bonus_amount: Decimal,
        top_up_date: NaiveDate,
        expiry_date: Option<NaiveDate>,
        source_account_id: Uuid,
        description: Option<String>,
    ) -> Self {
        let total_credited = paid_amount + bonus_amount;
        let now = chrono::Utc::now();
        Self {
            id,
            account_id,
            transaction_id,
            paid_amount,
            bonus_amount,
            total_credited,
            top_up_date,
            expiry_date,
            source_account_id,
            description,
            created_at: now,
            updated_at: now,
        }
    }
}
```

- [ ] **Step 4: 注册模块**

在 `src-tauri/src/domain/value_objects/mod.rs` 中新增：
```rust
pub mod top_up_record;
pub use top_up_record::TopUpRecord;
```

在 `src-tauri/src/domain/aggregates/mod.rs` 的 pub use 行中确认 AccountType/Ownership 已导出（它们已经在）。

- [ ] **Step 5: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -5`
Expected: 编译可能有未使用警告，但不应有错误

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/domain/
git commit -m "feat(prepaid): add Prepaid account type, TopUpRecord value object, and PrepaidLowBalance reminder"
```

---

## Task 3: Domain 层 — Prepaid Repository Trait + Account Repository 更新

**Files:**
- Create: `src-tauri/src/domain/repositories/prepaid_repository.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs`

- [ ] **Step 1: 创建 PrepaidRepository trait**

创建 `src-tauri/src/domain/repositories/prepaid_repository.rs`：
```rust
use crate::domain::value_objects::TopUpRecord;
use uuid::Uuid;

#[allow(async_fn_in_trait)]
pub trait PrepaidRepository: Send + Sync {
    async fn create_top_up_record(&self, record: &TopUpRecord) -> sqlx::Result<()>;
    async fn find_top_up_records_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<TopUpRecord>>;
    async fn find_top_up_record_by_id(&self, id: Uuid) -> sqlx::Result<Option<TopUpRecord>>;
    async fn find_top_up_record_by_transaction(&self, transaction_id: Uuid) -> sqlx::Result<Option<TopUpRecord>>;
}
```

- [ ] **Step 2: 注册模块**

在 `src-tauri/src/domain/repositories/mod.rs` 中新增：
```rust
mod prepaid_repository;
pub use prepaid_repository::PrepaidRepository;
```

- [ ] **Step 3: 更新 Account Repository 的 row_to_account**

在 `src-tauri/src/infrastructure/repositories/account_repository.rs` 的 `row_to_account` 函数中：

`account_type` match 新增：
```rust
"prepaid" => AccountType::Prepaid,
```

在构建 `Account` struct 的位置（约第 147 行），`interest_rate` 字段之后、`sync_metadata` 之前新增：
```rust
low_balance_threshold: {
    let s: Option<String> = row.try_get("low_balance_threshold")?;
    s.map(|v| Decimal::from_str(&v))
        .transpose()
        .map_err(|e: rust_decimal::Error| sqlx::Error::Decode(format!("low_balance_threshold: {e}").into()))?
},
```

同样需要更新 `create` 和 `update` 方法中的 INSERT/UPDATE SQL，加入 `low_balance_threshold` 列（作为 TEXT 存储的 Decimal）。在 INSERT 时将 `low_balance_threshold` 用 `.map(|d| d.to_string()).unwrap_or_default()` 或 NULL 处理。

- [ ] **Step 4: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -5`
Expected: 编译通过

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/repositories/ src-tauri/src/infrastructure/repositories/account_repository.rs
git commit -m "feat(prepaid): add PrepaidRepository trait and update account repo for prepaid type"
```

---

## Task 4: Infrastructure 层 — Prepaid Repository SQLite 实现

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/prepaid_repository.rs`
- Modify: `src-tauri/src/infrastructure/repositories/mod.rs`

- [ ] **Step 1: 实现 SqlitePrepaidRepository**

创建 `src-tauri/src/infrastructure/repositories/prepaid_repository.rs`：
```rust
use crate::domain::repositories::PrepaidRepository;
use crate::domain::value_objects::TopUpRecord;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use uuid::Uuid;

#[derive(Clone)]
pub struct SqlitePrepaidRepository {
    pool: SqlitePool,
}

impl SqlitePrepaidRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_top_up_record(row: &sqlx::sqlite::SqliteRow) -> Result<TopUpRecord, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let id = Uuid::from_str(&id_str)
            .map_err(|e| sqlx::Error::Decode(format!("id: {e}").into()))?;

        let account_id_str: String = row.try_get("account_id")?;
        let account_id = Uuid::from_str(&account_id_str)
            .map_err(|e| sqlx::Error::Decode(format!("account_id: {e}").into()))?;

        let transaction_id_str: Option<String> = row.try_get("transaction_id")?;
        let transaction_id = transaction_id_str
            .map(|s| Uuid::from_str(&s))
            .transpose()
            .map_err(|e: uuid::Error| sqlx::Error::Decode(format!("transaction_id: {e}").into()))?;

        let paid_amount_str: String = row.try_get("paid_amount")?;
        let paid_amount = Decimal::from_str(&paid_amount_str)
            .map_err(|e| sqlx::Error::Decode(format!("paid_amount: {e}").into()))?;

        let bonus_amount_str: String = row.try_get("bonus_amount")?;
        let bonus_amount = Decimal::from_str(&bonus_amount_str)
            .map_err(|e| sqlx::Error::Decode(format!("bonus_amount: {e}").into()))?;

        let total_credited_str: String = row.try_get("total_credited")?;
        let total_credited = Decimal::from_str(&total_credited_str)
            .map_err(|e| sqlx::Error::Decode(format!("total_credited: {e}").into()))?;

        let top_up_date_str: String = row.try_get("top_up_date")?;
        let top_up_date = NaiveDate::parse_from_str(&top_up_date_str, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(format!("top_up_date: {e}").into()))?;

        let expiry_date_str: Option<String> = row.try_get("expiry_date")?;
        let expiry_date = expiry_date_str
            .map(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d"))
            .transpose()
            .map_err(|e: chrono::ParseError| sqlx::Error::Decode(format!("expiry_date: {e}").into()))?;

        let source_account_id_str: String = row.try_get("source_account_id")?;
        let source_account_id = Uuid::from_str(&source_account_id_str)
            .map_err(|e| sqlx::Error::Decode(format!("source_account_id: {e}").into()))?;

        let description: Option<String> = row.try_get("description")?;

        let created_at_str: String = row.try_get("created_at")?;
        let created_at = parse_sqlite_datetime(&created_at_str)
            .map_err(|e| sqlx::Error::Decode(format!("created_at: {e}").into()))?;

        let updated_at_str: String = row.try_get("updated_at")?;
        let updated_at = parse_sqlite_datetime(&updated_at_str)
            .map_err(|e| sqlx::Error::Decode(format!("updated_at: {e}").into()))?;

        Ok(TopUpRecord {
            id,
            account_id,
            transaction_id,
            paid_amount,
            bonus_amount,
            total_credited,
            top_up_date,
            expiry_date,
            source_account_id,
            description,
            created_at,
            updated_at,
        })
    }

    async fn create_top_up_record(&self, record: &TopUpRecord) -> sqlx::Result<()> {
        sqlx::query(
            r#"INSERT INTO top_up_records (id, account_id, transaction_id, paid_amount, bonus_amount, total_credited, top_up_date, expiry_date, source_account_id, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"#
        )
        .bind(record.id.to_string())
        .bind(record.account_id.to_string())
        .bind(record.transaction_id.map(|id| id.to_string()))
        .bind(record.paid_amount.to_string())
        .bind(record.bonus_amount.to_string())
        .bind(record.total_credited.to_string())
        .bind(record.top_up_date.format("%Y-%m-%d").to_string())
        .bind(record.expiry_date.map(|d| d.format("%Y-%m-%d").to_string()))
        .bind(record.source_account_id.to_string())
        .bind(&record.description)
        .bind(record.created_at.format("%Y-%m-%d %H:%M:%S").to_string())
        .bind(record.updated_at.format("%Y-%m-%d %H:%M:%S").to_string())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn find_top_up_records_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<TopUpRecord>> {
        let rows = sqlx::query("SELECT * FROM top_up_records WHERE account_id = ? ORDER BY top_up_date DESC")
            .bind(account_id.to_string())
            .fetch_all(&self.pool)
            .await?;
        rows.iter().map(|r| Self::row_to_top_up_record(r)).collect()
    }

    async fn find_top_up_record_by_id(&self, id: Uuid) -> sqlx::Result<Option<TopUpRecord>> {
        let row = sqlx::query("SELECT * FROM top_up_records WHERE id = ?")
            .bind(id.to_string())
            .fetch_optional(&self.pool)
            .await?;
        row.map(|r| Self::row_to_top_up_record(&r)).transpose()
    }

    async fn find_top_up_record_by_transaction(&self, transaction_id: Uuid) -> sqlx::Result<Option<TopUpRecord>> {
        let row = sqlx::query("SELECT * FROM top_up_records WHERE transaction_id = ?")
            .bind(transaction_id.to_string())
            .fetch_optional(&self.pool)
            .await?;
        row.map(|r| Self::row_to_top_up_record(&r)).transpose()
    }
}

fn parse_sqlite_datetime(s: &str) -> Result<DateTime<Utc>, chrono::ParseError> {
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return Ok(dt.with_timezone(&Utc));
    }
    chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S")
        .map(|ndt| DateTime::<Utc>::from_naive_utc_and_offset(ndt, Utc))
}
```

- [ ] **Step 2: 注册模块**

在 `src-tauri/src/infrastructure/repositories/mod.rs` 中新增：
```rust
pub mod prepaid_repository;
pub use prepaid_repository::SqlitePrepaidRepository;
```

- [ ] **Step 3: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -5`
Expected: 编译通过

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/
git commit -m "feat(prepaid): add SqlitePrepaidRepository implementation"
```

---

## Task 5: Application 层 — DTOs

**Files:**
- Create: `src-tauri/src/application/dtos/prepaid_dto.rs`
- Modify: `src-tauri/src/application/dtos/mod.rs`

- [ ] **Step 1: 创建 DTOs**

创建 `src-tauri/src/application/dtos/prepaid_dto.rs`：
```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRequest {
    pub account_id: Uuid,
    pub source_account_id: Uuid,
    pub paid_amount: Decimal,
    pub bonus_amount: Option<Decimal>,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRecordDto {
    pub id: Uuid,
    pub account_id: Uuid,
    pub transaction_id: Option<Uuid>,
    pub paid_amount: String,
    pub bonus_amount: String,
    pub total_credited: String,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub source_account_id: Uuid,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrepaidDetailDto {
    pub account_id: Uuid,
    pub account_name: String,
    pub currency_code: String,
    pub current_balance: String,
    pub total_top_ups: String,
    pub total_consumption: String,
    pub low_balance_threshold: Option<String>,
    pub top_up_records: Vec<TopUpRecordDto>,
}
```

- [ ] **Step 2: 注册模块**

在 `src-tauri/src/application/dtos/mod.rs` 中新增：
```rust
pub mod prepaid_dto;
pub use prepaid_dto::*;
```

- [ ] **Step 3: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -5`
Expected: 编译通过

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/dtos/
git commit -m "feat(prepaid): add prepaid DTOs"
```

---

## Task 6: Application 层 — Prepaid Service

**Files:**
- Create: `src-tauri/src/application/services/prepaid_service.rs`
- Modify: `src-tauri/src/application/services/mod.rs`

- [ ] **Step 1: 创建 PrepaidService**

创建 `src-tauri/src/application/services/prepaid_service.rs`。

这个服务需要：
- 持有 `SqlitePrepaidRepository`、`SqliteAccountRepository`、`SqliteTransactionRepository`（Arc 包装）
- `PrepaidServiceError` 错误枚举
- `top_up()` 方法：创建充值交易 + top_up_record
- `get_prepaid_detail()` 方法：获取储值明细
- `get_top_up_records()` 方法：获取充值记录列表
- `check_low_balance_alert()` 方法：检查低余额并创建提醒

```rust
use crate::application::dtos::prepaid_dto::*;
use crate::domain::aggregates::{AccountType, Ownership, Reminder, ReminderType, RepeatPattern, Transaction};
use crate::domain::repositories::{AccountRepository, PrepaidRepository, TransactionRepository};
use crate::domain::value_objects::{Money, SyncMetadata, TopUpRecord, TransactionEntry};
use chrono::Utc;
use rust_decimal::Decimal;
use std::str::FromStr;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Debug)]
pub enum PrepaidServiceError {
    AccountNotFound(Uuid),
    NotPrepaidAccount(Uuid),
    SourceAccountNotFound(Uuid),
    InsufficientBalance { balance: Decimal, requested: Decimal },
    RepositoryError(String),
    TransactionError(String),
}

impl std::fmt::Display for PrepaidServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AccountNotFound(id) => write!(f, "Account not found: {id}"),
            Self::NotPrepaidAccount(id) => write!(f, "Account is not a prepaid account: {id}"),
            Self::SourceAccountNotFound(id) => write!(f, "Source account not found: {id}"),
            Self::InsufficientBalance { balance, requested } => {
                write!(f, "Insufficient prepaid balance: {balance} < {requested}")
            }
            Self::RepositoryError(e) => write!(f, "Repository error: {e}"),
            Self::TransactionError(e) => write!(f, "Transaction error: {e}"),
        }
    }
}

impl std::error::Error for PrepaidServiceError {}

impl From<sqlx::Error> for PrepaidServiceError {
    fn from(e: sqlx::Error) -> Self {
        Self::RepositoryError(e.to_string())
    }
}

pub struct PrepaidService<
    PR: PrepaidRepository,
    AR: AccountRepository,
    TR: TransactionRepository,
> {
    prepaid_repo: Arc<PR>,
    account_repo: Arc<AR>,
    transaction_repo: Arc<TR>,
}

impl<
    PR: PrepaidRepository,
    AR: AccountRepository,
    TR: TransactionRepository,
> PrepaidService<PR, AR, TR>
{
    pub fn new(
        prepaid_repo: Arc<PR>,
        account_repo: Arc<AR>,
        transaction_repo: Arc<TR>,
    ) -> Self {
        Self { prepaid_repo, account_repo, transaction_repo }
    }

    /// 充值：创建交易 + top_up_record
    pub async fn top_up(&self, request: TopUpRequest) -> Result<(Uuid, TopUpRecordDto), PrepaidServiceError> {
        let prepaid_account = self.account_repo
            .find_by_id(request.account_id)
            .await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?
            .ok_or(PrepaidServiceError::AccountNotFound(request.account_id))?;

        if prepaid_account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(request.account_id));
        }

        let source_account = self.account_repo
            .find_by_id(request.source_account_id)
            .await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?
            .ok_or(PrepaidServiceError::SourceAccountNotFound(request.source_account_id))?;

        let bonus = request.bonus_amount.unwrap_or(Decimal::ZERO);
        let total_credited = request.paid_amount + bonus;

        let currency = &prepaid_account.currency_code;

        // 构建交易分录
        let mut entries = Vec::new();

        // 借：储值账户（资产增加）
        entries.push(TransactionEntry::new(
            Uuid::new_v4(),
            request.account_id,
            prepaid_account.chart_code.clone().unwrap_or_else(|| "1123".to_string()),
            Some(Money::new(total_credited, currency).map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?),
            None,
            Some("充值".to_string()),
        ));

        // 贷：来源账户（资产减少）
        entries.push(TransactionEntry::new(
            Uuid::new_v4(),
            request.source_account_id,
            source_account.chart_code.clone().unwrap_or_else(|| "1002".to_string()),
            None,
            Some(Money::new(request.paid_amount, currency).map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?),
            Some(request.description.clone().unwrap_or_default()),
        ));

        // 如果有赠送金额，加一条贷方分录（其他收入）
        if bonus > Decimal::ZERO {
            // 需要找到或使用一个赠送收入账户（external income, chart_code 4901）
            // 这里使用已有的 external income 账户，或创建一条直接引用 chart_code 的分录
            entries.push(TransactionEntry::new(
                Uuid::new_v4(),
                // 赠送收入需要一个 external income 账户 ID
                // 使用 account_repo 查找 chart_code 为 "4901" 或 "490101" 的 external income 账户
                // 如果找不到，使用一个默认账户
                self.find_bonus_income_account().await?,
                "490101".to_string(),
                None,
                Some(Money::new(bonus, currency).map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?),
                Some("赠送金额".to_string()),
            ));
        }

        let transaction = Transaction::new(
            Uuid::new_v4(),
            request.top_up_date,
            request.description.clone().unwrap_or_else(|| "储值充值".to_string()),
            entries,
        ).map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;

        let transaction_id = transaction.id;

        // 持久化交易
        self.transaction_repo.create(&transaction).await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?;

        // 创建充值记录
        let record = TopUpRecord::new(
            Uuid::new_v4(),
            request.account_id,
            Some(transaction_id),
            request.paid_amount,
            bonus,
            request.top_up_date,
            request.expiry_date,
            request.source_account_id,
            request.description,
        );

        self.prepaid_repo.create_top_up_record(&record).await?;

        Ok((transaction_id, self.to_top_up_record_dto(&record)))
    }

    /// 获取储值账户明细
    pub async fn get_prepaid_detail(&self, account_id: Uuid) -> Result<PrepaidDetailDto, PrepaidServiceError> {
        let account = self.account_repo
            .find_by_id(account_id)
            .await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        if account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(account_id));
        }

        let balances = self.account_repo.compute_balances_for_all_accounts().await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?;

        let balance = balances.get(&account_id)
            .map(|b| *b)
            .unwrap_or(Decimal::ZERO)
            + account.initial_balance.amount();

        let records = self.prepaid_repo.find_top_up_records_by_account(account_id).await?;

        let total_top_ups: Decimal = records.iter().map(|r| r.total_credited).sum();

        let total_consumption = total_top_ups - balance;

        let top_up_dtos: Vec<TopUpRecordDto> = records.iter().map(|r| self.to_top_up_record_dto(r)).collect();

        Ok(PrepaidDetailDto {
            account_id,
            account_name: account.name,
            currency_code: account.currency_code,
            current_balance: balance.to_string(),
            total_top_ups: total_top_ups.to_string(),
            total_consumption: total_consumption.to_string(),
            low_balance_threshold: account.low_balance_threshold.map(|d| d.to_string()),
            top_up_records: top_up_dtos,
        })
    }

    /// 获取充值记录列表
    pub async fn get_top_up_records(&self, account_id: Uuid) -> Result<Vec<TopUpRecordDto>, PrepaidServiceError> {
        let records = self.prepaid_repo.find_top_up_records_by_account(account_id).await?;
        Ok(records.iter().map(|r| self.to_top_up_record_dto(r)).collect())
    }

    /// 检查余额是否充足
    pub async fn check_balance_sufficient(
        &self,
        account_id: Uuid,
        amount: Decimal,
    ) -> Result<bool, PrepaidServiceError> {
        let account = self.account_repo
            .find_by_id(account_id)
            .await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        let balances = self.account_repo.compute_balances_for_all_accounts().await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?;

        let balance = balances.get(&account_id)
            .map(|b| *b)
            .unwrap_or(Decimal::ZERO)
            + account.initial_balance.amount();

        Ok(balance >= amount)
    }

    /// 检查低余额并创建提醒
    pub async fn check_low_balance_alert(&self, account_id: Uuid) -> Result<Option<Uuid>, PrepaidServiceError> {
        let account = self.account_repo
            .find_by_id(account_id)
            .await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        let threshold = match account.low_balance_threshold {
            Some(t) => t,
            None => return Ok(None),
        };

        let balances = self.account_repo.compute_balances_for_all_accounts().await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?;

        let balance = balances.get(&account_id)
            .map(|b| *b)
            .unwrap_or(Decimal::ZERO)
            + account.initial_balance.amount();

        if balance < threshold {
            // 创建低余额提醒
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::PrepaidLowBalance,
                Some(account_id),
                format!("{} 余额不足", account.name),
                format!("当前余额: {}，低于阈值: {}", balance, threshold),
                Utc::now(),
                None,
                crate::domain::aggregates::Priority::High,
                SyncMetadata::new(Uuid::new_v4()),
            ).map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;

            Ok(Some(reminder.id))
        } else {
            Ok(None)
        }
    }

    async fn find_bonus_income_account(&self) -> Result<Uuid, PrepaidServiceError> {
        // 查找 chart_code 为 4901 或 490101 的 external income 账户
        let all_accounts = self.account_repo.find_all().await
            .map_err(|e| PrepaidServiceError::RepositoryError(e.to_string()))?;

        let income_account = all_accounts.iter().find(|a| {
            a.ownership == Ownership::External
                && a.account_type == AccountType::Income
                && a.chart_code.as_deref() == Some("4901")
        });

        match income_account {
            Some(a) => Ok(a.id),
            None => {
                // 回退：找任意 external income 账户
                let fallback = all_accounts.iter().find(|a| {
                    a.ownership == Ownership::External && a.account_type == AccountType::Income
                });
                fallback.map(|a| a.id).ok_or_else(|| PrepaidServiceError::RepositoryError("No income account found for bonus".to_string()))
            }
        }
    }

    fn to_top_up_record_dto(&self, record: &TopUpRecord) -> TopUpRecordDto {
        TopUpRecordDto {
            id: record.id,
            account_id: record.account_id,
            transaction_id: record.transaction_id,
            paid_amount: record.paid_amount.to_string(),
            bonus_amount: record.bonus_amount.to_string(),
            total_credited: record.total_credited.to_string(),
            top_up_date: record.top_up_date,
            expiry_date: record.expiry_date,
            source_account_id: record.source_account_id,
            description: record.description.clone(),
        }
    }
}
```

- [ ] **Step 2: 注册模块**

在 `src-tauri/src/application/services/mod.rs` 中新增：
```rust
pub mod prepaid_service;
pub use prepaid_service::PrepaidService;
```

- [ ] **Step 3: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -10`
Expected: 可能有未使用警告，但无错误

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/services/
git commit -m "feat(prepaid): add PrepaidService with top-up, balance check, and low balance alert"
```

---

## Task 7: Application 层 — Transaction Service 修改

**Files:**
- Modify: `src-tauri/src/application/services/transaction_service.rs`

- [ ] **Step 1: 在 create_expense 中新增 prepaid 余额校验**

在 `src-tauri/src/application/services/transaction_service.rs` 的 `create_expense` 方法中，在查找 credit_account 之后、创建 entries 之前，新增：

```rust
// 检查储值账户余额是否充足
if credit_account.account_type == AccountType::Prepaid {
    let balances = self.account_repo.compute_balances_for_all_accounts().await
        .map_err(|e| TransactionError::RepositoryError(e.to_string()))?;
    let balance = balances.get(&dto.credit_account_id)
        .map(|b| *b)
        .unwrap_or(Decimal::ZERO)
        + credit_account.initial_balance.amount();
    if balance < money.amount() {
        return Err(TransactionError::ValidationError(
            format!("储值余额不足: {} < {}", balance, money.amount())
        ));
    }
}
```

注意：需要在文件顶部确保 `AccountType` 已导入（通常已通过 `use crate::domain::aggregates::*` 导入）。

- [ ] **Step 2: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -5`
Expected: 编译通过

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/services/transaction_service.rs
git commit -m "feat(prepaid): add prepaid balance validation to expense creation"
```

---

## Task 8: Presentation 层 — Tauri Commands + Main.rs 注册

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/prepaid_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: 创建 Prepaid Commands**

创建 `src-tauri/src/presentation/tauri_commands/prepaid_commands.rs`：

```rust
use crate::application::dtos::prepaid_dto::*;
use crate::application::services::prepaid_service::PrepaidService;
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqlitePrepaidRepository, SqliteTransactionRepository,
};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

pub struct PrepaidCommandState {
    service: PrepaidService<SqlitePrepaidRepository, SqliteAccountRepository, SqliteTransactionRepository>,
}

impl PrepaidCommandState {
    pub async fn from_pool(pool: SqlitePool) -> Result<Self, String> {
        let prepaid_repo = Arc::new(SqlitePrepaidRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool));

        // Run migrations for the new tables
        let migrate_options = sqlx::sqlite::SqliteConnectOptions::from_str(&format!("sqlite:"))
            .map_err(|e| e.to_string())?;
        // Tables already created by migration system, no need to run here

        Ok(Self {
            service: PrepaidService::new(prepaid_repo, account_repo, transaction_repo),
        })
    }

    pub fn service(&self) -> &PrepaidService<SqlitePrepaidRepository, SqliteAccountRepository, SqliteTransactionRepository> {
        &self.service
    }
}

#[tauri::command]
pub async fn top_up(state: State<'_, PrepaidCommandState>, request: TopUpRequest) -> Result<String, String> {
    let (transaction_id, _record) = state.service().top_up(request).await
        .map_err(|e| e.to_string())?;
    Ok(transaction_id.to_string())
}

#[tauri::command]
pub async fn get_prepaid_detail(state: State<'_, PrepaidCommandState>, account_id: String) -> Result<PrepaidDetailDto, String> {
    let id = uuid::Uuid::parse_str(&account_id).map_err(|e| e.to_string())?;
    state.service().get_prepaid_detail(id).await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_top_up_records(state: State<'_, PrepaidCommandState>, account_id: String) -> Result<Vec<TopUpRecordDto>, String> {
    let id = uuid::Uuid::parse_str(&account_id).map_err(|e| e.to_string())?;
    state.service().get_top_up_records(id).await
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2: 更新 mod.rs**

在 `src-tauri/src/presentation/tauri_commands/mod.rs` 中新增：
```rust
pub mod prepaid_commands;
pub use prepaid_commands::{
    get_prepaid_detail, get_top_up_records, top_up, PrepaidCommandState,
};
```

- [ ] **Step 3: 更新 main.rs**

在 `main.rs` 的 import 块中新增：
```rust
use presentation::tauri_commands::{
    prepaid_commands::{
        get_prepaid_detail, get_top_up_records, top_up, PrepaidCommandState,
    },
    // ... 现有的 imports 保持不变
};
```

在 state 创建块中（约第 119 行之后）新增：
```rust
let prepaid_state = PrepaidCommandState::from_pool(pool.clone())
    .await
    .expect("failed to initialize prepaid command state");
```

在 `.manage()` 块中新增：
```rust
.manage(prepaid_state)
```

在 `tauri::generate_handler![]` 中新增命令：
```rust
top_up,
get_prepaid_detail,
get_top_up_records,
```

- [ ] **Step 4: 编译验证**

Run: `cd src-tauri && cargo build 2>&1 | tail -10`
Expected: 编译通过

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/ src-tauri/src/main.rs
git commit -m "feat(prepaid): add Tauri commands and register in main.rs"
```

---

## Task 9: 后端完整编译验证

**Files:** 无新增/修改

- [ ] **Step 1: 完整编译**

Run: `cd src-tauri && cargo build 2>&1`
Expected: 编译成功，可接受 unused warnings

- [ ] **Step 2: 运行现有测试**

Run: `cd src-tauri && cargo test 2>&1 | tail -20`
Expected: 所有现有测试通过

---

## Task 10: Frontend — TypeScript 类型和 API 函数

**Files:**
- Create: `src/lib/tauri/prepaid.ts`
- Modify: `src/lib/tauri/index.ts`
- Modify: `src/lib/tauri/account.ts`

- [ ] **Step 1: 更新 AccountType**

在 `src/lib/tauri/account.ts` 中：

`AccountType` 类型新增：
```typescript
export type AccountType = 'Cash' | 'Bank' | 'CreditCard' | 'Investment' | 'BorrowedOut' | 'BorrowedIn' | 'Other' | 'Income' | 'Expense' | 'Prepaid';
```

`CreateAccountDto` 和 `UpdateAccountDto` 中新增可选字段：
```typescript
low_balance_threshold?: number;
```

- [ ] **Step 2: 创建 prepaid.ts**

创建 `src/lib/tauri/prepaid.ts`：
```typescript
import { invokeTauri } from '../tauri';

export interface TopUpRequest {
  account_id: string;
  source_account_id: string;
  paid_amount: number;
  bonus_amount?: number;
  top_up_date: string; // YYYY-MM-DD
  expiry_date?: string; // YYYY-MM-DD
  description?: string;
}

export interface TopUpRecordDto {
  id: string;
  account_id: string;
  transaction_id: string | null;
  paid_amount: string;
  bonus_amount: string;
  total_credited: string;
  top_up_date: string;
  expiry_date: string | null;
  source_account_id: string;
  description: string | null;
}

export interface PrepaidDetailDto {
  account_id: string;
  account_name: string;
  currency_code: string;
  current_balance: string;
  total_top_ups: string;
  total_consumption: string;
  low_balance_threshold: string | null;
  top_up_records: TopUpRecordDto[];
}

export async function topUp(request: TopUpRequest): Promise<string> {
  return invokeTauri<string>('top_up', { request });
}

export async function getPrepaidDetail(accountId: string): Promise<PrepaidDetailDto> {
  return invokeTauri<PrepaidDetailDto>('get_prepaid_detail', { accountId });
}

export async function getTopUpRecords(accountId: string): Promise<TopUpRecordDto[]> {
  return invokeTauri<TopUpRecordDto[]>('get_top_up_records', { accountId });
}
```

- [ ] **Step 3: 更新 index.ts**

在 `src/lib/tauri/index.ts` 中新增导出：
```typescript
export * from './prepaid';
```

- [ ] **Step 4: Commit**

```bash
git add src/lib/tauri/
git commit -m "feat(prepaid): add frontend types and API functions"
```

---

## Task 11: Frontend — AccountForm 新增 Prepaid 支持

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: AccountForm 修改**

在 `AccountForm.tsx` 中：

1. 在 ownership='own' 对应的 account_type 选项中新增 `Prepaid`：
```typescript
{ value: 'Prepaid', label: t('accounts.types.prepaid', '储值账户') }
```

2. 当 `account_type === 'Prepaid'` 时，显示额外字段：
```tsx
{accountForm.watch('account_type') === 'Prepaid' && (
  <FormField
    control={accountForm.control}
    name="low_balance_threshold"
    render={({ field }) => (
      <FormItem>
        <FormLabel>{t('accounts.lowBalanceThreshold', '低余额预警阈值')}</FormLabel>
        <FormControl>
          <Input type="number" step="0.01" placeholder="200.00" {...field} />
        </FormControl>
      </FormItem>
    )}
  />
)}
```

3. 在 zod schema 中为 `low_balance_threshold` 添加可选的 number 验证。

4. 在提交时将 `low_balance_threshold` 包含在 DTO 中（仅当 account_type 为 Prepaid 时）。

5. 设置 Prepaid 账户的默认 `chart_code` 为 `'1123'`。

- [ ] **Step 2: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat(prepaid): add Prepaid account type to AccountForm with low balance threshold"
```

---

## Task 12: Frontend — TopUpDialog 组件

**Files:**
- Create: `src/components/TopUpDialog.tsx`

- [ ] **Step 1: 创建 TopUpDialog**

创建 `src/components/TopUpDialog.tsx`。组件接收 props：
```typescript
interface TopUpDialogProps {
  accountId: string;
  accountName: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}
```

组件内容：
- 使用 `react-hook-form` + `zod` 验证
- 字段：付款账户（下拉选择 own Cash/Bank 账户）、充值金额（必填 number）、赠送金额（可选 number）、有效期（可选 date）、备注（可选 text）
- 底部预览区显示：实际入账 = 充值金额 + 赠送金额
- 提交调用 `topUp()` API
- 使用 shadcn/ui 的 Sheet 或 Dialog 组件

- [ ] **Step 2: Commit**

```bash
git add src/components/TopUpDialog.tsx
git commit -m "feat(prepaid): add TopUpDialog component"
```

---

## Task 13: Frontend — PrepaidDetailPanel 组件

**Files:**
- Create: `src/components/PrepaidDetailPanel.tsx`

- [ ] **Step 1: 创建 PrepaidDetailPanel**

创建 `src/components/PrepaidDetailPanel.tsx`。组件接收 props：
```typescript
interface PrepaidDetailPanelProps {
  accountId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}
```

组件内容：
- 顶部三个指标卡：当前余额、累计充值、累计消费（使用 `getPrepaidDetail` 查询）
- Tab 切换：充值记录 / 消费记录
- 充值记录列表：每条显示描述、日期、来源账户、入账金额、实付/赠送明细
- 消费记录列表：通过 `getTransactionsByAccount` 获取该账户作为 credit 方的交易
- 使用 shadcn/ui 的 Sheet 组件

- [ ] **Step 2: Commit**

```bash
git add src/components/PrepaidDetailPanel.tsx
git commit -m "feat(prepaid): add PrepaidDetailPanel component"
```

---

## Task 14: Frontend — SimpleTransactionForm 支持 Prepaid

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

- [ ] **Step 1: SimpleTransactionForm 修改**

在 `SimpleTransactionForm.tsx` 中：

1. 在 expense 类型的付款账户过滤中，确保 `Prepaid` 类型账户包含在 `filteredOwnAccounts` 中。当前代码已经按 `ownership === 'own'` 过滤，Prepaid 的 ownership 就是 'own'，所以应该已经包含。验证一下过滤逻辑是否正确。

2. 当用户选择了 Prepaid 账户作为付款来源时，在金额输入旁显示当前余额提示：
```tsx
{selectedAccount?.account_type === 'Prepaid' && prepaidBalance !== null && (
  <p className="text-sm text-muted-foreground">
    当前余额: ¥{prepaidBalance.toFixed(2)}
  </p>
)}
```

3. 需要用 `useQuery` 或 `getAccountBalance` 获取选中 prepaid 账户的余额。

- [ ] **Step 2: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat(prepaid): show prepaid balance in expense form"
```

---

## Task 15: Frontend — AccountsPage 储值账户展示

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: AccountsPage 修改**

在 `AccountsPage.tsx` 中：

1. 导入 `TopUpDialog` 和 `PrepaidDetailPanel` 组件。

2. 为 Prepaid 类型的账户卡片添加特殊渲染：
   - 显示当前余额（通过 `listAccountsWithBalances` 已有数据）
   - 低余额警告色（余额 < threshold 时余额显示红色 + 警告图标）
   - "充值"按钮 → 打开 TopUpDialog
   - "明细"按钮 → 打开 PrepaidDetailPanel

3. 新增 state 管理 dialog 开关和选中的账户：
```typescript
const [topUpAccountId, setTopUpAccountId] = useState<string | null>(null);
const [detailAccountId, setDetailAccountId] = useState<string | null>(null);
```

4. 渲染 TopUpDialog 和 PrepaidDetailPanel。

- [ ] **Step 2: Commit**

```bash
git add src/pages/AccountsPage.tsx src/components/TopUpDialog.tsx src/components/PrepaidDetailPanel.tsx
git commit -m "feat(prepaid): integrate TopUpDialog and PrepaidDetailPanel into AccountsPage"
```

---

## Task 16: Frontend — ReportsPage 储值汇总

**Files:**
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: 新增储值账户汇总表**

在 `ReportsPage.tsx` 中：

1. 导入 `getPrepaidDetail`, `listAccounts`（已有）
2. 新增一个查询获取所有 Prepaid 类型账户
3. 在报表页面新增一个折叠面板或 Tab："储值账户汇总"
4. 渲染一个表格，列为：储值账户名称、当前余额、本月消费、本月充值、状态（正常/低余额）
5. 低余额行高亮显示红色

- [ ] **Step 2: Commit**

```bash
git add src/pages/ReportsPage.tsx
git commit -m "feat(prepaid): add prepaid account summary table to ReportsPage"
```

---

## Task 17: i18n 国际化 (原 Task 16)

**Files:**
- Modify: `src/i18n/zh.json` (如有)
- Modify: `src/i18n/en.json` (如有)

- [ ] **Step 1: 添加国际化键值**

在中文翻译文件中新增：
```json
{
  "accounts": {
    "types": {
      "prepaid": "储值账户"
    },
    "lowBalanceThreshold": "低余额预警阈值",
    "lowBalanceWarning": "低于阈值",
    "topUp": "充值",
    "detail": "明细",
    "topUpTitle": "{{name}} 充值",
    "paidAmount": "充值金额",
    "bonusAmount": "赠送金额",
    "expiryDate": "有效期",
    "totalCredited": "实际入账",
    "currentBalance": "当前余额",
    "totalTopUps": "累计充值",
    "totalConsumption": "累计消费",
    "topUpRecords": "充值记录",
    "consumptionRecords": "消费记录"
  }
}
```

英文翻译类似。

- [ ] **Step 2: Commit**

```bash
git add src/i18n/
git commit -m "feat(prepaid): add i18n keys for prepaid feature"
```

---

## Task 18: 端到端验证

**Files:** 无新增/修改

- [ ] **Step 1: 启动应用**

Run: `cd src-tauri && cargo tauri dev`
Expected: 应用正常启动，无报错

- [ ] **Step 2: 验证创建储值账户**

1. 打开账户页面 → 新建账户 → 选择"储值账户"类型
2. 填写名称"健身卡"，设置低余额阈值 200
3. 确认创建成功

- [ ] **Step 3: 验证充值**

1. 在储值账户卡片点击"充值"
2. 选择付款账户（银行/现金），输入充值金额 1000，赠送金额 200
3. 确认充值成功
4. 验证储值账户余额显示 1200

- [ ] **Step 4: 验证消费**

1. 创建一笔支出，选择健身卡作为付款账户
2. 输入消费金额 50
3. 确认消费成功
4. 验证储值账户余额显示 1150

- [ ] **Step 5: 验证超额拒绝**

1. 创建一笔支出，金额超过当前余额
2. 确认返回"储值余额不足"错误

- [ ] **Step 6: 验证明细面板**

1. 点击"明细"按钮
2. 确认显示余额、充值记录、消费记录

- [ ] **Step 7: Commit 最终状态**

```bash
git add -A
git commit -m "feat(prepaid): complete prepaid consumption feature with top-up, consumption, balance check, and low balance alert"
```
