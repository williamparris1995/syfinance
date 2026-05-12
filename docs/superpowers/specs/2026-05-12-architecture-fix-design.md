# 财务管理系统架构修复设计文档

**文档版本**: 1.0  
**创建日期**: 2026-05-12  
**设计方案**: 方案3 - 混合演进架构  
**状态**: 待审核

---

## 执行摘要

本文档描述了对个人财务管理系统Phase 1的架构修复方案。当前系统存在4个关键问题：

1. Account/Category概念混淆（部分已修复）
2. 数据同步功能未集成（PostgreSQL仓储未使用）
3. 通知服务未集成（ReminderScheduler未启动）
4. 后台同步调度器未启动

**修复策略**: 采用混合演进架构，根据数据特性使用不同的同步和通知策略，完全删除错误的旧代码，直接使用新版本正确实现替换。

**预期成果**:
- 完整可用的多设备同步功能
- 可靠的三层通知系统
- 符合会计审计要求的操作日志
- 清晰的DDD领域边界

**工作量估算**: 约120小时（2-3周）

---

## 目录

1. [问题分析](#1-问题分析)
2. [DDD领域模型重构](#2-ddd领域模型重构)
3. [混合同步策略设计](#3-混合同步策略设计)
4. [混合通知系统设计](#4-混合通知系统设计)
5. [数据库Schema变更](#5-数据库schema变更)
6. [架构层次和模块重构](#6-架构层次和模块重构)
7. [测试策略](#7-测试策略)
8. [实施计划](#8-实施计划)
9. [风险评估](#9-风险评估)
10. [参考标准](#10-参考标准)

---

## 1. 问题分析

### 1.1 当前架构问题

#### 问题1: Account/Category概念混淆

**现状**:
- Migration 20260507000011已移除Account表的`chart_of_account_code`字段
- Account现在是纯粹的"用户账户"（银行卡、现金、信用卡）
- Category独立管理收入/支出分类
- TransactionEntry同时引用Account和ChartOfAccountCode

**残留问题**:
- 部分代码仍假设Account有chart_of_account_code
- 测试用例未更新（见LSP错误）
- 文档未同步更新

**修复方案**: 清理所有引用旧字段的代码和测试

#### 问题2: 数据同步功能未集成

**现状**:
- PostgreSQL仓储已实现但未使用
- SyncService只有内存实现
- sync_routes.rs接受数据但不持久化
- 无冲突检测和解决机制

**影响**: 多设备同步完全不可用

**修复方案**: 实现混合同步策略，集成PostgreSQL仓储

#### 问题3: 通知服务未集成

**现状**:
- NotificationService存在但未连接到ReminderScheduler
- Reminder创建后不会触发通知
- 无OS级任务调度

**影响**: 还款提醒功能不可用

**修复方案**: 实现三层通知架构

#### 问题4: 后台服务未启动

**现状**:
- SyncScheduler和ReminderScheduler未在main.rs中启动
- 后台任务不运行

**影响**: 自动同步和提醒不工作

**修复方案**: 在main.rs中启动所有后台服务

---

## 2. DDD领域模型重构

### 2.1 限界上下文（Bounded Contexts）

#### 2.1.1 账户管理上下文（Account Management Context）

**聚合根**: Account, Category  
**职责**: 管理用户的资金账户和分类体系  
**不变量**: 账户余额必须通过交易变更

**核心概念**:
- Account: 用户的实际账户（银行卡、现金、信用卡）
- Category: 收入/支出分类（餐饮、交通、工资等）
- 两者完全独立，不再混淆

#### 2.1.2 交易记账上下文（Transaction Ledger Context）

**聚合根**: Transaction  
**值对象**: TransactionEntry, TransactionOperation  
**职责**: 复式记账、借贷平衡、操作日志  
**不变量**: 借贷必须平衡、操作不可修改

**核心概念**:
- Transaction: 一笔完整的交易
- TransactionEntry: 交易分录（借方/贷方）
- TransactionOperation: 操作日志（CREATE, UPDATE, DELETE）

#### 2.1.3 债务管理上下文（Debt Management Context）

**聚合根**: Debt  
**实体**: DebtPayment  
**职责**: 贷款、信用卡、还款计划  
**不变量**: 还款记录不可删除

#### 2.1.4 提醒通知上下文（Reminder & Notification Context）

**聚合根**: Reminder  
**服务**: NotificationService, ReminderScheduler  
**职责**: 提醒调度、多层通知  
**不变量**: 提醒必须在到期前触发

#### 2.1.5 数据同步上下文（Data Synchronization Context）

**服务**: SyncService, ConflictResolver  
**职责**: 多设备同步、冲突解决  
**策略**: 根据数据类型使用不同同步算法

### 2.2 核心修复点

#### 修复1: Account模型清理

✅ 已移除 `chart_of_account_code`（通过migration 20260507000011）  
✅ Account现在是纯粹的"用户账户"  
✅ Category独立管理收入/支出分类  
✅ TransactionEntry同时引用Account和ChartOfAccountCode

#### 修复2: Transaction操作日志

✨ 新增: TransactionOperation表（记录所有操作）  
✨ 类型: CREATE, UPDATE, DELETE, RECONCILE  
✨ 支持审计追踪和冲突解决

#### 修复3: 同步元数据增强

✨ 新增: version_vector（版本向量，检测冲突）  
✨ 新增: operation_log（操作日志，用于CRDT）  
✅ 保留: updated_at, synced_at, device_id

---

## 3. 混合同步策略设计

### 3.1 同步策略矩阵

| 数据类型 | 同步策略 | 冲突解决 | 理由 |
|---------|---------|---------|------|
| **Transaction** | Operation-based CRDT | 操作日志合并 | 财务审计要求，不可丢失 |
| **Account/Category** | LWW + Version Vector | 检测后提示用户 | 配置数据，冲突少 |
| **Debt/Payment** | Append-only Log | 时间戳排序 | 还款记录不可修改 |
| **Reminder** | LWW | 最新覆盖 | 提醒可以覆盖 |

### 3.2 Transaction同步详细设计

#### 3.2.1 操作日志结构

```rust
pub struct TransactionOperation {
    pub id: Uuid,
    pub transaction_id: Uuid,
    pub operation_type: OperationType,
    pub entry_id: Option<Uuid>,
    pub payload: serde_json::Value,
    pub timestamp: DateTime<Utc>,
    pub device_id: Uuid,
    pub sequence_number: u64,
}

pub enum OperationType {
    CreateTransaction,
    AddEntry,
    UpdateEntry,
    DeleteEntry,
    UpdateDescription,
}
```

#### 3.2.2 同步流程

1. 客户端记录所有操作到 `transaction_operations` 表
2. 同步时上传未同步的操作日志
3. 服务器按 (timestamp, device_id, sequence_number) 排序
4. 客户端下载并重放操作日志
5. 冲突自动合并（操作可交换）

#### 3.2.3 符合标准

- **RFC 6902** (JSON Patch) - 操作语义
- **CRDT论文** (Shapiro et al. 2011) - 操作型CRDT
- **会计准则** - 审计追踪要求（所有操作可追溯）

### 3.3 Account/Category同步详细设计

#### 3.3.1 版本向量

```rust
pub struct VersionVector {
    pub device_id: Uuid,
    pub version: u64,
    pub vector: HashMap<Uuid, u64>,
}
```

#### 3.3.2 冲突检测

- 如果 `vector_a` 和 `vector_b` 都不是对方的子集 → 冲突
- 冲突时：保存两个版本，提示用户选择
- 用户选择后：合并版本向量

#### 3.3.3 符合标准

- **Vector Clocks** (Lamport 1978)
- **Dynamo论文** (Amazon 2007)

### 3.4 Debt/Payment同步详细设计

#### 3.4.1 Append-only日志

- DebtPayment一旦创建不可修改
- 使用 `payment_timestamp` 排序
- 冲突：保留所有记录，按时间戳排序

#### 3.4.2 还款计划同步

- 还款计划（schedule）可以重新生成
- 实际还款记录（payment）不可修改
- 符合财务不可篡改原则

---

## 4. 混合通知系统设计

### 4.1 三层通知架构

```
┌─────────────────────────────────────────┐
│  Layer 3: 云端推送（可选扩展层）          │
│  - WebSocket推送服务                     │
│  - 支持未来移动端                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Layer 2: 操作系统任务调度（备份层）      │
│  - Windows Task Scheduler               │
│  - macOS launchd                        │
│  - Linux systemd timer                  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Layer 1: 应用内调度器（实时层）          │
│  - ReminderScheduler                    │
│  - 每小时检查                            │
└─────────────────────────────────────────┘
```

### 4.2 Layer 1: 应用内调度器

#### 4.2.1 ReminderScheduler实现

```rust
pub struct ReminderScheduler {
    reminder_repo: Arc<dyn ReminderRepository>,
    notification_service: Arc<NotificationService>,
    check_interval: Duration,
}

impl ReminderScheduler {
    pub async fn start(&self) {
        loop {
            self.check_and_send_reminders().await;
            tokio::time::sleep(self.check_interval).await;
        }
    }
}
```

#### 4.2.2 启动时机

- 在 `main.rs` 的 Tauri setup hook 中启动
- 作为后台tokio任务运行
- 应用关闭时优雅停止

### 4.3 Layer 2: 操作系统任务调度

#### 4.3.1 跨平台实现

**Windows (Task Scheduler)**:
```rust
pub struct WindowsScheduler;

impl WindowsScheduler {
    pub fn register_task(&self, reminder: &Reminder) -> Result<()> {
        Command::new("schtasks")
            .args(&["/Create", "/TN", &task_name, ...])
            .output()?;
        Ok(())
    }
}
```

**macOS (launchd)**:
```rust
pub struct MacOSScheduler;

impl MacOSScheduler {
    pub fn register_task(&self, reminder: &Reminder) -> Result<()> {
        // 创建 ~/Library/LaunchAgents/*.plist
        fs::write(plist_path, plist)?;
        Command::new("launchctl").args(&["load", &plist_path]).output()?;
        Ok(())
    }
}
```

**Linux (systemd timer)**:
```rust
pub struct LinuxScheduler;

impl LinuxScheduler {
    pub fn register_task(&self, reminder: &Reminder) -> Result<()> {
        // 创建 ~/.config/systemd/user/*.timer 和 *.service
        fs::write(timer_path, timer)?;
        Command::new("systemctl").args(&["--user", "enable", &timer_name]).output()?;
        Ok(())
    }
}
```

#### 4.3.2 统一接口

```rust
pub trait OSScheduler: Send + Sync {
    fn register_reminder(&self, reminder: &Reminder) -> Result<()>;
    fn unregister_reminder(&self, reminder_id: &Uuid) -> Result<()>;
    fn list_scheduled(&self) -> Result<Vec<Uuid>>;
}
```

### 4.4 Layer 3: 云端推送（可选）

```rust
pub struct CloudPushService {
    ws_url: String,
    device_token: String,
}

impl CloudPushService {
    pub async fn send_push(&self, reminder: &Reminder) -> Result<()> {
        // 连接到云端推送服务
        // 发送推送消息到所有设备
    }
}
```

**配置**:
- 默认禁用（用户可在设置中启用）
- 需要用户登录账号
- 使用自建WebSocket服务器

### 4.5 通知优先级和去重

#### 4.5.1 优先级

1. 逾期提醒（红色，紧急）
2. 当天到期（橙色，重要）
3. 提前3天（黄色，普通）
4. 提前7天（蓝色，信息）

#### 4.5.2 去重策略

- 同一提醒24小时内只发送一次
- 使用 `last_notified_at` 字段记录
- 用户关闭通知后不再发送

---

## 5. 数据库Schema变更

### 5.1 新增表

#### 5.1.1 transaction_operations（交易操作日志）

```sql
CREATE TABLE transaction_operations (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL,
    operation_type VARCHAR(20) NOT NULL,
    entry_id TEXT,
    payload TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    device_id TEXT NOT NULL,
    sequence_number INTEGER NOT NULL,
    synced_at TIMESTAMP,
    CHECK (operation_type IN ('CREATE', 'ADD_ENTRY', 'UPDATE_ENTRY', 
                              'DELETE_ENTRY', 'UPDATE_DESCRIPTION')),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);

CREATE INDEX idx_transaction_operations_transaction ON transaction_operations(transaction_id);
CREATE INDEX idx_transaction_operations_device ON transaction_operations(device_id);
CREATE INDEX idx_transaction_operations_sync ON transaction_operations(synced_at);
CREATE UNIQUE INDEX idx_transaction_operations_sequence 
    ON transaction_operations(device_id, sequence_number);
```

#### 5.1.2 version_vectors（版本向量）

```sql
CREATE TABLE version_vectors (
    entity_type VARCHAR(20) NOT NULL,
    entity_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (entity_type, entity_id, device_id),
    CHECK (entity_type IN ('account', 'category'))
);

CREATE INDEX idx_version_vectors_entity ON version_vectors(entity_type, entity_id);
```

#### 5.1.3 sync_conflicts（同步冲突记录）

```sql
CREATE TABLE sync_conflicts (
    id TEXT PRIMARY KEY NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    entity_id TEXT NOT NULL,
    local_version TEXT NOT NULL,
    remote_version TEXT NOT NULL,
    conflict_type VARCHAR(20) NOT NULL,
    detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution VARCHAR(20),
    CHECK (entity_type IN ('account', 'category', 'transaction', 'debt')),
    CHECK (conflict_type IN ('UPDATE_UPDATE', 'DELETE_UPDATE', 'UPDATE_DELETE'))
);

CREATE INDEX idx_sync_conflicts_entity ON sync_conflicts(entity_type, entity_id);
CREATE INDEX idx_sync_conflicts_unresolved ON sync_conflicts(resolved_at) 
    WHERE resolved_at IS NULL;
```

#### 5.1.4 notification_log（通知日志）

```sql
CREATE TABLE notification_log (
    id TEXT PRIMARY KEY NOT NULL,
    reminder_id TEXT NOT NULL,
    notification_type VARCHAR(20) NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    CHECK (notification_type IN ('IN_APP', 'OS_NATIVE', 'CLOUD_PUSH')),
    CHECK (status IN ('SUCCESS', 'FAILED', 'DISMISSED')),
    FOREIGN KEY (reminder_id) REFERENCES reminders(id) ON DELETE CASCADE
);

CREATE INDEX idx_notification_log_reminder ON notification_log(reminder_id);
CREATE INDEX idx_notification_log_sent ON notification_log(sent_at);
```

### 5.2 修改现有表

#### 5.2.1 reminders表增强

```sql
ALTER TABLE reminders ADD COLUMN last_notified_at TIMESTAMP;
ALTER TABLE reminders ADD COLUMN notification_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE reminders ADD COLUMN os_task_id TEXT;
ALTER TABLE reminders ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL' 
    CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT'));
```

#### 5.2.2 accounts表添加版本字段

```sql
ALTER TABLE accounts ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
```

#### 5.2.3 categories表添加版本字段

```sql
ALTER TABLE categories ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
```

### 5.3 删除的代码/功能

**完全删除**:
1. ❌ 旧的 `SyncService` 中的 LWW 实现
2. ❌ 未使用的 PostgreSQL repositories（重写后集成）
3. ❌ 空的 `NotificationService`
4. ❌ 未启动的 `SyncScheduler`
5. ❌ 未启动的 `ReminderScheduler`
6. ❌ 所有 `#![allow(dead_code)]` 标记的代码

**不保留回滚逻辑**: 直接使用新实现

---

## 6. 架构层次和模块重构

### 6.1 DDD分层架构

```
src-tauri/src/
├── domain/                          # 领域层（纯业务逻辑）
│   ├── aggregates/
│   │   ├── account.rs              # ✅ 保留
│   │   ├── category.rs             # ✅ 保留
│   │   ├── transaction.rs          # 🔄 增强（操作日志）
│   │   ├── debt.rs                 # ✅ 保留
│   │   └── reminder.rs             # 🔄 增强（通知优先级）
│   ├── value_objects/
│   │   ├── money.rs                # ✅ 保留
│   │   ├── currency.rs             # ✅ 保留
│   │   ├── transaction_entry.rs    # ✅ 保留
│   │   ├── sync_metadata.rs        # 🔄 增强（版本向量）
│   │   ├── transaction_operation.rs # ✨ 新增
│   │   └── version_vector.rs       # ✨ 新增
│   ├── repositories/               # 仓储接口
│   │   ├── account_repository.rs   # ✅ 保留
│   │   ├── transaction_repository.rs # 🔄 增强
│   │   ├── debt_repository.rs      # ✅ 保留
│   │   └── reminder_repository.rs  # ✅ 保留
│   └── services/                   # 领域服务
│       ├── conflict_resolver.rs    # ✨ 新增
│       └── balance_calculator.rs   # ✅ 保留
│
├── application/                     # 应用层
│   ├── services/
│   │   ├── account_service.rs      # ✅ 保留
│   │   ├── transaction_service.rs  # 🔄 重写
│   │   ├── debt_service.rs         # ✅ 保留
│   │   ├── sync_service.rs         # 🔄 完全重写
│   │   └── reminder_service.rs     # 🔄 重写
│   └── dtos/                       # ✅ 保留
│
├── infrastructure/                  # 基础设施层
│   ├── repositories/
│   │   ├── account_repository.rs           # ✅ 保留（SQLite）
│   │   ├── account_repository_postgres.rs  # 🔄 重写并集成
│   │   ├── transaction_repository.rs       # 🔄 增强
│   │   ├── transaction_repository_postgres.rs # 🔄 重写并集成
│   │   ├── operation_repository.rs         # ✨ 新增
│   │   ├── version_vector_repository.rs    # ✨ 新增
│   │   └── conflict_repository.rs          # ✨ 新增
│   ├── sync/
│   │   ├── sync_service.rs         # 🔄 完全重写
│   │   ├── sync_scheduler.rs       # 🔄 重写并启动
│   │   ├── strategies/             # ✨ 新增目录
│   │   │   ├── mod.rs
│   │   │   ├── operation_based_sync.rs
│   │   │   ├── lww_sync.rs
│   │   │   └── append_only_sync.rs
│   │   └── conflict_detector.rs    # ✨ 新增
│   ├── notifications/
│   │   ├── notification_service.rs # 🔄 完全重写
│   │   ├── os_scheduler/           # ✨ 新增目录
│   │   │   ├── mod.rs
│   │   │   ├── windows.rs
│   │   │   ├── macos.rs
│   │   │   └── linux.rs
│   │   └── cloud_push.rs           # ✨ 新增
│   └── reminders/
│       └── reminder_scheduler.rs   # 🔄 重写并启动
│
├── presentation/                    # 表示层
│   ├── tauri_commands/             # ✅ 保留
│   └── api/
│       └── sync_routes.rs          # 🔄 重写
│
├── main.rs                         # 🔄 重写
└── lib.rs                          # ✅ 保留
```

### 6.2 main.rs 启动流程

```rust
#[tokio::main]
async fn main() -> Result<()> {
    // 1. 初始化数据库
    let db_pool = initialize_database().await?;
    
    // 2. 创建仓储
    let account_repo = Arc::new(AccountRepository::new(db_pool.clone()));
    let transaction_repo = Arc::new(TransactionRepository::new(db_pool.clone()));
    let operation_repo = Arc::new(OperationRepository::new(db_pool.clone()));
    // ... 其他仓储
    
    // 3. 创建服务
    let sync_service = Arc::new(SyncService::new(/* 所有仓储 */));
    let notification_service = Arc::new(NotificationService::new());
    let reminder_service = Arc::new(ReminderService::new(/* ... */));
    
    // 4. 启动后台任务
    let sync_scheduler = SyncScheduler::new(sync_service.clone());
    tokio::spawn(async move {
        sync_scheduler.start().await;
    });
    
    let reminder_scheduler = ReminderScheduler::new(
        reminder_service.clone(),
        notification_service.clone()
    );
    tokio::spawn(async move {
        reminder_scheduler.start().await;
    });
    
    // 5. 启动Tauri应用
    tauri::Builder::default()
        .manage(account_repo)
        .manage(transaction_repo)
        .invoke_handler(tauri::generate_handler![/* ... */])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
    
    Ok(())
}
```

---

## 7. 测试策略

### 7.1 测试金字塔

```
                    /\
                   /  \
                  / E2E \ (10%)
                 /______\
                /        \
               / 集成测试  \ (30%)
              /____________\
             /              \
            /    单元测试      \ (60%)
           /___________________\
```

### 7.2 单元测试（60%覆盖率）

**领域层测试**（必须100%覆盖）:

```rust
// domain/aggregates/transaction.rs
#[cfg(test)]
mod tests {
    #[test]
    fn operation_log_records_all_changes() {
        // 测试操作日志记录
    }
    
    #[test]
    fn operations_are_commutative() {
        // 测试操作可交换性（CRDT要求）
    }
    
    #[test]
    fn balance_recalculation_from_operations() {
        // 测试从操作日志重建状态
    }
}
```

### 7.3 集成测试（30%覆盖率）

**同步集成测试**:

```rust
#[tokio::test]
async fn test_transaction_sync_with_operations() {
    // 1. 设备A创建交易
    // 2. 设备B修改交易
    // 3. 同步
    // 4. 验证两个设备状态一致
}

#[tokio::test]
async fn test_conflict_detection_and_resolution() {
    // 测试冲突检测和解决
}
```

**通知集成测试**:

```rust
#[tokio::test]
async fn test_three_layer_notification() {
    // 测试三层通知系统
}

#[tokio::test]
async fn test_notification_deduplication() {
    // 测试通知去重
}
```

### 7.4 E2E测试（10%覆盖率）

```rust
#[tokio::test]
async fn scenario_credit_card_payment_reminder() {
    // 完整的信用卡还款提醒场景
}

#[tokio::test]
async fn scenario_multi_device_sync() {
    // 多设备同步场景
}
```

### 7.5 性能测试

```rust
#[tokio::test]
async fn benchmark_sync_1000_transactions() {
    // 同步1000笔交易应在5秒内完成
    let start = Instant::now();
    sync_service.sync_all().await?;
    assert!(start.elapsed() < Duration::from_secs(5));
}
```

### 7.6 合规性测试

```rust
#[tokio::test]
async fn test_audit_trail_completeness() {
    // 验证审计追踪完整性
}

#[tokio::test]
async fn test_double_entry_invariant() {
    // 验证复式记账不变量
}
```

### 7.7 测试覆盖率目标

| 层次 | 目标覆盖率 | 关键指标 |
|------|-----------|---------|
| 领域层 | 100% | 所有业务规则必须测试 |
| 应用层 | 80% | 所有用例必须测试 |
| 基础设施层 | 60% | 关键路径必须测试 |
| 整体 | 75% | 符合行业标准 |

### 7.8 GitLab CI/CD集成

**.gitlab-ci.yml**:

```yaml
stages:
  - build
  - test
  - quality

test:unit:
  stage: test
  image: rust:1.94
  script:
    - cargo test --lib --verbose
  coverage: '/^\d+\.\d+% coverage/'

test:integration:
  stage: test
  image: rust:1.94
  services:
    - postgres:15
  variables:
    DATABASE_URL: postgres://test:test@postgres:5432/finance_test
  script:
    - cargo test --test '*' --verbose

quality:clippy:
  stage: quality
  image: rust:1.94
  script:
    - cargo clippy -- -D warnings
  allow_failure: false

quality:coverage:
  stage: quality
  image: rust:1.94
  script:
    - cargo install cargo-tarpaulin
    - cargo tarpaulin --out Xml --output-dir coverage
  coverage: '/^\d+\.\d+% coverage/'
```

**质量门禁**:
1. ✅ 所有测试必须通过
2. ✅ Clippy检查无警告
3. ✅ 代码格式化检查通过
4. ✅ 测试覆盖率 ≥ 75%
5. ✅ 至少1个代码审查批准

---

## 8. 实施计划

### 8.1 阶段划分

#### Phase 1: 数据库和领域层（Week 1）

**任务**:
1. 创建新的数据库表（transaction_operations, version_vectors, sync_conflicts, notification_log）
2. 修改现有表（添加version字段）
3. 实现新的值对象（TransactionOperation, VersionVector）
4. 增强Transaction聚合根（添加操作日志支持）
5. 增强Reminder聚合根（添加优先级）

**验收标准**:
- 所有migration脚本可执行
- 领域层单元测试100%通过
- 无编译错误

**工作量**: 40小时

#### Phase 2: 同步策略实现（Week 2）

**任务**:
1. 实现OperationRepository
2. 实现VersionVectorRepository
3. 实现ConflictRepository
4. 实现同步策略（operation_based_sync, lww_sync, append_only_sync）
5. 实现ConflictDetector和ConflictResolver
6. 重写SyncService
7. 集成PostgreSQL仓储

**验收标准**:
- 同步集成测试通过
- 冲突检测和解决测试通过
- 性能测试达标（1000笔交易<5秒）

**工作量**: 50小时

#### Phase 3: 通知系统实现（Week 2-3）

**任务**:
1. 实现OSScheduler接口（Windows/macOS/Linux）
2. 重写NotificationService（三层架构）
3. 重写ReminderScheduler
4. 实现CloudPushService（可选）
5. 在main.rs中启动所有后台服务

**验收标准**:
- 通知集成测试通过
- 三层通知都能正常工作
- 通知去重正确

**工作量**: 30小时

#### Phase 4: 清理和优化（Week 3）

**任务**:
1. 删除所有dead_code
2. 修复所有测试用例
3. 更新文档
4. 性能优化
5. 代码审查

**验收标准**:
- 无clippy警告
- 测试覆盖率≥75%
- 所有E2E测试通过
- 文档完整

**工作量**: 20小时

### 8.2 里程碑

| 里程碑 | 日期 | 交付物 |
|-------|------|--------|
| M1: 数据库和领域层完成 | Week 1 结束 | Migration脚本、领域模型 |
| M2: 同步功能可用 | Week 2 结束 | 多设备同步工作 |
| M3: 通知功能可用 | Week 3 中期 | 三层通知工作 |
| M4: 架构修复完成 | Week 3 结束 | 完整可用系统 |

### 8.3 依赖关系

```
Phase 1 (数据库和领域层)
    ↓
Phase 2 (同步策略) ← 依赖Phase 1
    ↓
Phase 3 (通知系统) ← 依赖Phase 1
    ↓
Phase 4 (清理和优化) ← 依赖Phase 2和Phase 3
```

---

## 9. 风险评估

### 9.1 技术风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| CRDT实现复杂度高 | 中 | 高 | 参考成熟论文和开源实现 |
| OS任务调度跨平台问题 | 中 | 中 | 提供fallback到应用内调度 |
| PostgreSQL集成问题 | 低 | 中 | 已有实现，只需集成 |
| 性能不达标 | 低 | 中 | 提前进行性能测试 |

### 9.2 业务风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 数据迁移失败 | 低 | 高 | 充分测试migration脚本 |
| 用户数据丢失 | 极低 | 极高 | 操作日志保证不丢失 |
| 同步冲突频繁 | 中 | 中 | 提供清晰的冲突解决UI |

### 9.3 进度风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 工作量估算不准 | 中 | 中 | 预留20%缓冲时间 |
| 依赖阻塞 | 低 | 中 | 并行开发独立模块 |
| 测试时间不足 | 中 | 高 | 提前编写测试用例 |

### 9.4 风险应对

**高优先级风险**:
1. CRDT实现复杂度 → 使用简化的Operation-based CRDT
2. 数据迁移失败 → 在测试环境充分验证
3. 测试时间不足 → TDD开发，边写边测

**监控指标**:
- 每日代码提交量
- 测试覆盖率趋势
- 集成测试通过率
- 性能基准测试结果

---

## 10. 参考标准

### 10.1 会计准则

**IFRS (国际财务报告准则)**:
- Section 4.63: 权益定义
- 审计追踪要求：所有交易必须可追溯
- 不可篡改原则：历史记录不可修改

**GAAP (美国公认会计原则)**:
- 复式记账要求
- 借贷平衡原则
- 会计科目体系

**中国会计准则**:
- 三级会计科目体系（1000-资产, 2000-负债, 3000-权益, 4000-收入, 5000-支出）
- 复式记账法
- 会计凭证管理

### 10.2 技术标准

**RFC 6902 - JSON Patch**:
- 定义操作语义（add, remove, replace, move, copy, test）
- 用于TransactionOperation的payload格式

**RFC 7396 - JSON Merge Patch**:
- 简化的合并语义
- 用于Account/Category的冲突合并

**Vector Clocks (Lamport 1978)**:
- 分布式系统中的因果关系追踪
- 用于版本向量实现

**CRDT (Shapiro et al. 2011)**:
- "A comprehensive study of Convergent and Commutative Replicated Data Types"
- Operation-based CRDT用于Transaction同步
- State-based CRDT用于Account同步

**Dynamo (Amazon 2007)**:
- "Dynamo: Amazon's Highly Available Key-value Store"
- 版本向量和冲突解决策略

### 10.3 行业最佳实践

**GnuCash**:
- 开源会计软件的标杆
- 完整的复式记账实现
- 审计追踪和日志系统

**QuickBooks**:
- 商业会计软件标准
- 多用户协作模式
- 数据同步策略

**Ledger CLI**:
- 纯文本会计系统
- Append-only日志
- 不可变数据原则

### 10.4 DDD参考

**Eric Evans - Domain-Driven Design (2003)**:
- 限界上下文划分
- 聚合根设计
- 领域事件

**Vaughn Vernon - Implementing Domain-Driven Design (2013)**:
- 事件溯源
- CQRS模式
- 仓储模式

### 10.5 测试标准

**测试金字塔 (Mike Cohn)**:
- 60% 单元测试
- 30% 集成测试
- 10% E2E测试

**测试覆盖率标准**:
- 领域层：100%
- 应用层：80%
- 基础设施层：60%
- 整体：75%（行业标准）

---

## 附录

### A. 术语表

| 术语 | 定义 |
|------|------|
| CRDT | Conflict-free Replicated Data Type，无冲突复制数据类型 |
| LWW | Last Write Wins，最后写入获胜 |
| DDD | Domain-Driven Design，领域驱动设计 |
| IFRS | International Financial Reporting Standards，国际财务报告准则 |
| GAAP | Generally Accepted Accounting Principles，公认会计原则 |
| Vector Clock | 向量时钟，用于分布式系统的因果关系追踪 |

### B. 变更日志

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|---------|------|
| 1.0 | 2026-05-12 | 初始版本 | Claude |

### C. 审批记录

| 角色 | 姓名 | 审批状态 | 日期 | 备注 |
|------|------|---------|------|------|
| 技术负责人 | - | 待审批 | - | - |
| 架构师 | - | 待审批 | - | - |
| 产品经理 | - | 待审批 | - | - |

---

**文档结束**

