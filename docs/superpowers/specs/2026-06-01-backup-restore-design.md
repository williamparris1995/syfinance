# 备份恢复功能设计规格

**日期:** 2026-06-01
**状态:** 已批准
**范围:** 修复备份格式 + 实现完整恢复功能

---

## 背景

备份模块（backup）已基本实现，但存在两个问题：

1. **备份格式不完整** — `BackupData` 只包含 6 个表，缺少 3 个关联子表（`debt_payment_schedule`、`budget_items`、`transaction_tags`）；且 `debts` 字段名对应的表已重命名为 `debt_details`
2. **恢复功能为占位符** — `RestoreDialog` UI 已有差异对比和冲突处理选项，但 `handleRestore` 只显示 "restoreNotImplemented" toast

---

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 数据安全 | 自动安全备份 + 事务回滚 | 恢复前自动创建当前数据库的备份，恢复失败可回滚 |
| 恢复范围 | 全库恢复 | 所有表一次性恢复，简单明确 |
| 实现方案 | 参数化 SQL 批量恢复 | 支持 3 种冲突策略，安全（参数化防注入），事务保证原子性 |
| 向后兼容 | `#[serde(alias)]` + `#[serde(default)]` | 旧格式备份可正常反序列化 |

---

## Section 1: 备份格式修复

### 1.1 修改 BackupData 结构

```rust
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

**关键点：**
- `debts` → `debt_details`，用 `#[serde(alias = "debts")]` 保持旧格式兼容
- 新增 3 个字段用 `#[serde(default)]` 标注，旧备份反序列化时自动为空数组

### 1.2 修改 query_all_tables

更新 `BackupService::query_all_tables()` 查询 9 个表：

```rust
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
    // ...
}
```

### 1.3 修改 BackupMetadata

`debt_count` 保留但标记为 `#[serde(skip_serializing_if = "Option::is_none")]`，新增 `debt_detail_count` 和 3 个子表计数字段：

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupMetadata {
    pub account_count: usize,
    pub transaction_count: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub debt_count: Option<usize>,          // 旧格式兼容，逐步废弃
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

### 1.4 更新 DiffSummary 和 compute_diff

扩展差异计算以覆盖 9 个表：

```rust
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

---

## Section 2: 恢复流程核心

### 2.1 恢复方法签名

```rust
impl BackupService {
    pub async fn restore_backup(
        &self,
        backup_data: &BackupData,
        strategy: &str,
        encryption_service: Option<&EncryptionService>,
    ) -> Result<RestoreResult, BackupError>
}
```

### 2.2 恢复流程

```
restore_backup(backup_data, strategy, encryption_service?)
├── 1. 自动创建安全备份（当前数据库状态 → safety_backup_{timestamp}.enc）
├── 2. 开启 SQLite 事务
├── 3. 按外键依赖顺序逐表恢复：
│   ├── accounts（无依赖）
│   ├── tags（无依赖）
│   ├── transactions（无外键）
│   ├── debt_details（依赖 accounts, transactions）
│   ├── debt_payment_schedule（依赖 debt_details, transactions）
│   ├── budgets（无依赖）
│   ├── budget_items（依赖 budgets, accounts）
│   ├── goals（无依赖）
│   └── transaction_tags（依赖 transactions, tags）
├── 4. 提交事务（失败自动回滚）
└── 5. 返回 RestoreResult
```

### 2.3 每表恢复逻辑

对于每个表：

1. 查询本地数据，建立 `id → updated_at` 映射（用于 `keep_newer` 策略）
2. 遍历备份数据的每一行，根据策略决定操作：

**`use_backup` 策略：**
- 所有备份行使用 `INSERT OR REPLACE`（SQLite 原生 upsert）

**`keep_local` 策略：**
- 本地不存在的行：INSERT
- 本地已存在的行：SKIP

**`keep_newer` 策略：**
- 本地不存在的行：INSERT
- 本地存在且 `updated_at` 更旧：UPDATE（用备份数据覆盖）
- 本地存在且 `updated_at` 更新或相等：SKIP
- 没有 `updated_at` 的表（tags, transaction_tags）：等同于 `keep_local`

3. 使用参数化 SQL（`sqlx::query`）执行，将 `serde_json::Value` 的每个字段绑定到 SQL 参数

### 2.4 软删除处理

备份中某行有 `deleted_at` 值时，恢复时保留该软删除状态。恢复的是历史快照，不是「只恢复未删除的行」。

### 2.5 返回类型

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreResult {
    pub safety_backup: String,
    pub tables: RestoreTableResult,
}

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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableRestoreStats {
    pub inserted: usize,
    pub updated: usize,
    pub skipped: usize,
}
```

### 2.6 row_to_sql 辅助函数

将 `serde_json::Value`（Object）转为参数化 SQL 的列名列表和值列表：

```rust
fn json_object_to_sql(obj: &serde_json::Map<String, serde_json::Value>) -> (Vec<String>, Vec<serde_json::Value>)
```

返回 `(column_names, values)`，用于构建 `INSERT INTO table (col1, col2, ...) VALUES (?, ?, ...)` 语句。

---

## Section 3: Tauri 命令层 + 前端对接

### 3.1 新增 Tauri 命令

在 `backup_commands.rs` 新增：

```rust
#[tauri::command]
pub async fn restore_backup(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
    strategy: String,
) -> Result<RestoreResult, String>
```

逻辑：
1. 读取备份文件 → 解密（复用 `get_backup_diff` 中已有的解密逻辑）
2. 调用 `BackupService::restore_backup()`
3. 返回 `RestoreResult`

注册到 `main.rs` 的 `generate_handler![]`。

### 3.2 TypeScript API 客户端

在 `src/lib/tauri/backup.ts` 新增：

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

export async function restoreBackup(
  filename: string,
  strategy: 'keep_newer' | 'use_backup' | 'keep_local'
): Promise<RestoreResult>
```

### 3.3 Hook 更新

在 `src/hooks/useBackup.ts` 新增 `restoreBackup` mutation，成功后自动 invalidate `backupsQuery` 以刷新备份列表（因为安全备份是新文件）。

### 3.4 RestoreDialog 对接

修改 `handleRestore`：
- 调用 `restoreBackup(filename, strategy)` 替换占位符
- 成功后显示恢复结果摘要 toast（各表插入/更新/跳过行数）
- toast 中包含安全备份文件名，让用户知道可以回退
- 关闭对话框

### 3.5 i18n 新增键

| 键 | 用途 |
|----|------|
| `backup.restoreSuccess` | 恢复成功提示（包含安全备份文件名和统计） |
| `backup.restoreFailed` | 恢复失败提示 |
| `backup.tableDebtDetails` | debt_details 表名显示 |
| `backup.tableDebtPaymentSchedule` | debt_payment_schedule 表名显示 |
| `backup.tableBudgetItems` | budget_items 表名显示 |
| `backup.tableTransactionTags` | transaction_tags 表名显示 |

---

## Section 4: 文件变更清单 + 验证

### 4.1 文件变更汇总

| 文件 | 操作 | 说明 |
|------|------|------|
| `src-tauri/src/infrastructure/backup/backup_service.rs` | 修改 | 修复 BackupData（重命名+新增字段），新增 `restore_backup()` 方法及相关类型 |
| `src-tauri/src/infrastructure/backup/mod.rs` | 修改 | 导出新增类型 |
| `src-tauri/src/presentation/tauri_commands/backup_commands.rs` | 修改 | 新增 `restore_backup` 命令 |
| `src-tauri/src/main.rs` | 修改 | 在 `generate_handler![]` 注册 `restore_backup` |
| `src/lib/tauri/backup.ts` | 修改 | 新增 `RestoreResult`、`TableRestoreStats` 类型和 `restoreBackup()` 函数 |
| `src/hooks/useBackup.ts` | 修改 | 新增 `restoreBackup` mutation |
| `src/components/RestoreDialog.tsx` | 修改 | 替换占位 `handleRestore`，显示恢复结果 |
| `src/i18n/locales/en.json` | 修改 | 新增恢复相关 i18n 键 |
| `src/i18n/locales/zh.json` | 修改 | 新增恢复相关 i18n 键 |

### 4.2 验证步骤

1. `cd src-tauri && cargo check` — Rust 编译通过
2. `cd src-tauri && make check` — clippy + 格式检查通过
3. `pnpm type-check` — TypeScript 类型检查通过
4. `pnpm lint` — ESLint 通过（含 i18n 检查）

### 4.3 不做的事（明确范围）

- ❌ 不修复 `query_table` 使用硬编码表名的问题（现有技术债，不在本次范围）
- ❌ 不实现 OAuth 提供商的实际授权流程
- ❌ 不实现跨设备同步恢复
- ❌ 不实现选择性恢复（仅支持全库恢复）
