# 御财账户详情对齐原型 · 实现计划

- **日期**: 2026-06-23
- **状态**: 待确认 → 转执行
- **范围**: 账户详情页对齐 OD v2 原型（近期交易真实样式 + 日/月/年周期切换 + 交易时间 HH:MM）
- **分支**: accounts-prototype-align（延续）
- **原型**: OD 项目 `yucai-account-prototype-65e6/detail-account.html`（已补画确认）

> **For agentic workers:** 用 superpowers:subagent-driven-development 执行。每任务一个全新实现子代理 + 两阶段审查（规格 + 质量）。任务扁平编号 1-14，task-brief N 提取 Task N。

## Goal

把账户详情页对齐 OD v2 原型，交付三块能力：
1. **交易时间**：Transaction 全链路新增 `transaction_time`，交易行显示 `MM-DD HH:MM`
2. **周期切换**：TransactionSummary 全链路支持 日/月/年 scope，stat 4 卡 + 饼图 + 圆心 + 图例联动
3. **视觉对齐**：近期交易真实行样式（分类 icon + 名称 + 分类·账户 + 金额 + 日期时间）+ 双色饼图（收入绿/支出红）+ stat 卡 icon/实时 tag

## 现状（Explore 结论）

- **服务端 TransactionSummary 锁死「月」**：proto `TransactionSummaryRequest{year, month, account_id}` + `monthRange` + SQL `substr(...,1,10)` 按日分组。无 scope/day。
- **Transaction 无时间字段**：只有 `transaction_date`（日期）+ `created_at`（入库时刻）。无交易发生时刻。
- **客户端全链路锁死「月」**：`LoadSummaryRequested{year, month, accountId}` + repo `summary(year, month, {accountId})` + `MonthlySummary` DTO。
- **account_detail_page 已有结构**：`_hero/_heroFields/_statsRow/_statsFor/_recentTxnPanel/_recentTxnRow/_summaryPanel/_DonutPainter/_infoCard`，但无周期切换、近期交易行紧凑无时间、饼图按分类多色（非收入/支出双色）。
- **Account entity 字段齐全**：Hero/字段网格用到的字段已存在（currentBalanceCents/interestRate/creditLimitCents/loanOriginalCents/investMarketValueCents/goldQuantity...）。

## Architecture（全链路，三切片顺序执行避免 proto 冲突）

```
切片 1（Task 1-5）交易时间字段   proto TransactionDTO.transaction_time
                                  → server ent/schema + migration + domain + DTO + handler + 用例
                                  → client proto stub + entity + mapper + 表单时间输入
切片 2（Task 6-9）周期 scope     proto TransactionSummaryRequest.Scope enum + day + Summary 泛化
                                  → server domain SummaryScope + scopeRange + SQL 粒度 + service/handler
                                  → client event + repo + MonthlySummary DTO + bloc
切片 3（Task 10-14）详情页前端   account_detail_page：周期 segmented control + scope state
                                  stat/饼图/hero 按 scope 动态 + 近期交易真实行(含时间) + 双色饼图
```

切片 1→2→3 顺序（Task 1-5、6-9 都改 `transaction.proto`，顺序避免冲突；Task 10-14 依赖 1+2 的数据能力）。

## Tech Stack

Go server（ent + sqlx raw SQL + gRPC）+ Flutter client（flutter_bloc + 御财 token app_design.dart）。TDD（server Go test + client widget/unit test）。

## Global Constraints（binding，逐字遵循）

- **御财 token**：奶油白 #f7f6f2 / 卡片白 #ffffff / 御财金 #b08d57 / 深色 #1c1e21（hero 渐变 #1c1e21→#2a2d33 + 金色 radial-glow accent #b08d57 alpha 0.18）/ 收入绿 #2d8a6e / 支出红 #c4544d / 边框 #e6e3dc / 圆角 sm 10px lg 14px / 标题 serif(Georgia,'Noto Serif SC') / 数字 mono+tabular-nums
- **account-as-category**：分类 = Expense/Income 账户。近期交易行分类 = entries 里 Expense/Income 账户；资产账户 = Asset 账户（复用 P0 转账双账户 entries 解析逻辑）
- **硬编码中文**（yucai 无 i18n，account 模块模式）
- **TDD**：每任务先失败测试 → 实现 → 通过 → commit
- **路径**：server `yucai/server/`，client `yucai/client/`
- **Rust 编码标准不适用**（本 plan 是 Go + Flutter，非 Rust）
- **金额**：INTEGER cents，mono+tabular-nums，负数红/正数绿

---

## 切片 1：交易时间字段（全链路，Task 1-5）

### Task 1: server ent schema + migration

**Files**:
- Modify: `yucai/server/internal/transaction/ent/schema/transaction.go`（加 `field.Time("transaction_time").Optional().Nillable().Default(time.Now)`）
- New: `yucai/server/migrations/NNNNNN_transaction_time.sql`（`ALTER TABLE transactions ADD COLUMN transaction_time TIMESTAMPTZ;` + `UPDATE transactions SET transaction_time = transaction_date WHERE transaction_time IS NULL;` 回填）

**Interface**:
- ent schema 加 `transaction_time`（Optional Nillable Default time.Now）
- `go generate ./...` 重新生成 ent（确认 ent 实体 + 查询生成 transaction_time 字段）

**Steps**:
- [ ] 写迁移 SQL（加列 + 回填 transaction_date → transaction_time，旧数据不 null）
- [ ] ent schema 加字段，`go generate` 重生成
- [ ] `cd src-tauri` 不适用；`cd yucai/server && go test ./...` 现有 transaction 测试不回归
- [ ] commit

**Interface for next task**: ent 生成的 Transaction 实体含 `TransactionTime *time.Time`。

### Task 2: server domain + DTO + proto TransactionDTO

**Files**:
- Modify: `yucai/server/internal/transaction/domain/entity.go`（Transaction 加 `TransactionTime *time.Time`）
- Modify: `yucai/server/internal/transaction/application/dto.go`（TransactionDTO 加 TransactionTime）
- Modify: `yucai/proto/transaction/v1/transaction.proto`（`TransactionDTO` 加 `string transaction_time = 8;` RFC3339 可选）
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`（ent ↔ domain 映射加 transaction_time）
- Modify: gRPC handler（TransactionDTO 序列化 transaction_time；null 时省略）

**Interface**:
- proto `TransactionDTO.transaction_time`（string RFC3339 "2026-06-05T19:20:00Z"，可选）
- domain `Transaction.TransactionTime *time.Time`
- `make proto`（或 buf generate）重新生成 server + client stub

**Steps**:
- [ ] proto 加字段，buf generate
- [ ] domain + DTO + repo 映射（ent TransactionTime ↔ domain）
- [ ] handler 序列化（nil 时省略字段）
- [ ] server test：CreateTransaction（带或不带 transaction_time）→ GetTransaction 返回一致
- [ ] commit

### Task 3: server 用例接受 transaction_time

**Files**:
- Modify: `yucai/server/internal/transaction/application/service.go`（Record/SimpleIncome/SimpleExpense/SimpleTransfer 入参加 `transactionTime *time.Time`，nil → time.Now；写库时设 transaction_time）
- Modify: proto Request messages（RecordTransactionRequest/SimpleIncomeRequest/SimpleExpenseRequest/SimpleTransferRequest）加 `string transaction_time` 字段
- Modify: gRPC handler（解析入参 RFC3339 → time.Time）

**Interface**: 用例签名 `(ctx, tenantID, ..., transactionTime *time.Time)`；nil 默认 time.Now。

**Steps**:
- [ ] proto Request 加字段 + buf generate
- [ ] service 用例 + handler 解析
- [ ] server test：SimpleExpense 带 transaction_time → 落库一致；不带 → 默认 now
- [ ] commit

### Task 4: client entity + mapper

**Files**:
- Modify: `yucai/client/lib/transaction/domain/entities/transaction_entity.dart`（加 `final DateTime? transactionTime;`）
- Modify: `yucai/client/lib/transaction/data/mappers/transaction_mapper.dart`（DTO.transactionTime → entity，RFC3339 解析）
- 前置: proto stub 重新生成（`cd yucai/client && dart run build_runner build --delete-conflicting-outputs` 或项目既定 protoc 命令）

**Interface**: TransactionEntity 加 `transactionTime`（DateTime?）；mapper 解析 RFC3339。

**Steps**:
- [ ] 生成 client proto stub（含 transaction_time）
- [ ] entity + mapper
- [ ] client unit test：DTO→entity 保留 transactionTime；null → null
- [ ] commit

### Task 5: client 交易表单加时间输入

**Files**:
- Modify: `yucai/client/lib/transaction/presentation/pages/transaction_form_page.dart`（日期选择器旁加时间选择器 `TimeOfDay`，默认当前时刻；提交时拼装 transaction_time RFC3339）

**Interface**: 表单 state 加 `TimeOfDay? _time`（默认 TimeOfDay.now）；提交时 date + time → DateTime → RFC3339 传 RPC。

**Steps**:
- [ ] 写失败 widget test：选时间 → 提交 → RPC request 携带 transaction_time
- [ ] 实现：日期 + 时间选择器 UI（时间默认当前）
- [ ] 提交拼装 transaction_time
- [ ] test 通过 + `flutter analyze` + commit

**切片 1 完成标志**: 记一笔可选时间，落库 + 返回一致，client entity 携带 transactionTime，表单可选时间。

---

## 切片 2：周期 scope（全链路，Task 6-9）

### Task 6: proto Scope enum + server domain SummaryScope

**Files**:
- Modify: `yucai/proto/transaction/v1/transaction.proto`（加 `enum Scope { SCOPE_UNSPECIFIED=0; DAY=1; MONTH=2; YEAR=3; }`；`TransactionSummaryRequest` 加 `Scope scope = 4;` + `int32 day = 5;`）
- Modify: `yucai/server/internal/transaction/domain/repository.go`（`SummaryScope` 加 `Scope Scope` + `Day *int`；定义 `type Scope int` 常量 ScopeDay/ScopeMonth/ScopeYear）
- buf generate（server + client stub）

**Interface**:
- proto enum Scope（DAY=1/MONTH=2/YEAR=3，UNSPECIFIED=0）
- domain `SummaryScope{TenantID, Year, Month, Day *int, Scope Scope, AccountID *uuid.UUID}`

**Steps**:
- [ ] proto enum + 字段 + buf generate
- [ ] domain SummaryScope + Scope 类型 + 常量
- [ ] server compile 通过
- [ ] commit

### Task 7: server repo scopeRange + SQL 粒度

**Files**:
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`
  - `monthRange(year, month)` → `scopeRange(scope, year, month, day)` 返回 `[start, end)` 窗口：DAY=[当日0点, 次日0点)；MONTH=[月初, 下月初)；YEAR=[年初, 下年初)
  - SQL 日期截取表达式按 scope：DAY → 单值（不分组，该日汇总）；MONTH → `substr(CAST(t.transaction_date AS TEXT),1,10)` 按日（现状）；YEAR → `substr(...,1,7)` 按月
  - `TransactionSummary` 方法接受 SummaryScope（含 Scope/Day）

**Interface**: `scopeRange(Scope, year, month, day *int) (start, end time.Time, err error)`；SQL 截取 map：DAY→""（单值）/MONTH→"substr(...,1,10)"/YEAR→"substr(...,1,7)"。

**Steps**:
- [ ] 写失败 test：scopeRange 三 scope 窗口正确（DAY/MONTH/YEAR 边界）
- [ ] scopeRange 实现 + test 通过
- [ ] SQL 改造（scope → 截取表达式；DAY 单值时 GROUP BY 单桶）
- [ ] server integration test：DAY/MONTH/YEAR 三 scope 聚合正确（构造跨日/跨月交易验证分组）
- [ ] commit

### Task 8: server service + handler

**Files**:
- Modify: `yucai/server/internal/transaction/application/service.go`（`TransactionSummary` 签名加 `scope domain.Scope, day *int`）
- Modify: gRPC handler（解析 req.Scope/req.Day → domain.Scope/Day，传 service；DAY 时 day 必填 1-31 校验；scope 默认 MONTH）

**Interface**: service `TransactionSummary(ctx, tenantID, year, month, day *int, scope Scope, accountID)`；handler 校验 + 透传。

**Steps**:
- [ ] service 签名 + 透传 scope/day
- [ ] handler 校验（DAY 时 day 必填；scope 默认 MONTH）
- [ ] server test：handler 三 scope 端到端（DAY 带 day / MONTH / YEAR）
- [ ] commit

### Task 9: client event + repo + DTO + bloc

**Files**:
- Modify: `yucai/client/lib/transaction/presentation/bloc/transaction_event.dart`（`LoadSummaryRequested` 加 `SummaryScope scope` + `int? day`；定义 client `enum SummaryScope { day, month, year }`）
- Modify: `yucai/client/lib/transaction/domain/repositories/transaction_repository.dart`（`summary` 签名加 `SummaryScope scope` + `int? day`）
- Modify: `yucai/client/lib/transaction/domain/value_objects.dart`（`MonthlySummary` 加 `SummaryScope? scope` 标识返回粒度，向后兼容默认 month）
- Modify: data mapper / remote ds（RPC 传 scope/day；proto enum 映射）
- Modify: `transaction_bloc.dart`（`_fetchSummary` 传 scope/day）

**Interface**: `LoadSummaryRequested{year, month, accountId, scope, day}`；repo `summary(year, month, {accountId, scope, day})`。

**Steps**:
- [ ] 生成 client proto stub（含 Scope enum）
- [ ] event/repo/DTO/mapper/bloc 全链路
- [ ] client unit test：bloc 发 LoadSummaryRequested(scope: year) → repo 收到 scope=year
- [ ] commit

**切片 2 完成标志**: TransactionSummary RPC 三 scope 返回正确聚合，client bloc 能按 scope 请求。

---

## 切片 3：详情页前端对齐（Task 10-14，依赖切片 1+2）

### Task 10: 周期切换 segmented control + scope state

**Files**:
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`
  - `_AccountDetailPageState` 加 `SummaryScope _scope = SummaryScope.month`（默认月）+ `int? _day`（DAY scope 时 = today）
  - `_summaryPanel` panel-head 加 segmented control（日/月/年，御财 token：bg #f7f6f2 + 边框 #e6e3dc + active 白底 + accent-press 金字 #98773f）
  - 切换 → setState `_scope` + 发 `LoadSummaryRequested(scope, year, month, day)` 重载

**Interface**: `_scope` state；切换触发 `_refreshTxn(scope)` 发 LoadSummaryRequested。

**Steps**:
- [ ] 写失败 widget test：点「年」→ 发 LoadSummaryRequested(scope: year)
- [ ] 实现 segmented control（日/月/年三段）+ state + 切换重载
- [ ] test 通过
- [ ] commit

### Task 11: stat 4 卡 + hero 文案按 scope 动态

**Files**:
- Modify: `account_detail_page.dart` `_statsFor` / `_hero`
  - label 按scope：「本日/本月/本年 收入/支出/净流入/交易」
  - 储蓄类 4 卡数据来自 summary（scope-scoped，切片 2 后自动对）

**Interface**: `_statsFor` label 用 `_scope` 决定前缀（本日/本月/本年）；`_hero` 副信息「本月收支」→ 按 scope。

**Steps**:
- [ ] 写失败 widget test：scope=year 时 stat 卡显示「本年收入」
- [ ] `_statsFor` label 按 `_scope` 动态
- [ ] `_hero` 副信息按 scope（本日/本月/本年 收支）
- [ ] test 通过 + commit

### Task 12: 近期交易真实行 + 时间

**Files**:
- Modify: `account_detail_page.dart` `_recentTxnRow`（重写）
  - 分类 icon 圆角方块（背景按收入绿 #2d8a6e / 支出红 #c4544d / 转账灰 #8a8b8f，icon 按分类）+ 交易名称（description）+ 副行（分类·账户）+ 右侧金额（正绿/负红 mono tabular-nums）+ 日期时间（`transaction_time` → `MM-dd HH:mm`，回退 `transaction_date` → `MM-dd`）
  - panel-head link「查看全部 →」（导航交易列表，account 预筛）

**Interface**: `_recentTxnRow(Transaction t, Map<String,Account> accounts)`；解析 entries 拿分类（Expense/Income 账户）+ 资产账户（Asset）。

**Steps**:
- [ ] 写失败 widget test：交易行显示 description + 分类·账户 + 金额（正绿负红）+ `06-05 09:30`
- [ ] 实现真实行（icon + 名称 + 副行 + 金额 + 日期时间）
- [ ] 解析 entries：分类 = Expense/Income 账户；资产 = Asset 账户（参考 P0 转账双账户逻辑）
- [ ] test 通过 + commit

### Task 13: 双色饼图 + 圆心净流入

**Files**:
- Modify: `account_detail_page.dart` `_summaryPanel` + `_DonutPainter`
  - 饼图从「按分类多色」改为「收入绿 + 支出红 双色」（income 弧 #2d8a6e + expense 弧 #c4544d）
  - 圆心显示净流入（`+¥X,XXX` 正绿/负红）+ label「本X净流入」
  - 图例：收入类 `¥X · NN%` / 支出类 `¥X · NN%`
  - 数据按 `_scope`（summary.incomeCents/expenseCents/netCents）

**Interface**: `_DonutPainter` 双色（incomeCents/total → 绿弧；expenseCents/total → 红弧）；圆心 net；图例 income/expense。

**Steps**:
- [ ] 写失败 widget test：饼图双色 + 圆心净流入 + 图例金额
- [ ] 改 `_DonutPainter` 双色（income 绿弧 + expense 红弧）
- [ ] 圆心 + 图例
- [ ] test 通过 + commit

### Task 14: stat 卡 icon + 实时 tag（视觉收尾）

**Files**:
- Modify: `_statsRow` / `_statsFor`（4 卡加 stat-ico 彩色方块 + icon；tag「实时」替代「待 Transaction」）

**Interface**: 4 卡 icon——收入绿 trend-up / 支出红 trend-dn / 净流入金 wallet / 交易蓝 notebook；tag「实时」。

**Steps**:
- [ ] 写失败 widget test：4 卡有 icon + tag「实时」
- [ ] 实现 stat-ico + icon + tag
- [ ] test 通过 + `flutter analyze` + commit

**切片 3 完成标志**: 详情页视觉对齐原型，周期切换联动，近期交易真实行带时间，饼图双色。

---

## Self-Review

**1. 原型覆盖**：
- 近期交易真实行（icon+名称+分类·账户+金额+时间）→ Task 12 ✅
- 日/月/年切换 → Task 10 + 切片 2 全链路 ✅
- 交易时间 HH:MM → 切片 1 全链路 + Task 12 ✅
- 双色饼图 + 圆心净流入 → Task 13 ✅
- stat 卡 icon/实时 tag → Task 14 ✅

**2. 依赖顺序**：Task 1-5（时间）→ 6-9（scope）→ 10-14（前端）。1-5 与 6-9 都改 transaction.proto，顺序执行避免冲突。10-14 依赖 1+2 数据能力。

**3. 风险**：
- ent schema 加字段 + 迁移回填（transaction_time = transaction_date）→ 旧数据不 null
- scope SQL 粒度切换 → 充分 integration test（跨日/跨月交易）
- proto 改动需 server + client 双端 buf generate 同步
- account-as-category：近期交易行分类 = Expense/Income 账户（复用 P0 Task 3 entries 解析）

**4. 范围边界**：
- 本 plan 做：交易时间 + 周期 scope + 详情页视觉对齐
- 不做：仪表盘/净资产趋势（独立页）、汇率 API（独立 spec）、移动端三尺寸优化（P1 轮次）

## Execution Handoff

Plan complete。14 任务，3 切片，顺序执行（1-5 → 6-9 → 10-14），每任务子代理 + 两阶段审查。原型参考 OD `yucai-account-prototype-65e6/detail-account.html`（已补画：近期交易真实行 + 日/月/年切换 + 双色饼图）。
