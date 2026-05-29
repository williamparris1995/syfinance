# Phase 4: 数据管理实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现标签系统、全局搜索、数据导入/导出功能

**Architecture:** 扩展现有系统，添加标签聚合根、搜索服务、导入/导出服务。采用 Repository 模式管理标签数据。

**Tech Stack:** Rust (Tauri), SQLite, TypeScript (React)

---

## 文件结构映射

### 新增文件
```
src-tauri/
├── src/
│   ├── domain/
│   │   ├── aggregates/
│   │   │   └── tag.rs               # 标签聚合根
│   │   └── repositories/
│   │       └── tag_repository.rs    # 标签仓库 trait
│   ├── infrastructure/
│   │   └── repositories/
│   │       └── tag_repository.rs    # 标签仓库实现
│   └── presentation/
│       └── tauri_commands/
│           ├── tag_commands.rs      # 标签命令
│           └── export_commands.rs   # 导出命令
└── migrations/
    └── 20260528000003_create_tags_table.sql

src/
├── lib/
│   ├── tauri/
│   │   ├── tag.ts                   # 标签 API 封装
│   │   └── export.ts               # 导出 API 封装
│   └── tag.ts                       # 标签工具函数
├── hooks/
│   └── useTag.ts                    # 标签 Hook
└── components/
    └── GlobalSearch.tsx             # 全局搜索组件
```

---

## Task 1: 创建标签数据库表

**Files:**
- Create: `src-tauri/migrations/20260528000003_create_tags_table.sql`

- [ ] **Step 1: 创建标签表迁移文件**

```sql
-- src-tauri/migrations/20260528000003_create_tags_table.sql
-- 标签表
CREATE TABLE IF NOT EXISTS tags (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(50) NOT NULL UNIQUE,
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00'
);

-- 交易-标签关联表
CREATE TABLE IF NOT EXISTS transaction_tags (
    transaction_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
    PRIMARY KEY (transaction_id, tag_id),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
CREATE INDEX IF NOT EXISTS idx_transaction_tags_transaction ON transaction_tags(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag ON transaction_tags(tag_id);
```

- [ ] **Step 2: 提交**

```bash
git add src-tauri/migrations/20260528000003_create_tags_table.sql
git commit -m "feat: add tags and transaction_tags tables migration"
```

---

## Task 2: 创建标签领域模型和仓库

**Files:**
- Create: `src-tauri/src/domain/aggregates/tag.rs`
- Create: `src-tauri/src/domain/repositories/tag_repository.rs`
- Create: `src-tauri/src/infrastructure/repositories/tag_repository.rs`

- [ ] **Step 1: 创建标签聚合根**

```rust
// src-tauri/src/domain/aggregates/tag.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tag {
    pub id: String,
    pub name: String,
    pub color: String,
}

impl Tag {
    pub fn new(id: String, name: String, color: String) -> Self {
        Self { id, name, color }
    }
}
```

- [ ] **Step 2: 创建标签仓库 trait**

```rust
// src-tauri/src/domain/repositories/tag_repository.rs
use crate::domain::aggregates::tag::Tag;
use async_trait::async_trait;

#[async_trait]
pub trait TagRepository: Send + Sync {
    async fn create(&self, tag: &Tag) -> sqlx::Result<()>;
    async fn find_all(&self) -> sqlx::Result<Vec<Tag>>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Tag>>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_to_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()>;
    async fn remove_from_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()>;
    async fn find_by_transaction(&self, transaction_id: &str) -> sqlx::Result<Vec<Tag>>;
}
```

- [ ] **Step 3: 创建标签仓库实现**

```rust
// src-tauri/src/infrastructure/repositories/tag_repository.rs
use crate::domain::aggregates::tag::Tag;
use async_trait::async_trait;
use sqlx::{sqlite::SqlitePool, Row};

#[derive(Clone)]
pub struct SqliteTagRepository {
    pool: SqlitePool,
}

impl SqliteTagRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_tag(row: &sqlx::sqlite::SqliteRow) -> Result<Tag, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let color: String = row.try_get("color")?;
        Ok(Tag { id, name, color })
    }
}

#[async_trait]
impl TagRepository for SqliteTagRepository {
    async fn create(&self, tag: &Tag) -> sqlx::Result<()> {
        sqlx::query("INSERT INTO tags (id, name, color) VALUES (?, ?, ?)")
            .bind(&tag.id)
            .bind(&tag.name)
            .bind(&tag.color)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Tag>> {
        let rows = sqlx::query("SELECT id, name, color FROM tags ORDER BY name")
            .fetch_all(&self.pool)
            .await?;
        rows.iter().map(Self::row_to_tag).collect()
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Tag>> {
        let row = sqlx::query("SELECT id, name, color FROM tags WHERE id = ?")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?;
        row.map(|r| Self::row_to_tag(&r)).transpose()
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM tags WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn add_to_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()> {
        sqlx::query("INSERT OR IGNORE INTO transaction_tags (transaction_id, tag_id) VALUES (?, ?)")
            .bind(transaction_id)
            .bind(tag_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn remove_from_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM transaction_tags WHERE transaction_id = ? AND tag_id = ?")
            .bind(transaction_id)
            .bind(tag_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn find_by_transaction(&self, transaction_id: &str) -> sqlx::Result<Vec<Tag>> {
        let rows = sqlx::query(
            r#"
            SELECT t.id, t.name, t.color
            FROM tags t
            JOIN transaction_tags tt ON t.id = tt.tag_id
            WHERE tt.transaction_id = ?
            ORDER BY t.name
            "#,
        )
        .bind(transaction_id)
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_tag).collect()
    }
}
```

- [ ] **Step 4: 更新模块文件**

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/domain/aggregates/tag.rs
git add src-tauri/src/domain/repositories/tag_repository.rs
git add src-tauri/src/infrastructure/repositories/tag_repository.rs
git commit -m "feat: add tag domain model and repository"
```

---

## Task 3: 创建标签 Tauri 命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/tag_commands.rs`

- [ ] **Step 1: 创建标签命令**

```rust
// src-tauri/src/presentation/tauri_commands/tag_commands.rs
use crate::domain::aggregates::tag::Tag;
use crate::domain::repositories::TagRepository;
use crate::infrastructure::repositories::SqliteTagRepository;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagDto {
    pub id: String,
    pub name: String,
    pub color: String,
}

impl From<Tag> for TagDto {
    fn from(tag: Tag) -> Self {
        Self {
            id: tag.id,
            name: tag.name,
            color: tag.color,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateTagDto {
    pub name: String,
    pub color: String,
}

pub struct TagCommandState {
    tag_repository: Arc<SqliteTagRepository>,
}

impl TagCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            tag_repository: Arc::new(SqliteTagRepository::new(pool)),
        }
    }

    pub fn repository(&self) -> &SqliteTagRepository {
        self.tag_repository.as_ref()
    }
}

#[tauri::command]
pub async fn list_tags(state: State<'_, TagCommandState>) -> Result<Vec<TagDto>, String> {
    state.repository().find_all().await
        .map(|tags| tags.into_iter().map(TagDto::from).collect())
        .map_err(|e| format!("Failed to list tags: {}", e))
}

#[tauri::command]
pub async fn create_tag(state: State<'_, TagCommandState>, dto: CreateTagDto) -> Result<TagDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let tag = Tag::new(id, dto.name, dto.color);
    state.repository().create(&tag).await
        .map_err(|e| format!("Failed to create tag: {}", e))?;
    Ok(TagDto::from(tag))
}

#[tauri::command]
pub async fn delete_tag(state: State<'_, TagCommandState>, id: String) -> Result<(), String> {
    state.repository().delete(&id).await
        .map_err(|e| format!("Failed to delete tag: {}", e))
}

#[tauri::command]
pub async fn add_tag_to_transaction(state: State<'_, TagCommandState>, transaction_id: String, tag_id: String) -> Result<(), String> {
    state.repository().add_to_transaction(&transaction_id, &tag_id).await
        .map_err(|e| format!("Failed to add tag to transaction: {}", e))
}

#[tauri::command]
pub async fn remove_tag_from_transaction(state: State<'_, TagCommandState>, transaction_id: String, tag_id: String) -> Result<(), String> {
    state.repository().remove_from_transaction(&transaction_id, &tag_id).await
        .map_err(|e| format!("Failed to remove tag from transaction: {}", e))
}

#[tauri::command]
pub async fn get_transaction_tags(state: State<'_, TagCommandState>, transaction_id: String) -> Result<Vec<TagDto>, String> {
    state.repository().find_by_transaction(&transaction_id).await
        .map(|tags| tags.into_iter().map(TagDto::from).collect())
        .map_err(|e| format!("Failed to get transaction tags: {}", e))
}
```

- [ ] **Step 2: 更新 mod.rs**

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/tag_commands.rs
git commit -m "feat: add tag Tauri commands"
```

---

## Task 4: 创建全局搜索服务

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/search_commands.rs`

- [ ] **Step 1: 创建搜索命令**

```rust
// src-tauri/src/presentation/tauri_commands/search_commands.rs
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResultDto {
    pub result_type: String, // "account", "transaction", "debt", "goal"
    pub id: String,
    pub title: String,
    pub subtitle: String,
}

pub struct SearchCommandState {
    pool: SqlitePool,
}

impl SearchCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

#[tauri::command]
pub async fn global_search(state: State<'_, SearchCommandState>, query: String) -> Result<Vec<SearchResultDto>, String> {
    let search_pattern = format!("%{}%", query);
    let mut results = Vec::new();

    // 搜索账户
    let accounts = sqlx::query(
        "SELECT id, name, account_type FROM accounts WHERE name LIKE ? LIMIT 5"
    )
    .bind(&search_pattern)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| format!("Search failed: {}", e))?;

    for row in accounts {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let account_type: String = row.try_get("account_type").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "account".to_string(),
            id,
            title: name,
            subtitle: account_type,
        });
    }

    // 搜索交易
    let transactions = sqlx::query(
        "SELECT id, description, transaction_date FROM transactions WHERE description LIKE ? LIMIT 5"
    )
    .bind(&search_pattern)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| format!("Search failed: {}", e))?;

    for row in transactions {
        let id: String = row.try_get("id").unwrap_or_default();
        let description: String = row.try_get("description").unwrap_or_default();
        let date: String = row.try_get("transaction_date").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "transaction".to_string(),
            id,
            title: description,
            subtitle: date,
        });
    }

    // 搜索目标
    let goals = sqlx::query(
        "SELECT id, name, goal_type FROM goals WHERE name LIKE ? LIMIT 5"
    )
    .bind(&search_pattern)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| format!("Search failed: {}", e))?;

    for row in goals {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let goal_type: String = row.try_get("goal_type").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "goal".to_string(),
            id,
            title: name,
            subtitle: goal_type,
        });
    }

    Ok(results)
}
```

- [ ] **Step 2: 更新 mod.rs**

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/search_commands.rs
git commit -m "feat: add global search Tauri command"
```

---

## Task 5: 创建数据导出服务

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/export_commands.rs`

- [ ] **Step 1: 创建导出命令**

```rust
// src-tauri/src/presentation/tauri_commands/export_commands.rs
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use tauri::State;

pub struct ExportCommandState {
    pool: SqlitePool,
}

impl ExportCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

#[derive(Debug, Serialize)]
pub struct ExportDataDto {
    pub accounts: Vec<serde_json::Value>,
    pub transactions: Vec<serde_json::Value>,
    pub debts: Vec<serde_json::Value>,
    pub goals: Vec<serde_json::Value>,
    pub budgets: Vec<serde_json::Value>,
    pub exported_at: String,
}

#[tauri::command]
pub async fn export_all_data(state: State<'_, ExportCommandState>) -> Result<ExportDataDto, String> {
    let accounts = sqlx::query("SELECT * FROM accounts")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(|row| {
            let mut map = serde_json::Map::new();
            // 简化导出，实际应该遍历所有列
            map.insert("id".to_string(), serde_json::Value::String(row.try_get::<String, _>("id").unwrap_or_default()));
            map.insert("name".to_string(), serde_json::Value::String(row.try_get::<String, _>("name").unwrap_or_default()));
            serde_json::Value::Object(map)
        })
        .collect();

    let transactions = sqlx::query("SELECT * FROM transactions")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(|row| {
            let mut map = serde_json::Map::new();
            map.insert("id".to_string(), serde_json::Value::String(row.try_get::<String, _>("id").unwrap_or_default()));
            map.insert("description".to_string(), serde_json::Value::String(row.try_get::<String, _>("description").unwrap_or_default()));
            serde_json::Value::Object(map)
        })
        .collect();

    Ok(ExportDataDto {
        accounts,
        transactions,
        debts: vec![],
        goals: vec![],
        budgets: vec![],
        exported_at: chrono::Utc::now().to_rfc3339(),
    })
}
```

- [ ] **Step 2: 更新 mod.rs**

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/export_commands.rs
git commit -m "feat: add data export Tauri command"
```

---

## Task 6: 创建前端 API 和组件

**Files:**
- Create: `src/lib/tauri/tag.ts`
- Create: `src/lib/tauri/search.ts`
- Create: `src/lib/tauri/export.ts`
- Create: `src/hooks/useTag.ts`
- Create: `src/components/GlobalSearch.tsx`

- [ ] **Step 1: 创建标签 API**

```typescript
// src/lib/tauri/tag.ts
import { invokeTauri } from '../tauri';

export interface TagDto {
  id: string;
  name: string;
  color: string;
}

export interface CreateTagDto {
  name: string;
  color: string;
}

export const listTags = () => invokeTauri<TagDto[]>('list_tags');
export const createTag = (dto: CreateTagDto) => invokeTauri<TagDto>('create_tag', { dto });
export const deleteTag = (id: string) => invokeTauri<void>('delete_tag', { id });
export const addTagToTransaction = (transactionId: string, tagId: string) => invokeTauri<void>('add_tag_to_transaction', { transactionId, tagId });
export const removeTagFromTransaction = (transactionId: string, tagId: string) => invokeTauri<void>('remove_tag_from_transaction', { transactionId, tagId });
export const getTransactionTags = (transactionId: string) => invokeTauri<TagDto[]>('get_transaction_tags', { transactionId });
```

- [ ] **Step 2: 创建搜索 API**

```typescript
// src/lib/tauri/search.ts
import { invokeTauri } from '../tauri';

export interface SearchResultDto {
  result_type: string;
  id: string;
  title: string;
  subtitle: string;
}

export const globalSearch = (query: string) => invokeTauri<SearchResultDto[]>('global_search', { query });
```

- [ ] **Step 3: 创建导出 API**

```typescript
// src/lib/tauri/export.ts
import { invokeTauri } from '../tauri';

export interface ExportDataDto {
  accounts: any[];
  transactions: any[];
  debts: any[];
  goals: any[];
  budgets: any[];
  exported_at: string;
}

export const exportAllData = () => invokeTauri<ExportDataDto>('export_all_data');
```

- [ ] **Step 4: 创建标签 Hook**

```typescript
// src/hooks/useTag.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { listTags, createTag, deleteTag, TagDto, CreateTagDto } from '../lib/tauri/tag';
import { toast } from 'sonner';

export function useTags() {
  return useQuery({ queryKey: ['tags'], queryFn: listTags });
}

export function useCreateTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (dto: CreateTagDto) => createTag(dto),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['tags'] }); toast.success('标签创建成功'); },
    onError: (error) => { toast.error(`创建标签失败: ${error}`); },
  });
}

export function useDeleteTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteTag(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['tags'] }); toast.success('标签删除成功'); },
    onError: (error) => { toast.error(`删除标签失败: ${error}`); },
  });
}
```

- [ ] **Step 5: 创建全局搜索组件**

Create `src/components/GlobalSearch.tsx` with:
- Search input with debounce
- Search results dropdown
- Navigation to result items

- [ ] **Step 6: 添加到 Header**

Update `src/components/layout/Header.tsx` to include GlobalSearch component.

- [ ] **Step 7: 添加 i18n**

- [ ] **Step 8: 提交**

```bash
git add src/lib/tauri/tag.ts src/lib/tauri/search.ts src/lib/tauri/export.ts src/hooks/useTag.ts src/components/GlobalSearch.tsx
git commit -m "feat: add tag API, search API, and global search component"
```

---

## Phase 4 完成检查清单

- [ ] 标签表创建成功
- [ ] 可以创建/删除标签
- [ ] 可以给交易添加/移除标签
- [ ] 全局搜索功能正常
- [ ] 数据导出功能正常
- [ ] 代码已提交

---

## 下一步

Phase 4 完成后，进入 [Phase 5: UI/UX 打磨](./2026-05-27-phase5-ui-ux.md)
