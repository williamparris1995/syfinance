# 代码质量改进实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 改进Phase 1代码质量，消除硬编码、引入ORM、改进日志系统

**Duration:** 16小时

**Reference:** 基于Phase 1代码质量审查反馈

---

## 任务清单

### Part 1: 引入SeaORM（8小时）

- [ ] Task QA-1.1: 添加SeaORM依赖和配置
  - Files: `src-tauri/Cargo.toml`, `src-tauri/build.rs`
  - 添加：sea-orm, sea-orm-migration依赖
  - 配置：数据库连接池

- [ ] Task QA-1.2: 使用sea-orm-cli生成Entity模型
  - Files: `src-tauri/src/entities/` (新目录)
  - 生成：reminders, accounts, categories, transactions等实体
  - 验证：生成的模型与数据库schema一致

- [ ] Task QA-1.3: 重写ReminderRepository使用SeaORM
  - Files: `src-tauri/src/infrastructure/repositories/reminder_repository.rs`
  - 删除：硬编码SQL查询
  - 使用：SeaORM的查询构建器
  - 测试：所有CRUD操作

- [ ] Task QA-1.4: 重写AccountRepository使用SeaORM
  - Files: `src-tauri/src/infrastructure/repositories/account_repository.rs`
  - 同上

- [ ] Task QA-1.5: 重写CategoryRepository使用SeaORM
  - Files: `src-tauri/src/infrastructure/repositories/category_repository.rs`
  - 同上

- [ ] Task QA-1.6: 重写TransactionRepository使用SeaORM
  - Files: `src-tauri/src/infrastructure/repositories/transaction_repository.rs`
  - 同上

### Part 2: 消除硬编码字符串（4小时）

- [ ] Task QA-2.1: 重构Priority enum
  - Files: `src-tauri/src/domain/aggregates/reminder.rs`
  - 删除：手动的as_str/from_str实现
  - 添加：serde derives with rename_all
  - 测试：序列化/反序列化

- [ ] Task QA-2.2: 重构ReminderType enum
  - Files: `src-tauri/src/domain/aggregates/reminder.rs`
  - 同上

- [ ] Task QA-2.3: 重构RepeatPattern enum
  - Files: `src-tauri/src/domain/aggregates/reminder.rs`
  - 同上

- [ ] Task QA-2.4: 创建常量文件
  - Files: `src-tauri/src/domain/constants.rs`
  - 定义：所有魔法字符串为常量
  - 导出：在mod.rs中

### Part 3: 改进日志系统（4小时）

- [ ] Task QA-3.1: 引入tracing框架
  - Files: `src-tauri/Cargo.toml`, `src-tauri/src/main.rs`
  - 添加：tracing, tracing-subscriber依赖
  - 配置：日志级别、格式、输出

- [ ] Task QA-3.2: 为Service层添加tracing
  - Files: `src-tauri/src/application/services/*.rs`
  - 添加：#[tracing::instrument]宏
  - 替换：println!为tracing宏
  - 测试：日志输出包含上下文

- [ ] Task QA-3.3: 为Repository层添加tracing
  - Files: `src-tauri/src/infrastructure/repositories/*.rs`
  - 同上

- [ ] Task QA-3.4: 为错误处理添加tracing
  - Files: 所有返回Result的函数
  - 添加：error!宏记录错误
  - 包含：错误上下文信息

---

## 验收标准

### Part 1: SeaORM
- ✅ 所有Repository使用SeaORM
- ✅ 无硬编码SQL字段名
- ✅ 所有测试通过
- ✅ 性能无明显下降

### Part 2: 无硬编码字符串
- ✅ 所有enum使用serde自动序列化
- ✅ 无手动字符串匹配
- ✅ 魔法字符串提取为常量
- ✅ 测试代码可以有硬编码字符串

### Part 3: 日志系统
- ✅ 所有日志包含模块/文件信息
- ✅ 使用tracing框架
- ✅ 日志级别正确（debug/info/warn/error）
- ✅ 关键操作有日志记录

---

## 风险

1. **SeaORM学习曲线** - 缓解：参考官方文档和示例
2. **性能影响** - 缓解：进行性能测试对比
3. **破坏现有功能** - 缓解：保持完整的测试覆盖

---
