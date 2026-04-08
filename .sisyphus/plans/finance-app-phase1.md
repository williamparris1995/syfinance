# 个人财务管理系统 - Phase 1: 核心财务模块

## TL;DR

> **Quick Summary**: 构建个人财务管理桌面应用的核心财务功能，包括多币种账户管理、复式记账收支跟踪、借贷还款管理、财务报表生成和数据同步。采用DDD分层架构，Tauri跨平台客户端，Rust后端服务，遵循中国会计准则。
> 
> **Deliverables**: 
> - Tauri桌面应用（Windows/macOS/Linux）
> - 账户管理系统（三级会计科目）
> - 多币种支持（汇率管理）
> - 收支记录系统（复式记账）
> - 借贷管理系统（还款计划+提醒）
> - 财务报表（资产负债表、收支表、科目余额表）
> - 数据同步服务（SQLite ↔ PostgreSQL）
> - 系统通知（还款提醒、逾期提醒）
> 
> **Estimated Effort**: Large（6-8周）
> **Parallel Execution**: YES - 5 waves
> **Critical Path**: Wave 1 → Wave 2 → Wave 3 → Wave 4 → Wave 5 → Final Verification

---

## Context

### Original Request
用户需要开发一个综合性个人财务管理应用，使用Tauri框架构建跨平台客户端，Rust后端服务，采用DDD设计和TDD开发方式。Phase 1聚焦核心财务功能：账户管理、收支记录、借贷管理、报表生成、数据同步。

### Interview Summary
**Key Discussions**:
- 数据存储：离线优先（本地SQLite）+ 后台自动同步到PostgreSQL
- 前端技术栈：React + TypeScript + TanStack Query/Router + shadcn/ui
- 用户模式：单用户（带账号ID用于同步识别）
- 测试策略：简化测试（核心逻辑单元测试 + Agent QA场景）
- 多币种支持：需要（汇率管理、多币种汇总）
- 会计准则：遵循中国会计准则（三级科目体系）
- 借贷管理：区分借出/借入/信用卡/贷款，支持还款提醒和逾期管理

### Metis Review
**Identified Gaps** (addressed):
- 数据库迁移策略：使用sqlx migrations，服务端拥有schema真相
- 同步冲突解决：Last Write Wins（updated_at时间戳比较），软删除tombstone策略
- 账号ID生成：服务端生成UUID，首次启动注册获取
- 复式记账验证：Transaction聚合根包含借贷双方，领域层断言debit == credit
- 通知调度：OS级定时通知，应用启动时重新调度
- 会计科目体系：遵循中国会计准则，实现常用科目，支持用户自定义三级科目
- 多币种精度：使用rust_decimal + rust_money库

---

## Work Objectives

### Core Objective
构建个人财务管理系统的核心财务模块（Phase 1），实现多币种账户管理、复式记账、借贷还款跟踪、财务报表生成和离线优先的数据同步，遵循DDD分层架构和中国会计准则。

### Concrete Deliverables
- `src-tauri/`: Rust后端DDD分层架构（Domain/Application/Infrastructure/Presentation）
- `src/`: React前端应用（账户、交易、借贷、报表页面）
- SQLite数据库schema（本地存储）
- PostgreSQL数据库schema（云端同步）
- Tauri Commands API（前后端通信）
- REST API（同步服务）
- 系统通知集成（还款提醒）

### Definition of Done
- [ ] `cargo build --release` 编译成功，无警告
- [ ] `pnpm build` 前端构建成功
- [ ] `cargo test` 所有单元测试通过
- [ ] `pnpm vitest run` 关键组件测试通过
- [ ] `tauri build` 生成可执行文件（Windows/macOS/Linux）
- [ ] 所有QA场景验证通过，证据文件存在于`.sisyphus/evidence/`
- [ ] 数据库迁移脚本可重复执行
- [ ] 同步功能正常（本地↔云端）
- [ ] 还款提醒正常触发

### Must Have
- 三级会计科目体系（遵循中国会计准则）
- 复式记账（每笔交易借贷平衡）
- 多币种支持（至少CNY, USD, EUR）
- 汇率管理（手动输入）
- 借贷类型区分（借出/借入/信用卡/贷款）
- 还款计划自动生成（等额本息/等额本金）
- 还款提醒（到期前N天）
- 逾期管理和提醒
- 离线优先数据同步
- 软删除（保留历史记录）
- rust_decimal精确货币计算

### Must NOT Have (Guardrails)
- ❌ 富文本编辑器（Phase 1仅纯文本）
- ❌ 文件附件上传
- ❌ 实时汇率API（手动输入，API在Phase 2）
- ❌ 预算功能（Phase 2）
- ❌ 投资跟踪（Phase 2）
- ❌ 税务报表（Phase 2）
- ❌ 日历功能（Phase 3）
- ❌ 待办事项（Phase 3）
- ❌ 备忘录（Phase 3）
- ❌ 邮件通知（后续迭代）
- ❌ 暗黑模式（后续迭代）
- ❌ 数据导入导出（后续迭代）
- ❌ 可变利率贷款
- ❌ 贷款重组或部分提前还款重算
- ❌ 子任务或依赖关系
- ❌ 过度抽象（保持简单直接）
- ❌ 过度验证（仅必要的业务规则验证）
- ❌ 过度文档化（代码即文档，仅关键处注释）

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.
> Acceptance criteria requiring "user manually tests/confirms" are FORBIDDEN.

### Test Decision
- **Infrastructure exists**: NO（需要搭建）
- **Automated tests**: 简化测试（核心逻辑单元测试）
- **Framework**: 
  - Rust: cargo test
  - TypeScript: vitest
- **TDD**: 核心领域逻辑使用TDD（Account, Transaction, Debt聚合根）

### QA Policy
Every task MUST include agent-executed QA scenarios (see TODO template below).
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright (playwright skill) - Navigate, interact, assert DOM, screenshot
- **TUI/CLI**: Use interactive_bash (tmux) - Run command, send keystrokes, validate output
- **API/Backend**: Use Bash (curl) - Send requests, assert status + response fields
- **Database**: Use Bash (sqlite3/psql) - Query tables, assert data integrity
- **Library/Module**: Use Bash (cargo test) - Run tests, assert pass/fail

---

## Execution Strategy

### Parallel Execution Waves

> Maximize throughput by grouping independent tasks into parallel waves.
> Each wave completes before the next begins.
> Target: 5-8 tasks per wave. Fewer than 3 per wave (except final) = under-splitting.

```
Wave 1 (Foundation - 8 tasks, can start immediately):
├── Task 1: Project scaffolding (Tauri + React + Rust) [quick]
├── Task 2: Database schema design (SQLite + PostgreSQL) [unspecified-high]
├── Task 3: DDD layer structure setup [quick]
├── Task 4: Test infrastructure setup [quick]
├── Task 5: Currency value object + repository [quick]
├── Task 6: ChartOfAccounts aggregate (中国会计准则科目) [unspecified-high]
├── Task 7: Money value object (rust_decimal) [quick]
└── Task 8: SyncMetadata value object [quick]

Wave 2 (Core Domain - 7 tasks, depends on Wave 1):
├── Task 9: Account aggregate + repository (depends: 6, 7) [deep]
├── Task 10: Transaction aggregate + double-entry validation (depends: 6, 7, 9) [deep]
├── Task 11: Debt aggregate + amortization calculation (depends: 7, 9) [deep]
├── Task 12: Reminder aggregate + scheduling logic (depends: 11) [unspecified-high]
├── Task 13: Account application service + use cases (depends: 9) [unspecified-high]
├── Task 14: Transaction application service + use cases (depends: 10) [unspecified-high]
└── Task 15: Debt application service + use cases (depends: 11, 12) [unspecified-high]

Wave 3 (Infrastructure + API - 8 tasks, depends on Wave 2):
├── Task 16: SQLite repository implementations (depends: 9, 10, 11) [unspecified-high]
├── Task 17: PostgreSQL repository implementations (depends: 9, 10, 11) [unspecified-high]
├── Task 18: Sync service (conflict resolution) (depends: 16, 17) [deep]
├── Task 19: Notification service (tauri-plugin-notification) (depends: 12) [quick]
├── Task 20: Tauri Commands (accounts) (depends: 13, 16) [quick]
├── Task 21: Tauri Commands (transactions) (depends: 14, 16) [quick]
├── Task 22: Tauri Commands (debts) (depends: 15, 16) [quick]
└── Task 23: REST API (sync endpoints) (depends: 18, 17) [unspecified-high]

Wave 4 (Frontend - 8 tasks, depends on Wave 3):
├── Task 24: shadcn/ui setup + theme configuration (depends: 1) [visual-engineering]
├── Task 25: TanStack Query + Router setup (depends: 1) [quick]
├── Task 26: Account management page (depends: 20, 24, 25) [visual-engineering]
├── Task 27: Transaction recording page (depends: 21, 24, 25) [visual-engineering]
├── Task 28: Debt management page (depends: 22, 24, 25) [visual-engineering]
├── Task 29: Reports page (balance sheet, income statement) (depends: 21, 24, 25) [visual-engineering]
├── Task 30: Currency settings page (depends: 20, 24, 25) [visual-engineering]
└── Task 31: Sync status indicator + manual sync button (depends: 23, 24, 25) [visual-engineering]

Wave 5 (Integration + Polish - 6 tasks, depends on Wave 4):
├── Task 32: Account registration + device binding (depends: 23, 31) [unspecified-high]
├── Task 33: Background sync scheduler (depends: 18, 32) [unspecified-high]
├── Task 34: Reminder notification integration (depends: 19, 28) [unspecified-high]
├── Task 35: Multi-currency report aggregation (depends: 29, 30) [deep]
├── Task 36: Error handling + user feedback (depends: 26, 27, 28, 29) [unspecified-high]
└── Task 37: Application build + packaging (depends: all above) [quick]

Wave FINAL (Verification - 4 parallel reviews, then user okay):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high + playwright skill)
└── Task F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay
```

**Critical Path**: T1 → T6 → T9 → T10 → T16 → T21 → T27 → T36 → T37 → F1-F4 → user okay

**Parallel Speedup**: ~65% faster than sequential

**Max Concurrent**: 8 tasks (Waves 1, 3, 4)

### Dependency Matrix

**Wave 1 (1-8)**: No dependencies - can start immediately

**Wave 2**:
- **9**: 6, 7 → 10, 13, 16, 17
- **10**: 6, 7, 9 → 14, 16, 17
- **11**: 7, 9 → 12, 15, 16, 17
- **12**: 11 → 15, 19
- **13**: 9 → 20
- **14**: 10 → 21
- **15**: 11, 12 → 22

**Wave 3**:
- **16**: 9, 10, 11 → 20, 21, 22
- **17**: 9, 10, 11 → 18, 23
- **18**: 16, 17 → 23, 33
- **19**: 12 → 34
- **20**: 13, 16 → 26, 30
- **21**: 14, 16 → 27, 29
- **22**: 15, 16 → 28
- **23**: 18, 17 → 31, 32

**Wave 4**:
- **24**: 1 → 26-31
- **25**: 1 → 26-31
- **26**: 20, 24, 25 → 36
- **27**: 21, 24, 25 → 36
- **28**: 22, 24, 25 → 34, 36
- **29**: 21, 24, 25 → 35, 36
- **30**: 20, 24, 25 → 35
- **31**: 23, 24, 25 → 32

**Wave 5**:
- **32**: 23, 31 → 33
- **33**: 18, 32 → 37
- **34**: 19, 28 → 37
- **35**: 29, 30 → 37
- **36**: 26, 27, 28, 29 → 37
- **37**: 32-36 → F1-F4

**Wave FINAL**:
- **F1-F4**: 37 → user okay

### Agent Dispatch Summary

- **Wave 1**: 8 tasks - T1,3,4,5,7,8 → `quick`, T2,6 → `unspecified-high`
- **Wave 2**: 7 tasks - T9,10,11 → `deep`, T12-15 → `unspecified-high`
- **Wave 3**: 8 tasks - T16,17,18,23 → `unspecified-high`/`deep`, T19-22 → `quick`
- **Wave 4**: 8 tasks - T24,26-31 → `visual-engineering`, T25 → `quick`
- **Wave 5**: 6 tasks - T32-36 → `unspecified-high`/`deep`, T37 → `quick`
- **Wave FINAL**: 4 tasks - F1 → `oracle`, F2,F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.
> **A task WITHOUT QA Scenarios is INCOMPLETE. No exceptions.**

---

### Wave 1: Foundation (8 tasks, start immediately)

- [x] 1. Project Scaffolding - Tauri + React + Rust

  **What to do**:
  - Initialize Tauri 2.x project with React + TypeScript template
  - Configure pnpm workspace (root for frontend, src-tauri for backend)
  - Setup Vite build configuration
  - Configure Tailwind CSS
  - Create basic project structure: src/pages, src/components, src/lib
  - Setup Rust workspace in src-tauri with DDD folder structure
  - Configure Cargo.toml with dependencies: axum, sqlx, tokio, serde, rust_decimal, chrono
  - Create .gitignore for Rust and Node artifacts
  - Verify project builds successfully

  **Must NOT do**:
  - Do not add unnecessary dependencies
  - Do not create placeholder files beyond basic structure
  - Do not implement any business logic yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Straightforward project initialization using standard templates

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2-8)
  - **Blocks**: Tasks 3, 4, 24, 25
  - **Blocked By**: None (can start immediately)

  **References**:
  - Official docs: https://tauri.app/v2/guides/getting-started/ - Tauri 2.x project setup
  - Official docs: https://react.dev/learn/start-a-new-react-project - React + Vite setup
  - Official docs: https://tailwindcss.com/docs/guides/vite - Tailwind with Vite

  **Acceptance Criteria**:
  - [ ] `pnpm install` completes without errors
  - [ ] `cargo build` in src-tauri completes successfully
  - [ ] `pnpm dev` starts development server
  - [ ] `tauri dev` launches application window

  **QA Scenarios**:

  ```
  Scenario: Project builds successfully
    Tool: Bash (cargo + pnpm)
    Preconditions: Fresh project directory
    Steps:
      1. Run `pnpm install` in project root
      2. Run `cargo build` in src-tauri directory
      3. Assert exit code 0 for both commands
    Expected Result: Both commands succeed, no error output
    Failure Indicators: Non-zero exit code, error messages in output
    Evidence: .sisyphus/evidence/task-1-build-success.txt

  Scenario: Development server starts
    Tool: Bash (pnpm + timeout)
    Preconditions: Dependencies installed
    Steps:
      1. Run `pnpm dev` with 10s timeout
      2. Check for "Local: http://localhost" in output
      3. Kill process
    Expected Result: Dev server starts, shows localhost URL
    Failure Indicators: Process crashes, no URL in output
    Evidence: .sisyphus/evidence/task-1-dev-server.txt
  ```

  **Evidence to Capture**:
  - [ ] task-1-build-success.txt (cargo + pnpm build output)
  - [ ] task-1-dev-server.txt (dev server startup log)

  **Commit**: YES
  - Message: `chore(infra): initialize Tauri + React project structure`
  - Files: `package.json, Cargo.toml, src-tauri/*, src/*, vite.config.ts, tailwind.config.js`
  - Pre-commit: `cargo check && pnpm type-check`

- [x] 2. Database Schema Design - SQLite + PostgreSQL

  **What to do**:
  - Design database schema for both SQLite (local) and PostgreSQL (remote)
  - Create sqlx migration files in src-tauri/migrations/
  - Implement tables: currencies, chart_of_accounts, accounts, transactions, transaction_entries, debts, debt_payments, reminders, sync_metadata
  - Add indexes for common queries (account_id, transaction_date, debt_due_date)
  - Add CHECK constraints for double-entry validation (debit_sum = credit_sum per transaction)
  - Add foreign key constraints with ON DELETE RESTRICT for data integrity
  - Include soft delete columns (deleted_at) for all synced tables
  - Include sync metadata columns (updated_at, device_id, synced_at)
  - Write migration rollback scripts
  - Test migrations on both SQLite and PostgreSQL

  **Must NOT do**:
  - Do not use auto-increment IDs (use UUIDs for sync compatibility)
  - Do not use FLOAT/DOUBLE for money (use DECIMAL/NUMERIC)
  - Do not create tables for Phase 2/3 features (investments, taxes, calendar)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Complex schema design requiring careful consideration of sync, constraints, and data integrity

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3-8)
  - **Blocks**: Tasks 5, 6, 7, 8, 9, 10, 11, 16, 17
  - **Blocked By**: None (can start immediately)

  **References**:
  - Official docs: https://docs.rs/sqlx/latest/sqlx/migrate/ - sqlx migrations
  - Pattern: Double-entry bookkeeping schema design (transactions + entries tables)
  - Constraint: 中国会计准则科目编码规则 (1000-资产, 2000-负债, 3000-权益, 4000-收入, 5000-支出)

  **Acceptance Criteria**:
  - [ ] `sqlx migrate run --database-url sqlite:local.db` succeeds
  - [ ] `sqlx migrate run --database-url postgresql://localhost/finance` succeeds
  - [ ] All tables created with correct columns and types
  - [ ] CHECK constraint prevents unbalanced transactions
  - [ ] Foreign keys enforce referential integrity

  **QA Scenarios**:

  ```
  Scenario: SQLite migrations apply successfully
    Tool: Bash (sqlx)
    Preconditions: SQLite database file does not exist
    Steps:
      1. Run `sqlx migrate run --database-url sqlite:test.db`
      2. Assert exit code 0
      3. Run `sqlite3 test.db ".tables"` and verify all tables exist
      4. Count tables: should be 9 (currencies, chart_of_accounts, accounts, transactions, transaction_entries, debts, debt_payments, reminders, sync_metadata)
    Expected Result: All 9 tables created
    Failure Indicators: Migration fails, missing tables
    Evidence: .sisyphus/evidence/task-2-sqlite-migration.txt

  Scenario: Double-entry constraint enforced
    Tool: Bash (sqlite3)
    Preconditions: Migrations applied
    Steps:
      1. Insert transaction with unbalanced entries (debit=100, credit=50)
      2. Assert INSERT fails with CHECK constraint violation
    Expected Result: Database rejects unbalanced transaction
    Failure Indicators: INSERT succeeds (constraint not working)
    Evidence: .sisyphus/evidence/task-2-constraint-test.txt
  ```

  **Evidence to Capture**:
  - [ ] task-2-sqlite-migration.txt (migration output + table list)
  - [ ] task-2-postgresql-migration.txt (PostgreSQL migration output)
  - [ ] task-2-constraint-test.txt (constraint validation test)

  **Commit**: YES
  - Message: `feat(db): add database schema with migrations for SQLite and PostgreSQL`
  - Files: `src-tauri/migrations/*.sql`
  - Pre-commit: `sqlx migrate run --database-url sqlite::memory:`

- [x] 3. DDD Layer Structure Setup

  **What to do**:
  - Create Rust module structure for DDD layers in src-tauri/src/
  - Domain layer: src-tauri/src/domain/ (aggregates, value_objects, repositories traits)
  - Application layer: src-tauri/src/application/ (use_cases, dtos, services)
  - Infrastructure layer: src-tauri/src/infrastructure/ (repositories impl, database, sync, notifications)
  - Presentation layer: src-tauri/src/presentation/ (tauri_commands, api)
  - Create mod.rs files for each module
  - Setup dependency injection pattern using trait objects
  - Create AppState struct to hold repository instances
  - Configure Tauri to use AppState

  **Must NOT do**:
  - Do not implement any business logic yet (just structure)
  - Do not create concrete implementations (only traits and empty structs)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Straightforward folder structure and module setup

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4-8)
  - **Blocks**: Tasks 5-15
  - **Blocked By**: Task 1

  **References**:
  - Pattern: DDD layered architecture in Rust (Domain → Application → Infrastructure → Presentation)
  - Pattern: Trait-based dependency injection with Arc<dyn Trait>

  **Acceptance Criteria**:
  - [ ] All module folders exist with mod.rs files
  - [ ] `cargo check` passes (no compilation errors)
  - [ ] Module hierarchy correctly declared in lib.rs

  **QA Scenarios**:

  ```
  Scenario: Module structure compiles
    Tool: Bash (cargo)
    Preconditions: Project scaffolding complete
    Steps:
      1. Run `cargo check` in src-tauri
      2. Assert exit code 0
      3. Verify no warnings about unused modules
    Expected Result: Compilation succeeds
    Failure Indicators: Compilation errors, module not found errors
    Evidence: .sisyphus/evidence/task-3-module-check.txt
  ```

  **Evidence to Capture**:
  - [ ] task-3-module-check.txt (cargo check output)

  **Commit**: YES
  - Message: `chore(arch): setup DDD layer structure`
  - Files: `src-tauri/src/domain/, src-tauri/src/application/, src-tauri/src/infrastructure/, src-tauri/src/presentation/`
  - Pre-commit: `cargo check`

- [x] 4. Test Infrastructure Setup

  **What to do**:
  - Configure cargo test in src-tauri/Cargo.toml
  - Create tests/ directory for integration tests
  - Setup vitest for frontend in package.json
  - Create vitest.config.ts with React testing library
  - Add test utilities: test database setup, mock factories
  - Create example unit test in domain layer
  - Create example component test in frontend
  - Verify tests run successfully

  **Must NOT do**:
  - Do not write comprehensive tests yet (just infrastructure)
  - Do not setup E2E testing (out of scope for Phase 1)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Standard test framework configuration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-3, 5-8)
  - **Blocks**: Tasks 9-15 (TDD for domain logic)
  - **Blocked By**: Task 1

  **References**:
  - Official docs: https://doc.rust-lang.org/book/ch11-00-testing.html - Rust testing
  - Official docs: https://vitest.dev/guide/ - Vitest setup

  **Acceptance Criteria**:
  - [ ] `cargo test` runs and passes example test
  - [ ] `pnpm vitest run` runs and passes example test
  - [ ] Test coverage reporting configured

  **QA Scenarios**:

  ```
  Scenario: Rust tests execute
    Tool: Bash (cargo)
    Preconditions: Test infrastructure configured
    Steps:
      1. Run `cargo test` in src-tauri
      2. Assert exit code 0
      3. Verify "test result: ok" in output
    Expected Result: Tests pass
    Failure Indicators: Test failures, compilation errors
    Evidence: .sisyphus/evidence/task-4-rust-tests.txt

  Scenario: Frontend tests execute
    Tool: Bash (pnpm)
    Preconditions: Vitest configured
    Steps:
      1. Run `pnpm vitest run`
      2. Assert exit code 0
      3. Verify "Test Files  1 passed" in output
    Expected Result: Tests pass
    Failure Indicators: Test failures, configuration errors
    Evidence: .sisyphus/evidence/task-4-frontend-tests.txt
  ```

  **Evidence to Capture**:
  - [ ] task-4-rust-tests.txt (cargo test output)
  - [ ] task-4-frontend-tests.txt (vitest output)

  **Commit**: YES
  - Message: `chore(test): setup test infrastructure for Rust and TypeScript`
  - Files: `Cargo.toml, vitest.config.ts, src-tauri/tests/, src/__tests__/`
  - Pre-commit: `cargo test && pnpm vitest run`

- [x] 5. Currency Value Object + Repository

  **What to do**:
  - Create Currency value object in domain/value_objects/currency.rs
  - Fields: code (String, ISO 4217), symbol (String), exchange_rate (Decimal relative to base currency)
  - Implement validation: code must be 3 uppercase letters
  - Create CurrencyRepository trait in domain/repositories/
  - Implement SQLite repository in infrastructure/repositories/currency_repository.rs
  - Add CRUD methods: create, find_by_code, list_all, update_rate
  - Write unit tests for Currency value object validation
  - Write integration tests for repository CRUD operations

  **Must NOT do**:
  - Do not implement real-time exchange rate API (manual input only)
  - Do not add currency conversion logic yet (that's in Money value object)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Simple value object with basic CRUD repository

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-4, 6-8)
  - **Blocks**: Tasks 7, 9, 30
  - **Blocked By**: Task 2 (database schema)

  **References**:
  - `src-tauri/migrations/001_create_currencies.sql` - currencies table schema
  - Official docs: https://docs.rs/rust_decimal/latest/rust_decimal/ - Decimal type for exchange rates
  - Standard: ISO 4217 currency codes

  **Acceptance Criteria**:
  - [ ] Currency::new("CNY", "¥", Decimal::ONE) creates valid currency
  - [ ] Currency::new("invalid", "$", Decimal::ONE) returns validation error
  - [ ] `cargo test domain::value_objects::currency` passes all tests
  - [ ] Repository can insert and retrieve currencies from SQLite

  **QA Scenarios**:

  ```
  Scenario: Currency validation works
    Tool: Bash (cargo test)
    Preconditions: Currency value object implemented
    Steps:
      1. Run `cargo test currency::validation`
      2. Assert tests pass for valid codes (CNY, USD, EUR)
      3. Assert tests fail for invalid codes (cn, US, 123)
    Expected Result: Validation tests pass
    Failure Indicators: Tests fail, invalid currencies accepted
    Evidence: .sisyphus/evidence/task-5-currency-validation.txt

  Scenario: Currency repository CRUD
    Tool: Bash (sqlite3)
    Preconditions: Repository implemented, migrations applied
    Steps:
      1. Insert CNY currency via repository
      2. Query `sqlite3 test.db "SELECT * FROM currencies WHERE code='CNY'"`
      3. Assert row exists with correct symbol and rate
      4. Update exchange rate
      5. Query again and verify rate changed
    Expected Result: CRUD operations succeed
    Failure Indicators: Insert fails, query returns no rows, update doesn't persist
    Evidence: .sisyphus/evidence/task-5-currency-crud.txt
  ```

  **Evidence to Capture**:
  - [ ] task-5-currency-validation.txt (unit test output)
  - [ ] task-5-currency-crud.txt (integration test output)

  **Commit**: YES
  - Message: `feat(domain): add Currency value object and repository`
  - Files: `src-tauri/src/domain/value_objects/currency.rs, src-tauri/src/infrastructure/repositories/currency_repository.rs`
  - Pre-commit: `cargo test currency`

- [x] 6. ChartOfAccounts Aggregate - 中国会计准则科目

  **What to do**:
  - Create ChartOfAccounts aggregate in domain/aggregates/chart_of_accounts.rs
  - Fields: code (String, e.g. "1001"), name (String), level (1/2/3), account_type (Asset/Liability/Equity/Income/Expense), parent_code (Option<String>), balance_direction (Debit/Credit)
  - Implement 中国会计准则 standard accounts as constants or seed data
  - Level 1: 1000-资产, 2000-负债, 3000-权益, 4000-收入, 5000-支出
  - Level 2: 1001-库存现金, 1002-银行存款, 1012-其他货币资金, 2001-短期借款, 2201-应付账款, 4001-主营业务收入, 5001-主营业务成本, 5201-财务费用
  - Add validation: code format, parent must exist for level 2/3
  - Create ChartOfAccountsRepository trait
  - Implement SQLite repository
  - Write unit tests for validation rules
  - Write integration tests for hierarchical queries

  **Must NOT do**:
  - Do not implement all possible accounting subjects (only common ones for personal finance)
  - Do not add complex accounting rules beyond basic validation

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Requires understanding of Chinese accounting standards and hierarchical data modeling

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-5, 7-8)
  - **Blocks**: Tasks 9, 10, 13, 14
  - **Blocked By**: Task 2 (database schema)

  **References**:
  - `src-tauri/migrations/002_create_chart_of_accounts.sql` - chart_of_accounts table schema
  - Standard: 中国企业会计准则 (simplified for personal finance)
  - Pattern: Hierarchical data with parent-child relationships

  **Acceptance Criteria**:
  - [ ] Seed data includes all level 1 and common level 2 accounts
  - [ ] ChartOfAccounts::new validates code format (4 digits for level 1/2, 6 digits for level 3)
  - [ ] Repository can query accounts by level and type
  - [ ] Repository can retrieve account hierarchy (parent → children)

  **QA Scenarios**:

  ```
  Scenario: Standard accounts seeded
    Tool: Bash (sqlite3)
    Preconditions: Migrations applied, seed data inserted
    Steps:
      1. Query `sqlite3 test.db "SELECT COUNT(*) FROM chart_of_accounts WHERE level=1"`
      2. Assert count = 5 (资产/负债/权益/收入/支出)
      3. Query `sqlite3 test.db "SELECT COUNT(*) FROM chart_of_accounts WHERE level=2"`
      4. Assert count >= 8 (common level 2 accounts)
    Expected Result: Standard accounts exist
    Failure Indicators: Missing accounts, incorrect count
    Evidence: .sisyphus/evidence/task-6-seed-data.txt

  Scenario: Hierarchical query works
    Tool: Bash (cargo test)
    Preconditions: Repository implemented
    Steps:
      1. Run integration test that queries children of "1000-资产"
      2. Assert returns accounts 1001, 1002, 1012, etc.
      3. Verify parent_code correctly set
    Expected Result: Hierarchy query returns correct children
    Failure Indicators: Query returns empty, incorrect parent-child relationships
    Evidence: .sisyphus/evidence/task-6-hierarchy-test.txt
  ```

  **Evidence to Capture**:
  - [ ] task-6-seed-data.txt (database query showing seeded accounts)
  - [ ] task-6-hierarchy-test.txt (integration test output)

  **Commit**: YES
  - Message: `feat(domain): add ChartOfAccounts aggregate with 中国会计准则 standard accounts`
  - Files: `src-tauri/src/domain/aggregates/chart_of_accounts.rs, src-tauri/src/infrastructure/repositories/chart_of_accounts_repository.rs, src-tauri/migrations/003_seed_chart_of_accounts.sql`
  - Pre-commit: `cargo test chart_of_accounts`

- [x] 7. Money Value Object - rust_decimal

  **What to do**:
  - Create Money value object in domain/value_objects/money.rs
  - Fields: amount (Decimal), currency_code (String)
  - Implement arithmetic operations: add, subtract (same currency only)
  - Implement currency conversion: convert_to(target_currency, exchange_rate)
  - Implement comparison: eq, gt, lt (same currency only)
  - Implement Display trait for formatting (e.g. "¥1,234.56")
  - Add validation: amount precision (2 decimal places), currency code exists
  - Write unit tests for all operations
  - Write property-based tests using proptest (e.g. add is commutative)

  **Must NOT do**:
  - Do not use f64 for amounts (MUST use rust_decimal::Decimal)
  - Do not allow operations between different currencies without explicit conversion

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Well-defined value object with clear mathematical operations

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-6, 8)
  - **Blocks**: Tasks 9, 10, 11
  - **Blocked By**: Task 2 (database schema), Task 5 (Currency)

  **References**:
  - Official docs: https://docs.rs/rust_decimal/latest/rust_decimal/ - Decimal arithmetic
  - Official docs: https://docs.rs/proptest/latest/proptest/ - Property-based testing
  - Pattern: Martin Fowler's Money pattern

  **Acceptance Criteria**:
  - [ ] Money::new(Decimal::from_str("100.00"), "CNY") creates valid money
  - [ ] Adding Money(100, CNY) + Money(50, CNY) = Money(150, CNY)
  - [ ] Adding Money(100, CNY) + Money(50, USD) returns error
  - [ ] Property test: ∀ a, b: Money, a + b = b + a (commutativity)
  - [ ] Display formats correctly: Money(1234.56, CNY) → "¥1,234.56"

  **QA Scenarios**:

  ```
  Scenario: Money arithmetic works
    Tool: Bash (cargo test)
    Preconditions: Money value object implemented
    Steps:
      1. Run `cargo test money::arithmetic`
      2. Assert addition, subtraction tests pass
      3. Assert cross-currency operation returns error
    Expected Result: All arithmetic tests pass
    Failure Indicators: Incorrect calculations, cross-currency operations allowed
    Evidence: .sisyphus/evidence/task-7-money-arithmetic.txt

  Scenario: Property-based tests pass
    Tool: Bash (cargo test)
    Preconditions: proptest configured
    Steps:
      1. Run `cargo test money::properties`
      2. Assert commutativity, associativity properties hold
      3. Verify 100+ random test cases executed
    Expected Result: All property tests pass
    Failure Indicators: Property violations found
    Evidence: .sisyphus/evidence/task-7-money-properties.txt
  ```

  **Evidence to Capture**:
  - [ ] task-7-money-arithmetic.txt (unit test output)
  - [ ] task-7-money-properties.txt (proptest output)

  **Commit**: YES
  - Message: `feat(domain): add Money value object with rust_decimal`
  - Files: `src-tauri/src/domain/value_objects/money.rs`
  - Pre-commit: `cargo test money`

- [x] 8. SyncMetadata Value Object

  **What to do**:
  - Create SyncMetadata value object in domain/value_objects/sync_metadata.rs
  - Fields: updated_at (DateTime<Utc>), deleted_at (Option<DateTime<Utc>>), device_id (Uuid), synced_at (Option<DateTime<Utc>>)
  - Implement methods: mark_deleted(), mark_synced(), is_deleted(), needs_sync()
  - Add to all aggregate roots that need syncing (Account, Transaction, Debt)
  - Write unit tests for sync state transitions

  **Must NOT do**:
  - Do not implement sync logic here (just metadata tracking)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Simple value object for tracking sync state

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-7)
  - **Blocks**: Tasks 9, 10, 11, 18
  - **Blocked By**: Task 2 (database schema)

  **References**:
  - Pattern: Soft delete with tombstones
  - Pattern: Last Write Wins conflict resolution (uses updated_at)

  **Acceptance Criteria**:
  - [ ] SyncMetadata::new() creates metadata with current timestamp
  - [ ] mark_deleted() sets deleted_at to current time
  - [ ] is_deleted() returns true after mark_deleted()
  - [ ] needs_sync() returns true when synced_at < updated_at

  **QA Scenarios**:

  ```
  Scenario: Sync state transitions
    Tool: Bash (cargo test)
    Preconditions: SyncMetadata implemented
    Steps:
      1. Run `cargo test sync_metadata::state_transitions`
      2. Assert new metadata needs_sync() = true
      3. Assert after mark_synced(), needs_sync() = false
      4. Assert after mark_deleted(), is_deleted() = true
    Expected Result: All state transition tests pass
    Failure Indicators: Incorrect state logic
    Evidence: .sisyphus/evidence/task-8-sync-metadata.txt
  ```

  **Evidence to Capture**:
  - [ ] task-8-sync-metadata.txt (unit test output)

  **Commit**: YES
  - Message: `feat(domain): add SyncMetadata value object for sync tracking`
  - Files: `src-tauri/src/domain/value_objects/sync_metadata.rs`
  - Pre-commit: `cargo test sync_metadata`

---

### Wave 2: Core Domain (7 tasks, depends on Wave 1)

- [x] 9. Account Aggregate + Repository

  **What to do**:
  - Create Account aggregate in domain/aggregates/account.rs using TDD
  - Fields: id (Uuid), name (String), account_type (Asset/Liability/Equity), chart_of_account_code (String), currency_code (String), balance (Money), sync_metadata (SyncMetadata)
  - Business rules: balance calculation from transactions, account type validation
  - Methods: create(), update_balance(), can_delete() (false if has transactions)
  - Create AccountRepository trait in domain/repositories/
  - Write failing tests FIRST for each business rule
  - Implement minimum code to pass tests
  - Refactor while keeping tests green

  **Must NOT do**:
  - Do not implement transaction logic here (that's Transaction aggregate)
  - Do not allow negative balance for Asset accounts without warning flag

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - **Reason**: Core domain aggregate with complex business rules, requires TDD approach

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 10-15)
  - **Blocks**: Tasks 10, 11, 13, 16, 17, 20
  - **Blocked By**: Tasks 6 (ChartOfAccounts), 7 (Money)

  **References**:
  - `src-tauri/src/domain/value_objects/money.rs` - Money type for balance
  - `src-tauri/src/domain/aggregates/chart_of_accounts.rs` - Account classification
  - `src-tauri/migrations/004_create_accounts.sql` - accounts table schema
  - Pattern: DDD Aggregate Root with invariants

  **Acceptance Criteria**:
  - [ ] Account::create() validates account_type matches chart_of_account_code
  - [ ] Account::update_balance() recalculates balance from transaction sum
  - [ ] Account::can_delete() returns false if transactions exist
  - [ ] `cargo test account` passes all tests (written TDD style)

  **QA Scenarios**:

  ```
  Scenario: Account creation with valid data
    Tool: Bash (cargo test)
    Preconditions: Account aggregate implemented
    Steps:
      1. Run `cargo test account::creation`
      2. Assert test creates account with CNY currency
      3. Assert initial balance is zero
      4. Assert sync_metadata.needs_sync() = true
    Expected Result: Account created successfully
    Failure Indicators: Validation errors, incorrect initial state
    Evidence: .sisyphus/evidence/task-9-account-creation.txt

  Scenario: Account type validation
    Tool: Bash (cargo test)
    Preconditions: TDD tests written
    Steps:
      1. Run `cargo test account::validation`
      2. Assert creating Asset account with Liability code fails
      3. Assert error message indicates type mismatch
    Expected Result: Validation prevents type mismatch
    Failure Indicators: Invalid accounts accepted
    Evidence: .sisyphus/evidence/task-9-account-validation.txt
  ```

  **Evidence to Capture**:
  - [ ] task-9-account-creation.txt (unit test output)
  - [ ] task-9-account-validation.txt (validation test output)

  **Commit**: YES
  - Message: `feat(domain): add Account aggregate with TDD`
  - Files: `src-tauri/src/domain/aggregates/account.rs, src-tauri/src/domain/repositories/account_repository.rs`
  - Pre-commit: `cargo test account`

- [x] 10. Transaction Aggregate + Double-Entry Validation

  **What to do**:
  - Create Transaction aggregate in domain/aggregates/transaction.rs using TDD
  - Fields: id (Uuid), transaction_date (Date), description (String), entries (Vec<TransactionEntry>), tags (Vec<String>), sync_metadata (SyncMetadata)
  - TransactionEntry: account_id (Uuid), chart_of_account_code (String), debit_amount (Option<Money>), credit_amount (Option<Money>), note (String)
  - Business rule: ∑debit_amount MUST equal ∑credit_amount (double-entry bookkeeping)
  - Business rule: Each entry must have either debit OR credit, not both
  - Methods: create(), add_entry(), validate_balance(), is_balanced()
  - Write failing tests FIRST for double-entry validation
  - Implement validation in domain layer (not database)
  - Create TransactionRepository trait

  **Must NOT do**:
  - Do not allow unbalanced transactions (enforce in aggregate, not just database)
  - Do not implement complex transaction templates (keep it simple)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - **Reason**: Critical financial logic requiring rigorous TDD and double-entry bookkeeping understanding

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9, 11-15)
  - **Blocks**: Tasks 14, 16, 17, 21
  - **Blocked By**: Tasks 6 (ChartOfAccounts), 7 (Money), 9 (Account)

  **References**:
  - `src-tauri/src/domain/aggregates/account.rs` - Account for entries
  - `src-tauri/migrations/005_create_transactions.sql` - transactions and transaction_entries tables
  - Pattern: Double-entry bookkeeping (every debit has corresponding credit)
  - Validation: ∑debit = ∑credit invariant

  **Acceptance Criteria**:
  - [ ] Transaction::create() with balanced entries succeeds
  - [ ] Transaction::create() with unbalanced entries returns error
  - [ ] Transaction::add_entry() maintains balance invariant
  - [ ] Property test: ∀ transaction: is_balanced() = true
  - [ ] `cargo test transaction` passes all TDD tests

  **QA Scenarios**:

  ```
  Scenario: Balanced transaction accepted
    Tool: Bash (cargo test)
    Preconditions: Transaction aggregate implemented
    Steps:
      1. Run `cargo test transaction::balanced`
      2. Create transaction with debit=100 CNY, credit=100 CNY
      3. Assert is_balanced() = true
      4. Assert transaction created successfully
    Expected Result: Balanced transaction accepted
    Failure Indicators: Validation fails for balanced transaction
    Evidence: .sisyphus/evidence/task-10-balanced-transaction.txt

  Scenario: Unbalanced transaction rejected
    Tool: Bash (cargo test)
    Preconditions: Validation implemented
    Steps:
      1. Run `cargo test transaction::unbalanced`
      2. Attempt to create transaction with debit=100 CNY, credit=50 CNY
      3. Assert returns error "Transaction not balanced"
      4. Assert transaction NOT created
    Expected Result: Unbalanced transaction rejected
    Failure Indicators: Unbalanced transaction accepted
    Evidence: .sisyphus/evidence/task-10-unbalanced-transaction.txt
  ```

  **Evidence to Capture**:
  - [ ] task-10-balanced-transaction.txt (unit test output)
  - [ ] task-10-unbalanced-transaction.txt (validation test output)

  **Commit**: YES
  - Message: `feat(domain): add Transaction aggregate with double-entry validation`
  - Files: `src-tauri/src/domain/aggregates/transaction.rs, src-tauri/src/domain/repositories/transaction_repository.rs`
  - Pre-commit: `cargo test transaction`

- [x] 11. Debt Aggregate + Amortization Calculation

  **What to do**:
  - Create Debt aggregate in domain/aggregates/debt.rs using TDD
  - Fields: id (Uuid), debt_type (BorrowedOut/BorrowedIn/CreditCard/Loan), counterparty (String), principal (Money), interest_rate (Decimal), start_date (Date), due_date (Date), payment_schedule (Vec<PaymentSchedule>), sync_metadata (SyncMetadata)
  - PaymentSchedule: payment_date (Date), principal_amount (Money), interest_amount (Money), total_amount (Money), paid (bool)
  - Business rule: Generate amortization schedule for Loan type (等额本息/等额本金)
  - Methods: create(), generate_schedule_equal_principal_interest(), generate_schedule_equal_principal(), mark_payment_paid(), remaining_balance()
  - Write failing tests FIRST for amortization formulas
  - Implement 等额本息: PMT = P * r * (1+r)^n / ((1+r)^n - 1)
  - Implement 等额本金: Principal per period = P / n, Interest = Remaining * r
  - Create DebtRepository trait

  **Must NOT do**:
  - Do not support variable interest rates (fixed rate only)
  - Do not implement partial early repayment recalculation (only full payoff)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - **Reason**: Complex financial calculations requiring TDD and mathematical precision

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9, 10, 12-15)
  - **Blocks**: Tasks 12, 15, 16, 17, 22
  - **Blocked By**: Tasks 7 (Money), 9 (Account)

  **References**:
  - `src-tauri/migrations/006_create_debts.sql` - debts and debt_payments tables
  - Formula: 等额本息 PMT = P * r * (1+r)^n / ((1+r)^n - 1)
  - Formula: 等额本金 Principal = P / n, Interest = (P - paid) * r
  - Pattern: Golden master testing (compare against known-good Excel calculations)

  **Acceptance Criteria**:
  - [ ] Debt::generate_schedule_equal_principal_interest() produces correct schedule
  - [ ] Golden master test: 100,000 CNY loan, 5% annual rate, 12 months matches Excel output
  - [ ] Debt::remaining_balance() correctly sums unpaid payments
  - [ ] `cargo test debt` passes all TDD tests including golden master

  **QA Scenarios**:

  ```
  Scenario: Equal principal interest calculation
    Tool: Bash (cargo test)
    Preconditions: Amortization logic implemented
    Steps:
      1. Run `cargo test debt::equal_principal_interest`
      2. Create loan: 100,000 CNY, 5% annual rate, 12 months
      3. Assert monthly payment ≈ 8,560.75 CNY (within 0.01 tolerance)
      4. Assert total interest ≈ 2,728.96 CNY
    Expected Result: Calculation matches expected values
    Failure Indicators: Payment amount incorrect, rounding errors
    Evidence: .sisyphus/evidence/task-11-amortization-equal-interest.txt

  Scenario: Equal principal calculation
    Tool: Bash (cargo test)
    Preconditions: Both amortization methods implemented
    Steps:
      1. Run `cargo test debt::equal_principal`
      2. Create loan: 100,000 CNY, 5% annual rate, 12 months
      3. Assert first payment ≈ 8,750.00 CNY (principal 8,333.33 + interest 416.67)
      4. Assert last payment ≈ 8,368.06 CNY (principal 8,333.33 + interest 34.72)
    Expected Result: Calculation matches expected values
    Failure Indicators: Incorrect principal/interest split
    Evidence: .sisyphus/evidence/task-11-amortization-equal-principal.txt
  ```

  **Evidence to Capture**:
  - [ ] task-11-amortization-equal-interest.txt (test output with calculations)
  - [ ] task-11-amortization-equal-principal.txt (test output with calculations)

  **Commit**: YES
  - Message: `feat(domain): add Debt aggregate with amortization calculation`
  - Files: `src-tauri/src/domain/aggregates/debt.rs, src-tauri/src/domain/repositories/debt_repository.rs`
  - Pre-commit: `cargo test debt`

- [x] 12. Reminder Aggregate + Scheduling Logic

  **What to do**:
  - Create Reminder aggregate in domain/aggregates/reminder.rs
  - Fields: id (Uuid), reminder_type (DebtPayment/Custom), related_entity_id (Option<Uuid>), title (String), description (String), remind_at (DateTime<Utc>), repeat_pattern (Option<String>), notified (bool), sync_metadata (SyncMetadata)
  - Methods: create(), should_trigger_now(), mark_notified(), calculate_next_occurrence()
  - Support repeat patterns: daily, weekly, monthly, yearly (simple cron-like)
  - Create ReminderRepository trait
  - Write unit tests for scheduling logic

  **Must NOT do**:
  - Do not implement complex cron expressions (simple patterns only)
  - Do not implement notification delivery here (that's infrastructure)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Scheduling logic with date/time calculations

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9-11, 13-15)
  - **Blocks**: Tasks 15, 19, 34
  - **Blocked By**: Task 11 (Debt)

  **References**:
  - `src-tauri/migrations/007_create_reminders.sql` - reminders table
  - Official docs: https://docs.rs/chrono/latest/chrono/ - Date/time handling

  **Acceptance Criteria**:
  - [ ] Reminder::should_trigger_now() returns true when remind_at <= now
  - [ ] Reminder::calculate_next_occurrence() correctly calculates next date for repeat patterns
  - [ ] `cargo test reminder` passes all tests

  **QA Scenarios**:

  ```
  Scenario: Reminder triggers at correct time
    Tool: Bash (cargo test)
    Preconditions: Reminder aggregate implemented
    Steps:
      1. Run `cargo test reminder::trigger_time`
      2. Create reminder for 2026-04-08 10:00:00
      3. Assert should_trigger_now() = false when now < remind_at
      4. Assert should_trigger_now() = true when now >= remind_at
    Expected Result: Trigger logic works correctly
    Failure Indicators: Incorrect time comparison
    Evidence: .sisyphus/evidence/task-12-reminder-trigger.txt

  Scenario: Repeat pattern calculation
    Tool: Bash (cargo test)
    Preconditions: Repeat logic implemented
    Steps:
      1. Run `cargo test reminder::repeat_pattern`
      2. Create monthly reminder starting 2026-04-01
      3. Assert next occurrence = 2026-05-01
      4. Assert next after that = 2026-06-01
    Expected Result: Monthly pattern calculates correctly
    Failure Indicators: Incorrect date calculation
    Evidence: .sisyphus/evidence/task-12-reminder-repeat.txt
  ```

  **Evidence to Capture**:
  - [ ] task-12-reminder-trigger.txt (unit test output)
  - [ ] task-12-reminder-repeat.txt (repeat pattern test output)

  **Commit**: YES
  - Message: `feat(domain): add Reminder aggregate with scheduling logic`
  - Files: `src-tauri/src/domain/aggregates/reminder.rs, src-tauri/src/domain/repositories/reminder_repository.rs`
  - Pre-commit: `cargo test reminder`

- [x] 13. Account Application Service + Use Cases

  **What to do**:
  - Create AccountService in application/services/account_service.rs
  - DTOs: CreateAccountDto, UpdateAccountDto, AccountDto
  - Use cases: create_account(), update_account(), delete_account(), get_account(), list_accounts(), get_account_balance()
  - Implement business logic orchestration (validate, call repository, return DTO)
  - Add transaction management (use sqlx transactions)
  - Write integration tests for each use case

  **Must NOT do**:
  - Do not put business rules here (they belong in aggregate)
  - Do not directly access database (use repository trait)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Application layer orchestration with transaction management

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9-12, 14-15)
  - **Blocks**: Task 20
  - **Blocked By**: Task 9 (Account aggregate)

  **References**:
  - `src-tauri/src/domain/aggregates/account.rs` - Account aggregate
  - `src-tauri/src/domain/repositories/account_repository.rs` - Repository trait
  - Pattern: Application Service pattern (orchestration, no business logic)

  **Acceptance Criteria**:
  - [ ] AccountService::create_account() validates input and calls repository
  - [ ] AccountService::delete_account() checks can_delete() before deletion
  - [ ] All use cases wrapped in database transactions
  - [ ] `cargo test account_service` passes integration tests

  **QA Scenarios**:

  ```
  Scenario: Create account use case
    Tool: Bash (cargo test)
    Preconditions: AccountService implemented
    Steps:
      1. Run integration test for create_account()
      2. Call service with valid CreateAccountDto
      3. Assert account saved to database
      4. Query database and verify account exists
    Expected Result: Account created successfully
    Failure Indicators: Service fails, account not in database
    Evidence: .sisyphus/evidence/task-13-create-account.txt

  Scenario: Delete account with transactions blocked
    Tool: Bash (cargo test)
    Preconditions: Delete validation implemented
    Steps:
      1. Create account with transactions
      2. Call delete_account()
      3. Assert returns error "Cannot delete account with transactions"
      4. Verify account still exists in database
    Expected Result: Deletion blocked
    Failure Indicators: Account deleted despite having transactions
    Evidence: .sisyphus/evidence/task-13-delete-blocked.txt
  ```

  **Evidence to Capture**:
  - [ ] task-13-create-account.txt (integration test output)
  - [ ] task-13-delete-blocked.txt (validation test output)

  **Commit**: YES
  - Message: `feat(application): add Account application service with use cases`
  - Files: `src-tauri/src/application/services/account_service.rs, src-tauri/src/application/dtos/account_dto.rs`
  - Pre-commit: `cargo test account_service`

- [x] 14. Transaction Application Service + Use Cases

  **What to do**:
  - Create TransactionService in application/services/transaction_service.rs
  - DTOs: CreateTransactionDto, TransactionDto, TransactionEntryDto
  - Use cases: create_transaction(), get_transaction(), list_transactions(), get_transactions_by_account(), get_transactions_by_date_range()
  - Validate double-entry balance before saving
  - Update account balances after transaction created
  - Write integration tests for transaction creation and balance updates

  **Must NOT do**:
  - Do not allow unbalanced transactions to be saved
  - Do not update balances outside of transaction boundary

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Critical financial operations requiring careful transaction management

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9-13, 15)
  - **Blocks**: Task 21
  - **Blocked By**: Task 10 (Transaction aggregate)

  **References**:
  - `src-tauri/src/domain/aggregates/transaction.rs` - Transaction aggregate
  - `src-tauri/src/domain/aggregates/account.rs` - Account for balance updates
  - Pattern: Unit of Work (transaction boundary includes balance updates)

  **Acceptance Criteria**:
  - [ ] TransactionService::create_transaction() validates balance before saving
  - [ ] Account balances updated atomically with transaction creation
  - [ ] Database transaction rolls back if balance update fails
  - [ ] `cargo test transaction_service` passes integration tests

  **QA Scenarios**:

  ```
  Scenario: Transaction creation updates balances
    Tool: Bash (sqlite3 + cargo test)
    Preconditions: TransactionService implemented
    Steps:
      1. Create two accounts: Checking (balance 1000), Cash (balance 0)
      2. Create transaction: debit Cash 100, credit Checking 100
      3. Query account balances
      4. Assert Checking balance = 900, Cash balance = 100
    Expected Result: Balances updated correctly
    Failure Indicators: Balances not updated, incorrect amounts
    Evidence: .sisyphus/evidence/task-14-balance-update.txt

  Scenario: Unbalanced transaction rejected
    Tool: Bash (cargo test)
    Preconditions: Validation implemented
    Steps:
      1. Attempt to create unbalanced transaction (debit 100, credit 50)
      2. Assert service returns error
      3. Query database and verify no transaction created
      4. Verify account balances unchanged
    Expected Result: Transaction rejected, no side effects
    Failure Indicators: Unbalanced transaction saved, balances changed
    Evidence: .sisyphus/evidence/task-14-unbalanced-rejected.txt
  ```

  **Evidence to Capture**:
  - [ ] task-14-balance-update.txt (integration test with balance verification)
  - [ ] task-14-unbalanced-rejected.txt (validation test output)

  **Commit**: YES
  - Message: `feat(application): add Transaction application service with balance updates`
  - Files: `src-tauri/src/application/services/transaction_service.rs, src-tauri/src/application/dtos/transaction_dto.rs`
  - Pre-commit: `cargo test transaction_service`

- [x] 15. Debt Application Service + Use Cases

  **What to do**:
  - Create DebtService in application/services/debt_service.rs
  - DTOs: CreateDebtDto, DebtDto, PaymentScheduleDto, RecordPaymentDto
  - Use cases: create_debt(), get_debt(), list_debts(), record_payment(), get_upcoming_payments()
  - Generate payment schedule on debt creation
  - Create reminders for upcoming payments
  - Update debt status when fully paid
  - Write integration tests for debt lifecycle

  **Must NOT do**:
  - Do not allow payment recording without corresponding transaction
  - Do not support partial early repayment recalculation

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Complex orchestration involving debt, payments, and reminders

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 9-14)
  - **Blocks**: Task 22
  - **Blocked By**: Tasks 11 (Debt aggregate), 12 (Reminder aggregate)

  **References**:
  - `src-tauri/src/domain/aggregates/debt.rs` - Debt aggregate
  - `src-tauri/src/domain/aggregates/reminder.rs` - Reminder for payment notifications
  - Pattern: Saga pattern (debt creation → schedule generation → reminder creation)

  **Acceptance Criteria**:
  - [ ] DebtService::create_debt() generates payment schedule and creates reminders
  - [ ] DebtService::record_payment() marks payment as paid and updates remaining balance
  - [ ] DebtService::get_upcoming_payments() returns payments due within N days
  - [ ] `cargo test debt_service` passes integration tests

  **QA Scenarios**:

  ```
  Scenario: Debt creation generates schedule and reminders
    Tool: Bash (sqlite3 + cargo test)
    Preconditions: DebtService implemented
    Steps:
      1. Create loan: 100,000 CNY, 5% annual rate, 12 months, remind 3 days before
      2. Query debt_payments table: assert 12 payment records created
      3. Query reminders table: assert 12 reminder records created
      4. Verify first reminder date = first payment date - 3 days
    Expected Result: Schedule and reminders created
    Failure Indicators: Missing payments, missing reminders, incorrect dates
    Evidence: .sisyphus/evidence/task-15-debt-creation.txt

  Scenario: Payment recording updates status
    Tool: Bash (cargo test)
    Preconditions: Payment recording implemented
    Steps:
      1. Create debt with 3 payments
      2. Record first payment
      3. Assert payment marked as paid in database
      4. Assert remaining_balance decreased by payment amount
      5. Record remaining payments
      6. Assert debt status = "Paid Off"
    Expected Result: Payment tracking works correctly
    Failure Indicators: Status not updated, balance incorrect
    Evidence: .sisyphus/evidence/task-15-payment-recording.txt
  ```

  **Evidence to Capture**:
  - [ ] task-15-debt-creation.txt (integration test with database queries)
  - [ ] task-15-payment-recording.txt (payment lifecycle test)

  **Commit**: YES
  - Message: `feat(application): add Debt application service with payment tracking`
  - Files: `src-tauri/src/application/services/debt_service.rs, src-tauri/src/application/dtos/debt_dto.rs`
  - Pre-commit: `cargo test debt_service`

---

### Wave 3: Infrastructure + API (8 tasks, depends on Wave 2)

- [x] 16. SQLite Repository Implementations

  **What to do**:
  - Implement AccountRepositorySqlite in infrastructure/repositories/account_repository_sqlite.rs
  - Implement TransactionRepositorySqlite in infrastructure/repositories/transaction_repository_sqlite.rs
  - Implement DebtRepositorySqlite in infrastructure/repositories/debt_repository_sqlite.rs
  - Use sqlx for compile-time SQL checking
  - Implement all CRUD methods from repository traits
  - Add methods for sync: get_changes_since(timestamp), mark_as_synced()
  - Handle soft deletes (filter out deleted_at IS NOT NULL by default)
  - Write integration tests for each repository

  **Must NOT do**:
  - Do not put business logic in repositories (data access only)
  - Do not use raw SQL strings (use sqlx query macros)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Data access layer with sqlx integration and sync support

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 17-23)
  - **Blocks**: Tasks 20, 21, 22
  - **Blocked By**: Tasks 9 (Account), 10 (Transaction), 11 (Debt)

  **References**:
  - `src-tauri/src/domain/repositories/*.rs` - Repository trait definitions
  - `src-tauri/migrations/*.sql` - Database schema
  - Official docs: https://docs.rs/sqlx/latest/sqlx/ - sqlx query macros

  **Acceptance Criteria**:
  - [ ] All repository methods compile with sqlx compile-time checking
  - [ ] CRUD operations work correctly in integration tests
  - [ ] Soft deletes filtered out in queries
  - [ ] get_changes_since() returns only records updated after timestamp
  - [ ] `cargo test repositories::sqlite` passes all tests

  **QA Scenarios**:

  ```
  Scenario: Account repository CRUD
    Tool: Bash (sqlite3 + cargo test)
    Preconditions: Repository implemented, migrations applied
    Steps:
      1. Run integration test for AccountRepositorySqlite
      2. Insert account via repository
      3. Query `sqlite3 test.db "SELECT * FROM accounts WHERE id='...'"` 
      4. Assert account exists with correct data
      5. Update account name
      6. Query again and verify name changed
      7. Soft delete account
      8. Assert find_by_id() returns None (soft delete filtered)
    Expected Result: All CRUD operations work
    Failure Indicators: Insert fails, updates don't persist, soft delete not filtered
    Evidence: .sisyphus/evidence/task-16-account-repo-crud.txt

  Scenario: Sync change tracking
    Tool: Bash (cargo test)
    Preconditions: Sync methods implemented
    Steps:
      1. Create 3 accounts at different times
      2. Call get_changes_since(timestamp) with middle timestamp
      3. Assert returns only accounts created after timestamp
      4. Mark accounts as synced
      5. Assert synced_at updated
    Expected Result: Change tracking works correctly
    Failure Indicators: Wrong records returned, synced_at not updated
    Evidence: .sisyphus/evidence/task-16-sync-tracking.txt
  ```

  **Evidence to Capture**:
  - [ ] task-16-account-repo-crud.txt (integration test output)
  - [ ] task-16-sync-tracking.txt (sync method test output)

  **Commit**: YES
  - Message: `feat(infrastructure): add SQLite repository implementations`
  - Files: `src-tauri/src/infrastructure/repositories/*_sqlite.rs`
  - Pre-commit: `cargo test repositories::sqlite`

- [x] 17. PostgreSQL Repository Implementations

  **What to do**:
  - Implement AccountRepositoryPostgres in infrastructure/repositories/account_repository_postgres.rs
  - Implement TransactionRepositoryPostgres in infrastructure/repositories/transaction_repository_postgres.rs
  - Implement DebtRepositoryPostgres in infrastructure/repositories/debt_repository_postgres.rs
  - Use sqlx with PostgreSQL-specific features (RETURNING clause, UPSERT)
  - Implement same methods as SQLite repositories
  - Handle connection pooling with sqlx::PgPool
  - Write integration tests (requires PostgreSQL test container or local instance)

  **Must NOT do**:
  - Do not duplicate business logic from SQLite repos
  - Do not use PostgreSQL-specific features that break compatibility with domain layer

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Similar to SQLite repos but with PostgreSQL specifics

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16, 18-23)
  - **Blocks**: Tasks 18, 23
  - **Blocked By**: Tasks 9 (Account), 10 (Transaction), 11 (Debt)

  **References**:
  - `src-tauri/src/infrastructure/repositories/*_sqlite.rs` - SQLite implementations as reference
  - Official docs: https://docs.rs/sqlx/latest/sqlx/postgres/ - PostgreSQL with sqlx

  **Acceptance Criteria**:
  - [ ] All repository methods work with PostgreSQL
  - [ ] Connection pooling configured correctly
  - [ ] UPSERT operations handle conflicts properly
  - [ ] `cargo test repositories::postgres` passes (requires PostgreSQL)

  **QA Scenarios**:

  ```
  Scenario: PostgreSQL repository CRUD
    Tool: Bash (psql + cargo test)
    Preconditions: PostgreSQL running, repository implemented
    Steps:
      1. Run integration test for AccountRepositoryPostgres
      2. Insert account via repository
      3. Query `psql -d finance -c "SELECT * FROM accounts WHERE id='...'"` 
      4. Assert account exists
      5. Test UPSERT: insert same ID with different data
      6. Assert data updated (not duplicate created)
    Expected Result: CRUD and UPSERT work
    Failure Indicators: Insert fails, UPSERT creates duplicate
    Evidence: .sisyphus/evidence/task-17-postgres-repo-crud.txt
  ```

  **Evidence to Capture**:
  - [ ] task-17-postgres-repo-crud.txt (integration test output)

  **Commit**: YES
  - Message: `feat(infrastructure): add PostgreSQL repository implementations`
  - Files: `src-tauri/src/infrastructure/repositories/*_postgres.rs`
  - Pre-commit: `cargo test repositories::postgres`

- [ ] 18. Sync Service - Conflict Resolution

  **What to do**:
  - Create SyncService in infrastructure/sync/sync_service.rs
  - Methods: sync_to_server(), sync_from_server(), resolve_conflict()
  - Implement Last Write Wins conflict resolution (compare updated_at timestamps)
  - Handle tombstones (deleted_at records)
  - Batch sync operations (don't sync one record at a time)
  - Implement incremental sync (only changed records since last sync)
  - Add retry logic with exponential backoff for network failures
  - Write integration tests for conflict scenarios

  **Must NOT do**:
  - Do not implement real-time sync (background polling only)
  - Do not use complex CRDT algorithms (simple LWW is sufficient)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - **Reason**: Complex sync logic with conflict resolution and edge cases

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-17, 19-23)
  - **Blocks**: Tasks 23, 33
  - **Blocked By**: Tasks 16 (SQLite repos), 17 (PostgreSQL repos)

  **References**:
  - `src-tauri/src/domain/value_objects/sync_metadata.rs` - Sync metadata
  - Pattern: Last Write Wins conflict resolution
  - Pattern: Tombstone for soft deletes

  **Acceptance Criteria**:
  - [ ] SyncService::sync_to_server() uploads only changed records
  - [ ] SyncService::sync_from_server() downloads only new/updated records
  - [ ] Conflict resolution: newer updated_at wins
  - [ ] Tombstones synced and applied correctly
  - [ ] `cargo test sync_service` passes conflict scenario tests

  **QA Scenarios**:

  ```
  Scenario: Last Write Wins conflict resolution
    Tool: Bash (cargo test)
    Preconditions: SyncService implemented
    Steps:
      1. Create account locally: updated_at = 2026-04-07 10:00
      2. Create same account on server: updated_at = 2026-04-07 11:00
      3. Run sync_from_server()
      4. Assert local account overwritten with server version (server is newer)
      5. Update local account: updated_at = 2026-04-07 12:00
      6. Run sync_to_server()
      7. Assert server account overwritten with local version (local is newer)
    Expected Result: Newer version always wins
    Failure Indicators: Wrong version kept, data loss
    Evidence: .sisyphus/evidence/task-18-conflict-resolution.txt

  Scenario: Tombstone sync
    Tool: Bash (cargo test)
    Preconditions: Soft delete handling implemented
    Steps:
      1. Delete account locally (soft delete, deleted_at set)
      2. Run sync_to_server()
      3. Assert server record has deleted_at set
      4. Query server with normal find: assert record not returned
      5. Query server including deleted: assert record exists with deleted_at
    Expected Result: Soft deletes synced correctly
    Failure Indicators: Deleted record not synced, hard deleted on server
    Evidence: .sisyphus/evidence/task-18-tombstone-sync.txt
  ```

  **Evidence to Capture**:
  - [ ] task-18-conflict-resolution.txt (conflict test output)
  - [ ] task-18-tombstone-sync.txt (soft delete sync test)

  **Commit**: YES
  - Message: `feat(infrastructure): add sync service with Last Write Wins conflict resolution`
  - Files: `src-tauri/src/infrastructure/sync/sync_service.rs`
  - Pre-commit: `cargo test sync_service`

- [x] 19. Notification Service - tauri-plugin-notification

  **What to do**:
  - Create NotificationService in infrastructure/notifications/notification_service.rs
  - Integrate tauri-plugin-notification
  - Methods: schedule_notification(), send_notification(), cancel_notification(), reschedule_all()
  - Implement OS-level scheduled notifications
  - On app startup, reschedule all pending reminders
  - Handle notification click events (open app to relevant page)
  - Write integration tests (mock notification API)

  **Must NOT do**:
  - Do not implement email notifications (out of scope for Phase 1)
  - Do not implement in-app notifications (OS notifications only)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Straightforward plugin integration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-18, 20-23)
  - **Blocks**: Task 34
  - **Blocked By**: Task 12 (Reminder aggregate)

  **References**:
  - Official docs: https://github.com/tauri-apps/plugins-workspace/tree/v2/plugins/notification - tauri-plugin-notification
  - `src-tauri/src/domain/aggregates/reminder.rs` - Reminder aggregate

  **Acceptance Criteria**:
  - [ ] NotificationService::schedule_notification() creates OS notification
  - [ ] NotificationService::reschedule_all() called on app startup
  - [ ] Notification click opens app
  - [ ] `cargo test notification_service` passes

  **QA Scenarios**:

  ```
  Scenario: Notification scheduling
    Tool: Bash (cargo test with mock)
    Preconditions: NotificationService implemented
    Steps:
      1. Run test with mocked notification API
      2. Schedule notification for 5 seconds from now
      3. Assert notification API called with correct parameters
      4. Assert notification stored in pending list
    Expected Result: Notification scheduled
    Failure Indicators: API not called, incorrect parameters
    Evidence: .sisyphus/evidence/task-19-notification-schedule.txt

  Scenario: Reschedule on startup
    Tool: Bash (cargo test)
    Preconditions: Reschedule logic implemented
    Steps:
      1. Create 3 reminders in database (not yet notified)
      2. Call reschedule_all()
      3. Assert 3 notifications scheduled
      4. Verify notification times match reminder times
    Expected Result: All pending reminders rescheduled
    Failure Indicators: Missing notifications, incorrect times
    Evidence: .sisyphus/evidence/task-19-reschedule-startup.txt
  ```

  **Evidence to Capture**:
  - [ ] task-19-notification-schedule.txt (test output)
  - [ ] task-19-reschedule-startup.txt (reschedule test output)

  **Commit**: YES
  - Message: `feat(infrastructure): add notification service with tauri-plugin-notification`
  - Files: `src-tauri/src/infrastructure/notifications/notification_service.rs, src-tauri/Cargo.toml (add plugin)`
  - Pre-commit: `cargo test notification_service`

- [x] 20. Tauri Commands - Accounts

  **What to do**:
  - Create account commands in presentation/tauri_commands/account_commands.rs
  - Commands: create_account, update_account, delete_account, get_account, list_accounts, get_account_balance
  - Use Tauri's command macro
  - Inject AccountService via AppState
  - Handle errors and return Result<T, String>
  - Add TypeScript type definitions for frontend
  - Write integration tests calling commands

  **Must NOT do**:
  - Do not put business logic in commands (delegate to service)
  - Do not expose internal errors to frontend (map to user-friendly messages)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Straightforward Tauri command wrappers

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-19, 21-23)
  - **Blocks**: Task 26
  - **Blocked By**: Tasks 13 (AccountService), 16 (SQLite repos)

  **References**:
  - Official docs: https://tauri.app/v2/guides/features/command/ - Tauri commands
  - `src-tauri/src/application/services/account_service.rs` - AccountService

  **Acceptance Criteria**:
  - [ ] All account commands registered in Tauri builder
  - [ ] Commands callable from frontend via invoke()
  - [ ] TypeScript types generated for commands
  - [ ] `cargo test account_commands` passes

  **QA Scenarios**:

  ```
  Scenario: Create account command
    Tool: Bash (cargo test)
    Preconditions: Commands implemented
    Steps:
      1. Run integration test that invokes create_account command
      2. Pass CreateAccountDto as JSON
      3. Assert command returns success with account ID
      4. Query database and verify account created
    Expected Result: Command creates account
    Failure Indicators: Command fails, account not created
    Evidence: .sisyphus/evidence/task-20-create-account-command.txt

  Scenario: Error handling
    Tool: Bash (cargo test)
    Preconditions: Error mapping implemented
    Steps:
      1. Invoke create_account with invalid data (empty name)
      2. Assert command returns Err with user-friendly message
      3. Assert message does not contain internal error details
    Expected Result: User-friendly error returned
    Failure Indicators: Internal error exposed, unclear error message
    Evidence: .sisyphus/evidence/task-20-error-handling.txt
  ```

  **Evidence to Capture**:
  - [ ] task-20-create-account-command.txt (command test output)
  - [ ] task-20-error-handling.txt (error handling test)

  **Commit**: YES
  - Message: `feat(presentation): add Tauri commands for account management`
  - Files: `src-tauri/src/presentation/tauri_commands/account_commands.rs, src-tauri/src/lib.rs (register commands)`
  - Pre-commit: `cargo test account_commands`

- [x] 21. Tauri Commands - Transactions

  **What to do**:
  - Create transaction commands in presentation/tauri_commands/transaction_commands.rs
  - Commands: create_transaction, get_transaction, list_transactions, get_transactions_by_account, get_transactions_by_date_range
  - Handle multi-entry transactions (array of entries in DTO)
  - Add TypeScript type definitions
  - Write integration tests

  **Must NOT do**:
  - Do not allow unbalanced transactions (validation in service layer)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Similar to account commands

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-20, 22-23)
  - **Blocks**: Task 27
  - **Blocked By**: Tasks 14 (TransactionService), 16 (SQLite repos)

  **References**:
  - `src-tauri/src/application/services/transaction_service.rs` - TransactionService
  - `src-tauri/src/presentation/tauri_commands/account_commands.rs` - Pattern reference

  **Acceptance Criteria**:
  - [ ] All transaction commands registered
  - [ ] Commands handle multi-entry transactions correctly
  - [ ] TypeScript types generated
  - [ ] `cargo test transaction_commands` passes

  **QA Scenarios**:

  ```
  Scenario: Create transaction command
    Tool: Bash (cargo test)
    Preconditions: Commands implemented
    Steps:
      1. Invoke create_transaction with 2 entries (debit + credit)
      2. Assert command returns success
      3. Query database: verify transaction and entries created
      4. Verify account balances updated
    Expected Result: Transaction created, balances updated
    Failure Indicators: Transaction not created, balances incorrect
    Evidence: .sisyphus/evidence/task-21-create-transaction-command.txt
  ```

  **Evidence to Capture**:
  - [ ] task-21-create-transaction-command.txt (command test output)

  **Commit**: YES
  - Message: `feat(presentation): add Tauri commands for transaction management`
  - Files: `src-tauri/src/presentation/tauri_commands/transaction_commands.rs`
  - Pre-commit: `cargo test transaction_commands`

- [x] 22. Tauri Commands - Debts

  **What to do**:
  - Create debt commands in presentation/tauri_commands/debt_commands.rs
  - Commands: create_debt, get_debt, list_debts, record_payment, get_upcoming_payments, get_overdue_debts
  - Return payment schedule with debt details
  - Add TypeScript type definitions
  - Write integration tests

  **Must NOT do**:
  - Do not expose internal amortization calculation details

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Similar to previous commands

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-21, 23)
  - **Blocks**: Task 28
  - **Blocked By**: Tasks 15 (DebtService), 16 (SQLite repos)

  **References**:
  - `src-tauri/src/application/services/debt_service.rs` - DebtService

  **Acceptance Criteria**:
  - [ ] All debt commands registered
  - [ ] Commands return payment schedules correctly
  - [ ] TypeScript types generated
  - [ ] `cargo test debt_commands` passes

  **QA Scenarios**:

  ```
  Scenario: Create debt command with schedule
    Tool: Bash (cargo test)
    Preconditions: Commands implemented
    Steps:
      1. Invoke create_debt with loan parameters
      2. Assert command returns success with debt ID
      3. Invoke get_debt to retrieve details
      4. Assert payment_schedule array has correct number of payments
      5. Verify first payment amount matches expected
    Expected Result: Debt created with schedule
    Failure Indicators: Schedule missing, incorrect calculations
    Evidence: .sisyphus/evidence/task-22-create-debt-command.txt
  ```

  **Evidence to Capture**:
  - [ ] task-22-create-debt-command.txt (command test output)

  **Commit**: YES
  - Message: `feat(presentation): add Tauri commands for debt management`
  - Files: `src-tauri/src/presentation/tauri_commands/debt_commands.rs`
  - Pre-commit: `cargo test debt_commands`

- [x] 23. REST API - Sync Endpoints

  **What to do**:
  - Create Axum REST API in presentation/api/sync_api.rs
  - Endpoints: POST /api/sync/upload, POST /api/sync/download, POST /api/register
  - Upload: receive changed records from client, apply to PostgreSQL
  - Download: send changed records since last sync to client
  - Register: create account ID and return to client
  - Add authentication middleware (simple device token)
  - Configure CORS for local development
  - Write integration tests for sync flow

  **Must NOT do**:
  - Do not implement complex authentication (simple token is sufficient)
  - Do not expose all CRUD endpoints (sync endpoints only)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: REST API with sync protocol implementation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 16-22)
  - **Blocks**: Tasks 31, 32
  - **Blocked By**: Tasks 18 (SyncService), 17 (PostgreSQL repos)

  **References**:
  - Official docs: https://docs.rs/axum/latest/axum/ - Axum web framework
  - `src-tauri/src/infrastructure/sync/sync_service.rs` - SyncService

  **Acceptance Criteria**:
  - [ ] All sync endpoints respond correctly
  - [ ] Upload endpoint applies changes to PostgreSQL
  - [ ] Download endpoint returns changes since timestamp
  - [ ] Register endpoint generates unique account ID
  - [ ] `cargo test sync_api` passes integration tests

  **QA Scenarios**:

  ```
  Scenario: Upload sync endpoint
    Tool: Bash (curl)
    Preconditions: API running, PostgreSQL available
    Steps:
      1. Start API server
      2. curl -X POST http://localhost:3000/api/sync/upload -H "Content-Type: application/json" -d '{"device_id":"test","accounts":[...]}'
      3. Assert HTTP 200 response
      4. Assert response body: {"synced": 1}
      5. Query PostgreSQL: verify account inserted
    Expected Result: Upload succeeds, data in PostgreSQL
    Failure Indicators: HTTP error, data not inserted
    Evidence: .sisyphus/evidence/task-23-upload-endpoint.txt

  Scenario: Download sync endpoint
    Tool: Bash (curl)
    Preconditions: API running, data in PostgreSQL
    Steps:
      1. Insert account in PostgreSQL with updated_at = now
      2. curl -X POST http://localhost:3000/api/sync/download -d '{"device_id":"test","since":"2026-04-01T00:00:00Z"}'
      3. Assert HTTP 200 response
      4. Assert response contains account data
    Expected Result: Download returns changed records
    Failure Indicators: HTTP error, missing data
    Evidence: .sisyphus/evidence/task-23-download-endpoint.txt
  ```

  **Evidence to Capture**:
  - [ ] task-23-upload-endpoint.txt (curl output)
  - [ ] task-23-download-endpoint.txt (curl output)

  **Commit**: YES
  - Message: `feat(presentation): add REST API for sync endpoints`
  - Files: `src-tauri/src/presentation/api/sync_api.rs, src-tauri/src/main.rs (start API server)`
  - Pre-commit: `cargo test sync_api`

---

### Wave 4: Frontend (8 tasks, depends on Wave 3)

- [ ] 24. shadcn/ui Setup + Theme Configuration

  **What to do**:
  - Install shadcn/ui components via CLI
  - Configure Tailwind CSS with design tokens
  - Setup theme provider (light mode only for Phase 1)
  - Install core components: Button, Input, Select, Table, Dialog, Card, Form
  - Create layout components: AppLayout, Sidebar, Header
  - Configure typography and spacing system
  - Create color palette for financial data (green for income, red for expense)
  - Test component rendering

  **Must NOT do**:
  - Do not implement dark mode (out of scope for Phase 1)
  - Do not customize components excessively (use defaults)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: UI component setup and design system configuration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 25)
  - **Blocks**: Tasks 26-31
  - **Blocked By**: Task 1 (project scaffolding)

  **References**:
  - Official docs: https://ui.shadcn.com/docs/installation/vite - shadcn/ui with Vite
  - Official docs: https://tailwindcss.com/docs - Tailwind CSS

  **Acceptance Criteria**:
  - [ ] shadcn/ui components installed and importable
  - [ ] Theme provider configured in App.tsx
  - [ ] Layout components render correctly
  - [ ] `pnpm dev` shows styled components

  **QA Scenarios**:

  ```
  Scenario: Components render with styling
    Tool: Playwright (playwright skill)
    Preconditions: shadcn/ui configured, dev server running
    Steps:
      1. Navigate to http://localhost:5173
      2. Assert page loads without errors
      3. Check for Tailwind CSS classes in DOM
      4. Verify Button component has correct styling
      5. Take screenshot
    Expected Result: Components styled correctly
    Failure Indicators: Unstyled components, CSS not loaded
    Evidence: .sisyphus/evidence/task-24-components-styled.png
  ```

  **Evidence to Capture**:
  - [ ] task-24-components-styled.png (screenshot of styled components)

  **Commit**: YES
  - Message: `feat(frontend): setup shadcn/ui with theme configuration`
  - Files: `src/components/ui/*, src/lib/utils.ts, tailwind.config.js, src/App.tsx`
  - Pre-commit: `pnpm type-check`

- [ ] 25. TanStack Query + Router Setup

  **What to do**:
  - Install and configure TanStack Query for data fetching
  - Setup QueryClient with default options (staleTime, cacheTime)
  - Install and configure TanStack Router
  - Define routes: /, /accounts, /transactions, /debts, /reports, /settings
  - Create route components (empty shells)
  - Setup navigation in Sidebar
  - Create Tauri invoke wrapper with TypeScript types
  - Test navigation and data fetching

  **Must NOT do**:
  - Do not implement page content yet (just routing structure)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Standard library configuration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 24)
  - **Blocks**: Tasks 26-31
  - **Blocked By**: Task 1 (project scaffolding)

  **References**:
  - Official docs: https://tanstack.com/query/latest/docs/framework/react/overview - TanStack Query
  - Official docs: https://tanstack.com/router/latest/docs/framework/react/overview - TanStack Router

  **Acceptance Criteria**:
  - [ ] QueryClient configured and provided to app
  - [ ] All routes defined and navigable
  - [ ] Tauri invoke wrapper typed correctly
  - [ ] `pnpm dev` allows navigation between routes

  **QA Scenarios**:

  ```
  Scenario: Route navigation works
    Tool: Playwright (playwright skill)
    Preconditions: Router configured, dev server running
    Steps:
      1. Navigate to http://localhost:5173
      2. Click "Accounts" in sidebar
      3. Assert URL changes to /accounts
      4. Assert route component renders
      5. Navigate to /transactions, /debts, /reports
      6. Verify each route loads
    Expected Result: All routes navigable
    Failure Indicators: 404 errors, routes not rendering
    Evidence: .sisyphus/evidence/task-25-route-navigation.txt
  ```

  **Evidence to Capture**:
  - [ ] task-25-route-navigation.txt (navigation test log)

  **Commit**: YES
  - Message: `feat(frontend): setup TanStack Query and Router`
  - Files: `src/main.tsx, src/routes/*, src/lib/tauri.ts`
  - Pre-commit: `pnpm type-check`

- [ ] 26. Account Management Page

  **What to do**:
  - Create AccountsPage component in src/pages/AccountsPage.tsx
  - Display account list in Table component
  - Show account name, type, currency, balance
  - Add "Create Account" button opening Dialog
  - Create AccountForm component with validation
  - Fields: name, account_type (select), chart_of_account_code (select), currency (select)
  - Implement create, update, delete operations using Tauri commands
  - Use TanStack Query for data fetching and mutations
  - Add loading states and error handling
  - Write component tests for form validation

  **Must NOT do**:
  - Do not implement advanced filtering/sorting (basic list only)
  - Do not add bulk operations

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: UI page with forms and data display

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 27-31)
  - **Blocks**: Task 36
  - **Blocked By**: Tasks 20 (account commands), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - `src-tauri/src/presentation/tauri_commands/account_commands.rs` - Available commands
  - `src/components/ui/*` - shadcn/ui components
  - Pattern: Form with validation using react-hook-form + zod

  **Acceptance Criteria**:
  - [ ] Account list displays correctly
  - [ ] Create account form validates input
  - [ ] Account created successfully via Tauri command
  - [ ] Account list updates after creation
  - [ ] Delete account shows confirmation dialog

  **QA Scenarios**:

  ```
  Scenario: Create account flow
    Tool: Playwright (playwright skill)
    Preconditions: App running, backend available
    Steps:
      1. Navigate to /accounts
      2. Click "Create Account" button
      3. Fill form: name="Checking Account", type="Asset", code="1002", currency="CNY"
      4. Click "Save"
      5. Assert dialog closes
      6. Assert new account appears in table
      7. Take screenshot
    Expected Result: Account created and displayed
    Failure Indicators: Form validation fails, account not created, table not updated
    Evidence: .sisyphus/evidence/task-26-create-account-flow.png

  Scenario: Form validation
    Tool: Playwright (playwright skill)
    Preconditions: Create account dialog open
    Steps:
      1. Click "Save" without filling form
      2. Assert validation errors displayed
      3. Assert error message: "Name is required"
      4. Fill name only, click "Save"
      5. Assert error: "Account type is required"
    Expected Result: Validation prevents invalid submission
    Failure Indicators: Form submits with empty fields
    Evidence: .sisyphus/evidence/task-26-form-validation.png
  ```

  **Evidence to Capture**:
  - [ ] task-26-create-account-flow.png (screenshot of account creation)
  - [ ] task-26-form-validation.png (screenshot of validation errors)

  **Commit**: YES
  - Message: `feat(frontend): add account management page`
  - Files: `src/pages/AccountsPage.tsx, src/components/AccountForm.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 27. Transaction Recording Page

  **What to do**:
  - Create TransactionsPage component in src/pages/TransactionsPage.tsx
  - Display transaction list with date, description, amount, accounts involved
  - Add "Record Transaction" button opening Dialog
  - Create TransactionForm component with multi-entry support
  - Fields: date, description, entries (dynamic array), tags
  - Entry fields: account (select), debit_amount, credit_amount, note
  - Validate double-entry balance in frontend before submission
  - Show running balance calculation as entries added
  - Implement create operation using Tauri command
  - Add date range filter
  - Write component tests

  **Must NOT do**:
  - Do not implement transaction templates (manual entry only)
  - Do not add transaction editing (create only for Phase 1)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: Complex form with dynamic entries and validation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26, 28-31)
  - **Blocks**: Task 36
  - **Blocked By**: Tasks 21 (transaction commands), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - `src-tauri/src/presentation/tauri_commands/transaction_commands.rs` - Available commands
  - Pattern: Dynamic form array with react-hook-form FieldArray

  **Acceptance Criteria**:
  - [ ] Transaction list displays correctly
  - [ ] Multi-entry form allows adding/removing entries
  - [ ] Balance validation shows error if debit ≠ credit
  - [ ] Transaction created successfully
  - [ ] Account balances update after transaction

  **QA Scenarios**:

  ```
  Scenario: Record balanced transaction
    Tool: Playwright (playwright skill)
    Preconditions: App running, accounts exist
    Steps:
      1. Navigate to /transactions
      2. Click "Record Transaction"
      3. Fill date, description
      4. Add entry 1: account="Checking", debit=100 CNY
      5. Add entry 2: account="Cash", credit=100 CNY
      6. Assert balance indicator shows "Balanced ✓"
      7. Click "Save"
      8. Assert transaction appears in list
      9. Navigate to /accounts
      10. Verify Checking balance decreased by 100
    Expected Result: Transaction recorded, balances updated
    Failure Indicators: Transaction not created, balances incorrect
    Evidence: .sisyphus/evidence/task-27-record-transaction.png

  Scenario: Unbalanced transaction blocked
    Tool: Playwright (playwright skill)
    Preconditions: Transaction form open
    Steps:
      1. Add entry 1: debit=100 CNY
      2. Add entry 2: credit=50 CNY
      3. Assert balance indicator shows "Unbalanced: -50 CNY"
      4. Click "Save"
      5. Assert error message: "Transaction must be balanced"
      6. Assert form not submitted
    Expected Result: Unbalanced transaction blocked
    Failure Indicators: Unbalanced transaction accepted
    Evidence: .sisyphus/evidence/task-27-unbalanced-blocked.png
  ```

  **Evidence to Capture**:
  - [ ] task-27-record-transaction.png (screenshot of transaction recording)
  - [ ] task-27-unbalanced-blocked.png (screenshot of validation error)

  **Commit**: YES
  - Message: `feat(frontend): add transaction recording page with double-entry validation`
  - Files: `src/pages/TransactionsPage.tsx, src/components/TransactionForm.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 28. Debt Management Page

  **What to do**:
  - Create DebtsPage component in src/pages/DebtsPage.tsx
  - Display debt list with type, counterparty, principal, remaining balance, due date
  - Add "Create Debt" button opening Dialog
  - Create DebtForm component
  - Fields: debt_type (select), counterparty, principal, interest_rate, start_date, due_date, payment_method (等额本息/等额本金)
  - Show payment schedule preview before saving
  - Implement create and record_payment operations
  - Display upcoming payments and overdue debts prominently
  - Add payment recording dialog
  - Write component tests

  **Must NOT do**:
  - Do not implement debt editing (create only)
  - Do not support partial early repayment

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: UI page with financial calculations preview

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-27, 29-31)
  - **Blocks**: Tasks 34, 36
  - **Blocked By**: Tasks 22 (debt commands), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - `src-tauri/src/presentation/tauri_commands/debt_commands.rs` - Available commands

  **Acceptance Criteria**:
  - [ ] Debt list displays correctly
  - [ ] Payment schedule preview shows correct calculations
  - [ ] Debt created with schedule
  - [ ] Payment recording updates debt status
  - [ ] Overdue debts highlighted in red

  **QA Scenarios**:

  ```
  Scenario: Create debt with schedule preview
    Tool: Playwright (playwright skill)
    Preconditions: App running
    Steps:
      1. Navigate to /debts
      2. Click "Create Debt"
      3. Fill: type="Loan", principal=100000 CNY, rate=5%, term=12 months, method="等额本息"
      4. Assert payment schedule preview displays 12 payments
      5. Assert first payment amount ≈ 8,560.75 CNY
      6. Click "Save"
      7. Assert debt appears in list
      8. Click debt to view details
      9. Assert full payment schedule displayed
    Expected Result: Debt created with schedule
    Failure Indicators: Schedule not generated, incorrect calculations
    Evidence: .sisyphus/evidence/task-28-create-debt.png

  Scenario: Record payment
    Tool: Playwright (playwright skill)
    Preconditions: Debt with payments exists
    Steps:
      1. Navigate to /debts
      2. Click debt to view details
      3. Click "Record Payment" on first unpaid payment
      4. Confirm payment
      5. Assert payment marked as paid
      6. Assert remaining balance decreased
    Expected Result: Payment recorded successfully
    Failure Indicators: Payment not marked, balance incorrect
    Evidence: .sisyphus/evidence/task-28-record-payment.png
  ```

  **Evidence to Capture**:
  - [ ] task-28-create-debt.png (screenshot of debt creation with schedule)
  - [ ] task-28-record-payment.png (screenshot of payment recording)

  **Commit**: YES
  - Message: `feat(frontend): add debt management page with payment schedule`
  - Files: `src/pages/DebtsPage.tsx, src/components/DebtForm.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 29. Reports Page - Balance Sheet & Income Statement

  **What to do**:
  - Create ReportsPage component in src/pages/ReportsPage.tsx
  - Implement Balance Sheet report (资产负债表)
  - Show assets, liabilities, equity with totals
  - Implement Income Statement report (收支表)
  - Show income, expenses by category with totals
  - Add date range selector (month, quarter, year, custom)
  - Display multi-currency amounts with conversion to base currency
  - Add export to CSV button (basic implementation)
  - Use Chart component for simple visualizations (bar chart for income/expense)
  - Write component tests

  **Must NOT do**:
  - Do not implement complex charts (simple bar/pie only)
  - Do not add advanced analytics (basic reports only)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: Data visualization and report generation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-28, 30-31)
  - **Blocks**: Tasks 35, 36
  - **Blocked By**: Tasks 21 (transaction commands), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - Pattern: Balance Sheet = Assets - Liabilities = Equity
  - Pattern: Income Statement = Income - Expenses = Net Income

  **Acceptance Criteria**:
  - [ ] Balance sheet displays correctly with totals
  - [ ] Income statement shows income and expenses by category
  - [ ] Date range filter works
  - [ ] Multi-currency amounts converted to base currency
  - [ ] Export to CSV downloads file

  **QA Scenarios**:

  ```
  Scenario: Balance sheet displays correctly
    Tool: Playwright (playwright skill)
    Preconditions: App running, accounts and transactions exist
    Steps:
      1. Navigate to /reports
      2. Select "Balance Sheet" tab
      3. Assert Assets section displays account balances
      4. Assert Liabilities section displays debt balances
      5. Assert total Assets - Liabilities = Equity
      6. Take screenshot
    Expected Result: Balance sheet balanced
    Failure Indicators: Totals don't match, missing accounts
    Evidence: .sisyphus/evidence/task-29-balance-sheet.png

  Scenario: Income statement with date filter
    Tool: Playwright (playwright skill)
    Preconditions: Transactions exist
    Steps:
      1. Select "Income Statement" tab
      2. Set date range: 2026-04-01 to 2026-04-30
      3. Assert only April transactions included
      4. Assert income total = sum of income transactions
      5. Assert expense total = sum of expense transactions
      6. Assert net income = income - expenses
    Expected Result: Income statement calculates correctly
    Failure Indicators: Wrong transactions included, incorrect totals
    Evidence: .sisyphus/evidence/task-29-income-statement.png
  ```

  **Evidence to Capture**:
  - [ ] task-29-balance-sheet.png (screenshot of balance sheet)
  - [ ] task-29-income-statement.png (screenshot of income statement)

  **Commit**: YES
  - Message: `feat(frontend): add reports page with balance sheet and income statement`
  - Files: `src/pages/ReportsPage.tsx, src/components/BalanceSheet.tsx, src/components/IncomeStatement.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 30. Currency Settings Page

  **What to do**:
  - Create SettingsPage component in src/pages/SettingsPage.tsx
  - Display currency list with code, symbol, exchange rate
  - Add "Add Currency" button
  - Create CurrencyForm for adding/editing currencies
  - Fields: code (ISO 4217), symbol, exchange_rate (relative to base currency)
  - Set base currency selector (default CNY)
  - Show exchange rate update timestamp
  - Implement CRUD operations using Tauri commands
  - Write component tests

  **Must NOT do**:
  - Do not implement automatic exchange rate fetching (manual input only)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: Settings UI with form

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-29, 31)
  - **Blocks**: Task 35
  - **Blocked By**: Tasks 20 (account commands for currency), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - Standard: ISO 4217 currency codes

  **Acceptance Criteria**:
  - [ ] Currency list displays correctly
  - [ ] Add currency form validates ISO 4217 code
  - [ ] Exchange rate updates persist
  - [ ] Base currency selection works

  **QA Scenarios**:

  ```
  Scenario: Add currency
    Tool: Playwright (playwright skill)
    Preconditions: App running
    Steps:
      1. Navigate to /settings
      2. Click "Add Currency"
      3. Fill: code="USD", symbol="$", rate=7.25
      4. Click "Save"
      5. Assert USD appears in currency list
      6. Assert exchange rate displayed: 1 USD = 7.25 CNY
    Expected Result: Currency added successfully
    Failure Indicators: Currency not added, rate incorrect
    Evidence: .sisyphus/evidence/task-30-add-currency.png

  Scenario: Invalid currency code rejected
    Tool: Playwright (playwright skill)
    Preconditions: Add currency form open
    Steps:
      1. Fill code="US" (invalid, must be 3 letters)
      2. Click "Save"
      3. Assert validation error: "Currency code must be 3 letters"
      4. Fill code="123" (invalid, must be letters)
      5. Assert validation error
    Expected Result: Invalid codes rejected
    Failure Indicators: Invalid codes accepted
    Evidence: .sisyphus/evidence/task-30-currency-validation.png
  ```

  **Evidence to Capture**:
  - [ ] task-30-add-currency.png (screenshot of currency addition)
  - [ ] task-30-currency-validation.png (screenshot of validation)

  **Commit**: YES
  - Message: `feat(frontend): add currency settings page`
  - Files: `src/pages/SettingsPage.tsx, src/components/CurrencyForm.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 31. Sync Status Indicator + Manual Sync Button

  **What to do**:
  - Create SyncStatus component in src/components/SyncStatus.tsx
  - Display in Header: "Last synced: X minutes ago"
  - Show sync status: Syncing, Success, Failed
  - Add manual "Sync Now" button
  - Implement sync operation calling REST API via Tauri command
  - Show progress indicator during sync
  - Display error message if sync fails
  - Store last sync timestamp in localStorage
  - Write component tests

  **Must NOT do**:
  - Do not implement automatic background sync yet (manual only)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - **Reason**: UI component with API integration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 26-30)
  - **Blocks**: Task 32
  - **Blocked By**: Tasks 23 (sync API), 24 (shadcn/ui), 25 (TanStack)

  **References**:
  - `src-tauri/src/presentation/api/sync_api.rs` - Sync endpoints

  **Acceptance Criteria**:
  - [ ] Sync status displays correctly
  - [ ] Manual sync button triggers sync operation
  - [ ] Progress indicator shows during sync
  - [ ] Last sync timestamp updates after successful sync
  - [ ] Error message displays if sync fails

  **QA Scenarios**:

  ```
  Scenario: Manual sync succeeds
    Tool: Playwright (playwright skill)
    Preconditions: App running, server available
    Steps:
      1. Create account locally
      2. Click "Sync Now" button
      3. Assert progress indicator appears
      4. Wait for sync to complete
      5. Assert status shows "Last synced: just now"
      6. Query server database: verify account synced
    Expected Result: Sync succeeds, data on server
    Failure Indicators: Sync fails, data not on server
    Evidence: .sisyphus/evidence/task-31-manual-sync.png

  Scenario: Sync failure handling
    Tool: Playwright (playwright skill)
    Preconditions: Server unavailable
    Steps:
      1. Stop server
      2. Click "Sync Now"
      3. Assert error message displays: "Sync failed: Unable to connect"
      4. Assert last sync timestamp unchanged
    Expected Result: Error handled gracefully
    Failure Indicators: App crashes, no error message
    Evidence: .sisyphus/evidence/task-31-sync-failure.png
  ```

  **Evidence to Capture**:
  - [ ] task-31-manual-sync.png (screenshot of successful sync)
  - [ ] task-31-sync-failure.png (screenshot of error handling)

  **Commit**: YES
  - Message: `feat(frontend): add sync status indicator and manual sync button`
  - Files: `src/components/SyncStatus.tsx, src/components/Header.tsx`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

---

### Wave 5: Integration + Polish (6 tasks, depends on Wave 4)

- [ ] 32. Account Registration + Device Binding

  **What to do**:
  - Create onboarding flow for first-time users
  - On first launch, call /api/register to get account ID
  - Store account ID and device ID in secure storage (tauri-plugin-store)
  - Display account ID to user with "Save this ID" warning
  - Implement device binding: send device_id with all sync requests
  - Add "Link Device" feature in settings (enter existing account ID)
  - Write integration tests for registration flow

  **Must NOT do**:
  - Do not implement password authentication (device binding only)
  - Do not implement account recovery (user must save account ID)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Security-sensitive registration and device management

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 33-37)
  - **Blocks**: Task 33
  - **Blocked By**: Tasks 23 (sync API), 31 (sync UI)

  **References**:
  - Official docs: https://github.com/tauri-apps/plugins-workspace/tree/v2/plugins/store - tauri-plugin-store
  - `src-tauri/src/presentation/api/sync_api.rs` - Register endpoint

  **Acceptance Criteria**:
  - [ ] First launch triggers registration
  - [ ] Account ID stored securely
  - [ ] Device ID generated and stored
  - [ ] Sync requests include device_id
  - [ ] Link device feature works

  **QA Scenarios**:

  ```
  Scenario: First launch registration
    Tool: Playwright (playwright skill)
    Preconditions: Fresh app install, server running
    Steps:
      1. Launch app for first time
      2. Assert onboarding screen displays
      3. Click "Get Started"
      4. Assert registration API called
      5. Assert account ID displayed with save warning
      6. Click "I've Saved My ID"
      7. Assert main app loads
      8. Check secure storage: verify account_id and device_id stored
    Expected Result: Registration completes successfully
    Failure Indicators: API call fails, IDs not stored
    Evidence: .sisyphus/evidence/task-32-registration.png

  Scenario: Link existing device
    Tool: Playwright (playwright skill)
    Preconditions: App registered on device A
    Steps:
      1. Launch app on device B (fresh install)
      2. Click "Link Existing Account"
      3. Enter account ID from device A
      4. Click "Link"
      5. Assert device B now syncs with same account
      6. Create account on device B
      7. Sync
      8. Verify account appears on device A after sync
    Expected Result: Device linking works
    Failure Indicators: Sync fails, data not shared
    Evidence: .sisyphus/evidence/task-32-device-linking.png
  ```

  **Evidence to Capture**:
  - [ ] task-32-registration.png (screenshot of registration flow)
  - [ ] task-32-device-linking.png (screenshot of device linking)

  **Commit**: YES
  - Message: `feat(integration): add account registration and device binding`
  - Files: `src/pages/OnboardingPage.tsx, src/lib/auth.ts, src-tauri/Cargo.toml (add tauri-plugin-store)`
  - Pre-commit: `cargo test && pnpm type-check`

- [ ] 33. Background Sync Scheduler

  **What to do**:
  - Create background sync scheduler in src-tauri/src/infrastructure/sync/sync_scheduler.rs
  - Use tokio interval to trigger sync every N minutes (configurable, default 15 min)
  - Only sync when app is running (not a system service)
  - Check network connectivity before syncing
  - Implement exponential backoff on sync failures
  - Emit events to frontend on sync status changes
  - Add sync settings in frontend: enable/disable, interval
  - Write integration tests for scheduler

  **Must NOT do**:
  - Do not implement system service (app must be running)
  - Do not sync too frequently (respect interval setting)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Background task scheduling with error handling

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 32, 34-37)
  - **Blocks**: Task 37
  - **Blocked By**: Tasks 18 (SyncService), 32 (registration)

  **References**:
  - Official docs: https://docs.rs/tokio/latest/tokio/time/fn.interval.html - tokio interval
  - `src-tauri/src/infrastructure/sync/sync_service.rs` - SyncService

  **Acceptance Criteria**:
  - [ ] Sync scheduler starts on app launch
  - [ ] Sync triggered every N minutes
  - [ ] Exponential backoff on failures
  - [ ] Frontend receives sync status events
  - [ ] Sync settings persist

  **QA Scenarios**:

  ```
  Scenario: Automatic sync triggers
    Tool: Bash (cargo test with time mocking)
    Preconditions: Scheduler implemented
    Steps:
      1. Start app with sync interval = 1 minute (for testing)
      2. Create account locally
      3. Wait 1 minute
      4. Assert sync triggered automatically
      5. Query server: verify account synced
      6. Wait another minute
      7. Assert sync triggered again
    Expected Result: Sync runs on schedule
    Failure Indicators: Sync not triggered, wrong interval
    Evidence: .sisyphus/evidence/task-33-auto-sync.txt

  Scenario: Exponential backoff on failure
    Tool: Bash (cargo test)
    Preconditions: Server unavailable
    Steps:
      1. Start scheduler
      2. Assert first sync attempt at t=0
      3. Assert second attempt at t=2s (2^1)
      4. Assert third attempt at t=6s (2^2)
      5. Assert fourth attempt at t=14s (2^3)
      6. Start server
      7. Assert sync succeeds on next attempt
      8. Assert interval resets to normal
    Expected Result: Backoff works correctly
    Failure Indicators: No backoff, immediate retries
    Evidence: .sisyphus/evidence/task-33-backoff.txt
  ```

  **Evidence to Capture**:
  - [ ] task-33-auto-sync.txt (scheduler test log)
  - [ ] task-33-backoff.txt (backoff test log)

  **Commit**: YES
  - Message: `feat(integration): add background sync scheduler with exponential backoff`
  - Files: `src-tauri/src/infrastructure/sync/sync_scheduler.rs, src/pages/SettingsPage.tsx (sync settings)`
  - Pre-commit: `cargo test sync_scheduler`

- [ ] 34. Reminder Notification Integration

  **What to do**:
  - Integrate reminder system with notification service
  - On app startup, query all pending reminders
  - Schedule OS notifications for each reminder
  - Implement notification click handler: open app to debt details page
  - Create reminder check loop: every minute, check for due reminders
  - Send notification when reminder triggers
  - Mark reminder as notified after sending
  - Handle recurring reminders: create next occurrence
  - Write integration tests for reminder flow

  **Must NOT do**:
  - Do not send notifications when app is closed (OS handles scheduled notifications)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Integration of reminder and notification systems

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 32-33, 35-37)
  - **Blocks**: Task 37
  - **Blocked By**: Tasks 19 (NotificationService), 28 (debt page)

  **References**:
  - `src-tauri/src/infrastructure/notifications/notification_service.rs` - NotificationService
  - `src-tauri/src/domain/aggregates/reminder.rs` - Reminder aggregate

  **Acceptance Criteria**:
  - [ ] Reminders scheduled on app startup
  - [ ] Notifications sent when reminders trigger
  - [ ] Notification click opens relevant page
  - [ ] Recurring reminders create next occurrence
  - [ ] `cargo test reminder_integration` passes

  **QA Scenarios**:

  ```
  Scenario: Debt payment reminder triggers
    Tool: Playwright (playwright skill) + Bash
    Preconditions: App running, debt with payment due tomorrow
    Steps:
      1. Create debt with payment due 2026-04-08
      2. Create reminder for 3 days before (2026-04-05)
      3. Mock system time to 2026-04-05 10:00
      4. Wait for reminder check loop
      5. Assert OS notification sent
      6. Assert notification title: "Payment Due Soon"
      7. Assert notification body includes debt details
      8. Click notification
      9. Assert app opens to debt details page
    Expected Result: Reminder triggers and opens app
    Failure Indicators: Notification not sent, click doesn't open app
    Evidence: .sisyphus/evidence/task-34-reminder-trigger.png

  Scenario: Recurring reminder creates next occurrence
    Tool: Bash (cargo test)
    Preconditions: Monthly recurring reminder
    Steps:
      1. Create reminder: monthly, starting 2026-04-01
      2. Trigger reminder (mark as notified)
      3. Assert next occurrence created: 2026-05-01
      4. Trigger again
      5. Assert next occurrence: 2026-06-01
    Expected Result: Recurring reminders continue
    Failure Indicators: Next occurrence not created
    Evidence: .sisyphus/evidence/task-34-recurring-reminder.txt
  ```

  **Evidence to Capture**:
  - [ ] task-34-reminder-trigger.png (screenshot of notification)
  - [ ] task-34-recurring-reminder.txt (test log)

  **Commit**: YES
  - Message: `feat(integration): integrate reminder notifications with debt management`
  - Files: `src-tauri/src/infrastructure/reminders/reminder_scheduler.rs, src-tauri/src/main.rs`
  - Pre-commit: `cargo test reminder_integration`

- [ ] 35. Multi-Currency Report Aggregation

  **What to do**:
  - Implement currency conversion in report generation
  - Add "Display Currency" selector in reports page
  - Convert all amounts to selected display currency using exchange rates
  - Show original currency in tooltip/detail view
  - Handle missing exchange rates gracefully (show warning)
  - Update balance sheet to aggregate multi-currency accounts
  - Update income statement to aggregate multi-currency transactions
  - Add exchange rate disclaimer: "Rates as of [timestamp]"
  - Write integration tests for conversion accuracy

  **Must NOT do**:
  - Do not implement real-time rate updates (use stored rates)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - **Reason**: Complex financial calculations with currency conversion

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 32-34, 36-37)
  - **Blocks**: Task 37
  - **Blocked By**: Tasks 29 (reports page), 30 (currency settings)

  **References**:
  - `src-tauri/src/domain/value_objects/money.rs` - Money with currency conversion
  - `src/pages/ReportsPage.tsx` - Reports page

  **Acceptance Criteria**:
  - [ ] Display currency selector works
  - [ ] All amounts converted correctly
  - [ ] Original currency shown in tooltip
  - [ ] Missing rate warning displayed
  - [ ] Conversion accuracy within 0.01 tolerance

  **QA Scenarios**:

  ```
  Scenario: Multi-currency balance sheet
    Tool: Playwright (playwright skill)
    Preconditions: Accounts in CNY, USD, EUR exist
    Steps:
      1. Create accounts: CNY 1000, USD 100, EUR 50
      2. Set exchange rates: USD=7.25, EUR=8.00
      3. Navigate to /reports
      4. Select display currency: CNY
      5. Assert total assets = 1000 + (100*7.25) + (50*8.00) = 2125 CNY
      6. Change display currency to USD
      7. Assert total assets = (1000/7.25) + 100 + (50*8.00/7.25) ≈ 293.10 USD
      8. Hover over USD account
      9. Assert tooltip shows: "100.00 USD (original)"
    Expected Result: Conversion accurate
    Failure Indicators: Incorrect totals, conversion errors
    Evidence: .sisyphus/evidence/task-35-multi-currency-report.png

  Scenario: Missing exchange rate warning
    Tool: Playwright (playwright skill)
    Preconditions: Account in JPY without exchange rate
    Steps:
      1. Create account: JPY 10000
      2. Navigate to /reports
      3. Assert warning displayed: "Exchange rate for JPY not set"
      4. Assert JPY account shown with "N/A" for converted amount
    Expected Result: Missing rate handled gracefully
    Failure Indicators: App crashes, no warning
    Evidence: .sisyphus/evidence/task-35-missing-rate.png
  ```

  **Evidence to Capture**:
  - [ ] task-35-multi-currency-report.png (screenshot of converted report)
  - [ ] task-35-missing-rate.png (screenshot of warning)

  **Commit**: YES
  - Message: `feat(integration): add multi-currency aggregation in reports`
  - Files: `src/pages/ReportsPage.tsx, src/lib/currency.ts`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 36. Error Handling + User Feedback

  **What to do**:
  - Implement global error boundary in React
  - Create Toast notification system for user feedback
  - Add error handling for all Tauri command failures
  - Show user-friendly error messages (not technical stack traces)
  - Implement loading states for all async operations
  - Add confirmation dialogs for destructive actions (delete account, delete debt)
  - Implement optimistic updates with rollback on error
  - Add network error detection and offline indicator
  - Write tests for error scenarios

  **Must NOT do**:
  - Do not expose internal error details to users
  - Do not silently fail (always show feedback)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Reason**: Cross-cutting concern affecting all pages

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 32-35, 37)
  - **Blocks**: Task 37
  - **Blocked By**: Tasks 26, 27, 28, 29 (all pages)

  **References**:
  - Pattern: React Error Boundary
  - Pattern: Optimistic UI updates with rollback

  **Acceptance Criteria**:
  - [ ] Error boundary catches React errors
  - [ ] Toast notifications show for all operations
  - [ ] Confirmation dialogs prevent accidental deletions
  - [ ] Loading states display during async operations
  - [ ] Network errors show offline indicator

  **QA Scenarios**:

  ```
  Scenario: Delete confirmation prevents accidental deletion
    Tool: Playwright (playwright skill)
    Preconditions: Account exists
    Steps:
      1. Navigate to /accounts
      2. Click delete button on account
      3. Assert confirmation dialog appears
      4. Click "Cancel"
      5. Assert account still exists
      6. Click delete again
      7. Click "Confirm"
      8. Assert account deleted
      9. Assert success toast: "Account deleted"
    Expected Result: Confirmation prevents accidents
    Failure Indicators: No confirmation, immediate deletion
    Evidence: .sisyphus/evidence/task-36-delete-confirmation.png

  Scenario: Network error shows offline indicator
    Tool: Playwright (playwright skill)
    Preconditions: App running
    Steps:
      1. Disconnect network
      2. Click "Sync Now"
      3. Assert offline indicator appears in header
      4. Assert error toast: "Unable to sync: No network connection"
      5. Reconnect network
      6. Assert offline indicator disappears
    Expected Result: Network status visible
    Failure Indicators: No indicator, unclear error
    Evidence: .sisyphus/evidence/task-36-offline-indicator.png
  ```

  **Evidence to Capture**:
  - [ ] task-36-delete-confirmation.png (screenshot of confirmation dialog)
  - [ ] task-36-offline-indicator.png (screenshot of offline state)

  **Commit**: YES
  - Message: `feat(integration): add comprehensive error handling and user feedback`
  - Files: `src/components/ErrorBoundary.tsx, src/components/Toast.tsx, src/lib/error-handler.ts`
  - Pre-commit: `pnpm type-check && pnpm vitest run`

- [ ] 37. Application Build + Packaging

  **What to do**:
  - Configure Tauri build settings in tauri.conf.json
  - Set app name, version, identifier (com.finance.app)
  - Configure app icons for Windows, macOS, Linux
  - Setup code signing (development certificates)
  - Configure installer settings (Windows: MSI, macOS: DMG, Linux: AppImage)
  - Test build process: `tauri build`
  - Verify built application runs correctly
  - Test installation on clean system
  - Create build documentation
  - Write build verification tests

  **Must NOT do**:
  - Do not publish to app stores (local distribution only)
  - Do not implement auto-update (out of scope for Phase 1)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Reason**: Standard build configuration

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (must be last)
  - **Blocks**: F1-F4 (final verification)
  - **Blocked By**: All tasks 32-36

  **References**:
  - Official docs: https://tauri.app/v2/guides/building/ - Tauri build process
  - Official docs: https://tauri.app/v2/guides/distribution/ - Distribution

  **Acceptance Criteria**:
  - [ ] `tauri build` completes successfully
  - [ ] Built executable runs without errors
  - [ ] Installer creates desktop shortcut
  - [ ] App launches from installed location
  - [ ] All features work in production build

  **QA Scenarios**:

  ```
  Scenario: Production build succeeds
    Tool: Bash (tauri build)
    Preconditions: All code complete
    Steps:
      1. Run `pnpm tauri build`
      2. Assert build completes without errors
      3. Assert executable created in src-tauri/target/release/
      4. Run executable
      5. Assert app launches
      6. Test core features: create account, record transaction, create debt
      7. Assert all features work
    Expected Result: Production build functional
    Failure Indicators: Build fails, app crashes, features broken
    Evidence: .sisyphus/evidence/task-37-production-build.txt

  Scenario: Installer works on clean system
    Tool: Manual (or VM automation)
    Preconditions: Clean Windows/macOS/Linux system
    Steps:
      1. Run installer
      2. Assert installation completes
      3. Assert desktop shortcut created
      4. Launch app from shortcut
      5. Assert app runs
      6. Complete onboarding
      7. Create test data
      8. Assert data persists after restart
    Expected Result: Installer works correctly
    Failure Indicators: Installation fails, app doesn't launch
    Evidence: .sisyphus/evidence/task-37-installer-test.txt
  ```

  **Evidence to Capture**:
  - [ ] task-37-production-build.txt (build log)
  - [ ] task-37-installer-test.txt (installation test log)

  **Commit**: YES
  - Message: `chore(build): configure production build and packaging`
  - Files: `src-tauri/tauri.conf.json, src-tauri/icons/*, README.md (build instructions)`
  - Pre-commit: `tauri build`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
>
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.

- [ ] F1. **Plan Compliance Audit** — `oracle`

  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`

  Run `cargo build --release` + `cargo clippy` + `pnpm build`. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp).
  
  Output: `Build [PASS/FAIL] | Clippy [PASS/FAIL] | TypeScript [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if UI)

  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration (features working together, not isolation). Test edge cases: empty state, invalid input, rapid actions. Save to `.sisyphus/evidence/final-qa/`.
  
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`

  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes.
  
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

Each task produces one atomic commit following this format:

**Format**: `<type>(<scope>): <description>`

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

**Scopes**: `domain`, `application`, `infrastructure`, `presentation`, `frontend`, `infra`, `build`, `test`

**Examples**:
- `feat(domain): add Account aggregate with TDD`
- `feat(infrastructure): add SQLite repository implementations`
- `feat(frontend): add account management page`
- `chore(infra): initialize Tauri + React project structure`

**Pre-commit checks**: Each commit must pass relevant tests before committing.

---

## Success Criteria

### Verification Commands
```bash
# Backend build and test
cd src-tauri
cargo build --release
cargo test
cargo clippy -- -D warnings

# Frontend build and test
pnpm build
pnpm type-check
pnpm vitest run

# Application build
pnpm tauri build

# Database migrations
sqlx migrate run --database-url sqlite:local.db
sqlx migrate run --database-url postgresql://localhost/finance

# API server
cargo run --bin api-server

# Evidence verification
ls .sisyphus/evidence/ | wc -l  # Should have 100+ evidence files
```

### Final Checklist
- [ ] All "Must Have" features implemented and verified
- [ ] All "Must NOT Have" guardrails respected (no forbidden features)
- [ ] All tests pass (cargo test + pnpm vitest run)
- [ ] All QA scenarios executed with evidence captured
- [ ] Database migrations work on both SQLite and PostgreSQL
- [ ] Sync functionality works (local ↔ cloud)
- [ ] Reminder notifications trigger correctly
- [ ] Multi-currency conversion accurate
- [ ] Double-entry bookkeeping enforced
- [ ] Amortization calculations correct (golden master tests pass)
- [ ] Production build succeeds and runs
- [ ] No AI slop patterns (excessive comments, over-abstraction, generic names)
- [ ] No security issues (PII exposed, credentials in code)
- [ ] User feedback mechanisms work (toasts, error messages, loading states)
- [ ] All evidence files exist in `.sisyphus/evidence/`
- [ ] Final verification wave (F1-F4) all APPROVE
- [ ] User explicitly approves final results
