# Phase 3: 目标设定系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现财务目标设定系统，包括储蓄目标、债务目标、投资目标，以及进度追踪和可视化

**Architecture:** 扩展现有系统，添加目标聚合根、目标仓库、目标服务和目标命令。采用 Repository 模式管理目标数据。

**Tech Stack:** Rust (Tauri), SQLite, TypeScript (React), Recharts

---

## 文件结构映射

### 新增文件
```
src-tauri/
├── src/
│   ├── domain/
│   │   ├── aggregates/
│   │   │   └── goal.rs              # 目标聚合根
│   │   └── repositories/
│   │       └── goal_repository.rs   # 目标仓库 trait
│   ├── infrastructure/
│   │   └── repositories/
│   │       └── goal_repository.rs   # 目标仓库实现
│   └── presentation/
│       └── tauri_commands/
│           └── goal_commands.rs     # 目标命令
└── migrations/
    └── 20260528000002_create_goals_table.sql

src/
├── lib/
│   ├── tauri/
│   │   └── goal.ts                  # 目标 API 封装
│   └── goal.ts                      # 目标工具函数
├── hooks/
│   └── useGoal.ts                   # 目标 Hook
└── pages/
    └── GoalsPage.tsx                # 目标页面
```

---

## Task 1: 创建目标数据库表

**Files:**
- Create: `src-tauri/migrations/20260528000002_create_goals_table.sql`

- [ ] **Step 1: 创建目标表迁移文件**

```sql
-- src-tauri/migrations/20260528000002_create_goals_table.sql
-- 目标表
CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    goal_type VARCHAR(20) NOT NULL, -- 'savings', 'debt_payoff', 'investment'
    target_amount DECIMAL(20,10) NOT NULL,
    current_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    deadline DATE,
    linked_account_id TEXT, -- 关联的账户 ID
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    FOREIGN KEY (linked_account_id) REFERENCES accounts(id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_goals_type ON goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_goals_completed ON goals(is_completed);
CREATE INDEX IF NOT EXISTS idx_goals_deadline ON goals(deadline);
```

- [ ] **Step 2: 提交**

```bash
git add src-tauri/migrations/20260528000002_create_goals_table.sql
git commit -m "feat: add goals table migration"
```

---

## Task 2: 创建目标领域模型

**Files:**
- Create: `src-tauri/src/domain/aggregates/goal.rs`

- [ ] **Step 1: 创建目标聚合根**

```rust
// src-tauri/src/domain/aggregates/goal.rs
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum GoalType {
    Savings,
    DebtPayoff,
    Investment,
}

impl GoalType {
    pub fn as_str(&self) -> &str {
        match self {
            GoalType::Savings => "savings",
            GoalType::DebtPayoff => "debt_payoff",
            GoalType::Investment => "investment",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "savings" => GoalType::Savings,
            "debt_payoff" => GoalType::DebtPayoff,
            "investment" => GoalType::Investment,
            _ => GoalType::Savings,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Goal {
    pub id: String,
    pub name: String,
    pub goal_type: GoalType,
    pub target_amount: Decimal,
    pub current_amount: Decimal,
    pub currency_code: String,
    pub deadline: Option<NaiveDate>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
    pub is_completed: bool,
    pub completed_at: Option<String>,
}

impl Goal {
    pub fn new(
        id: String,
        name: String,
        goal_type: GoalType,
        target_amount: Decimal,
        currency_code: String,
    ) -> Self {
        Self {
            id,
            name,
            goal_type,
            target_amount,
            current_amount: Decimal::ZERO,
            currency_code,
            deadline: None,
            linked_account_id: None,
            notes: None,
            is_completed: false,
            completed_at: None,
        }
    }

    pub fn progress_percentage(&self) -> f64 {
        if self.target_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.current_amount / self.target_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    pub fn remaining_amount(&self) -> Decimal {
        self.target_amount - self.current_amount
    }

    pub fn is_overdue(&self) -> bool {
        if let Some(deadline) = self.deadline {
            let today = chrono::Utc::now().naive_utc().date();
            deadline < today && !self.is_completed
        } else {
            false
        }
    }

    pub fn add_progress(&mut self, amount: Decimal) {
        self.current_amount += amount;
        if self.current_amount >= self.target_amount {
            self.mark_completed();
        }
    }

    pub fn mark_completed(&mut self) {
        self.is_completed = true;
        self.completed_at = Some(chrono::Utc::now().to_rfc3339());
    }

    pub fn set_deadline(&mut self, deadline: NaiveDate) {
        self.deadline = Some(deadline);
    }

    pub fn link_account(&mut self, account_id: String) {
        self.linked_account_id = Some(account_id);
    }
}
```

- [ ] **Step 2: 更新模块文件**

Add to `src-tauri/src/domain/aggregates/mod.rs`:
```rust
pub mod goal;
```

- [ ] **Step 3: 编写单元测试**

Add tests at the end of `goal.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_goal_creation() {
        let goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        assert_eq!(goal.name, "买车基金");
        assert_eq!(goal.goal_type, GoalType::Savings);
        assert!(!goal.is_completed);
    }

    #[test]
    fn test_progress_percentage() {
        let mut goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        goal.add_progress(Decimal::new(100000, 0));
        assert!((goal.progress_percentage() - 50.0).abs() < 0.01);
    }

    #[test]
    fn test_mark_completed() {
        let mut goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        goal.add_progress(Decimal::new(200000, 0));
        assert!(goal.is_completed);
        assert!(goal.completed_at.is_some());
    }
}
```

- [ ] **Step 4: 运行测试**

Run: `cd src-tauri && cargo test domain::aggregates::goal`
Expected: 所有测试通过

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/domain/aggregates/goal.rs
git add src-tauri/src/domain/aggregates/mod.rs
git commit -m "feat: add goal domain model"
```

---

## Task 3: 创建目标仓库

**Files:**
- Create: `src-tauri/src/domain/repositories/goal_repository.rs`
- Create: `src-tauri/src/infrastructure/repositories/goal_repository.rs`

- [ ] **Step 1: 创建目标仓库 trait**

```rust
// src-tauri/src/domain/repositories/goal_repository.rs
use crate::domain::aggregates::goal::Goal;
use async_trait::async_trait;
use rust_decimal::Decimal;

#[async_trait]
pub trait GoalRepository: Send + Sync {
    async fn create(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Goal>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Goal>>;
    async fn find_active(&self) -> sqlx::Result<Vec<Goal>>;
    async fn find_completed(&self) -> sqlx::Result<Vec<Goal>>;
    async fn update(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_progress(&self, id: &str, amount: Decimal) -> sqlx::Result<()>;
}
```

- [ ] **Step 2: 创建目标仓库实现**

```rust
// src-tauri/src/infrastructure/repositories/goal_repository.rs
use crate::domain::aggregates::goal::{Goal, GoalType};
use async_trait::async_trait;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;

#[derive(Clone)]
pub struct SqliteGoalRepository {
    pool: SqlitePool,
}

impl SqliteGoalRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_goal(row: &sqlx::sqlite::SqliteRow) -> Result<Goal, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let goal_type_str: String = row.try_get("goal_type")?;
        let target_amount_raw: String = row.try_get("target_amount")?;
        let current_amount_raw: String = row.try_get("current_amount")?;
        let currency_code: String = row.try_get("currency_code")?;
        let deadline: Option<NaiveDate> = row.try_get("deadline")?;
        let linked_account_id: Option<String> = row.try_get("linked_account_id")?;
        let notes: Option<String> = row.try_get("notes")?;
        let is_completed: bool = row.try_get("is_completed")?;
        let completed_at: Option<String> = row.try_get("completed_at")?;

        let target_amount = Decimal::from_str(&target_amount_raw)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        let current_amount = Decimal::from_str(&current_amount_raw)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        Ok(Goal {
            id,
            name,
            goal_type: GoalType::from_str(&goal_type_str),
            target_amount,
            current_amount,
            currency_code,
            deadline,
            linked_account_id,
            notes,
            is_completed,
            completed_at,
        })
    }
}

#[async_trait]
impl GoalRepository for SqliteGoalRepository {
    async fn create(&self, goal: &Goal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO goals (id, name, goal_type, target_amount, current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&goal.id)
        .bind(&goal.name)
        .bind(goal.goal_type.as_str())
        .bind(goal.target_amount.to_string())
        .bind(goal.current_amount.to_string())
        .bind(&goal.currency_code)
        .bind(goal.deadline)
        .bind(&goal.linked_account_id)
        .bind(&goal.notes)
        .bind(goal.is_completed)
        .bind(&goal.completed_at)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Goal>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, goal_type, CAST(target_amount AS TEXT) AS target_amount, CAST(current_amount AS TEXT) AS current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at
            FROM goals
            WHERE id = ?
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|r| Self::row_to_goal(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Goal>> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, goal_type, CAST(target_amount AS TEXT) AS target_amount, CAST(current_amount AS TEXT) AS current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at
            FROM goals
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn find_active(&self) -> sqlx::Result<Vec<Goal>> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, goal_type, CAST(target_amount AS TEXT) AS target_amount, CAST(current_amount AS TEXT) AS current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at
            FROM goals
            WHERE is_completed = FALSE
            ORDER BY deadline ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn find_completed(&self) -> sqlx::Result<Vec<Goal>> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, goal_type, CAST(target_amount AS TEXT) AS target_amount, CAST(current_amount AS TEXT) AS current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at
            FROM goals
            WHERE is_completed = TRUE
            ORDER BY completed_at DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn update(&self, goal: &Goal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE goals
            SET name = ?, goal_type = ?, target_amount = ?, current_amount = ?, currency_code = ?, deadline = ?, linked_account_id = ?, notes = ?, is_completed = ?, completed_at = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&goal.name)
        .bind(goal.goal_type.as_str())
        .bind(goal.target_amount.to_string())
        .bind(goal.current_amount.to_string())
        .bind(&goal.currency_code)
        .bind(goal.deadline)
        .bind(&goal.linked_account_id)
        .bind(&goal.notes)
        .bind(goal.is_completed)
        .bind(&goal.completed_at)
        .bind(&now)
        .bind(&goal.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM goals WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn add_progress(&self, id: &str, amount: Decimal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE goals
            SET current_amount = current_amount + ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(amount.to_string())
        .bind(&now)
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}
```

- [ ] **Step 3: 更新模块文件**

Add to `src-tauri/src/domain/repositories/mod.rs`:
```rust
mod goal_repository;
pub use goal_repository::GoalRepository;
```

Add to `src-tauri/src/infrastructure/repositories/mod.rs`:
```rust
pub mod goal_repository;
pub use goal_repository::SqliteGoalRepository;
```

- [ ] **Step 4: 提交**

```bash
git add src-tauri/src/domain/repositories/goal_repository.rs
git add src-tauri/src/infrastructure/repositories/goal_repository.rs
git add src-tauri/src/domain/repositories/mod.rs
git add src-tauri/src/infrastructure/repositories/mod.rs
git commit -m "feat: add goal repository with SQLite implementation"
```

---

## Task 4: 创建 Tauri 命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/goal_commands.rs`

- [ ] **Step 1: 创建目标命令**

```rust
// src-tauri/src/presentation/tauri_commands/goal_commands.rs
use crate::domain::aggregates::goal::{Goal, GoalType};
use crate::domain::repositories::GoalRepository;
use crate::infrastructure::repositories::SqliteGoalRepository;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoalDto {
    pub id: String,
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub current_amount: String,
    pub progress_percentage: f64,
    pub remaining_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
    pub is_completed: bool,
    pub is_overdue: bool,
    pub completed_at: Option<String>,
}

impl From<Goal> for GoalDto {
    fn from(goal: Goal) -> Self {
        Self {
            id: goal.id,
            name: goal.name,
            goal_type: goal.goal_type.as_str().to_string(),
            target_amount: goal.target_amount.to_string(),
            current_amount: goal.current_amount.to_string(),
            progress_percentage: goal.progress_percentage(),
            remaining_amount: goal.remaining_amount().to_string(),
            currency_code: goal.currency_code,
            deadline: goal.deadline.map(|d| d.to_string()),
            linked_account_id: goal.linked_account_id,
            notes: goal.notes,
            is_completed: goal.is_completed,
            is_overdue: goal.is_overdue(),
            completed_at: goal.completed_at,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateGoalDto {
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
}

pub struct GoalCommandState {
    goal_repository: Arc<SqliteGoalRepository>,
}

impl GoalCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            goal_repository: Arc::new(SqliteGoalRepository::new(pool)),
        }
    }

    pub fn repository(&self) -> &SqliteGoalRepository {
        self.goal_repository.as_ref()
    }
}

#[tauri::command]
pub async fn list_goals(
    state: State<'_, GoalCommandState>,
) -> Result<Vec<GoalDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|goals| goals.into_iter().map(GoalDto::from).collect())
        .map_err(|e| format!("Failed to list goals: {}", e))
}

#[tauri::command]
pub async fn get_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<Option<GoalDto>, String> {
    state
        .repository()
        .find_by_id(&id)
        .await
        .map(|opt| opt.map(GoalDto::from))
        .map_err(|e| format!("Failed to get goal: {}", e))
}

#[tauri::command]
pub async fn create_goal(
    state: State<'_, GoalCommandState>,
    dto: CreateGoalDto,
) -> Result<GoalDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let target_amount = Decimal::from_str(&dto.target_amount)
        .map_err(|_| "Invalid target amount".to_string())?;
    let goal_type = GoalType::from_str(&dto.goal_type);

    let mut goal = Goal::new(id, dto.name, goal_type, target_amount, dto.currency_code);

    if let Some(deadline_str) = dto.deadline {
        let deadline = NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d")
            .map_err(|_| "Invalid deadline date".to_string())?;
        goal.set_deadline(deadline);
    }

    if let Some(account_id) = dto.linked_account_id {
        goal.link_account(account_id);
    }

    goal.notes = dto.notes;

    state
        .repository()
        .create(&goal)
        .await
        .map_err(|e| format!("Failed to create goal: {}", e))?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn update_goal_progress(
    state: State<'_, GoalCommandState>,
    id: String,
    amount: String,
) -> Result<GoalDto, String> {
    let amount = Decimal::from_str(&amount)
        .map_err(|_| "Invalid amount".to_string())?;

    state
        .repository()
        .add_progress(&id, amount)
        .await
        .map_err(|e| format!("Failed to update progress: {}", e))?;

    let goal = state
        .repository()
        .find_by_id(&id)
        .await
        .map_err(|e| format!("Failed to get goal: {}", e))?
        .ok_or_else(|| "Goal not found".to_string())?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn complete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<GoalDto, String> {
    let mut goal = state
        .repository()
        .find_by_id(&id)
        .await
        .map_err(|e| format!("Failed to get goal: {}", e))?
        .ok_or_else(|| "Goal not found".to_string())?;

    goal.mark_completed();

    state
        .repository()
        .update(&goal)
        .await
        .map_err(|e| format!("Failed to complete goal: {}", e))?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn delete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<(), String> {
    state
        .repository()
        .delete(&id)
        .await
        .map_err(|e| format!("Failed to delete goal: {}", e))
}
```

- [ ] **Step 2: 更新 mod.rs**

Add to `src-tauri/src/presentation/tauri_commands/mod.rs`:
```rust
pub mod goal_commands;
```

And add exports:
```rust
pub use goal_commands::{
    complete_goal, create_goal, delete_goal, get_goal, list_goals, update_goal_progress,
    GoalCommandState,
};
```

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/goal_commands.rs
git add src-tauri/src/presentation/tauri_commands/mod.rs
git commit -m "feat: add goal Tauri commands"
```

---

## Task 5: 创建前端 API 和页面

**Files:**
- Create: `src/lib/tauri/goal.ts`
- Create: `src/lib/goal.ts`
- Create: `src/hooks/useGoal.ts`
- Create: `src/pages/GoalsPage.tsx`
- Modify: `src/router.tsx`

- [ ] **Step 1: 创建 Tauri API 封装**

```typescript
// src/lib/tauri/goal.ts
import { invokeTauri } from '../tauri';

export interface GoalDto {
  id: string;
  name: string;
  goal_type: string;
  target_amount: string;
  current_amount: string;
  progress_percentage: number;
  remaining_amount: string;
  currency_code: string;
  deadline: string | null;
  linked_account_id: string | null;
  notes: string | null;
  is_completed: boolean;
  is_overdue: boolean;
  completed_at: string | null;
}

export interface CreateGoalDto {
  name: string;
  goal_type: string;
  target_amount: string;
  currency_code: string;
  deadline?: string;
  linked_account_id?: string;
  notes?: string;
}

export const listGoals = () => invokeTauri<GoalDto[]>('list_goals');
export const getGoal = (id: string) => invokeTauri<GoalDto | null>('get_goal', { id });
export const createGoal = (dto: CreateGoalDto) => invokeTauri<GoalDto>('create_goal', { dto });
export const updateGoalProgress = (id: string, amount: string) => invokeTauri<GoalDto>('update_goal_progress', { id, amount });
export const completeGoal = (id: string) => invokeTauri<GoalDto>('complete_goal', { id });
export const deleteGoal = (id: string) => invokeTauri<void>('delete_goal', { id });
```

- [ ] **Step 2: 创建目标工具函数**

```typescript
// src/lib/goal.ts
import { GoalDto } from './tauri/goal';

export function formatGoalAmount(amount: string): string {
  const num = parseFloat(amount);
  if (isNaN(num)) return '0.00';
  return num.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function getGoalTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    savings: '储蓄目标',
    debt_payoff: '还债目标',
    investment: '投资目标',
  };
  return labels[type] || type;
}

export function getGoalTypeColor(type: string): string {
  const colors: Record<string, string> = {
    savings: 'bg-blue-100 text-blue-800',
    debt_payoff: 'bg-red-100 text-red-800',
    investment: 'bg-green-100 text-green-800',
  };
  return colors[type] || 'bg-gray-100 text-gray-800';
}

export function getGoalProgressColor(percentage: number): string {
  if (percentage >= 100) return 'bg-emerald-500';
  if (percentage >= 75) return 'bg-blue-500';
  if (percentage >= 50) return 'bg-amber-500';
  return 'bg-gray-500';
}
```

- [ ] **Step 3: 创建目标 Hook**

```typescript
// src/hooks/useGoal.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { listGoals, getGoal, createGoal, updateGoalProgress, completeGoal, deleteGoal, GoalDto, CreateGoalDto } from '../lib/tauri/goal';
import { toast } from 'sonner';

export function useGoals() {
  return useQuery({ queryKey: ['goals'], queryFn: listGoals });
}

export function useGoal(id: string) {
  return useQuery({ queryKey: ['goal', id], queryFn: () => getGoal(id), enabled: !!id });
}

export function useCreateGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (dto: CreateGoalDto) => createGoal(dto),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['goals'] }); toast.success('目标创建成功'); },
    onError: (error) => { toast.error(`创建目标失败: ${error}`); },
  });
}

export function useUpdateGoalProgress() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, amount }: { id: string; amount: string }) => updateGoalProgress(id, amount),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['goals'] }); toast.success('进度更新成功'); },
    onError: (error) => { toast.error(`更新进度失败: ${error}`); },
  });
}

export function useCompleteGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => completeGoal(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['goals'] }); toast.success('目标已完成！'); },
    onError: (error) => { toast.error(`完成目标失败: ${error}`); },
  });
}

export function useDeleteGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteGoal(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['goals'] }); toast.success('目标删除成功'); },
    onError: (error) => { toast.error(`删除目标失败: ${error}`); },
  });
}
```

- [ ] **Step 4: 创建目标页面**

Create `src/pages/GoalsPage.tsx` with:
- Goal list with progress bars
- Goal type filter
- Create goal dialog
- Update progress dialog
- Complete/delete functionality

- [ ] **Step 5: 添加路由**

Add to `src/router.tsx`:
```typescript
import { GoalsPage } from './pages/GoalsPage';

const goalsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'goals',
  component: GoalsPage,
});

// Add to routeTree
```

- [ ] **Step 6: 添加 i18n**

Add translations to `src/i18n/locales/en.json` and `src/i18n/locales/zh.json`.

- [ ] **Step 7: 提交**

```bash
git add src/lib/tauri/goal.ts src/lib/goal.ts src/hooks/useGoal.ts src/pages/GoalsPage.tsx src/router.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add goals page with API and hooks"
```

---

## Phase 3 完成检查清单

- [ ] 目标表创建成功
- [ ] 可以创建/删除目标
- [ ] 可以更新目标进度
- [ ] 可以标记目标完成
- [ ] 目标页面显示正确
- [ ] 国际化支持完整
- [ ] 代码已提交

---

## 下一步

Phase 3 完成后，进入 [Phase 4: 数据管理](./2026-05-27-phase4-data-management.md)
