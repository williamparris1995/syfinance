# Holding 子项目 D-budget · budget actuals 接通 + 投资排除 + Flutter UI 设计

- **日期**: 2026-07-01
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: D-budget 完整(后端 actuals 接通 entryFunc + 投资双写不污染 + Flutter budget UI 完整多页 list/detail/create)
- **上游全景设计**: [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md) §7.3
- **前置**: A+B+C+D-goal+D-currency 已完成(final review Ready to merge Yes)
- **D 分解**: D-goal ✅ / D-currency ✅ / **D-budget 首批(本 spec)**

## 1. 背景与目标

御财 budget 现状(Explore 确认):
- budget 模块**已完整建好**(domain / repo / application.Service CRUD+ComputeActuals / handler / proto / main 注册),但 **actuals 是死代码**:[provideBudgetService](../../yucai/server/wire/providers.go#L287) `NewService(repo, nil)` —— entryFunc nil → `ComputeBudgetActuals` RPC 调必 nil-panic(service.go:144 `s.entryFunc(ctx,...)` 无 nil 守卫)
- `EntryTotalsFunc = func(ctx, accountID, from, to) (debitTotal, creditTotal int64, err)`, `ComputeActuals` 逐 BudgetItem 调它填 `ActualAmountCents`(存储字段, TotalActual/UsagePct/IsOverBudget 从它派生)
- **holding 双写在 handler 层**([holding_handler.go:506-527](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go#L506) `recordTradeTransaction`):Buy/Sell with fromAccount 调 `transactionSvc.RecordTransaction`(desc "Holding trade double-write")联动账户余额 → **若 actuals 简单按账户 debit 求和会污染 budget**(买股票≠消费)
-御财是 **account-as-category + 双账模型**:[TransactionType](../../yucai/server/internal/transaction/domain/repository.go#L29) Income/Expense/**Transfer**(asset→asset 自动归 transfer),expense 账户本身就是 category(餐饮/交通)
- **Flutter budget UI 完全不存在**(无路由/无页面/无 bloc)

D-budget 目标:
1. **后端 actuals 接通**:entryFunc 从 nil → 委托 `transaction.Service.SpendingByAccount`,读时算(不持久化)
2. **投资不污染**:budget item 按 **expense 账户(category)**粒度 —— transfer(asset→asset, 含 holding 双写 cash→investment)天然不涉 expense 账户 → 排除自动
3. **Flutter budget UI**:完整多页(list/detail/create),sidebar 入口

## 2. 范围边界

| 在范围(D-budget) | 不在范围(后续) |
|---|---|
| entryFunc 接通(委托 SpendingByAccount) | 多币种 budget 折算(MVP 原币相加) |
| SpendingByAccount(transaction.Service 新方法) | budget scheduler(定期重算 persist) |
| actuals 读时算(GetBudget/GetBudgetByMonth 填 DTO,不 persist) | ComputeActuals RPC 暴露(MVP 读时算, RPC 保留不暴露) |
| budget item 按 expense 账户(category) | wallet(asset 账户)预算(trace offsetting, 复杂, defer) |
| Flutter 3 页(list/detail/form)+ sidebar 入口 | bottom nav 入口(避免 7 拥挤) |
| account picker 只列 expense 账户(自动排除投资/wallet) | budget 模板/复用(CloneBudgetToMonth 已有, UI defer) |
| budget CRUD 接真(现有 CreateBudget/DeleteBudget/AddItem/RemoveItem RPC) | 跨 category 预算(组合 category) |

## 3. 架构总览

```
Flutter 预算 UI(BudgetListPage / BudgetDetailPage / BudgetFormPage)
   ↳ proto budget/v1 RPC
budget handler → application.Service
   ↳ GetBudget / GetBudgetByMonth / ListBudgets:读后逐 item 用 entryFunc 算 ActualAmountCents 填 DTO(不持久化)
   ↳ entryFunc: nil → 委托(闭包 over transaction.Service)
transaction.Service.SpendingByAccount(ctx, accountID, from, to) → (debit, credit, err)
   ↳ Σ DebitCents / CreditCents of TransactionEntry where account=accountID, date∈[from,to]
   ↳ budget item 是 expense 账户 → transfer(asset→asset)天然不涉 → holding 双写自动排除
```

**核心简化(account-as-category)**:budget item 粒度 = expense 账户(= category 如餐饮)。Transfer 是 asset→asset 流, **从不 touch expense 账户**, 故"排除转账/投资"是模型自带的, 不需 SpendingByAccount 里加 transfer 过滤逻辑。holding 双写(cash asset → investment asset)是 transfer → 不进任何 expense 账户 → budget actuals 不受污染。

**跨模块 port(函数注入, 照 D-goal/D-currency 模式)**:budget 不 import transaction;wire 在 provideBudgetService 注入一个闭包 `(ctx, acc, from, to) => txnService.SpendingByAccount(ctx, acc, from, to)`,精确匹配 `EntryTotalsFunc` 签名。

## 4. server 改动

### 4.1 transaction.Service.SpendingByAccount(新方法)
位置:`internal/transaction/application/service.go`。
```go
// SpendingByAccount returns the debit/credit totals of entries posted to
// accountID in [from, to]. Used by budget actuals (budget items track Expense
// accounts = categories; transfers are asset→asset and never touch Expense
// accounts, so they are excluded automatically — no explicit filter needed).
func (s *Service) SpendingByAccount(ctx context.Context, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)
```
- 实现:复用 entry 查询(Task 0 确认 repo 是否已有 `SumEntryTotalsByAccount(accountID, from, to)` 或加一个),Σ DebitCents / CreditCents。
- 签名**精确匹配 budget.EntryTotalsFunc**(无缝委托)。
- 不需 transfer 过滤(budget item = expense 账户, transfer 天然不涉);若 Task 0 发现需防御性 `Type != Transfer` 也可加,但语义冗余。

### 4.2 budget entryFunc 接线
[wire/providers.go:287](../../yucai/server/wire/providers.go#L287):
```go
// before: provideBudgetService(repo) → NewService(repo, nil)
// after:
func provideBudgetService(repo *budgetrepo.BudgetRepository, txnSvc *txnapp.Service) *budgetapp.Service {
    return budgetapp.NewService(repo, func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
        return txnSvc.SpendingByAccount(ctx, accountID, from, to)
    })
}
```
- wire_gen.go 手改(镜像 D-currency/B/C/D-goal, 见 [[yucai-wire-handmaintained]]):provideBudgetService 加 txnSvc 参数 + 声明顺序(budgetService 在 transactionService 之后)。
- budget application 不 import transaction(函数注入, port 模式)。

### 4.3 actuals 读时算(不 persist)
[budget/application/service.go](../../yucai/server/internal/budget/application/service.go):GetBudget / GetBudgetByMonth / ListBudgets 读后, 逐 item 调 entryFunc 算 ActualAmountCents 填进返回 DTO(**不调 IncrementVersion / repo.Update**, 避每次 view version 抖 + stale):
- entryFunc nil(测试/未接线)→ actuals 降级 0 + 不 panic(加 nil 守卫: `if s.entryFunc != nil { ... }`)
- entryFunc err → 该 item actuals 降级 0 + 日志(best-effort, 照 net-worth)
- ComputeActuals(persist 变种)保留作 future 显式刷新;**MVP handler 不暴露 ComputeBudgetActuals RPC**(或保留但 UI 不调)

### 4.4 proto
budget proto 现有 RPC 全(CreateBudget / GetBudget / GetBudgetByMonth / ListBudgets / DeleteBudget / AddBudgetItem / RemoveBudgetItem / ComputeBudgetActuals)。Task 0 确认:
- `BudgetItemDTO` 含 `actual_amount_cents` 字段(填读时算值)
- `BudgetDTO`/`BudgetDetailDTO` 含 `total_actual_cents` / `usage_pct` / `total_remaining_cents`(派生, 或 client 算)
- 若缺, 补字段 + 重生成 Go/Dart stub(`make gen-dart`, protoc_plugin 25.0.0, 见 [[yucai-dev-env]])

## 5. schema 改动

**零新表/字段**。复用 `budgets` + `budget_items`(ActualAmountCents 已有)+ `transaction_entries`。Budget 模型 = per-month 单币种(CurrencyCode)+ per-expense-account items。

## 6. Flutter 改动(DDD 四层, 照 debt/holding 范式)

### 6.1 数据层
- `BudgetRemoteDataSource`(GrpcClient + AuthRetryCaller, 对齐 HoldingRemoteDataSource)→ proto budget RPC
- `BudgetRepositoryImpl` + domain `BudgetRepository` interface
- `BudgetView` entity(Equatable: id/name/month/currency/totalPlanned/items[], item = {accountId, accountName, planned, actual, notes})
- `BudgetBloc`:LoadListRequested / LoadDetailRequested / CreateBudgetRequested / UpdateBudgetRequested / DeleteBudgetRequested / AddItemRequested / RemoveItemRequested

### 6.2 三页面
1. **BudgetListPage** `/budgets` —— 月份切换(← 2026-07 →)+ 月度预算卡片 list(每卡:Name + 总进度环 + TotalActual/TotalAmount + UsagePct% + 超支红/正常绿)+ AppBar"新建" → push `/budgets/new`
2. **BudgetDetailPage** `/budgets/:id` —— 头(Name + Month + 总进度环 + Remaining + UsagePct)+ per-item 列表(category 账户名 + Planned + Actual + 进度条 + 占比% + 剩余 + 超支标记)+ 编辑/加/删 item
3. **BudgetFormPage** `/budgets/new` + `/budgets/:id/edit` —— Name + Month(YYYY-MM picker) + CurrencyCode + Items 编辑(**account picker 只列 expense 账户**, 排除投资/wallet + PlannedAmountCents + notes, 增删 item)

### 6.3 导航
- **仅 sidebar entry"预算"**(不进 bottom nav, 避免 7 目的地拥挤, 见 holding Minor)
- router.dart 加 `/budgets` 分支(branch 6, 子路由 `/new` `/:id` `/edit` 静态在 `/:id` 前, 照 holdings 路由模式)
- app_shell sidebar 加"预算"入口(lucide `wallet` icon)

### 6.4 复用
- 御财设计语言(金 #b08d57 / 衬线 / 米白, lucide icon, 同 holding UI)
- budget 单币种:显示用 budget.CurrencyCode 符号(不做 net-worth 多币种聚合)
- Account picker:复用 ListAccounts, 客户端 filter `accountType == expense`(category 账户)

## 7. 失败/降级策略
| 场景 | 处理 |
|---|---|
| SpendingByAccount err(单 item) | 该 item actuals 降级 0 + 日志, 不中断其他 item(照 net-worth best-effort) |
| entryFunc nil(未接线/测试) | actuals 全 0 + 不 panic(nil 守卫) |
| 无 transaction_entries | actuals=0, 进度 0%(正常空态) |
| proto 缺 actuals 字段 | Task 0 确认, 缺则补 + regen stub |
| budget 无 item | domain 已禁(NewBudget 要求 ≥1 item);UI 显示空态引导创建 |
| RPC fail | list/detail 错误态(非崩溃) |

## 8. 测试策略(全程 TDD)
- **server transaction**: SpendingByAccount 单测(expense 账户 debit 求和 / 日期范围 / 跨 tenant 隔离 / 空 / holding 双写 txn 不涉 expense 账户验证)
- **server budget**: entryFunc 委托(mock SpendingByAccount) + GetBudget/GetBudgetByMonth 读时算 actuals 填 DTO + nil entryFunc 降级 + err 降级 + CRUD 回归(现有测不破)
- **server e2e**(我自做, 无 commit):grpcurl CreateBudget(餐饮 category, ¥2000)+ 记一笔餐饮支出 ¥500 + GetBudget 验 actuals=500;buy holding(cash→investment)+ GetBudget 验 actuals 仍 500(投资不污染)
- **Flutter**: BudgetListPage(月份切换/进度环/超支色) + BudgetDetailPage(per-item 进度条/占比) + BudgetFormPage(创建 + account picker 只列 expense 账户) + bloc(ds/repo mapper, 照 holding 套件)

## 9. 前置验证(Task 0)
- **Read transaction entry repo**:确认是否已有 `SumEntryTotalsByAccount(accountID, from, to)` 或需新增(Task 4.1 实现依赖)
- **Read budget proto DTO**:确认 BudgetItemDTO/BudgetDTO 是否含 actuals/usage 字段(Task 4.4 依赖)
- 确认 AccountType 枚举有 `expense`(account picker 过滤依赖)
- 确认 router.dart branch 结构(照 holdings branch 5 模式加 branch 6)

## 10. 实施顺序建议(供 writing-plans, ~12-14 task)
```
1. transaction.Service.SpendingByAccount(+ entry repo sum-by-account, Task 0 确认)+ 单测
2. budget actuals 读时算(GetBudget/GetBudgetByMonth/ListBudgets 填 DTO + nil/err 降级)+ 单测
3. wire + main budget entryFunc 接线(provideBudgetService 注入 txnSvc 闭包 + wire_gen 手改)
4. server e2e 验证(actuals 接通 + 投资不污染)
5. budget proto 字段确认/补 + Go/Dart stub regen(若需)
6. Flutter data 层(BudgetRemoteDataSource / Repository / BudgetView entity)
7. Flutter domain/bloc(BudgetBloc + events/states)
8. Flutter BudgetListPage(月份切换 + 卡片 list + 进度环)
9. Flutter BudgetDetailPage(per-item 进度 + 占比 + 超支)
10. Flutter BudgetFormPage(创建/编辑 + account picker 过滤 expense)
11. router + app_shell sidebar 入口(branch 6)
12. 全链路 + final review
```

## 11. 决策记录(用户拍板)
| # | 决策 | 选定 |
|---|---|---|
| D-budget 范围 | 后端 only / UI only / 全栈 | **全栈一轮**(后端 actuals + UI MVP 完整多页) |
| ① actuals 语义 | 支出排转账 / 所有 money-out / 净流出 | **支出排转账**(后由 ④ 简化为按 expense 账户, 转账自动排除) |
| ② 后端架构 | adapter 内联 / transaction 暴露 / schema 打标 | **transaction.Service.SpendingByAccount**(budget 委托, port 模式) |
| ③ UI 形状 | 精简单页 / 完整多页 / 只读 | **完整多页**(list/detail/create) |
| ④ budget item 粒度 | category(expense 账户) / wallet(asset) / 两者 | **category(expense 账户)** —— account-as-category 模型下转账/投资天然排除, 最干净 |
| ⑤ 导航入口 | 仅 sidebar / sidebar+bottom nav / 重构 | **仅 sidebar**(不进底栏, 避免 7 拥挤) |
| ⑥ 投资账户 | 过滤 / 允许 | **过滤**(被 ④ 包含: picker 只列 expense 账户, 投资/wallet 自动排除) |
| ⑦ actuals trigger | 读时算 / ComputeActuals persist | **读时算**(不 persist, 避 version 抖);RPC 保留不暴露 |
| ⑧ 多币种 budget | 折算 / 原币相加 | **原币相加**(defer 折算) |

## 12. 风险清单(plan 需显式处理)
1. **entry repo sum-by-account 方法**(Task 0 确认存在或新增)—— SpendingByAccount 实现依赖
2. **budget proto actuals 字段**(Task 0 确认)—— 缺则补字段 + regen Go/Dart stub
3. **wire_gen 手改**(provideBudgetService 加 txnSvc 参数 + 声明顺序, 镜像 D-currency;见 [[yucai-wire-handmaintained]])
4. **budget item 粒度 = expense 账户**(account picker 客户端过滤 `accountType==expense`;若误允许 asset 账户, actuals 语义错 —— UI 层硬过滤)
5. **actuals 读时算性能**(ListBudgets N 预算 × M item × SpendingByAccount 查询;MVP N 小可接受, 优化 defer)
6. **多币种**(budget.CurrencyCode vs expense 账户 currency 不一致;MVP 原币相加不折算, UI note)

## 13. 参考
- budget 现状:[service.go ComputeActuals:135](../../yucai/server/internal/budget/application/service.go#L135) + [entryFunc nil providers.go:287](../../yucai/server/wire/providers.go#L287)
- holding 双写:[holding_handler.go recordTradeTransaction:506](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go#L506)
- account-as-category 模型:[TransactionType repository.go:29](../../yucai/server/internal/transaction/domain/repository.go#L29)(Transfer = asset→asset)
- D-currency port 模式:[networth 模块](../../yucai/server/internal/networth/application/service.go)(函数注入, 不 import 消费模块)
- 相关:[[yucai-wire-handmaintained]] [[yucai-dev-env]] [[od-prototype-to-flutter]]
