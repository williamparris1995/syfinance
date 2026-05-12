# 财务管理系统架构修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复个人财务管理系统的4个核心架构问题：Account/Category概念混淆、数据同步未集成、通知服务未集成、后台服务未启动

**Architecture:** 采用混合演进架构，基于DDD分层设计。Transaction使用Operation-based CRDT同步，Account/Category使用LWW+版本向量，Debt/Payment使用Append-only日志。通知系统采用三层架构（应用内+OS任务+云端推送）。

**Tech Stack:** Rust 1.94, Tauri 2.x, SQLite, PostgreSQL, tokio, sqlx, serde, chrono

**Duration:** 120小时（3周），分4个Phase

**Reference:** `docs/superpowers/specs/2026-05-12-architecture-fix-design.md`

---

## 实施说明

由于这是一个大型架构修复项目（120小时，4个Phase），完整的逐步实施计划将非常庞大。本文档提供高层次的任务分解和关键实施要点。

**详细设计参考**: `docs/superpowers/specs/2026-05-12-architecture-fix-design.md`

**建议执行方式**:
1. 按Phase顺序执行（Phase 1 → Phase 2 → Phase 3 → Phase 4）
2. 每个Phase内的任务可以部分并行
3. 使用TDD方法：先写测试，再写实现
4. 每完成一个小任务就提交（频繁提交）

---

## Phase 1: 数据库和领域层（Week 1，40小时）

### 目标
- 创建新的数据库表（4个）
- 修改现有表（3个）
- 实现新的值对象（2个）
- 增强聚合根（2个）

### 任务清单

**数据库Migration（8小时）**:
- [ ] Task 1.1: 创建transaction_operations表
- [ ] Task 1.2: 创建version_vectors表
- [ ] Task 1.3: 创建sync_conflicts表
- [ ] Task 1.4: 创建notification_log表
- [ ] Task 1.5: 修改reminders表（添加4个字段）
- [ ] Task 1.6: 修改accounts表（添加version字段）
- [ ] Task 1.7: 修改categories表（添加version字段）

**领域层值对象（12小时）**:
- [ ] Task 1.8: 实现TransactionOperation值对象
  - File: `src-tauri/src/domain/value_objects/transaction_operation.rs`
  - 包含：OperationType枚举、TransactionOperation结构体、序列化/反序列化
  - 测试：操作创建、JSON序列化、验证逻辑

- [ ] Task 1.9: 实现VersionVector值对象
  - File: `src-tauri/src/domain/value_objects/version_vector.rs`
  - 包含：VersionVector结构体、冲突检测方法、合并方法
  - 测试：版本比较、冲突检测、向量合并

**领域层聚合根增强（20小时）**:
- [ ] Task 1.10: 增强Transaction聚合根
  - File: `src-tauri/src/domain/aggregates/transaction.rs`
  - 添加：操作日志记录、操作重放、CRDT支持
  - 测试：操作记录、重放验证、可交换性测试

- [ ] Task 1.11: 增强Reminder聚合根
  - File: `src-tauri/src/domain/aggregates/reminder.rs`
  - 添加：priority字段、last_notified_at字段、os_task_id字段
  - 测试：优先级验证、通知状态管理

**验收标准**:
- ✅ 所有migration脚本可执行
- ✅ 领域层单元测试100%通过
- ✅ 无编译错误
- ✅ Clippy无警告

---

## Phase 2: 同步策略实现（Week 2，50小时）

### 目标
- 实现3个新仓储
- 实现3种同步策略
- 重写SyncService
- 集成PostgreSQL仓储

### 任务清单

**基础设施层仓储（15小时）**:
- [ ] Task 2.1: 实现OperationRepository
  - Files: `src-tauri/src/infrastructure/repositories/operation_repository.rs`
  - 方法：save, find_by_transaction, find_unsync, mark_synced
  - 测试：CRUD操作、查询过滤

- [ ] Task 2.2: 实现VersionVectorRepository
  - Files: `src-tauri/src/infrastructure/repositories/version_vector_repository.rs`
  - 方法：save, find_by_entity, update_version, get_all_for_entity
  - 测试：版本更新、查询

- [ ] Task 2.3: 实现ConflictRepository
  - Files: `src-tauri/src/infrastructure/repositories/conflict_repository.rs`
  - 方法：save, find_unresolved, mark_resolved
  - 测试：冲突记录、解决标记

**同步策略实现（20小时）**:
- [ ] Task 2.4: 实现Operation-based同步策略
  - Files: `src-tauri/src/infrastructure/sync/strategies/operation_based_sync.rs`
  - 功能：操作日志上传、下载、重放、合并
  - 测试：多设备同步、操作合并、冲突自动解决

- [ ] Task 2.5: 实现LWW+版本向量同步策略
  - Files: `src-tauri/src/infrastructure/sync/strategies/lww_sync.rs`
  - 功能：版本向量比较、冲突检测、LWW解决
  - 测试：并发更新、冲突检测、版本合并

- [ ] Task 2.6: 实现Append-only同步策略
  - Files: `src-tauri/src/infrastructure/sync/strategies/append_only_sync.rs`
  - 功能：时间戳排序、记录追加
  - 测试：多设备还款记录、时间戳排序

**冲突检测和解决（10小时）**:
- [ ] Task 2.7: 实现ConflictDetector
  - Files: `src-tauri/src/infrastructure/sync/conflict_detector.rs`
  - 功能：检测UPDATE_UPDATE、DELETE_UPDATE、UPDATE_DELETE冲突
  - 测试：各种冲突场景

- [ ] Task 2.8: 实现ConflictResolver（领域服务）
  - Files: `src-tauri/src/domain/services/conflict_resolver.rs`
  - 功能：冲突解决策略、用户选择接口
  - 测试：自动解决、用户选择

**SyncService重写（5小时）**:
- [ ] Task 2.9: 重写SyncService
  - Files: `src-tauri/src/application/services/sync_service.rs`
  - 删除：旧的内存实现
  - 新增：使用混合策略、集成PostgreSQL仓储
  - 测试：完整同步流程、性能测试（1000笔<5秒）

**验收标准**:
- ✅ 同步集成测试通过
- ✅ 冲突检测和解决测试通过
- ✅ 性能测试达标（1000笔交易<5秒）
- ✅ PostgreSQL仓储正常工作

---

## Phase 3: 通知系统实现（Week 2-3，30小时）

### 目标
- 实现跨平台OS任务调度
- 重写NotificationService（三层架构）
- 重写ReminderScheduler
- 在main.rs中启动所有后台服务

### 任务清单

**OS任务调度器（15小时）**:
- [ ] Task 3.1: 实现OSScheduler trait
  - Files: `src-tauri/src/infrastructure/notifications/os_scheduler/mod.rs`
  - 定义：register_reminder, unregister_reminder, list_scheduled接口

- [ ] Task 3.2: 实现WindowsScheduler
  - Files: `src-tauri/src/infrastructure/notifications/os_scheduler/windows.rs`
  - 使用：schtasks.exe创建任务
  - 测试：任务创建、删除、列表

- [ ] Task 3.3: 实现MacOSScheduler
  - Files: `src-tauri/src/infrastructure/notifications/os_scheduler/macos.rs`
  - 使用：launchd创建.plist文件
  - 测试：任务创建、删除、列表

- [ ] Task 3.4: 实现LinuxScheduler
  - Files: `src-tauri/src/infrastructure/notifications/os_scheduler/linux.rs`
  - 使用：systemd timer创建.timer和.service文件
  - 测试：任务创建、删除、列表

**NotificationService重写（8小时）**:
- [ ] Task 3.5: 重写NotificationService
  - Files: `src-tauri/src/infrastructure/notifications/notification_service.rs`
  - 删除：空实现
  - 新增：三层通知（应用内+OS+云端）、去重逻辑、优先级处理
  - 测试：三层通知、去重、优先级

**ReminderScheduler重写（5小时）**:
- [ ] Task 3.6: 重写ReminderScheduler
  - Files: `src-tauri/src/infrastructure/reminders/reminder_scheduler.rs`
  - 删除：未启动的代码
  - 新增：集成NotificationService、每小时检查、通知日志记录
  - 测试：定时检查、通知触发

**后台服务启动（2小时）**:
- [ ] Task 3.7: 修改main.rs启动所有后台服务
  - Files: `src-tauri/src/main.rs`
  - 新增：启动SyncScheduler、启动ReminderScheduler
  - 测试：应用启动、后台任务运行

**验收标准**:
- ✅ 通知集成测试通过
- ✅ 三层通知都能正常工作
- ✅ 通知去重正确
- ✅ 后台服务自动启动

---

## Phase 4: 清理和优化（Week 3，20小时）

### 目标
- 删除所有dead_code
- 修复所有测试用例
- 更新文档
- 性能优化
- 代码审查

### 任务清单

**代码清理（8小时）**:
- [ ] Task 4.1: 删除所有dead_code
  - 删除：所有`#![allow(dead_code)]`标记的未使用代码
  - 删除：旧的SyncService内存实现
  - 删除：空的NotificationService实现
  - 运行：`cargo clippy`确保无警告

- [ ] Task 4.2: 修复所有测试用例
  - 修复：account_commands.rs中的chart_of_account_code引用
  - 修复：transaction_commands.rs中的参数不匹配
  - 修复：transaction_repository.rs中的类型错误
  - 运行：`cargo test`确保全部通过

**文档更新（4小时）**:
- [ ] Task 4.3: 更新README和文档
  - 更新：BUILD.md中的构建说明
  - 更新：TESTING_GUIDE.md中的测试说明
  - 更新：PROJECT_SUMMARY.md反映新架构
  - 删除：LIMITATIONS.md中已修复的问题

**性能优化（4小时）**:
- [ ] Task 4.4: 性能优化
  - 优化：同步批量操作
  - 优化：数据库查询索引
  - 优化：通知调度频率
  - 测试：性能基准测试

**代码审查（4小时）**:
- [ ] Task 4.5: 代码审查和重构
  - 审查：所有新增代码
  - 重构：重复代码
  - 优化：错误处理
  - 确保：符合Rust最佳实践

**验收标准**:
- ✅ 无clippy警告
- ✅ 测试覆盖率≥75%
- ✅ 所有E2E测试通过
- ✅ 文档完整且准确
- ✅ 性能测试达标

---

## 关键文件清单

### 新增文件（约30个）

**Migrations**:
- `src-tauri/migrations/20260512000001_create_transaction_operations.sql`
- `src-tauri/migrations/20260512000002_create_version_vectors.sql`
- `src-tauri/migrations/20260512000003_create_sync_conflicts.sql`
- `src-tauri/migrations/20260512000004_create_notification_log.sql`
- `src-tauri/migrations/20260512000005_alter_reminders.sql`
- `src-tauri/migrations/20260512000006_alter_accounts.sql`
- `src-tauri/migrations/20260512000007_alter_categories.sql`

**领域层**:
- `src-tauri/src/domain/value_objects/transaction_operation.rs`
- `src-tauri/src/domain/value_objects/version_vector.rs`
- `src-tauri/src/domain/services/conflict_resolver.rs`

**基础设施层**:
- `src-tauri/src/infrastructure/repositories/operation_repository.rs`
- `src-tauri/src/infrastructure/repositories/version_vector_repository.rs`
- `src-tauri/src/infrastructure/repositories/conflict_repository.rs`
- `src-tauri/src/infrastructure/sync/strategies/mod.rs`
- `src-tauri/src/infrastructure/sync/strategies/operation_based_sync.rs`
- `src-tauri/src/infrastructure/sync/strategies/lww_sync.rs`
- `src-tauri/src/infrastructure/sync/strategies/append_only_sync.rs`
- `src-tauri/src/infrastructure/sync/conflict_detector.rs`
- `src-tauri/src/infrastructure/notifications/os_scheduler/mod.rs`
- `src-tauri/src/infrastructure/notifications/os_scheduler/windows.rs`
- `src-tauri/src/infrastructure/notifications/os_scheduler/macos.rs`
- `src-tauri/src/infrastructure/notifications/os_scheduler/linux.rs`
- `src-tauri/src/infrastructure/notifications/cloud_push.rs`

### 修改文件（约15个）

**领域层**:
- `src-tauri/src/domain/aggregates/transaction.rs`
- `src-tauri/src/domain/aggregates/reminder.rs`
- `src-tauri/src/domain/value_objects/sync_metadata.rs`

**应用层**:
- `src-tauri/src/application/services/sync_service.rs`
- `src-tauri/src/application/services/transaction_service.rs`
- `src-tauri/src/application/services/reminder_service.rs`

**基础设施层**:
- `src-tauri/src/infrastructure/repositories/transaction_repository.rs`
- `src-tauri/src/infrastructure/repositories/transaction_repository_postgres.rs`
- `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs`
- `src-tauri/src/infrastructure/sync/sync_scheduler.rs`
- `src-tauri/src/infrastructure/notifications/notification_service.rs`
- `src-tauri/src/infrastructure/reminders/reminder_scheduler.rs`
- `src-tauri/src/presentation/api/sync_routes.rs`

**入口**:
- `src-tauri/src/main.rs`

### 删除文件
- 所有标记`#![allow(dead_code)]`的未使用代码

---

## 测试策略

### 单元测试（60%）
- 每个新增的值对象、聚合根、服务都需要单元测试
- 领域层必须100%覆盖
- 使用TDD：先写测试，再写实现

### 集成测试（30%）
- 同步功能集成测试（多设备场景）
- 通知功能集成测试（三层通知）
- 数据库操作集成测试

### E2E测试（10%）
- 完整的用户场景测试
- 信用卡还款提醒场景
- 多设备同步场景

### 性能测试
- 同步1000笔交易<5秒
- 操作日志重放<10秒
- 通知触发<1秒

---

## GitLab CI/CD

参考设计文档第7.8节的完整CI/CD配置。

**关键检查点**:
- ✅ 所有测试必须通过
- ✅ Clippy检查无警告
- ✅ 代码格式化检查通过
- ✅ 测试覆盖率 ≥ 75%
- ✅ 至少1个代码审查批准

---

## 风险和缓解

参考设计文档第9节的完整风险评估。

**高优先级风险**:
1. CRDT实现复杂度 → 使用简化的Operation-based CRDT
2. 数据迁移失败 → 在测试环境充分验证
3. 测试时间不足 → TDD开发，边写边测

---

## 下一步

1. 审查本实施计划
2. 选择执行方式：
   - **Subagent-Driven (推荐)**: 每个任务派发独立子代理，任务间审查
   - **Inline Execution**: 在当前会话中批量执行，设置检查点
3. 开始Phase 1实施

---

