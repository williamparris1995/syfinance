# Phase 2: 预算管理系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现零基预算系统，包括预算分类、预算追踪、预算规则引擎和预算报告

**Architecture:** 扩展现有账户和交易系统，添加预算聚合根、预算仓库、预算服务和预算命令。采用 Repository 模式管理预算数据，Service 模式处理预算计算逻辑。

**Tech Stack:** Rust (Tauri), SQLite, TypeScript (React), Recharts

---

## 文件结构映射

### 新增文件
```
src-tauri/
├── src/
│   ├── domain/
│   │   ├── aggregates/
│   │   │   └── budget.rs           # 预算聚合根
│   │   └── value_objects/
│   │       └── budget_item.rs      # 预算项值对象
│   ├── infrastructure/
│   │   └── repositories/
│   │       └── budget_repository.rs # 预算仓库
│   └── presentation/
│       └── tauri_commands/
│           └── budget_commands.rs  # 预算命令
└── migrations/
    └── 20260528000001_create_budgets_table.sql

src/
├── lib/
│   ├── tauri/
│   │   └── budget.ts              # 预算 API 封装
│   └── budget.ts                  # 预算工具函数
├── hooks/
│   └── useBudget.ts               # 预算 Hook
└── pages/
    └── BudgetPage.tsx             # 预算页面
```

---

## Task 1: 创建预算数据库表

**Files:**
- Create: `src-tauri/migrations/20260528000001_create_budgets_table.sql`

- [ ] **Step 1: 创建预算表迁移文件**

```sql
-- src-tauri/migrations/20260528000001_create_budgets_table.sql
-- 预算表
CREATE TABLE IF NOT EXISTS budgets (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    month VARCHAR(7) NOT NULL, -- 格式: YYYY-MM
    total_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    UNIQUE(month, currency_code)
);

-- 预算项表
CREATE TABLE IF NOT EXISTS budget_items (
    id TEXT PRIMARY KEY NOT NULL,
    budget_id TEXT NOT NULL,
    category_account_id TEXT NOT NULL, -- 关联到 Expense 类型的账户
    planned_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    actual_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE,
    FOREIGN KEY (category_account_id) REFERENCES accounts(id),
    UNIQUE(budget_id, category_account_id)
);

-- 创建索引
CREATE INDEX idx_budgets_month ON budgets(month);
CREATE INDEX idx_budget_items_budget_id ON budget_items(budget_id);
CREATE INDEX idx_budget_items_category ON budget_items(category_account_id);
```

- [ ] **Step 2: 运行迁移**

Run: `cd src-tauri && cargo run`
Expected: 迁移成功，budgets 和 budget_items 表已创建

- [ ] **Step 3: 验证表结构**

Run: `sqlite3 src-tauri/target/debug/finance.db ".schema budgets"`
Expected: 显示 budgets 表结构

- [ ] **Step 4: 提交**

```bash
git add src-tauri/migrations/20260528000001_create_budgets_table.sql
git commit -m "feat: add budgets and budget_items tables migration"
```

---

## Task 2: 创建预算领域模型

**Files:**
- Create: `src-tauri/src/domain/aggregates/budget.rs`
- Create: `src-tauri/src/domain/value_objects/budget_item.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`
- Modify: `src-tauri/src/domain/value_objects/mod.rs`

- [ ] **Step 1: 创建预算项值对象**

```rust
// src-tauri/src/domain/value_objects/budget_item.rs
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetItem {
    pub id: String,
    pub budget_id: String,
    pub category_account_id: String,
    pub planned_amount: Decimal,
    pub actual_amount: Decimal,
    pub notes: Option<String>,
}

impl BudgetItem {
    pub fn new(
        id: String,
        budget_id: String,
        category_account_id: String,
        planned_amount: Decimal,
        notes: Option<String>,
    ) -> Self {
        Self {
            id,
            budget_id,
            category_account_id,
            planned_amount,
            actual_amount: Decimal::ZERO,
            notes,
        }
    }

    pub fn remaining(&self) -> Decimal {
        self.planned_amount - self.actual_amount
    }

    pub fn usage_percentage(&self) -> f64 {
        if self.planned_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.actual_amount / self.planned_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    pub fn is_over_budget(&self) -> bool {
        self.actual_amount > self.planned_amount
    }

    pub fn record_actual(&mut self, amount: Decimal) {
        self.actual_amount = amount;
    }
}
```

- [ ] **Step 2: 创建预算聚合根**

```rust
// src-tauri/src/domain/aggregates/budget.rs
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use super::super::value_objects::budget_item::BudgetItem;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Budget {
    pub id: String,
    pub name: String,
    pub month: String, // YYYY-MM 格式
    pub total_amount: Decimal,
    pub currency_code: String,
    pub is_active: bool,
    pub items: Vec<BudgetItem>,
}

impl Budget {
    pub fn new(
        id: String,
        name: String,
        month: String,
        currency_code: String,
    ) -> Self {
        Self {
            id,
            name,
            month,
            total_amount: Decimal::ZERO,
            currency_code,
            is_active: true,
            items: Vec::new(),
        }
    }

    pub fn add_item(&mut self, item: BudgetItem) {
        self.total_amount += item.planned_amount;
        self.items.push(item);
    }

    pub fn remove_item(&mut self, item_id: &str) {
        if let Some(pos) = self.items.iter().position(|i| i.id == item_id) {
            let item = self.items.remove(pos);
            self.total_amount -= item.planned_amount;
        }
    }

    pub fn update_item_amount(&mut self, item_id: &str, new_amount: Decimal) {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == item_id) {
            self.total_amount -= item.planned_amount;
            item.planned_amount = new_amount;
            self.total_amount += new_amount;
        }
    }

    pub fn total_actual(&self) -> Decimal {
        self.items.iter().map(|i| i.actual_amount).sum()
    }

    pub fn total_remaining(&self) -> Decimal {
        self.total_amount - self.total_actual()
    }

    pub fn overall_usage_percentage(&self) -> f64 {
        if self.total_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.total_actual() / self.total_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    pub fn is_over_budget(&self) -> bool {
        self.total_actual() > self.total_amount
    }

    pub fn deactivate(&mut self) {
        self.is_active = false;
    }

    pub fn activate(&mut self) {
        self.is_active = true;
    }
}
```

- [ ] **Step 3: 更新模块文件**

```rust
// src-tauri/src/domain/aggregates/mod.rs (添加 budget)
pub mod budget;

// src-tauri/src/domain/value_objects/mod.rs (添加 budget_item)
pub mod budget_item;
```

- [ ] **Step 4: 编写单元测试**

```rust
// src-tauri/src/domain/aggregates/budget.rs (在文件末尾添加)
#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;

    #[test]
    fn test_budget_creation() {
        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );
        assert_eq!(budget.id, "test-id");
        assert_eq!(budget.name, "5月预算");
        assert_eq!(budget.month, "2026-05");
        assert!(budget.is_active);
        assert!(budget.items.is_empty());
    }

    #[test]
    fn test_add_item() {
        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            Some("餐饮预算".to_string()),
        );

        budget.add_item(item);
        assert_eq!(budget.items.len(), 1);
        assert_eq!(budget.total_amount, Decimal::new(3000, 0));
    }

    #[test]
    fn test_over_budget() {
        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        let mut item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );
        item.record_actual(Decimal::new(3500, 0));
        budget.add_item(item);

        assert!(budget.is_over_budget());
        assert_eq!(budget.total_remaining(), Decimal::new(-500, 0));
    }
}
```

- [ ] **Step 5: 运行测试**

Run: `cd src-tauri && cargo test domain::aggregates::budget`
Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add src-tauri/src/domain/aggregates/budget.rs
git add src-tauri/src/domain/value_objects/budget_item.rs
git add src-tauri/src/domain/aggregates/mod.rs
git add src-tauri/src/domain/value_objects/mod.rs
git commit -m "feat: add budget domain model with budget items"
```

---

## Task 3: 创建预算仓库

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/budget_repository.rs`
- Modify: `src-tauri/src/infrastructure/repositories/mod.rs`

- [ ] **Step 1: 创建预算仓库接口和实现**

```rust
// src-tauri/src/infrastructure/repositories/budget_repository.rs
use crate::domain::aggregates::budget::Budget;
use crate::domain::value_objects::budget_item::BudgetItem;
use async_trait::async_trait;
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;

#[async_trait]
pub trait BudgetRepository: Send + Sync {
    async fn create(&self, budget: &Budget) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Budget>>;
    async fn find_by_month(&self, month: &str) -> sqlx::Result<Option<Budget>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Budget>>;
    async fn update(&self, budget: &Budget) -> sqlx::Result<()>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_item(&self, budget_id: &str, item: &BudgetItem) -> sqlx::Result<()>;
    async fn update_item(&self, item: &BudgetItem) -> sqlx::Result<()>;
    async fn remove_item(&self, item_id: &str) -> sqlx::Result<()>;
    async fn update_actual_amount(&self, budget_id: &str, category_account_id: &str, amount: Decimal) -> sqlx::Result<()>;
}

#[derive(Clone)]
pub struct SqliteBudgetRepository {
    pool: SqlitePool,
}

impl SqliteBudgetRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_budget_item(row: &sqlx::sqlite::SqliteRow) -> Result<BudgetItem, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let budget_id: String = row.try_get("budget_id")?;
        let category_account_id: String = row.try_get("category_account_id")?;
        let planned_amount_raw: String = row.try_get("planned_amount")?;
        let actual_amount_raw: String = row.try_get("actual_amount")?;
        let notes: Option<String> = row.try_get("notes")?;

        let planned_amount = Decimal::from_str(&planned_amount_raw)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        let actual_amount = Decimal::from_str(&actual_amount_raw)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        Ok(BudgetItem {
            id,
            budget_id,
            category_account_id,
            planned_amount,
            actual_amount,
            notes,
        })
    }
}

#[async_trait]
impl BudgetRepository for SqliteBudgetRepository {
    async fn create(&self, budget: &Budget) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO budgets (id, name, month, total_amount, currency_code, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&budget.id)
        .bind(&budget.name)
        .bind(&budget.month)
        .bind(budget.total_amount.to_string())
        .bind(&budget.currency_code)
        .bind(budget.is_active)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Budget>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            WHERE id = ?
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some(row) => {
                let id: String = row.try_get("id")?;
                let name: String = row.try_get("name")?;
                let month: String = row.try_get("month")?;
                let total_amount_raw: String = row.try_get("total_amount")?;
                let currency_code: String = row.try_get("currency_code")?;
                let is_active: bool = row.try_get("is_active")?;

                let total_amount = Decimal::from_str(&total_amount_raw)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

                // 获取预算项
                let items = self.find_items_by_budget_id(&id).await?;

                Ok(Some(Budget {
                    id,
                    name,
                    month,
                    total_amount,
                    currency_code,
                    is_active,
                    items,
                }))
            }
            None => Ok(None),
        }
    }

    async fn find_by_month(&self, month: &str) -> sqlx::Result<Option<Budget>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            WHERE month = ? AND is_active = TRUE
            "#,
        )
        .bind(month)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some(row) => {
                let id: String = row.try_get("id")?;
                let name: String = row.try_get("name")?;
                let month: String = row.try_get("month")?;
                let total_amount_raw: String = row.try_get("total_amount")?;
                let currency_code: String = row.try_get("currency_code")?;
                let is_active: bool = row.try_get("is_active")?;

                let total_amount = Decimal::from_str(&total_amount_raw)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

                let items = self.find_items_by_budget_id(&id).await?;

                Ok(Some(Budget {
                    id,
                    name,
                    month,
                    total_amount,
                    currency_code,
                    is_active,
                    items,
                }))
            }
            None => Ok(None),
        }
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Budget>> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            ORDER BY month DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut budgets = Vec::new();
        for row in rows {
            let id: String = row.try_get("id")?;
            let name: String = row.try_get("name")?;
            let month: String = row.try_get("month")?;
            let total_amount_raw: String = row.try_get("total_amount")?;
            let currency_code: String = row.try_get("currency_code")?;
            let is_active: bool = row.try_get("is_active")?;

            let total_amount = Decimal::from_str(&total_amount_raw)
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let items = self.find_items_by_budget_id(&id).await?;

            budgets.push(Budget {
                id,
                name,
                month,
                total_amount,
                currency_code,
                is_active,
                items,
            });
        }

        Ok(budgets)
    }

    async fn update(&self, budget: &Budget) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budgets
            SET name = ?, total_amount = ?, currency_code = ?, is_active = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&budget.name)
        .bind(budget.total_amount.to_string())
        .bind(&budget.currency_code)
        .bind(budget.is_active)
        .bind(&now)
        .bind(&budget.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM budgets WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn add_item(&self, budget_id: &str, item: &BudgetItem) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO budget_items (id, budget_id, category_account_id, planned_amount, actual_amount, notes, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&item.id)
        .bind(budget_id)
        .bind(&item.category_account_id)
        .bind(item.planned_amount.to_string())
        .bind(item.actual_amount.to_string())
        .bind(&item.notes)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update_item(&self, item: &BudgetItem) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budget_items
            SET planned_amount = ?, actual_amount = ?, notes = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(item.planned_amount.to_string())
        .bind(item.actual_amount.to_string())
        .bind(&item.notes)
        .bind(&now)
        .bind(&item.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn remove_item(&self, item_id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM budget_items WHERE id = ?")
            .bind(item_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn update_actual_amount(&self, budget_id: &str, category_account_id: &str, amount: Decimal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budget_items
            SET actual_amount = ?, updated_at = ?
            WHERE budget_id = ? AND category_account_id = ?
            "#,
        )
        .bind(amount.to_string())
        .bind(&now)
        .bind(budget_id)
        .bind(category_account_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}

impl SqliteBudgetRepository {
    async fn find_items_by_budget_id(&self, budget_id: &str) -> sqlx::Result<Vec<BudgetItem>> {
        let rows = sqlx::query(
            r#"
            SELECT id, budget_id, category_account_id, CAST(planned_amount AS TEXT) AS planned_amount, CAST(actual_amount AS TEXT) AS actual_amount, notes
            FROM budget_items
            WHERE budget_id = ?
            "#,
        )
        .bind(budget_id)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_budget_item).collect()
    }
}
```

- [ ] **Step 2: 更新模块文件**

```rust
// src-tauri/src/infrastructure/repositories/mod.rs (添加 budget_repository)
pub mod budget_repository;
pub use budget_repository::SqliteBudgetRepository;
```

- [ ] **Step 3: 编写集成测试**

```rust
// src-tauri/src/infrastructure/repositories/budget_repository.rs (在文件末尾添加)
#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect(":memory:")
            .await
            .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS budgets (
                id TEXT PRIMARY KEY NOT NULL,
                name VARCHAR(100) NOT NULL,
                month VARCHAR(7) NOT NULL,
                total_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                UNIQUE(month, currency_code)
            )
            "#
        )
        .execute(&pool)
        .await
        .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS budget_items (
                id TEXT PRIMARY KEY NOT NULL,
                budget_id TEXT NOT NULL,
                category_account_id TEXT NOT NULL,
                planned_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                actual_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                notes TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE
            )
            "#
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    #[tokio::test]
    async fn test_create_and_find_budget() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.name, "5月预算");
        assert_eq!(found.month, "2026-05");
    }

    #[tokio::test]
    async fn test_find_by_month() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let found = repo.find_by_month("2026-05").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "5月预算");
    }
}
```

- [ ] **Step 4: 运行测试**

Run: `cd src-tauri && cargo test infrastructure::repositories::budget_repository`
Expected: 所有测试通过

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/infrastructure/repositories/budget_repository.rs
git add src-tauri/src/infrastructure/repositories/mod.rs
git commit -m "feat: add budget repository with SQLite implementation"
```

---

## Task 4: 创建 Tauri 命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/budget_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`

- [ ] **Step 1: 创建预算命令**

```rust
// src-tauri/src/presentation/tauri_commands/budget_commands.rs
use crate::domain::aggregates::budget::Budget;
use crate::domain::value_objects::budget_item::BudgetItem;
use crate::infrastructure::repositories::SqliteBudgetRepository;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetDto {
    pub id: String,
    pub name: String,
    pub month: String,
    pub total_amount: String,
    pub total_actual: String,
    pub total_remaining: String,
    pub usage_percentage: f64,
    pub currency_code: String,
    pub is_active: bool,
    pub items: Vec<BudgetItemDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetItemDto {
    pub id: String,
    pub category_account_id: String,
    pub planned_amount: String,
    pub actual_amount: String,
    pub remaining: String,
    pub usage_percentage: f64,
    pub is_over_budget: bool,
    pub notes: Option<String>,
}

impl From<Budget> for BudgetDto {
    fn from(budget: Budget) -> Self {
        let items: Vec<BudgetItemDto> = budget.items.iter().map(|item| BudgetItemDto {
            id: item.id.clone(),
            category_account_id: item.category_account_id.clone(),
            planned_amount: item.planned_amount.to_string(),
            actual_amount: item.actual_amount.to_string(),
            remaining: item.remaining().to_string(),
            usage_percentage: item.usage_percentage(),
            is_over_budget: item.is_over_budget(),
            notes: item.notes.clone(),
        }).collect();

        Self {
            id: budget.id,
            name: budget.name,
            month: budget.month,
            total_amount: budget.total_amount.to_string(),
            total_actual: budget.total_actual().to_string(),
            total_remaining: budget.total_remaining().to_string(),
            usage_percentage: budget.overall_usage_percentage(),
            currency_code: budget.currency_code,
            is_active: budget.is_active,
            items,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateBudgetDto {
    pub name: String,
    pub month: String,
    pub currency_code: String,
}

#[derive(Debug, Deserialize)]
pub struct AddBudgetItemDto {
    pub category_account_id: String,
    pub planned_amount: String,
    pub notes: Option<String>,
}

pub struct BudgetCommandState {
    budget_repository: Arc<SqliteBudgetRepository>,
}

impl BudgetCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            budget_repository: Arc::new(SqliteBudgetRepository::new(pool)),
        }
    }

    pub fn repository(&self) -> &SqliteBudgetRepository {
        self.budget_repository.as_ref()
    }
}

#[tauri::command]
pub async fn list_budgets(
    state: State<'_, BudgetCommandState>,
) -> Result<Vec<BudgetDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|budgets| budgets.into_iter().map(BudgetDto::from).collect())
        .map_err(|e| format!("Failed to list budgets: {}", e))
}

#[tauri::command]
pub async fn get_budget(
    state: State<'_, BudgetCommandState>,
    id: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .repository()
        .find_by_id(&id)
        .await
        .map(|opt| opt.map(BudgetDto::from))
        .map_err(|e| format!("Failed to get budget: {}", e))
}

#[tauri::command]
pub async fn get_budget_by_month(
    state: State<'_, BudgetCommandState>,
    month: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .repository()
        .find_by_month(&month)
        .await
        .map(|opt| opt.map(BudgetDto::from))
        .map_err(|e| format!("Failed to get budget: {}", e))
}

#[tauri::command]
pub async fn create_budget(
    state: State<'_, BudgetCommandState>,
    dto: CreateBudgetDto,
) -> Result<BudgetDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let budget = Budget::new(id, dto.name, dto.month, dto.currency_code);

    state
        .repository()
        .create(&budget)
        .await
        .map_err(|e| format!("Failed to create budget: {}", e))?;

    Ok(BudgetDto::from(budget))
}

#[tauri::command]
pub async fn add_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    dto: AddBudgetItemDto,
) -> Result<BudgetDto, String> {
    let planned_amount = Decimal::from_str(&dto.planned_amount)
        .map_err(|_| "Invalid planned amount".to_string())?;

    let item_id = uuid::Uuid::new_v4().to_string();
    let item = BudgetItem::new(
        item_id,
        budget_id.clone(),
        dto.category_account_id,
        planned_amount,
        dto.notes,
    );

    state
        .repository()
        .add_item(&budget_id, &item)
        .await
        .map_err(|e| format!("Failed to add budget item: {}", e))?;

    // 重新获取预算
    let budget = state
        .repository()
        .find_by_id(&budget_id)
        .await
        .map_err(|e| format!("Failed to get budget: {}", e))?
        .ok_or_else(|| "Budget not found".to_string())?;

    Ok(BudgetDto::from(budget))
}

#[tauri::command]
pub async fn delete_budget(
    state: State<'_, BudgetCommandState>,
    id: String,
) -> Result<(), String> {
    state
        .repository()
        .delete(&id)
        .await
        .map_err(|e| format!("Failed to delete budget: {}", e))
}

#[tauri::command]
pub async fn remove_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    item_id: String,
) -> Result<BudgetDto, String> {
    state
        .repository()
        .remove_item(&item_id)
        .await
        .map_err(|e| format!("Failed to remove budget item: {}", e))?;

    let budget = state
        .repository()
        .find_by_id(&budget_id)
        .await
        .map_err(|e| format!("Failed to get budget: {}", e))?
        .ok_or_else(|| "Budget not found".to_string())?;

    Ok(BudgetDto::from(budget))
}
```

- [ ] **Step 2: 更新命令模块**

```rust
// src-tauri/src/presentation/tauri_commands/mod.rs
// 添加 budget_commands 模块
pub mod budget_commands;
```

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/budget_commands.rs
git add src-tauri/src/presentation/tauri_commands/mod.rs
git commit -m "feat: add budget Tauri commands"
```

---

## Task 5: 创建前端 API 封装

**Files:**
- Create: `src/lib/tauri/budget.ts`
- Create: `src/lib/budget.ts`
- Create: `src/hooks/useBudget.ts`

- [ ] **Step 1: 创建 Tauri API 封装**

```typescript
// src/lib/tauri/budget.ts
import { invokeTauri } from '../tauri';

export interface BudgetDto {
  id: string;
  name: string;
  month: string;
  total_amount: string;
  total_actual: string;
  total_remaining: string;
  usage_percentage: number;
  currency_code: string;
  is_active: boolean;
  items: BudgetItemDto[];
}

export interface BudgetItemDto {
  id: string;
  category_account_id: string;
  planned_amount: string;
  actual_amount: string;
  remaining: string;
  usage_percentage: number;
  is_over_budget: boolean;
  notes: string | null;
}

export interface CreateBudgetDto {
  name: string;
  month: string;
  currency_code: string;
}

export interface AddBudgetItemDto {
  category_account_id: string;
  planned_amount: string;
  notes?: string;
}

export const listBudgets = () => invokeTauri<BudgetDto[]>('list_budgets');

export const getBudget = (id: string) =>
  invokeTauri<BudgetDto | null>('get_budget', { id });

export const getBudgetByMonth = (month: string) =>
  invokeTauri<BudgetDto | null>('get_budget_by_month', { month });

export const createBudget = (dto: CreateBudgetDto) =>
  invokeTauri<BudgetDto>('create_budget', { dto });

export const addBudgetItem = (budgetId: string, dto: AddBudgetItemDto) =>
  invokeTauri<BudgetDto>('add_budget_item', { budgetId, dto });

export const deleteBudget = (id: string) =>
  invokeTauri<void>('delete_budget', { id });

export const removeBudgetItem = (budgetId: string, itemId: string) =>
  invokeTauri<BudgetDto>('remove_budget_item', { budgetId, itemId });
```

- [ ] **Step 2: 创建预算工具函数**

```typescript
// src/lib/budget.ts
import { BudgetDto, BudgetItemDto } from './tauri/budget';

/**
 * 格式化预算金额
 */
export function formatBudgetAmount(amount: string): string {
  const num = parseFloat(amount);
  if (isNaN(num)) return '0.00';
  return num.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * 获取预算使用状态颜色
 */
export function getBudgetStatusColor(percentage: number): string {
  if (percentage >= 100) return 'text-red-600';
  if (percentage >= 80) return 'text-amber-600';
  return 'text-emerald-600';
}

/**
 * 获取预算进度条颜色
 */
export function getBudgetProgressColor(percentage: number): string {
  if (percentage >= 100) return 'bg-red-500';
  if (percentage >= 80) return 'bg-amber-500';
  return 'bg-emerald-500';
}

/**
 * 获取当前月份 YYYY-MM 格式
 */
export function getCurrentMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * 格式化月份显示
 */
export function formatMonth(month: string): string {
  const [year, monthNum] = month.split('-');
  return `${year}年${parseInt(monthNum)}月`;
}
```

- [ ] **Step 3: 创建预算 Hook**

```typescript
// src/hooks/useBudget.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listBudgets,
  getBudget,
  getBudgetByMonth,
  createBudget,
  addBudgetItem,
  deleteBudget,
  removeBudgetItem,
  BudgetDto,
  CreateBudgetDto,
  AddBudgetItemDto,
} from '../lib/tauri/budget';
import { toast } from 'sonner';

export function useBudgets() {
  return useQuery({
    queryKey: ['budgets'],
    queryFn: listBudgets,
  });
}

export function useBudget(id: string) {
  return useQuery({
    queryKey: ['budget', id],
    queryFn: () => getBudget(id),
    enabled: !!id,
  });
}

export function useBudgetByMonth(month: string) {
  return useQuery({
    queryKey: ['budget', 'month', month],
    queryFn: () => getBudgetByMonth(month),
    enabled: !!month,
  });
}

export function useCreateBudget() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (dto: CreateBudgetDto) => createBudget(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success('预算创建成功');
    },
    onError: (error) => {
      toast.error(`创建预算失败: ${error}`);
    },
  });
}

export function useAddBudgetItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ budgetId, dto }: { budgetId: string; dto: AddBudgetItemDto }) =>
      addBudgetItem(budgetId, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success('预算项添加成功');
    },
    onError: (error) => {
      toast.error(`添加预算项失败: ${error}`);
    },
  });
}

export function useDeleteBudget() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => deleteBudget(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success('预算删除成功');
    },
    onError: (error) => {
      toast.error(`删除预算失败: ${error}`);
    },
  });
}

export function useRemoveBudgetItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ budgetId, itemId }: { budgetId: string; itemId: string }) =>
      removeBudgetItem(budgetId, itemId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success('预算项删除成功');
    },
    onError: (error) => {
      toast.error(`删除预算项失败: ${error}`);
    },
  });
}
```

- [ ] **Step 4: 提交**

```bash
git add src/lib/tauri/budget.ts
git add src/lib/budget.ts
git add src/hooks/useBudget.ts
git commit -m "feat: add budget frontend API and hooks"
```

---

## Task 6: 创建预算页面

**Files:**
- Create: `src/pages/BudgetPage.tsx`
- Modify: `src/router.tsx`

- [ ] **Step 1: 创建预算页面**

```typescript
// src/pages/BudgetPage.tsx
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Plus, Trash2, Edit } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Progress } from '@/components/ui/progress';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  useBudgets,
  useBudgetByMonth,
  useCreateBudget,
  useAddBudgetItem,
  useDeleteBudget,
  useRemoveBudgetItem,
} from '@/hooks/useBudget';
import {
  formatBudgetAmount,
  getBudgetStatusColor,
  getBudgetProgressColor,
  getCurrentMonth,
  formatMonth,
} from '@/lib/budget';
import { listAccounts } from '@/lib/tauri/account';

export function BudgetPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [currentMonth, setCurrentMonth] = useState(getCurrentMonth());
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [isAddItemDialogOpen, setIsAddItemDialogOpen] = useState(false);
  const [newBudgetName, setNewBudgetName] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState('');
  const [plannedAmount, setPlannedAmount] = useState('');
  const [itemNotes, setItemNotes] = useState('');

  const { data: budget, isLoading } = useBudgetByMonth(currentMonth);
  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const createMutation = useCreateBudget();
  const addItemMutation = useAddBudgetItem();
  const deleteMutation = useDeleteBudget();
  const removeItemMutation = useRemoveBudgetItem();

  // 获取支出类账户（用于预算分类）
  const expenseAccounts = accounts.filter(a => a.account_type === 'Expense');

  const handleCreateBudget = () => {
    if (!newBudgetName.trim()) {
      toast.error('请输入预算名称');
      return;
    }
    createMutation.mutate({
      name: newBudgetName,
      month: currentMonth,
      currency_code: 'CNY',
    }, {
      onSuccess: () => {
        setIsCreateDialogOpen(false);
        setNewBudgetName('');
      },
    });
  };

  const handleAddItem = () => {
    if (!budget || !selectedCategoryId || !plannedAmount) {
      toast.error('请填写完整信息');
      return;
    }
    addItemMutation.mutate({
      budgetId: budget.id,
      dto: {
        category_account_id: selectedCategoryId,
        planned_amount: plannedAmount,
        notes: itemNotes || undefined,
      },
    }, {
      onSuccess: () => {
        setIsAddItemDialogOpen(false);
        setSelectedCategoryId('');
        setPlannedAmount('');
        setItemNotes('');
      },
    });
  };

  const handleRemoveItem = (itemId: string) => {
    if (!budget) return;
    removeItemMutation.mutate({
      budgetId: budget.id,
      itemId,
    });
  };

  const handleDeleteBudget = () => {
    if (!budget) return;
    if (confirm('确定要删除这个预算吗？')) {
      deleteMutation.mutate(budget.id);
    }
  };

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="text-center py-12 text-muted-foreground">加载中...</div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">预算管理</h1>
        <div className="flex gap-2">
          <Input
            type="month"
            value={currentMonth}
            onChange={(e) => setCurrentMonth(e.target.value)}
            className="w-40"
          />
          {budget && (
            <Button variant="destructive" onClick={handleDeleteBudget}>
              删除预算
            </Button>
          )}
        </div>
      </div>

      {!budget ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <p className="text-muted-foreground mb-4">
              {formatMonth(currentMonth)} 还没有预算
            </p>
            <Button onClick={() => setIsCreateDialogOpen(true)}>
              <Plus className="h-4 w-4 mr-2" />
              创建预算
            </Button>
          </CardContent>
        </Card>
      ) : (
        <>
          {/* 预算概览 */}
          <div className="grid gap-4 md:grid-cols-4 mb-6">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">总预算</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  ¥{formatBudgetAmount(budget.total_amount)}
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">已使用</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  ¥{formatBudgetAmount(budget.total_actual)}
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">剩余</CardTitle>
              </CardHeader>
              <CardContent>
                <div className={`text-2xl font-bold ${getBudgetStatusColor(budget.usage_percentage)}`}>
                  ¥{formatBudgetAmount(budget.total_remaining)}
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">使用率</CardTitle>
              </CardHeader>
              <CardContent>
                <div className={`text-2xl font-bold ${getBudgetStatusColor(budget.usage_percentage)}`}>
                  {budget.usage_percentage.toFixed(1)}%
                </div>
                <Progress
                  value={Math.min(budget.usage_percentage, 100)}
                  className="mt-2"
                />
              </CardContent>
            </Card>
          </div>

          {/* 预算项列表 */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>预算分类</CardTitle>
                <Button onClick={() => setIsAddItemDialogOpen(true)}>
                  <Plus className="h-4 w-4 mr-2" />
                  添加分类
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {budget.items.length === 0 ? (
                <p className="text-muted-foreground text-center py-8">
                  还没有预算分类，点击上方按钮添加
                </p>
              ) : (
                <div className="space-y-4">
                  {budget.items.map((item) => {
                    const account = accounts.find(a => a.id === item.category_account_id);
                    return (
                      <div key={item.id} className="flex items-center gap-4 p-4 border rounded-lg">
                        <div className="flex-1">
                          <div className="font-medium">{account?.name || item.category_account_id}</div>
                          {item.notes && (
                            <div className="text-sm text-muted-foreground">{item.notes}</div>
                          )}
                        </div>
                        <div className="text-right min-w-[120px]">
                          <div className="text-sm text-muted-foreground">
                            ¥{formatBudgetAmount(item.actual_amount)} / ¥{formatBudgetAmount(item.planned_amount)}
                          </div>
                          <Progress
                            value={Math.min(item.usage_percentage, 100)}
                            className="mt-1"
                          />
                        </div>
                        <div className={`text-sm font-medium ${getBudgetStatusColor(item.usage_percentage)}`}>
                          {item.usage_percentage.toFixed(1)}%
                        </div>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleRemoveItem(item.id)}
                        >
                          <Trash2 className="h-4 w-4 text-red-500" />
                        </Button>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </>
      )}

      {/* 创建预算对话框 */}
      <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>创建预算</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>预算名称</Label>
              <Input
                value={newBudgetName}
                onChange={(e) => setNewBudgetName(e.target.value)}
                placeholder="例如：5月预算"
              />
            </div>
            <div>
              <Label>月份</Label>
              <Input value={formatMonth(currentMonth)} disabled />
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setIsCreateDialogOpen(false)}>
                取消
              </Button>
              <Button onClick={handleCreateBudget} disabled={createMutation.isPending}>
                {createMutation.isPending ? '创建中...' : '创建'}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* 添加预算项对话框 */}
      <Dialog open={isAddItemDialogOpen} onOpenChange={setIsAddItemDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>添加预算分类</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>支出分类</Label>
              <select
                value={selectedCategoryId}
                onChange={(e) => setSelectedCategoryId(e.target.value)}
                className="w-full p-2 border rounded"
              >
                <option value="">选择分类</option>
                {expenseAccounts.map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <Label>预算金额</Label>
              <Input
                type="number"
                value={plannedAmount}
                onChange={(e) => setPlannedAmount(e.target.value)}
                placeholder="0.00"
              />
            </div>
            <div>
              <Label>备注（可选）</Label>
              <Input
                value={itemNotes}
                onChange={(e) => setItemNotes(e.target.value)}
                placeholder="添加备注..."
              />
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setIsAddItemDialogOpen(false)}>
                取消
              </Button>
              <Button onClick={handleAddItem} disabled={addItemMutation.isPending}>
                {addItemMutation.isPending ? '添加中...' : '添加'}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
```

- [ ] **Step 2: 添加路由**

```typescript
// src/router.tsx
import { BudgetPage } from './pages/BudgetPage';

// 添加路由
const budgetRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'budget',
  component: BudgetPage,
});

// 在路由树中添加
const routeTree = rootRoute.addChildren([
  // ... 其他路由
  budgetRoute,
]);
```

- [ ] **Step 3: 提交**

```bash
git add src/pages/BudgetPage.tsx
git add src/router.tsx
git commit -m "feat: add budget page with routing"
```

---

## Task 7: 添加国际化支持

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: 添加英文翻译**

```json
// src/i18n/locales/en.json
{
  "nav": {
    "budget": "Budget"
  },
  "budget": {
    "title": "Budget Management",
    "createBudget": "Create Budget",
    "budgetName": "Budget Name",
    "budgetNamePlaceholder": "e.g., May Budget",
    "month": "Month",
    "totalBudget": "Total Budget",
    "used": "Used",
    "remaining": "Remaining",
    "usageRate": "Usage Rate",
    "categories": "Budget Categories",
    "addCategory": "Add Category",
    "noBudget": "No budget yet",
    "noBudgetDesc": "Create a budget for this month",
    "noCategories": "No budget categories yet",
    "noCategoriesDesc": "Click the button above to add",
    "deleteBudget": "Delete Budget",
    "deleteBudgetConfirm": "Are you sure you want to delete this budget?",
    "expenseCategory": "Expense Category",
    "selectCategory": "Select category",
    "plannedAmount": "Planned Amount",
    "notes": "Notes",
    "notesPlaceholder": "Add notes..."
  }
}
```

- [ ] **Step 2: 添加中文翻译**

```json
// src/i18n/locales/zh.json
{
  "nav": {
    "budget": "预算"
  },
  "budget": {
    "title": "预算管理",
    "createBudget": "创建预算",
    "budgetName": "预算名称",
    "budgetNamePlaceholder": "例如：5月预算",
    "month": "月份",
    "totalBudget": "总预算",
    "used": "已使用",
    "remaining": "剩余",
    "usageRate": "使用率",
    "categories": "预算分类",
    "addCategory": "添加分类",
    "noBudget": "还没有预算",
    "noBudgetDesc": "为本月创建一个预算",
    "noCategories": "还没有预算分类",
    "noCategoriesDesc": "点击上方按钮添加",
    "deleteBudget": "删除预算",
    "deleteBudgetConfirm": "确定要删除这个预算吗？",
    "expenseCategory": "支出分类",
    "selectCategory": "选择分类",
    "plannedAmount": "预算金额",
    "notes": "备注",
    "notesPlaceholder": "添加备注..."
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add src/i18n/locales/en.json
git add src/i18n/locales/zh.json
git commit -m "feat: add budget i18n translations"
```

---

## Phase 2 完成检查清单

- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 预算表和预算项表创建成功
- [ ] 可以创建/编辑/删除预算
- [ ] 可以添加/删除预算项
- [ ] 预算页面显示正确
- [ ] 预算使用率计算正确
- [ ] 国际化支持完整
- [ ] 代码已提交并推送

---

## 下一步

Phase 2 完成后，进入 [Phase 3: 目标设定系统](./2026-05-27-phase3-goals.md)
