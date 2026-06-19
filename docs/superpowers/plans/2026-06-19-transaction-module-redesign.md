# 御财交易模块重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付御财交易模块核心闭环（分类 + 记账 + 列表 + 详情 + 统计 + 接入账户详情），覆盖 Desktop/Tablet/Mobile 三尺寸，分类用 account-as-category 模型。

**Architecture:** 方法 3 全栈垂直切片 —— 切片 0 共享基础层先行（account 字段扩展 + proto stub + 客户端包骨架 + 共享组件 + 响应式断点），切片 1–6 每个特性端到端（服务端用例 → proto → 客户端 bloc → UI → 测试）。分类即 Expense/Income 账户，复用 account 模块，不新建 Category 表。

**Tech Stack:** 服务端 Go + ent ORM + gRPC + Wire DI + PostgreSQL；客户端 Flutter + flutter_bloc + go_router + protobuf；TDD（Go testing + Flutter vitest/widget test）。

## Global Constraints

（每个任务隐含遵守，摘自 spec docs/superpowers/specs/2026-06-19-transaction-module-redesign-design.md）

- **御财 token**：奶油白 #f7f6f2 / 御财金 #b08d57 / 深色侧栏 #1c1e21 / 收入绿 #2d8a6e / 支出红 #c4544d / 边框 #e6e3dc / 圆角 sm 10px lg 14px / 标题 serif(Georgia,'Noto Serif SC') / 数字 mono+tabular-nums
- **复式记账**：借贷平衡（DoubleEntryValidator），金额 int64 cents
- **account-as-category**：分类 = `AccountType=Expense/Income` 账户，不新建 Category 表
- **多租户**：所有查询带 TenantID；预置分类 per-tenant 注入
- **三尺寸响应式**：断点 ≤600 Mobile / 600–1200 Tablet / ≥1200 Desktop，业务逻辑共享只布局变
- **客户端 i18n**：UI 文案用 `t()`，不硬编码（参考 account 模块）
- **服务端日志**：英文结构化 `tracing`（`info!`/`error!`），禁 `println!`，禁 CJK 日志
- **TDD**：每任务先写失败测试 → 实现 → 通过 → commit
- **路径**：服务端 `yucai/server/`，客户端 `yucai/client/`，proto `yucai/proto/`

## File Structure

### 服务端创建/修改
- Create: `yucai/server/internal/account/migrations/YYYYMMDD_account_category_fields.sql` — account 加 parent_id/is_system/sort_order
- Create: `yucai/server/internal/account/migrations/YYYYMMDD_preset_categories_seed.sql` — 预置 10 分类（per-tenant 注入逻辑在 service）
- Modify: `yucai/server/internal/account/domain/entity.go` — Account 加 ParentID/IsSystem/SortOrder 字段
- Modify: `yucai/server/internal/account/domain/repository.go` — 加 `FindByAccountType` trait 方法
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go` — FindByAccountType + Category CRUD ent 实现
- Modify: `yucai/server/internal/account/application/service.go` — CreateCategory/UpdateCategory/DeleteCategory/ReorderCategories 用例
- Modify: `yucai/server/internal/transaction/application/service.go` — SimpleTransfer/Expense 校验 + TransactionSummary + FindRecentByAccount
- Modify: `yucai/server/internal/transaction/application/dto.go` — MonthlySummary/DailyItem DTO
- Modify: `yucai/server/internal/transaction/domain/repository.go` — FindRecentByAccount + SummaryQuery trait
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go` — N+1 修复 + Type filter + 聚合查询
- Modify: `yucai/server/internal/transaction/adapter/driving/grpc/transaction_handler.go` — TransactionSummary handler
- Modify: `yucai/server/cmd/wire/*.go` — 注册 transaction ProviderSet
- Modify: `yucai/proto/account/v1/account.proto` — FindByAccountType + Category CRUD RPC + parent_id/is_system/sort_order 字段
- Modify: `yucai/proto/transaction/v1/transaction.proto` — TransactionSummary RPC + ListTransactionsRequest.Type + MonthlySummary DTO

### 客户端创建/修改
- Create: `yucai/client/lib/transaction/domain/entities/transaction_entity.dart` — Transaction + Entry entity
- Create: `yucai/client/lib/transaction/domain/repositories/transaction_repository.dart` — abstract trait
- Create: `yucai/client/lib/transaction/domain/value_objects.dart` — EntryType, TxnType
- Create: `yucai/client/lib/transaction/data/datasources/transaction_remote_ds.dart` — gRPC 调用
- Create: `yucai/client/lib/transaction/data/repositories/transaction_repository_impl.dart`
- Create: `yucai/client/lib/transaction/data/models/transaction_model.dart` — DTO↔entity 映射
- Create: `yucai/client/lib/transaction/presentation/bloc/transaction_bloc.dart` + event + state
- Create: `yucai/client/lib/transaction/presentation/bloc/transaction_form_bloc.dart` + event + state
- Create: `yucai/client/lib/transaction/presentation/bloc/category_bloc.dart` + event + state
- Create: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`
- Create: `yucai/client/lib/transaction/presentation/pages/transaction_form_page.dart`
- Create: `yucai/client/lib/transaction/presentation/pages/transaction_detail_page.dart`
- Create: `yucai/client/lib/transaction/presentation/pages/category_management_page.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/summary_card.dart` — 汇总 4 卡
- Create: `yucai/client/lib/transaction/presentation/widgets/filter_bar.dart` — 筛选栏
- Create: `yucai/client/lib/transaction/presentation/widgets/txn_row.dart` — 交易行/卡
- Create: `yucai/client/lib/transaction/presentation/widgets/category_chip.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/journal_entry.dart` — 复式分录展示
- Create: `yucai/client/lib/transaction/presentation/widgets/responsive_layout.dart` — 三尺寸断点 helper
- Modify: `yucai/client/lib/account/...` — 分类下拉复用 FindByAccountType（form_page）
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart` — 占位变真实（切片 6）
- Generate: `yucai/client/lib/proto/transaction/v1/transaction.pbgrpc.dart` + account 同理

---

## 切片 0 · 共享基础层（先行，无可演示特性但是地基）

### Task 0.1: 服务端 account 字段扩展（parent_id/is_system/sort_order）

**Files:**
- Create: `yucai/server/internal/account/migrations/20260620_account_category_fields.sql`
- Modify: `yucai/server/internal/account/domain/entity.go`
- Modify: `yucai/server/ent/schema/account.go`（若 ent schema 在此；否则定位实际 schema 路径）
- Test: `yucai/server/internal/account/domain/entity_test.go`

**Interfaces:**
- Produces: `Account` struct 新增 `ParentID *uuid.UUID` / `IsSystem bool` / `SortOrder int`；migration 提供 default（null/false/0），现有账户不受影响

- [ ] **Step 1: 写失败测试**

```go
// entity_test.go
func TestAccount_CategoryFields(t *testing.T) {
    a := NewAccount(/* ... */)
    a.IsSystem = true
    a.SortOrder = 5
    pid := uuid.New()
    a.ParentID = &pid
    assert.True(a.IsSystem)
    assert.Equal(5, a.SortOrder)
    assert.Equal(&pid, a.ParentID)
}
```

- [ ] **Step 2: 运行测试验证失败** — `cd yucai/server && go test ./internal/account/domain/ -run TestAccount_CategoryFields` → FAIL（字段未定义）

- [ ] **Step 3: 写 migration**

```sql
-- 20260620_account_category_fields.sql
ALTER TABLE accounts ADD COLUMN parent_id UUID NULL;
ALTER TABLE accounts ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_accounts_parent_id ON accounts(parent_id);
```

- [ ] **Step 4: 扩展 ent schema + domain entity**（加 3 字段），运行 `go generate ./ent/...` 重新生成 ent 代码

- [ ] **Step 5: 运行测试验证通过** → PASS

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(account): add parent_id/is_system/sort_order fields for category-as-account"`

### Task 0.2: 服务端 account FindByAccountType 查询

**Files:**
- Modify: `yucai/server/internal/account/domain/repository.go`（加 trait 方法）
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go`（实现）
- Modify: `yucai/proto/account/v1/account.proto`（加 RPC + 字段）
- Test: `yucai/server/internal/account/adapter/driven/repository/account_repo_test.go`

**Interfaces:**
- Consumes: Task 0.1 的 Account 字段
- Produces: `AccountRepository.FindByAccountType(ctx, tenantID uuid.UUID, accountType AccountType) ([]Account, error)`；proto RPC `FindByAccountType(tenant_id, account_type) returns (stream AccountDTO)`

- [ ] **Step 1: 写失败测试** — 测 FindByAccountType 返回正确 type 的账户

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: trait 加方法 + ent 实现**（`repo.client.Account.Query().Where(account.TenantID(tenantID), account.AccountType(accountType.String()))`）

- [ ] **Step 4: proto 加 RPC + regenerate**（`buf generate`）

- [ ] **Step 5: 验证通过** → PASS

- [ ] **Step 6: Commit** — `feat(account): FindByAccountType query for category dropdown`

### Task 0.3: 服务端 transaction wire ProviderSet 注册

**Files:**
- Modify: `yucai/server/internal/transaction/adapter/driving/grpc/wire.go`（或 ProviderSet 定义处）
- Modify: `yucai/server/cmd/wire/wire_gen.go`（重新生成）

**Interfaces:**
- Produces: transaction 的 TransactionService/Repo/Handler 注入到 wire graph

- [ ] **Step 1: 定位 transaction ProviderSet**（探索发现未注册），定义 `var ProviderSet = wire.NewSet(...)`

- [ ] **Step 2: 在 cmd/wire 的 injector 包含 transaction.ProviderSet**

- [ ] **Step 3: 运行 `wire ./cmd/wire/...` 重新生成 wire_gen.go**

- [ ] **Step 4: 验证 `go build ./cmd/...` 成功**（transaction handler 已注入）

- [ ] **Step 5: Commit** — `chore(transaction): register ProviderSet in wire`

### Task 0.4: 客户端 proto grpc stub 生成

**Files:**
- Generate: `yucai/client/lib/proto/transaction/v1/transaction.pbgrpc.dart`
- Generate: `yucai/client/lib/proto/account/v1/account.pbgrpc.dart`
- Modify: `yucai/client/buf.gen.yaml`（或 protoc 配置，对比 auth 生成方式）

**Interfaces:**
- Produces: `TransactionServiceClient` / `AccountServiceClient` gRPC client stubs（供 datasource 调用）

- [ ] **Step 1: 定位 client proto 生成配置**（参考 `auth/v1/auth.pbgrpc.dart` 的生成方式：buf / protoc）

- [ ] **Step 2: 确认生成配置包含 grpc plugin（dart）**，补 transaction + account

- [ ] **Step 3: 运行生成命令**（`buf generate` 或 `protoc`）

- [ ] **Step 4: 验证 `transaction.pbgrpc.dart` 存在且含 `TransactionServiceClient`**

- [ ] **Step 5: `flutter analyze` 通过**（无 import 错误）

- [ ] **Step 6: Commit** — `chore(client): generate transaction/account grpc stubs`

### Task 0.5: 客户端 transaction domain 层 + data 层骨架

**Files:**
- Create: `yucai/client/lib/transaction/domain/entities/transaction_entity.dart`
- Create: `yucai/client/lib/transaction/domain/repositories/transaction_repository.dart`
- Create: `yucai/client/lib/transaction/domain/value_objects.dart`
- Create: `yucai/client/lib/transaction/data/datasources/transaction_remote_ds.dart`
- Create: `yucai/client/lib/transaction/data/repositories/transaction_repository_impl.dart`
- Create: `yucai/client/lib/transaction/data/models/transaction_model.dart`
- Test: `yucai/client/test/transaction/data/repositories/transaction_repository_impl_test.dart`

**Interfaces:**
- Consumes: Task 0.4 的 grpc stubs
- Produces: `TransactionRepository`（abstract）+ `TransactionRepositoryImpl` + `Transaction`/`TransactionEntry` entity；方法签名：
  - `recordExpense(RecordExpenseParams) -> Future<Result<void>>`
  - `listTransactions(ListParams) -> Future<List<Transaction>>`
  - `getTransaction(String id) -> Future<Transaction>`
  - `summary(int year, int month, {String? accountId}) -> Future<MonthlySummary>`

- [ ] **Step 1: 写失败测试** — mock datasource，测 repositoryImpl 正确转发 + DTO↔entity 映射

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 entity（Transaction{id, date, description, entries, version} + TransactionEntry{id, accountId, debitCents, creditCents, note}）+ value_objects + abstract repository**

- [ ] **Step 4: 实现 remote datasource（封装 grpc client）+ repositoryImpl（DTO→entity 映射）**

- [ ] **Step 5: 验证通过** → PASS

- [ ] **Step 6: Commit** — `feat(client): transaction domain + data layer skeleton`

### Task 0.6: 客户端御财共享组件 + 响应式断点

**Files:**
- Create: `yucai/client/lib/transaction/presentation/widgets/responsive_layout.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/summary_card.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/filter_bar.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/txn_row.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/category_chip.dart`
- Create: `yucai/client/lib/transaction/presentation/widgets/journal_entry.dart`
- Test: `yucai/client/test/transaction/presentation/widgets/responsive_layout_test.dart`

**Interfaces:**
- Produces:
  - `ResponsiveLayout({mobile, tablet, desktop})` — 按 MediaQuery 宽度选择（≤600/600-1200/≥1200）
  - `SummaryCard({income, expense, net, dailyAvg})` — 汇总 4 卡
  - `FilterBar({onTypeChange, onAccountChange, onCategoryChange, onMonthChange})`
  - `TxnRow(Transaction txn, {Breakpoint breakpoint})` — 表格行(Mobile 卡片)
  - `CategoryChip(Account category)`
  - `JournalEntry(List<TransactionEntry> entries)` — 借/贷/平衡标注

- [ ] **Step 1: 写失败测试** — 测 ResponsiveLayout 在 width=390 返回 mobile builder，width=1440 返回 desktop builder

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 ResponsiveLayout**（`MediaQuery.of(context).size.width` 判断断点）

- [ ] **Step 4: 实现其余 5 组件**（纯 UI，遵循御财 token，i18n `t()`）

- [ ] **Step 5: 验证通过 + `flutter analyze`**

- [ ] **Step 6: Commit** — `feat(client): shared transaction widgets + responsive layout`

---

## 切片 1 · 记一笔

### Task 1.1: 服务端 SimpleTransfer/SimpleExpense 业务校验

**Files:**
- Modify: `yucai/server/internal/transaction/application/service.go`（SimpleTransfer + SimpleExpense）
- Test: `yucai/server/internal/transaction/application/service_test.go`

**Interfaces:**
- Consumes: accountRepo（查账户 currency_code + balance）
- Produces: SimpleTransfer 拒绝不同币种；SimpleExpense 拒绝余额不足

- [ ] **Step 1: 写失败测试**

```go
func TestSimpleTransfer_RejectsMismatchedCurrency(t *testing.T) {
    // from 账户 CNY, to 账户 USD → expect error "currency mismatch"
}
func TestSimpleExpense_RejectsInsufficientBalance(t *testing.T) {
    // asset 账户余额 100, 支出 200 → expect error "insufficient balance"
}
```

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现** — SimpleTransfer 查两账户 currency_code 比对；SimpleExpense 查 asset 账户 currentBalanceCents，不足返回 error（参考 Tauri `create_expense`/`create_transfer`）

- [ ] **Step 4: 验证通过** → PASS

- [ ] **Step 5: Commit** — `feat(transaction): currency + balance validation on simple expense/transfer`

### Task 1.2: 客户端 TransactionFormPage（记一笔，三尺寸）

**Files:**
- Create: `yucai/client/lib/transaction/presentation/bloc/transaction_form_bloc.dart` + event + state
- Create: `yucai/client/lib/transaction/presentation/pages/transaction_form_page.dart`
- Modify: `yucai/client/lib/account/presentation/widgets/`（分类下拉复用）
- Test: `yucai/client/test/transaction/presentation/pages/transaction_form_page_test.dart`

**Interfaces:**
- Consumes: Task 0.4 grpc stubs, Task 0.5 repository, Task 0.6 widgets；account_bloc（FindByAccountType 查 Expense/Income 账户作分类下拉）
- Produces: 记一笔表单（类型 tabs 支出/收入/转账 + 金额 + 账户 + 分类 + 详情 + 标签占位 + 右栏复式预览[Desktop]），提交调 `recordExpense/Income/Transfer`

- [ ] **Step 1: 写失败 widget 测试** — 三尺寸断点（390/1024/1440）渲染不同布局；提交触发 bloc event

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 TransactionFormBloc**（RecordExpenseRequested/RecordIncomeRequested/RecordTransferRequested → repo 调用 → 成功/失败 state）

- [ ] **Step 4: 实现 TransactionFormPage**（ResponsiveLayout 切三尺寸布局；分类下拉 = `AccountBloc.loadByType(Expense/Income)`；标签区域占位 🔒「待 Tags 模块」；Desktop 右栏 JournalEntry 实时预览借=分类账户 贷=资产账户）

- [ ] **Step 5: 验证通过 + 三尺寸 widget 测试**

- [ ] **Step 6: Commit** — `feat(client): transaction form page (three sizes, account-as-category)`

---

## 切片 2 · 交易列表

### Task 2.1: 服务端 FindAll N+1 修复 + Type filter

**Files:**
- Modify: `yucai/server/internal/transaction/domain/repository.go`（TransactionFilter 加 Type）
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`（eager load entries + Type 过滤）
- Test: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo_test.go`

**Interfaces:**
- Produces: `TransactionFilter{AccountID, DateFrom, DateTo, Type}`；FindAll 用 ent eager load 一次性加载 entries（消除 N+1）；Type 过滤按 entry 方向推断（income=贷 Income 账户 / expense=借 Expense 账户 / transfer=两 Asset 账户）

- [ ] **Step 1: 写失败测试** — N+1 计数（断言查询次数）+ Type 过滤返回正确类型

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 改 FindAll** — ent `Transaction.Query().WithEntries()` eager load；Type 过滤在 SQL JOIN entry + account.type 条件

- [ ] **Step 4: 回归测试现有 ListTransactions** → PASS

- [ ] **Step 5: Commit** — `perf(transaction): fix FindAll N+1 + add Type filter`

### Task 2.2: 客户端 TransactionsPage（列表，三尺寸）

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/bloc/transaction_bloc.dart`（加 list 状态）
- Create: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`
- Test: `yucai/client/test/transaction/presentation/pages/transactions_page_test.dart`

**Interfaces:**
- Consumes: Task 0.5/0.6 + Task 2.1 service；SummaryCard 占位（切片 5 接真实）
- Produces: 列表页（汇总4卡[占位] + FilterBar + 按日分组 TxnRow 表格/卡片 + 分页 + 新增交易入口）

- [ ] **Step 1: 写失败 widget 测试** — 三尺寸（Desktop 表格列 / Mobile 卡片堆叠）；筛选触发 bloc

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 TransactionBloc**（LoadTransactions{filter, page} → repo.listTransactions → TransactionsLoaded）

- [ ] **Step 4: 实现 TransactionsPage**（ResponsiveLayout；按日分组 groupBy(date)；分页游标）

- [ ] **Step 5: 验证通过**

- [ ] **Step 6: Commit** — `feat(client): transactions list page (three sizes, day grouping, pagination)`

---

## 切片 3 · 交易详情

### Task 3.1: 服务端 FindRecentByAccount（同分类近期交易）

**Files:**
- Modify: `yucai/server/internal/transaction/domain/repository.go`
- Modify: `yucai/server/internal/transaction/application/service.go`
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`
- Test: `yucai/server/internal/transaction/application/service_test.go`

**Interfaces:**
- Produces: `Service.FindRecentByAccount(ctx, tenantID, accountID uuid.UUID, limit int) ([]Transaction, error)` — 查同账户（同分类）的近期交易

- [ ] **Step 1: 写失败测试** — 给定餐饮账户，返回该账户近期交易

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现** — repo 查 entries WHERE account_id + JOIN transaction，按 date desc limit

- [ ] **Step 4: 验证通过** → PASS

- [ ] **Step 5: Commit** — `feat(transaction): FindRecentByAccount for same-category recent transactions`

### Task 3.2: 客户端 TransactionDetailPage（详情，三尺寸 + 复式分录）

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/bloc/transaction_bloc.dart`（加 detail + recent 状态）
- Create: `yucai/client/lib/transaction/presentation/pages/transaction_detail_page.dart`
- Test: `yucai/client/test/transaction/presentation/pages/transaction_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 0.6 JournalEntry, Task 3.1 service
- Produces: 详情页（概要 + JournalEntry 复式分录 + 快捷操作[编辑/复制/删除] + 同分类近期交易列表 + 占位区[AA分摊🔒/同商户🔒/预算🔒]）

- [ ] **Step 1: 写失败 widget 测试** — 分录展示「借餐饮(Expense) ¥380 / 贷招商银行 ¥380 / 平衡」；同分类近期交易渲染

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 bloc**（LoadTransactionDetail{id} → getTransaction + findRecentByAccount）

- [ ] **Step 4: 实现 TransactionDetailPage**（三尺寸 ResponsiveLayout；占位区灰显 + 🔒 标记，沿用 account_detail 模式）

- [ ] **Step 5: 验证通过**

- [ ] **Step 6: Commit** — `feat(client): transaction detail page (journal entry + same-category + placeholder zones)`

---

## 切片 4 · 分类管理

### Task 4.1: 服务端 Category CRUD 用例 + 预置 seed

**Files:**
- Modify: `yucai/server/internal/account/application/service.go`（CreateCategory/UpdateCategory/DeleteCategory/ReorderCategories）
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go`
- Modify: `yucai/proto/account/v1/account.proto`（4 CRUD RPC）
- Create: `yucai/server/internal/account/migrations/20260620_preset_categories_seed.sql` 或 service 内 seed 逻辑（per-tenant）
- Test: `yucai/server/internal/account/application/service_test.go`

**Interfaces:**
- Produces: Category CRUD（is_system 拒删）+ 预置 10 分类 per-tenant（餐饮/交通/购物/娱乐/居家/医疗/工资/兼职/理财收益/红包）

- [ ] **Step 1: 写失败测试** — CreateCategory 成功；DeleteCategory 对 is_system=true 拒绝；Reorder 更新 sort_order；预置 seed 注入 10 分类

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 4 用例**（Create/Update 正常；Delete 检查 `is_system`；Reorder 批量更新 sort_order）

- [ ] **Step 4: 实现预置 seed**（首次创建 tenant 时注入 10 个 is_system=true 的 Expense/Income 账户）+ proto RPC + handler

- [ ] **Step 5: 验证通过** → PASS

- [ ] **Step 6: Commit** — `feat(account): category CRUD + preset seed (10 system categories)`

### Task 4.2: 客户端 CategoryManagementPage（分类管理，三尺寸）

**Files:**
- Create: `yucai/client/lib/transaction/presentation/bloc/category_bloc.dart` + event + state
- Create: `yucai/client/lib/transaction/presentation/pages/category_management_page.dart`
- Test: `yucai/client/test/transaction/presentation/pages/category_management_page_test.dart`

**Interfaces:**
- Consumes: Task 4.1 CRUD + Task 0.6 widgets；account_bloc（FindByAccountType）
- Produces: 分类管理页（类型 tab 支出/收入 + 列表[图标+名称+本月金额+系统标记] + 编辑面板[Desktop 右栏/Tablet 抽屉/Mobile sheet]：名称/图标/颜色/父分类/删除[系统禁用]）

- [ ] **Step 1: 写失败 widget 测试** — 三尺寸布局；系统分类删除禁用；编辑触发 CRUD event

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 CategoryBloc**（Load/Save/Delete/Reorder）

- [ ] **Step 4: 实现 CategoryManagementPage**（三尺寸 ResponsiveLayout；本月金额 = 账户当月余额，从 summary 取；二级分类 parent 下拉）

- [ ] **Step 5: 验证通过**

- [ ] **Step 6: Commit** — `feat(client): category management page (three sizes, CRUD, system lock)`

---

## 切片 5 · 统计汇总

### Task 5.1: 服务端 TransactionSummary 用例 + RPC + 聚合查询

**Files:**
- Modify: `yucai/server/internal/transaction/application/service.go`（TransactionSummary）
- Modify: `yucai/server/internal/transaction/application/dto.go`（MonthlySummary/DailyItem DTO）
- Modify: `yucai/server/internal/transaction/domain/repository.go`（SummaryQuery trait）
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`（聚合 SQL）
- Modify: `yucai/server/internal/transaction/adapter/driving/grpc/transaction_handler.go`
- Modify: `yucai/proto/transaction/v1/transaction.proto`（TransactionSummary RPC + DTO）
- Test: `yucai/server/internal/transaction/application/service_test.go`

**Interfaces:**
- Produces: `Service.TransactionSummary(ctx, tenantID uuid.UUID, year, month int, accountID *uuid.UUID) (MonthlySummary, error)`；返回：
  ```
  MonthlySummary{ IncomeCents, ExpenseCents, NetCents, DailyAvgCents, ByDay []DailyItem{Date, TotalIncome, TotalExpense, ByCategory []{AccountID,Name,AccountType,Amount}} }
  ```

- [ ] **Step 1: 写失败测试** — 给定若干交易，断言月汇总 + 按日 + 按分类聚合正确（含利息/理财收益/工资按账户拆分）

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 repo 聚合查询**（SQL：entry JOIN account ON account.type，按 account.type 判定收支方向 + GROUP BY date, account_id）

- [ ] **Step 4: 实现 service.TransactionSummary + DTO 组装 + proto RPC + handler**

- [ ] **Step 5: 验证通过** → PASS

- [ ] **Step 6: Commit** — `feat(transaction): TransactionSummary RPC with per-day per-category aggregation`

### Task 5.2: 客户端 SummaryCard 接真实统计

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/widgets/summary_card.dart`（接 MonthlySummary）
- Modify: `yucai/client/lib/transaction/data/models/transaction_model.dart`（MonthlySummary DTO）
- Modify: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`（占位 → 真实）
- Test: `yucai/client/test/transaction/presentation/widgets/summary_card_test.dart`

**Interfaces:**
- Consumes: Task 5.1 service
- Produces: SummaryCard 显示真实本月收入/支出/净额/日均（绿/红配色）

- [ ] **Step 1: 写失败测试** — SummaryCard 渲染 MonthlySummary 的 4 个值

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现 MonthlySummary model + SummaryCard 接真实数据 + TransactionsPage 触发 summary 加载**

- [ ] **Step 4: 验证通过**

- [ ] **Step 5: Commit** — `feat(client): summary card wired to real TransactionSummary`

---

## 切片 6 · 接入账户详情

### Task 6.1: 客户端 account_detail_page 占位变真实

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`
- Test: `yucai/client/test/account/presentation/pages/account_detail_page_test.dart`

**Interfaces:**
- Consumes: 切片 1（记一笔入口）+ 切片 2（近期交易）+ 切片 5（收支统计）的 bloc/repo
- Produces: account_detail_page 的「记一笔/转账」按钮（push TransactionFormPage）+ 近期交易 panel（TransactionBloc.loadByAccount）+ 收支统计 4 卡（summary(accountId)）+ 快捷操作激活

- [ ] **Step 1: 写失败测试** — 记一笔按钮 push 表单；近期交易显示该账户交易；4 卡显示该账户统计

- [ ] **Step 2: 验证失败** → FAIL

- [ ] **Step 3: 实现** — 替换 `onPressed: null` 为真实跳转；近期交易 panel 接 TransactionBloc；4 卡接 summary(accountId: widget.id)；快捷操作激活记一笔/转账

- [ ] **Step 4: 验证通过 + 全链路冒烟**（建账户 → 记一笔 → 看详情 → 余额/统计变化）

- [ ] **Step 5: Commit** — `feat(client): wire account detail to transaction module (placeholder → real)`

---

## Self-Review

**1. Spec coverage**（逐节核对）：
- 方案 A → 切片 0.1/0.2/4.1（account-as-category 落地）✅
- 切片地图（spec 第 4 节）→ 切片 0–6 任务全覆盖 ✅
- 服务端 5 处补齐（spec 第 5 节）→ 0.1/0.2/0.3(字段/查询/wire) + 1.1(校验) + 2.1(N+1+filter) + 3.1(recent) + 4.1(CRUD+seed) + 5.1(summary RPC) ✅
- 客户端结构 + 三尺寸（spec 第 6 节）→ 0.4/0.5/0.6(包+组件+响应式) + 各切片 page ✅
- 统计模型 MonthlySummary.ByDay 按分类（spec 第 7 节）→ 5.1 ✅
- 测试策略 TDD（spec 第 8 节）→ 每任务 TDD ✅
- 风险对策（spec 第 9 节）→ 0.3(wire) + 0.4(grpc stub) + 2.1(N+1 回归) + 1.1(校验) + 0.1(migration 兼容) + 4.1(per-tenant seed) ✅
- 数据迁移（spec 第 10 节）→ 0.1(migration 1) + 4.1(migration 2 seed) ✅
- UI 占位（spec 第 11 节）→ 1.2(标签占位) + 3.2(AA分摊/同商户/预算占位) + 投资市值复用 account_detail ✅

**2. Placeholder scan**：无 TBD/TODO；migration 日期用具体 `20260620`（实施日，可调）；每任务有具体文件路径 + 接口签名 + TDD 步骤 + 关键代码 ✅

**3. Type consistency**：
- `FindByAccountType(tenantID, AccountType)` 在 0.2 定义，1.2/4.2 复用 ✅
- `TransactionRepository` 方法签名在 0.5 定义，各切片复用 ✅
- `MonthlySummary`/`DailyItem` 在 5.1 定义，5.2 复用 ✅
- `ResponsiveLayout({mobile,tablet,desktop})` 在 0.6 定义，各 page 复用 ✅

**Gap 修复**：无遗漏。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-19-transaction-module-redesign.md`. 切片 0–6 共 18 任务，每任务 TDD 5–6 步。
