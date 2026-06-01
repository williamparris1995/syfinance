# 备份恢复功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复备份格式（补齐缺失子表+修正表名）并实现完整恢复功能（参数化 SQL + 3 种冲突策略 + 自动安全备份）

**Architecture:** BackupService 扩展 BackupData/DiffSummary/BackupMetadata 覆盖 9 个表；新增 `restore_backup()` 方法按外键依赖顺序逐表恢复；Tauri 命令层桥接前后端；RestoreDialog 对接真实恢复逻辑

**Tech Stack:** Rust (sqlx, serde, flate2, sha2, aes-gcm), TypeScript, React, TanStack React Query, shadcn/ui, i18next

**Design spec:** `docs/superpowers/specs/2026-06-01-backup-restore-design.md`

---

## 文件结构

```
修改文件:
  src-tauri/src/infrastructure/backup/backup_service.rs   # 核心变更：修复 BackupData，新增 restore_backup
  src-tauri/src/infrastructure/backup/mod.rs              # 导出新增类型
  src-tauri/src/presentation/tauri_commands/backup_commands.rs  # 新增 restore_backup 命令
  src-tauri/src/main.rs                                   # 注册 restore_backup 命令
  src/lib/tauri/backup.ts                                 # 新增类型和 restoreBackup 函数
  src/hooks/useBackup.ts                                  # 新增 restoreBackup mutation
  src/components/RestoreDialog.tsx                         # 替换占位 handleRestore
  src/i18n/locales/en.json                                # 新增 i18n 键
  src/i18n/locales/zh.json                                # 新增 i18n 键
```

---

### Task 1: 修复 BackupData 和 BackupMetadata 类型

**Files:**
- Modify: `src-tauri/src/infrastructure/backup/backup_service.rs`

本任务修复 Rust 类型定义，使其覆盖 9 个数据库表，并保持向后兼容。

- [ ] **Step 1: 更新 BackupData 结构**

在 `src-tauri/src/infrastructure/backup/backup_service.rs` 中，替换 `BackupData` 结构体（当前在第 42-50 行）：

```rust
/// The actual data inside a backup.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupData {
    pub accounts: Vec<serde_json::Value>,
    pub transactions: Vec<serde_json::Value>,
    #[serde(alias = "debts")]
    pub debt_details: Vec<serde_json::Value>,
    #[serde(default)]
    pub debt_payment_schedule: Vec<serde_json::Value>,
    pub goals: Vec<serde_json::Value>,
    pub budgets: Vec<serde_json::Value>,
    #[serde(default)]
    pub budget_items: Vec<serde_json::Value>,
    pub tags: Vec<serde_json::Value>,
    #[serde(default)]
    pub transaction_tags: Vec<serde_json::Value>,
}
```

关键：`#[serde(alias = "debts")]` 让旧备份中的 `"debts"` 字段自动映射到 `debt_details`；`#[serde(default)]` 让旧备份中缺少的字段自动为空数组。

- [ ] **Step 2: 更新 BackupMetadata 结构**

替换 `BackupMetadata` 结构体（当前在第 54-62 行）：

```rust
/// Counts per table + device identifier. Stored unencrypted in the envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupMetadata {
    pub account_count: usize,
    pub transaction_count: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub debt_count: Option<usize>,
    pub debt_detail_count: usize,
    pub debt_payment_count: usize,
    pub goal_count: usize,
    pub budget_count: usize,
    pub budget_item_count: usize,
    pub tag_count: usize,
    pub transaction_tag_count: usize,
    pub device_id: String,
}
```

`debt_count` 保留为 `Option<usize>` 并标记 `skip_serializing_if`，逐步废弃。新字段总是写入。

- [ ] **Step 3: 更新 DiffSummary 结构**

替换 `DiffSummary` 结构体（当前在第 86-93 行）：

```rust
/// Aggregate diff across all nine tables.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiffSummary {
    pub accounts: TableDiff,
    pub transactions: TableDiff,
    pub debt_details: TableDiff,
    pub debt_payment_schedule: TableDiff,
    pub goals: TableDiff,
    pub budgets: TableDiff,
    pub budget_items: TableDiff,
    pub tags: TableDiff,
    pub transaction_tags: TableDiff,
}
```

- [ ] **Step 4: 更新 query_all_tables 方法**

替换 `query_all_tables` 方法（当前在第 434-450 行）：

```rust
    /// Query all 9 tables and return rows as JSON values.
    async fn query_all_tables(&self) -> Result<BackupData, BackupError> {
        let accounts = self.query_table("accounts").await?;
        let transactions = self.query_table("transactions").await?;
        let debt_details = self.query_table("debt_details").await?;
        let debt_payment_schedule = self.query_table("debt_payment_schedule").await?;
        let goals = self.query_table("goals").await?;
        let budgets = self.query_table("budgets").await?;
        let budget_items = self.query_table("budget_items").await?;
        let tags = self.query_table("tags").await?;
        let transaction_tags = self.query_table("transaction_tags").await?;

        Ok(BackupData {
            accounts,
            transactions,
            debt_details,
            debt_payment_schedule,
            goals,
            budgets,
            budget_items,
            tags,
            transaction_tags,
        })
    }
```

- [ ] **Step 5: 更新 create_backup 中的 metadata 构建**

在 `create_backup` 方法中，替换 metadata 构建部分（当前在第 222-230 行）：

```rust
        let metadata = BackupMetadata {
            account_count: data.accounts.len(),
            transaction_count: data.transactions.len(),
            debt_count: None,
            debt_detail_count: data.debt_details.len(),
            debt_payment_count: data.debt_payment_schedule.len(),
            goal_count: data.goals.len(),
            budget_count: data.budgets.len(),
            budget_item_count: data.budget_items.len(),
            tag_count: data.tags.len(),
            transaction_tag_count: data.transaction_tags.len(),
            device_id: self.get_device_id(),
        };
```

- [ ] **Step 6: 更新 compute_diff 方法**

替换 `compute_diff` 方法（当前在第 405-415 行）：

```rust
    pub async fn compute_diff(&self, backup_data: &BackupData) -> Result<DiffSummary, BackupError> {
        let local = self.query_all_tables().await?;
        Ok(DiffSummary {
            accounts: diff_table(&local.accounts, &backup_data.accounts),
            transactions: diff_table(&local.transactions, &backup_data.transactions),
            debt_details: diff_table(&local.debt_details, &backup_data.debt_details),
            debt_payment_schedule: diff_table(
                &local.debt_payment_schedule,
                &backup_data.debt_payment_schedule,
            ),
            goals: diff_table(&local.goals, &backup_data.goals),
            budgets: diff_table(&local.budgets, &backup_data.budgets),
            budget_items: diff_table(&local.budget_items, &backup_data.budget_items),
            tags: diff_table(&local.tags, &backup_data.tags),
            transaction_tags: diff_table(&local.transaction_tags, &backup_data.transaction_tags),
        })
    }
```

- [ ] **Step 7: 验证编译**

Run: `cd src-tauri && cargo check`
Expected: 编译成功（会有 backup_commands.rs 的类型不匹配错误，因为 DiffSummary 字段名变了 — 这是预期的，将在 Task 5 修复）

注意：如果编译报 `diff_table` 对 `debt_payment_schedule` 等新字段的类型错误，检查所有使用 `DiffSummary` 的代码。

- [ ] **Step 8: 提交**

```bash
git add src-tauri/src/infrastructure/backup/backup_service.rs
git commit -m "feat(backup): expand BackupData/DiffSummary/Metadata to cover all 9 tables with backward compatibility"
```

---

### Task 2: 新增恢复相关类型

**Files:**
- Modify: `src-tauri/src/infrastructure/backup/backup_service.rs`

在 `backup_service.rs` 中新增恢复结果类型，这些类型被 Task 3 的 `restore_backup` 方法使用。

- [ ] **Step 1: 在 Data types 区域（BackupInfo 之后）添加恢复类型**

在 `BackupInfo` 结构体之后、`TableDiff` 之前（大约第 73 行），添加以下类型定义：

```rust
/// Per-table statistics after a restore operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableRestoreStats {
    pub inserted: usize,
    pub updated: usize,
    pub skipped: usize,
}

/// Statistics for all tables after restore.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreTableResult {
    pub accounts: TableRestoreStats,
    pub transactions: TableRestoreStats,
    pub debt_details: TableRestoreStats,
    pub debt_payment_schedule: TableRestoreStats,
    pub goals: TableRestoreStats,
    pub budgets: TableRestoreStats,
    pub budget_items: TableRestoreStats,
    pub tags: TableRestoreStats,
    pub transaction_tags: TableRestoreStats,
}

/// Result of a restore operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreResult {
    /// Filename of the automatic safety backup created before restore.
    pub safety_backup: String,
    /// Per-table restore statistics.
    pub tables: RestoreTableResult,
}
```

- [ ] **Step 2: 更新 mod.rs 导出新类型**

在 `src-tauri/src/infrastructure/backup/mod.rs` 中，更新 `pub use` 行：

```rust
pub use backup_service::{
    BackupService, RestoreResult, RestoreTableResult, TableRestoreStats,
};
pub use cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};
```

- [ ] **Step 3: 验证编译**

Run: `cd src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add src-tauri/src/infrastructure/backup/backup_service.rs src-tauri/src/infrastructure/backup/mod.rs
git commit -m "feat(backup): add RestoreResult, RestoreTableResult, TableRestoreStats types"
```

---

### Task 3: 实现 restore_backup 核心方法

**Files:**
- Modify: `src-tauri/src/infrastructure/backup/backup_service.rs`

实现 `BackupService::restore_backup()` 及辅助方法。这是恢复功能的核心逻辑。

- [ ] **Step 1: 在 BackupService impl 中添加辅助函数**

在 `backup_service.rs` 文件末尾（`impl BackupService` 块内的 `get_device_id` 方法之后、`// internal helpers` 区域的末尾），添加以下辅助方法：

```rust
    // ----- restore_backup --------------------------------------------------

    /// Restore data from a backup into the current database.
    ///
    /// Creates a safety backup first, then applies changes in a transaction.
    pub async fn restore_backup(
        &self,
        backup_data: &BackupData,
        strategy: &str,
    ) -> Result<RestoreResult, BackupError> {
        info!(strategy = strategy, "Starting restore");

        // 1. Create safety backup of current state
        let safety_info = self.create_backup(None).await?;
        info!(safety_backup = %safety_info.filename, "Safety backup created");

        // 2. Execute restore in a transaction
        let result = self
            .restore_in_transaction(backup_data, strategy)
            .await?;

        info!(
            safety_backup = %safety_info.filename,
            "Restore completed"
        );

        Ok(RestoreResult {
            safety_backup: safety_info.filename,
            tables: result,
        })
    }

    /// Execute the restore within a database transaction.
    ///
    /// On failure, the transaction is rolled back automatically.
    async fn restore_in_transaction(
        &self,
        backup_data: &BackupData,
        strategy: &str,
    ) -> Result<RestoreTableResult, BackupError> {
        // Start a transaction
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|e| BackupError::Database(format!("failed to begin transaction: {e}")))?;

        // Tables in foreign key dependency order
        let accounts =
            restore_table(&mut tx, "accounts", &backup_data.accounts, strategy, "id").await?;
        let tags = restore_table(&mut tx, "tags", &backup_data.tags, strategy, "id").await?;
        let transactions =
            restore_table(&mut tx, "transactions", &backup_data.transactions, strategy, "id")
                .await?;
        let debt_details = restore_table(
            &mut tx,
            "debt_details",
            &backup_data.debt_details,
            strategy,
            "id",
        )
        .await?;
        let debt_payment_schedule = restore_table(
            &mut tx,
            "debt_payment_schedule",
            &backup_data.debt_payment_schedule,
            strategy,
            "id",
        )
        .await?;
        let budgets =
            restore_table(&mut tx, "budgets", &backup_data.budgets, strategy, "id").await?;
        let budget_items = restore_table(
            &mut tx,
            "budget_items",
            &backup_data.budget_items,
            strategy,
            "id",
        )
        .await?;
        let goals = restore_table(&mut tx, "goals", &backup_data.goals, strategy, "id").await?;
        let transaction_tags = restore_table(
            &mut tx,
            "transaction_tags",
            &backup_data.transaction_tags,
            strategy,
            "id",
        )
        .await?;

        tx.commit()
            .await
            .map_err(|e| BackupError::Database(format!("failed to commit transaction: {e}")))?;

        Ok(RestoreTableResult {
            accounts,
            transactions,
            debt_details,
            debt_payment_schedule,
            budgets,
            budget_items,
            goals,
            tags,
            transaction_tags,
        })
    }
```

注意：`create_backup(None)` 创建无加密的安全备份。这样即使加密服务被锁定也能创建安全备份。

- [ ] **Step 2: 在文件末尾（`impl BackupService` 之外）添加自由函数**

在 `backup_service.rs` 文件末尾的 `diff_table` 函数之后，添加以下恢复辅助函数：

```rust
/// Restore a single table from backup data.
///
/// Uses parameterized SQL to prevent injection. Applies the conflict strategy
/// to decide whether each row should be inserted, updated, or skipped.
async fn restore_table(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    table_name: &str,
    backup_rows: &[serde_json::Value],
    strategy: &str,
    id_column: &str,
) -> Result<TableRestoreStats, BackupError> {
    // Tables without updated_at column
    let no_updated_at = matches!(table_name, "tags" | "transaction_tags");

    // Build set of existing IDs
    let query = format!("SELECT {id_column}, updated_at FROM {table_name}");
    let rows = sqlx::query(&query)
        .fetch_all(&mut **tx)
        .await
        .map_err(|e| BackupError::Database(format!("failed to query {table_name}: {e}")))?;

    let mut local_ids: std::collections::HashMap<String, Option<String>> = std::collections::HashMap::new();
    for row in &rows {
        let id: String = row.try_get::<String, _>(0).unwrap_or_default();
        let updated_at: Option<String> = row.try_get::<String, _>(1).ok();
        local_ids.insert(id, updated_at);
    }

    let mut inserted = 0usize;
    let mut updated = 0usize;
    let mut skipped = 0usize;

    for row in backup_rows {
        let obj = match row.as_object() {
            Some(o) => o,
            None => continue,
        };

        let row_id = match obj.get(id_column).and_then(|v| v.as_str()) {
            Some(id) => id.to_string(),
            None => continue,
        };

        let exists = local_ids.contains_key(&row_id);

        match strategy {
            "use_backup" => {
                // INSERT OR REPLACE for all rows
                upsert_row(&mut **tx, table_name, obj).await?;
                if exists {
                    updated += 1;
                } else {
                    inserted += 1;
                }
            }
            "keep_local" => {
                if exists {
                    skipped += 1;
                } else {
                    insert_row(&mut **tx, table_name, obj).await?;
                    inserted += 1;
                }
            }
            "keep_newer" | _ => {
                if !exists {
                    insert_row(&mut **tx, table_name, obj).await?;
                    inserted += 1;
                } else if no_updated_at {
                    // Tables without updated_at: treat as keep_local
                    skipped += 1;
                } else {
                    // Compare updated_at
                    let local_updated = local_ids.get(&row_id).and_then(|u| u.as_deref());
                    let backup_updated = obj.get("updated_at").and_then(|v| v.as_str());

                    let backup_is_newer = match (local_updated, backup_updated) {
                        (Some(local), Some(backup)) => backup > local,
                        _ => false,
                    };

                    if backup_is_newer {
                        update_row(&mut **tx, table_name, obj, id_column, &row_id).await?;
                        updated += 1;
                    } else {
                        skipped += 1;
                    }
                }
            }
        }
    }

    Ok(TableRestoreStats {
        inserted,
        updated,
        skipped,
    })
}

/// Insert a row into a table using parameterized SQL.
async fn insert_row(
    executor: &mut sqlx::SqliteConnection,
    table_name: &str,
    obj: &serde_json::Map<String, serde_json::Value>,
) -> Result<(), BackupError> {
    let (columns, _values) = json_object_to_sql(obj);
    let placeholders: Vec<&str> = columns.iter().map(|_| "?").collect();
    let sql = format!(
        "INSERT INTO {} ({}) VALUES ({})",
        table_name,
        columns.join(", "),
        placeholders.join(", ")
    );

    let mut query = sqlx::query(&sql);
    for (_col, val) in obj.iter() {
        query = bind_json_value(query, val);
    }

    query
        .execute(executor)
        .await
        .map_err(|e| BackupError::Database(format!("insert into {table_name} failed: {e}")))?;

    Ok(())
}

/// Update an existing row in a table using parameterized SQL.
async fn update_row(
    executor: &mut sqlx::SqliteConnection,
    table_name: &str,
    obj: &serde_json::Map<String, serde_json::Value>,
    id_column: &str,
    id_value: &str,
) -> Result<(), BackupError> {
    let set_columns: Vec<String> = obj
        .keys()
        .filter(|k| *k != id_column)
        .cloned()
        .collect();
    let set_clause: Vec<String> = set_columns.iter().map(|c| format!("{c} = ?")).collect();
    let sql = format!(
        "UPDATE {} SET {} WHERE {} = ?",
        table_name,
        set_clause.join(", "),
        id_column
    );

    let mut query = sqlx::query(&sql);
    for key in &set_columns {
        if let Some(val) = obj.get(key) {
            query = bind_json_value(query, val);
        }
    }
    query = query.bind(id_value);

    query
        .execute(executor)
        .await
        .map_err(|e| BackupError::Database(format!("update {table_name} failed: {e}")))?;

    Ok(())
}

/// Upsert a row using INSERT OR REPLACE.
async fn upsert_row(
    executor: &mut sqlx::SqliteConnection,
    table_name: &str,
    obj: &serde_json::Map<String, serde_json::Value>,
) -> Result<(), BackupError> {
    let (columns, _values) = json_object_to_sql(obj);
    let placeholders: Vec<&str> = columns.iter().map(|_| "?").collect();
    let sql = format!(
        "INSERT OR REPLACE INTO {} ({}) VALUES ({})",
        table_name,
        columns.join(", "),
        placeholders.join(", ")
    );

    let mut query = sqlx::query(&sql);
    for (_col, val) in obj.iter() {
        query = bind_json_value(query, val);
    }

    query
        .execute(executor)
        .await
        .map_err(|e| BackupError::Database(format!("upsert into {table_name} failed: {e}")))?;

    Ok(())
}

/// Extract column names and values from a JSON object.
fn json_object_to_sql(
    obj: &serde_json::Map<String, serde_json::Value>,
) -> (Vec<String>, Vec<serde_json::Value>) {
    let columns: Vec<String> = obj.keys().cloned().collect();
    let values: Vec<serde_json::Value> = obj.values().cloned().collect();
    (columns, values)
}

/// Bind a JSON value to a sqlx query builder.
fn bind_json_value<'q>(
    query: sqlx::query::Query<'q, sqlx::Sqlite, sqlx::sqlite::SqliteArguments<'q>>,
    val: &serde_json::Value,
) -> sqlx::query::Query<'q, sqlx::Sqlite, sqlx::sqlite::SqliteArguments<'q>> {
    match val {
        serde_json::Value::String(s) => query.bind(s.clone()),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                query.bind(i)
            } else if let Some(f) = n.as_f64() {
                query.bind(f)
            } else {
                query.bind(serde_json::to_string(val).unwrap_or_default())
            }
        }
        serde_json::Value::Bool(b) => query.bind(*b),
        serde_json::Value::Null => query.bind(Option::<String>::None),
        // For complex types (objects, arrays), serialize to JSON string
        _ => query.bind(serde_json::to_string(val).unwrap_or_default()),
    }
}
```

- [ ] **Step 3: 验证编译**

Run: `cd src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add src-tauri/src/infrastructure/backup/backup_service.rs
git commit -m "feat(backup): implement restore_backup with conflict resolution and transaction support"
```

---

### Task 4: 更新 backup_commands.rs 适配新类型

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/backup_commands.rs`

修复因 `BackupData`/`DiffSummary` 字段变更导致的编译错误，并新增 `restore_backup` Tauri 命令。

- [ ] **Step 1: 添加 import**

在 `backup_commands.rs` 顶部的 use 块中，更新从 `backup_service` 的导入（当前第 2-4 行）：

```rust
use crate::infrastructure::backup::backup_service::{
    BackupFile, BackupInfo, BackupService, DiffSummary, RestoreResult,
};
```

添加 `RestoreResult`。

- [ ] **Step 2: 新增 restore_backup 命令**

在 `backup_commands.rs` 的 `delete_backup` 命令之后（大约第 148 行），添加新命令：

```rust
#[tauri::command]
pub async fn restore_backup(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
    strategy: String,
) -> Result<RestoreResult, String> {
    info!(filename = %filename, strategy = %strategy, "Restoring backup via Tauri command");

    // Validate strategy
    if !["keep_newer", "use_backup", "keep_local"].contains(&strategy.as_str()) {
        return Err(format!("invalid strategy: {strategy}"));
    }

    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    // Read and parse the backup file
    let path = state.backup_dir.join(&filename);
    let contents =
        std::fs::read_to_string(&path).map_err(|e| format!("failed to read backup file: {e}"))?;
    let backup: BackupFile =
        serde_json::from_str(&contents).map_err(|e| format!("failed to parse backup file: {e}"))?;

    // Decrypt if needed
    let backup_data = if backup.encrypted {
        let encryption = state
            .encryption_state
            .get_encryption_service()
            .ok_or_else(|| "encryption is locked - unlock to restore".to_string())?;
        BackupService::decrypt_backup_data(&backup, &encryption).map_err(|e| e.to_string())?
    } else {
        BackupService::decrypt_backup_data_no_encryption(&backup).map_err(|e| e.to_string())?
    };

    service
        .restore_backup(&backup_data, &strategy)
        .await
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 3: 在 main.rs 注册命令**

在 `src-tauri/src/main.rs` 的 `generate_handler![]` 中，在 `delete_backup` 之后（第 301 行）添加：

```rust
            restore_backup,
```

- [ ] **Step 4: 在 tauri_commands/mod.rs 确认导出**

检查 `src-tauri/src/presentation/tauri_commands/mod.rs`，确认 `backup_commands` 模块已声明（已存在，无需修改）。确认 `restore_backup` 函数是 `pub` 的（Step 2 中已标记）。

- [ ] **Step 5: 验证编译**

Run: `cd src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 6: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/backup_commands.rs src-tauri/src/main.rs
git commit -m "feat(backup): add restore_backup Tauri command with strategy validation"
```

---

### Task 5: 更新前端 TypeScript 类型和 API 客户端

**Files:**
- Modify: `src/lib/tauri/backup.ts`

更新 TypeScript 类型以匹配 Rust 端的变更（DiffSummary 新字段、BackupInfo metadata 新字段），并新增恢复相关类型和函数。

- [ ] **Step 1: 更新 BackupInfo 的 metadata 类型**

在 `src/lib/tauri/backup.ts` 中，替换 `BackupInfo` 接口的 `metadata` 类型（当前第 4-17 行）：

```typescript
export interface BackupMetadata {
  device_id: string;
  account_count: number;
  transaction_count: number;
  debt_count?: number;
  debt_detail_count: number;
  debt_payment_count: number;
  goal_count: number;
  budget_count: number;
  budget_item_count: number;
  tag_count: number;
  transaction_tag_count: number;
}

export interface BackupInfo {
  filename: string;
  file_size: number;
  created_at: string;
  metadata: BackupMetadata | null;
  on_cloud: boolean;
}
```

- [ ] **Step 2: 更新 DiffSummary 接口**

替换 `DiffSummary` 接口（当前第 30-37 行）：

```typescript
export interface DiffSummary {
  accounts: TableDiff;
  transactions: TableDiff;
  debt_details: TableDiff;
  debt_payment_schedule: TableDiff;
  goals: TableDiff;
  budgets: TableDiff;
  budget_items: TableDiff;
  tags: TableDiff;
  transaction_tags: TableDiff;
}
```

- [ ] **Step 3: 更新 BackupFile 的 metadata 类型**

更新 `BackupFile` 接口，使其 `metadata` 字段使用新的 `BackupMetadata` 类型（当前第 19-28 行）：

```typescript
export interface BackupFile {
  version: string;
  encrypted: boolean;
  compressed: boolean;
  salt: string;
  data: string;
  checksum: string;
  metadata: BackupMetadata | null;
}
```

注意：去掉了原来不存在的 `created_at` 字段（Rust 端 `BackupFile` 没有 `created_at`）。

- [ ] **Step 4: 新增恢复类型和 API 函数**

在文件末尾（`listCloudBackups` 之后）添加：

```typescript
export interface TableRestoreStats {
  inserted: number;
  updated: number;
  skipped: number;
}

export interface RestoreResult {
  safety_backup: string;
  tables: Record<string, TableRestoreStats>;
}

export const restoreBackup = (
  filename: string,
  strategy: 'keep_newer' | 'use_backup' | 'keep_local',
) => invokeTauri<RestoreResult>('restore_backup', { filename, strategy });
```

- [ ] **Step 5: 验证类型检查**

Run: `pnpm type-check`
Expected: 可能有 RestoreDialog.tsx 中的 `TABLE_KEYS` 和 diff 字段名不匹配 — 这将在 Task 7 修复。如果出现其他错误先记录。

- [ ] **Step 6: 提交**

```bash
git add src/lib/tauri/backup.ts
git commit -m "feat(backup): update TS types for 9-table schema, add RestoreResult and restoreBackup API"
```

---

### Task 6: 更新 useBackup Hook

**Files:**
- Modify: `src/hooks/useBackup.ts`

新增 `restoreBackup` mutation。

- [ ] **Step 1: 添加 import 和 mutation**

在 `src/hooks/useBackup.ts` 中：

1. 在 import 行（第 3-6 行）添加 `restoreBackup`：

```typescript
import {
  createBackup, listBackups, getCloudPresets, getCloudSettings,
  saveCloudSettings, testCloudConnection, uploadToCloud, deleteBackup,
  restoreBackup,
  type BackupInfo, type CloudPreset, type CloudSettings,
  type RestoreResult,
} from '../lib/tauri/backup';
```

2. 在 `uploadToCloudMutation` 定义之后（第 48 行）添加 restore mutation：

```typescript
  const restoreBackupMutation = useMutation({
    mutationFn: ({ filename, strategy }: { filename: string; strategy: 'keep_newer' | 'use_backup' | 'keep_local' }) =>
      restoreBackup(filename, strategy),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['backups'] }),
  });
```

3. 在 return 对象中添加 restore 相关字段：

```typescript
    restoreBackup: restoreBackupMutation.mutateAsync,
    isRestoringBackup: restoreBackupMutation.isPending,
```

完整的 return 对象应为：

```typescript
  return {
    backups: backupsQuery.data ?? [],
    isLoadingBackups: backupsQuery.isLoading,
    cloudPresets: cloudPresetsQuery.data ?? [],
    cloudSettings: cloudSettingsQuery.data,
    isLoadingCloudSettings: cloudSettingsQuery.isLoading,
    createBackup: createBackupMutation.mutateAsync,
    isCreatingBackup: createBackupMutation.isPending,
    deleteBackup: deleteBackupMutation.mutateAsync,
    isDeletingBackup: deleteBackupMutation.isPending,
    saveCloudSettings: saveCloudSettingsMutation.mutateAsync,
    isSavingCloudSettings: saveCloudSettingsMutation.isPending,
    testConnection: testConnectionMutation.mutateAsync,
    isTestingConnection: testConnectionMutation.isPending,
    uploadToCloud: uploadToCloudMutation.mutateAsync,
    isUploading: uploadToCloudMutation.isPending,
    restoreBackup: restoreBackupMutation.mutateAsync,
    isRestoringBackup: restoreBackupMutation.isPending,
  };
```

- [ ] **Step 2: 验证类型检查**

Run: `pnpm type-check`
Expected: 只有 RestoreDialog.tsx 中的错误（Task 7 修复）

- [ ] **Step 3: 提交**

```bash
git add src/hooks/useBackup.ts
git commit -m "feat(backup): add restoreBackup mutation to useBackup hook"
```

---

### Task 7: 更新 RestoreDialog.tsx

**Files:**
- Modify: `src/components/RestoreDialog.tsx`

替换占位 `handleRestore`，更新 `TABLE_KEYS` 以覆盖 9 个表，对接真实恢复逻辑。

- [ ] **Step 1: 更新 import 和 TABLE_KEYS**

替换 `TABLE_KEYS` 常量（当前第 29-36 行）为：

```typescript
const TABLE_KEYS = [
  { key: 'accounts', labelKey: 'backup.tableAccounts' },
  { key: 'transactions', labelKey: 'backup.tableTransactions' },
  { key: 'debt_details', labelKey: 'backup.tableDebtDetails' },
  { key: 'debt_payment_schedule', labelKey: 'backup.tableDebtPaymentSchedule' },
  { key: 'goals', labelKey: 'backup.tableGoals' },
  { key: 'budgets', labelKey: 'backup.tableBudgets' },
  { key: 'budget_items', labelKey: 'backup.tableBudgetItems' },
  { key: 'tags', labelKey: 'backup.tableTags' },
  { key: 'transaction_tags', labelKey: 'backup.tableTransactionTags' },
] as const;
```

- [ ] **Step 2: 更新 RestoreDialogProps 和组件签名**

添加 `onRestoreComplete` 回调 prop。替换接口和组件签名（当前第 38-44 行）：

```typescript
interface RestoreDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  filename: string;
  onRestoreComplete?: () => void;
}

export function RestoreDialog({ open, onOpenChange, filename, onRestoreComplete }: RestoreDialogProps) {
```

- [ ] **Step 3: 替换 handleRestore 函数**

替换 `handleRestore` 函数（当前第 74-83 行）为：

```typescript
  const handleRestore = async () => {
    setIsRestoring(true);
    try {
      const result = await restoreBackup(filename, strategy);

      const totalInserted = Object.values(result.tables).reduce((sum, t) => sum + t.inserted, 0);
      const totalUpdated = Object.values(result.tables).reduce((sum, t) => sum + t.updated, 0);
      const totalSkipped = Object.values(result.tables).reduce((sum, t) => sum + t.skipped, 0);

      toast.success(t('backup.restoreSuccess'), {
        description: t('backup.restoreStats', {
          inserted: totalInserted,
          updated: totalUpdated,
          skipped: totalSkipped,
          safety: result.safety_backup,
        }),
        duration: 8000,
      });

      onRestoreComplete?.();
      handleOpenChange(false);
    } catch (error) {
      toast.error(t('backup.restoreFailed'), {
        description: error instanceof Error ? error.message : undefined,
      });
    } finally {
      setIsRestoring(false);
    }
  };
```

- [ ] **Step 4: 更新 import 添加 restoreBackup**

在文件顶部的 import 中，更新从 `@/lib/tauri/backup` 的导入：

```typescript
import { getBackupDiff, restoreBackup } from '@/lib/tauri/backup';
```

- [ ] **Step 5: 更新 BackupPage.tsx 传递回调**

在 `src/pages/BackupPage.tsx` 中，更新 `RestoreDialog` 调用（大约第 283-287 行）：

```tsx
      <RestoreDialog
        open={isRestoreDialogOpen}
        onOpenChange={setIsRestoreDialogOpen}
        filename={restoreFilename}
        onRestoreComplete={() => {
          // Refresh queries after restore
          queryClient.invalidateQueries({ queryKey: ['backups'] });
        }}
      />
```

注意：需要在 BackupPage.tsx 顶部添加 `useQueryClient` 的 import（如果尚未有）：

```typescript
import { useQueryClient } from '@tanstack/react-query';
```

并在组件函数内添加：

```typescript
const queryClient = useQueryClient();
```

- [ ] **Step 6: 验证类型检查**

Run: `pnpm type-check`
Expected: 通过（可能需要检查 `restoreBackup` 函数是否在 RestoreDialog 的 import 路径中正确导入）

- [ ] **Step 7: 提交**

```bash
git add src/components/RestoreDialog.tsx src/pages/BackupPage.tsx
git commit -m "feat(backup): wire RestoreDialog to real restore API with result feedback"
```

---

### Task 8: 添加 i18n 键

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

添加恢复功能相关的 i18n 键，以及新表名的显示文本。

- [ ] **Step 1: 在 en.json 的 backup 部分末尾添加键**

在 `src/i18n/locales/en.json` 中 `backup` 对象的末尾（`"restoring"` 键之后），添加：

```json
      "restoreSuccess": "Backup restored successfully",
      "restoreFailed": "Failed to restore backup",
      "restoreStats": "Inserted: {{inserted}}, Updated: {{updated}}, Skipped: {{skipped}}. Safety backup: {{safety}}",
      "tableDebtDetails": "Debt Details",
      "tableDebtPaymentSchedule": "Debt Payments",
      "tableBudgetItems": "Budget Items",
      "tableTransactionTags": "Transaction Tags"
```

- [ ] **Step 2: 在 zh.json 的 backup 部分末尾添加键**

在 `src/i18n/locales/zh.json` 中 `backup` 对象的末尾，添加对应中文：

```json
      "restoreSuccess": "备份恢复成功",
      "restoreFailed": "恢复备份失败",
      "restoreStats": "新增: {{inserted}}, 更新: {{updated}}, 跳过: {{skipped}}。安全备份: {{safety}}",
      "tableDebtDetails": "债务明细",
      "tableDebtPaymentSchedule": "还款计划",
      "tableBudgetItems": "预算项目",
      "tableTransactionTags": "交易标签"
```

- [ ] **Step 3: 验证 lint 通过**

Run: `pnpm lint`
Expected: 无错误（新键已在 JSX 中通过 `t()` 使用）

- [ ] **Step 4: 验证类型检查通过**

Run: `pnpm type-check`
Expected: 通过

- [ ] **Step 5: 提交**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(backup): add i18n keys for restore results and new table names"
```

---

### Task 9: 最终验证

**Files:**
- 无新文件变更，仅运行验证命令

- [ ] **Step 1: Rust 编译检查**

Run: `cd src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 2: Rust clippy + 格式检查**

Run: `cd src-tauri && make check`
Expected: 通过

- [ ] **Step 3: 前端类型检查**

Run: `pnpm type-check`
Expected: 通过

- [ ] **Step 4: 前端 lint**

Run: `pnpm lint`
Expected: 通过（无 hardcoded string 违规）
