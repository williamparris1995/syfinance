# Receivables 模块全量对齐 OD 原型 — Design Spec

**Date**: 2026-07-03
**Branch**: `holding-asset-management`
**Status**: design(待 plan)
**OD 原型**: `yucai-receivables-prototype-558f`(9 HTML:list/detail/form × desktop/tablet/mobile)
**Flutter 现状**: `yucai/client/lib/debt/presentation/pages/{receivables,receivable_detail,receivable_form}_page.dart`

## Goal

将 receivables 模块三页(list / detail / form)从当前实现**全量对齐 OD 原型**。视觉差距已通过 visual companion side-by-side 与用户确认(2026-07-03)。为支撑 OD 信息密度,需配套后端扩展(新字段 + 历史快照 + summary RPC);**trend 采用行业最佳实践 = 点-in-time 历史快照**(照御财 `holding_snapshot` / `goal_progress_snapshot` 既有模式),而非实时算上月。

## Background — 差距清单(visual companion 已确认)

### List 页(4 项,纯 UI + DTO 扩)
- **L1**(High):44px avatar tile(债务人首字,类型色 gold/blue/green/other-gray)缺失 — 卡片以 plain counterparty 文字开头。
- **L2**(High):4-card stat strip(笔数 / 已收本息 green / 待收利息 / 逾期应收 red)完全缺失。
- **L3**(High):卡片改横向 4-col row(avatar|amt|prog|meta2)+ foot「下次收款 第N期 ¥X 逾期N天」callout + 收款 CTA。现 Flutter 是竖向堆叠卡。
- **L4**(Medium):overview 加 trend「较上月 +¥X」+ 待收利息 breakdown + 下次收款 callout(带 CTA)+ 筛选加「逾期」4-seg。

### Detail 页(4 项,纯 UI + entity 已有数据)
- **D1**(High):hero 改双列 — 50px avatar + delta pill「↓¥X 较上月减少 · 已收 N/M 期」+ 右侧 4-tile(年利率/月供/到期日/已收期数)。现 hero 单列、无 avatar/delta/side。
- **D2**(High):5-stat 改**金额汇总维度**(借出本金 / 已收合计 green / 待收合计 / 累计利息 green / 逾期 red)。现是元数据维度(利率/到期/摊还/已收期数)。**信息维度实质性不同**。
- **D3**(High):右侧 side panel(收款账户卡 + 借款信息卡:债务人/联系方式/借出/到期/摊还/合同借据)整个缺失。需新字段 `contact` + `contract_ref`。
- **D4**(High):确认收款改 OD 行内 link-btn 直接确认 → toast。需持久化 `collection_account_id`(DebtDTO 现不存收款账户,故现状弹 dialog 选)。真·行内确认。

### Form 页(2 项,纯 UI + 新字段输入)
- **F1**(Medium):类型 / 摊还方法 `_RadioChip` 纯文字 → OD radio cards(32px icon tile + 摊还加描述副标题)。
- **F2**(Medium):预览 tags → OD `pv-sum` 2×2 大数字 grid(月供 / 总利息 green / 期数 / 总还款)。
- form 加 `contact` + `contract_ref` + `collection_account_id` 输入(D3/D4 配套)。

## Architecture

跨前后端改动:

```
server(Go DDD)
  proto/debt/v1/debt.proto         DebtDTO 加 6 字段 + CreateDebt/UpdateDebt 加 3 字段 + 新 GetReceivablesSummary RPC
  internal/debt/ent/schema         debt 加 3 字段(contact/contract_ref/collection_account_id)+ 新 debt_progress_snapshot 表
  internal/debt/domain             DebtDetails 加 3 字段 + NewDebtDetails 签名扩 + DebtProgressSnapshot entity
  internal/debt/application        repo 读写新字段 + DebtToDTO 填 next_payment_* + GetReceivablesSummary + SyncAllDebts(scheduler 算子)+ SnapshotRepo
  internal/debt/scheduler          DebtScheduler(照 goal/holding scheduler 模式,第 5 个 scheduler)
  internal/debt/adapter/driving   GetReceivablesSummary handler
  wire/providers.go + wire/wire_gen.go(手改)  summary handler + scheduler 接线

client(Flutter DDD)
  lib/proto/debt/v1/               stub regen(protoc_plugin 25.0.0)
  lib/debt/domain/entities         Debt 加 6 字段 + ReceivablesSummary entity
  lib/debt/data/                   mapper 填新字段 + ReceivablesSummaryDataSource/Repo
  lib/debt/presentation/pages      receivables_page(L1-L4)+ receivable_detail_page(D1-D4)+ receivable_form_page(F1-F2 + 3 字段输入)
  lib/debt/presentation/widgets    新 _ReceivableCard(avatar/row/foot)/_StatStrip/_RadioCard/_PreviewSum(或复用升级现有)
```

## Tech Stack
- Go:ent + grpc + slog + wire(手改 wire_gen)
- proto3(buf generate Go + `make gen-dart` Dart,**protoc_plugin 25.0.0**)
- Flutter:flutter_bloc + injectable + lucide_icons + 御财设计语言(gold #b08d57 / serif / cream)

## Global Constraints(御财)
1. **分支** `holding-asset-management`(当前主 checkout,不新建 worktree)
2. **schema 用 ent**(非 SQL migration files);`go generate ./internal/debt/...` 重生成
3. **wire 手改** `wire_gen.go`(工具链坏,见 memory `yucai-wire-handmaintained`):新 provider 声明在依赖方之后
4. **proto regen** Go + Dart 都要(protoc_plugin 25.0.0,Dart 21.x 生成 protobuf 4.x 旧 API → analyze 暴增)
5. **interface 加方法 → grep 全 implementer(含 test fake)**;implementer 跑**全量 suite**(非 scoped,否则跨包 fake 漏改致 build fail — 照 D-budget Task1 教训)
6. **English 结构化日志**(slog,无 CJK 在 log 串)
7. **复用第一**:snapshot 表照 `goal_progress_snapshot`;scheduler 照 `goal SyncAllGoals`;avatar/badge 照 receivables 现有 `_Badge`/`_inferBadge` 升级
8. **路由优先级**:静态 `/new` `/edit` 在 `/:id` 前(receivables 路由已接入,不改)
9. **flutter analyze 基线 22 error**(全 pbserver)+ 3 预存 fail(account/debt/transaction_detail_page,非本 spec 引入)
10. **每 task commit**(中文 conventional `feat(holding-receivables-...): ...`)
11. **多币种 — 不硬编码符号/币种字符串**(用户强调):所有货币显示走 `currencySymbol(code)`(禁裸 `¥`/`$`);币种字符串走变量(preferred / Debt.currencyCode / 集中常量 `kBaseCurrency`),禁散落 `'CNY'` 硬编码。summary/snapshot/trend 金额折算到 preferred(复用 D-currency `convertToBase` / rate 基础设施)。**Debt 当前无 currencyCode(假设 CNY)**:实现用 `toPreferredCents(cents, debt.currencyCode ?? 'CNY', rates, preferred)` 为未来多币种留口,集中常量不散落;snapshot 存原币 cents(server trend 按原币算),client 折算 preferred 显示。

---

## A. 后端扩展(server)

### A1. proto `yucai/proto/debt/v1/debt.proto`(append-only,无字段号冲突)

**DebtDTO** 加 6 字段(现有 1-14):
```proto
message DebtDTO {
  // ... 1-14 现有(id/account_id/counterparty/interest_rate/amortization_method/
  //        start_date/due_date/total_principal_cents/remaining_principal_cents/
  //        version/created_at/updated_at/debt_type/subtype)...
  string contact = 15;                    // 债务人联系方式(receivable 用,borrowIn 空)
  string contract_ref = 16;               // 合同/借据编号(receivable 用)
  string collection_account_id = 17;      // 收款入账默认账户(receivable 收回时钱进此账户;borrowIn 空)
  string next_payment_date = 18;          // 下次收款日(最早 !paid entry,server 算)
  int64 next_payment_amount_cents = 19;   // 下次收款金额
  int32 next_payment_period_no = 20;      // 下次收款期次号(1-based)
  int64 remaining_trend_cents = 21;       // 剩余应收 trend(本月 vs 上月 snapshot,负=减少;detail hero delta,server per-debt 算)
}
```

**CreateDebtRequest** 加 3 字段(现有 1-10):
```proto
message CreateDebtRequest {
  // ... 1-10 现有 ...
  string contact = 11;
  string contract_ref = 12;
  string collection_account_id = 13;   // borrowedOut 必填(收款账户);borrowedIn 忽略
}
```

**UpdateDebtRequest** 加 3 字段(现有 1-4):
```proto
message UpdateDebtRequest {
  // ... 1-4 现有(id/counterparty/interest_rate/version)...
  string contact = 5;
  string contract_ref = 6;
  string collection_account_id = 7;   // receivable 编辑可改收款账户
}
```

**新 RPC + messages**:
```proto
service DebtService {
  // ... 现有 7 RPC ...
  rpc GetReceivablesSummary(GetReceivablesSummaryRequest) returns (ReceivablesSummaryResponse);
}

message GetReceivablesSummaryRequest {}

message ReceivablesSummaryDTO {
  int64 total_principal_cents = 1;          // 总借出本金
  int64 total_remaining_cents = 2;          // 总剩余应收
  int64 total_collected_cents = 3;          // 累计已收(本金+利息)
  int64 pending_interest_cents = 4;         // 待收利息(list overview breakdown)
  int32 count = 5;                          // 在追笔数
  int32 overdue_count = 6;                  // 逾期笔数
  int64 overdue_amount_cents = 7;           // 逾期应收合计
  // trend(本月最新快照 vs 上月快照,Σ borrowedOut)
  int64 principal_trend_cents = 8;          // 总借出 trend(正=本月新增借出)
  int64 remaining_trend_cents = 9;          // 剩余应收 trend(负=本月收回)
  // 下次收款 callout(全局最早 !paid entry,跨所有 receivable)
  string next_payment_date = 10;
  int64 next_payment_amount_cents = 11;
  string next_payment_counterparty = 12;
  int32 next_payment_period_no = 13;
}
message ReceivablesSummaryResponse { ReceivablesSummaryDTO summary = 1; }
```

**RecordPaymentRequest 不改**(D4 用 `collection_account_id` 走现有 `from_account_id` 字段)。

### A2. ent schema

**`internal/debt/ent/schema/debt.go`** 加 3 nullable 字段:
```go
field.String("contact").Optional().Default(""),
field.String("contract_ref").Optional().Default(""),
field.UUID("collection_account_id", uuid.UUID{}).Optional().Nillable(),
```

**新建 `internal/debt/ent/schema/debt_progress_snapshot.go`**(照 `goal_progress_snapshot.go`):
```go
type DebtProgressSnapshot struct{ ent.Schema }

func (DebtProgressSnapshot) Fields() []ent.Field {
  return []ent.Field{
    field.UUID("debt_id", uuid.UUID{}),
    field.Time("snapshot_date"),
    field.Int64("total_principal_cents"),
    field.Int64("remaining_principal_cents"),
    field.Int64("paid_total_cents"),
    field.Time("created_at").Default(time.Now),
  }
}
func (DebtProgressSnapshot) Mixin() []schema.Mixin { return []schema.Mixin{mixin.TenantMixin{}} }
func (DebtProgressSnapshot) Indexes() []schema.Index {
  return []schema.Index{index.Unique().Fields("debt_id", "snapshot_date")}
}
```
**通用 debt 快照表(不分 borrowedIn/borrowedOut)**:scheduler 对所有 debts 快照,receivable 本次用(trend filter borrowedOut),debt 后续对齐也能用。

`go generate ./internal/debt/...` 重生成 ent client。

### A3. domain `internal/debt/domain/entity.go`

**`DebtDetails`** 加 3 字段:
```go
type DebtDetails struct {
  // ... 现有 ...
  Contact            string
  ContractRef         string
  CollectionAccountID *uuid.UUID   // nil = 未设(borrowedIn);receivable 必填
}
```

**`NewDebtDetails`** 签名加 3 参数(可选语义:空 string / nil uuid 表示未设):
```go
func NewDebtDetails(
  tenantID, accountID uuid.UUID,
  counterparty string,
  interestRate float64,
  method AmortizationMethod,
  startDate, dueDate time.Time,
  totalPrincipalCents int64,
  debtType DebtType,
  subtype string,
  contact string,                // 新(receivable 用,borrowedIn 传 ""
  contractRef string,            // 新
  collectionAccountID *uuid.UUID, // 新(receivable 必填;borrowedIn 传 nil)
) (*DebtDetails, error)
```
**关联**:`NewDebtDetails` 全 caller 适配 — 见「关联影响清单」。

**新 entity** `DebtProgressSnapshot`(id/tenant/debtID/snapshotDate/totalPrincipal/remaining/paidTotal/createdAt)+ repo 接口方法(SaveSnapshot/FindSnapshotRange/FindLatestByDebt)。

**新 port**(照 goal `AccountMarketValueSource` 模式,若 scheduler 需要):
- 复用现有 `TenantLister`(goal/holding/currency 已建,auth.TenantRepository.FindAllIDs 结构满足)。

### A4. application `internal/debt/application/`

**repo Save/FindAll/FindByID** 读写 contact/contract_ref/collection_account_id(ent 新字段)。

**`DebtToDTO`** 填新字段:
- contact/contract_ref/collection_account_id 直接映射
- `next_payment_*`:从 `schedule` 找最早 `!paid` entry(按 paymentDate 升序)→ 填 date/amountCents/periodNo(index+1);无则空/0
- 注意 `ListDebts` 也走 DebtToDTO → list 卡片 foot callout 有数据(L3 配套)

**新 `GetReceivablesSummary(ctx, tenantID)`**:
1. `repo.FindAll(tenantID, DebtTypeBorrowedOut)` 取全部债权
2. 聚合:totalPrincipal = Σ debt.totalPrincipalCents;totalRemaining = Σ debt.RemainingPrincipal();totalCollected = totalPrincipal − totalRemaining;pendingInterest = Σ schedule unpaid interest;count;overdueCount/overdueAmount = Σ (entry.overdue && !paid)
3. trend:snapshotRepo.FindLatestInRange(tenantID, 本月) vs FindLatestInRange(上月) → principal_trend / remaining_trend(Σ borrowedOut)
4. next_payment:跨所有 debt 的 schedule 找全局最早 !paid entry → date/amount/counterparty/periodNo

**新 `SyncAllDebts(ctx, tenantID) (int, error)`**(scheduler 算子,照 `SyncAllGoals`):
1. `repo.FindAll(tenantID)` 全部 debts(不分方向,通用快照)
2. per-debt:算 remaining/paidTotal → snapshotRepo.SaveSnapshot(upsert,(debt_id, snapshot_date) 唯一 → delete-then-insert 或 ent 无 OnConflict 用 per-row create→ConstraintError→update fallback,照 holding_snapshot C Task10 教训)
3. best-effort:per-debt err → skip + slog.Warn + continue
4. return count

**CreateDebt/UpdateDebt** 透传 contact/contract_ref/collection_account_id(domain.NewDebtDetails 新签名)。

### A5. handler `internal/debt/adapter/driving/grpc/debt_handler.go`

- `GetReceivablesSummary`:getTenantID → service.GetReceivablesSummary → 映射 DTO。覆盖 Unimplemented 默认(若 DebtHandler 嵌入 Unimplemented)。
- 现有 CreateDebt/UpdateDebt handler 读 req 新字段透传 service。

### A6. scheduler `internal/debt/scheduler/scheduler.go`

照 `goal/scheduler/scheduler.go` 1:1:
- 3 本地接口(DebtSyncer=SyncAllDebt / TenantLister / IntervalSource,scheduler 包不 import auth/goal)
- `NewScheduler(syncer, lister, src)`;`Start()` / `SyncNow()` / `doSync()`(FindAllIDs → per-tenant SyncAllDebts → Σ count;per-tenant err continue,照 goal)
- 复用 `tenantIntervalSource` 适配器(B/C/D-goal 已用,providers.go)

### A7. wire + main

**`wire/providers.go`**:
- `provideDebtSnapshotRepo`、`provideDebtScheduler`
- `provideDebtService` 加 snapshotRepo 参数 + `SetSnapshotRepo` setter(NewService 签名不变,照 goal SetAccountMarketValueSource 模式)
- `provideReceivablesSummaryHandler`

**`wire/wire_gen.go`**(手改):声明顺序 — snapshotRepo / debtScheduler 在 debtService 前(若 debtService 消耗);summaryHandler 在 debtService 后;`NewApp` 加 DebtScheduler 参数。

**`app.go`**:App.DebtScheduler 字段。
**`main.go`**:`go app.DebtScheduler.Start()`(在其他 scheduler 之后)。

---

## B. Client 改动

### B1. proto stub regen
- Go:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(无网 fallback 本地 protoc + 手修 `package debtv1`)
- Dart:`cd yucai && make gen-dart`(protoc_plugin **25.0.0**)
- 验证:DebtDTO 6 新字段 + CreateDebt 3 + UpdateDebt 3 + GetReceivablesSummary client 方法 + messages

### B2. `lib/debt/domain/entities/debt_entity.dart`
Debt 加 6 字段:
```dart
final String contact;                 // 默认 ''
final String contractRef;             // 默认 ''
final String? collectionAccountId;    // receivable 必填,borrowIn null
final DateTime? nextPaymentDate;
final int nextPaymentAmountCents;     // 默认 0
final int nextPaymentPeriodNo;        // 默认 0
```
+ `ReceivablesSummary` entity(Equatable,13 字段对齐 DTO)+ getters(`progressPct` 等)。

### B3. `lib/debt/data/`
- `debt_mapper.dart`:debtDtoToEntity 填 6 新字段(Int64→int .toInt(),空处理)
- 新 `receivables_summary_data_source.dart`(@LazySingleton,GrpcClient+AuthRetryCaller 自建 DebtServiceClient + `_retry`)+ `receivables_summary_repository.dart`(abstract + impl `_guard`,照 holding/budget 范式)
- build_runner 重生成 injection.config.dart

### B4. `receivables_page.dart`(L1-L4)
- **L1**:`_ReceivableCard` 头部加 44px avatar(tile —债务人首字 · 类型色:_inferBadge 已有商业蓝/亲友绿/私人金/其他 gray;**加 other gray 色**)
- **L2**:overview 下加 `_StatStrip`(4-card:笔数/已收本息 green/待收利息/逾期 red,从 ReceivablesSummary)
- **L3**:卡片改横向 4-col row(avatar+name+badge | 剩余应收 | 收回进度+已收 | meta2 利率/到期)+ foot callout(下次收款 from `Debt.nextPaymentDate/Amount/PeriodNo` + 逾期天数)+ 收款 CTA(行内,触发 detail 的 RecordPayment 或直接 dispatch)
- **L4**:overview 加 trend(`ReceivablesSummary.principalTrendCents`)+ 待收利息 breakdown(`pendingInterestCents`)+ 下次收款 callout(summary 全局 next_payment,带"查看收款计划"CTA)+ 筛选 4-seg(加「逾期」tab,_ListFilter 加 overdue 枚举)
- 数据源:initState 加载 summary(FutureBuilder 或 Bloc);列表仍 DebtBloc(LoadDebtsRequested borrowedOut)

### B5. `receivable_detail_page.dart`(D1-D4)
- **D1**:`_hero` 改双列 — 50px avatar(债务人首字 tile)+ delta pill(较上月减少,从 snapshot trend — 需 server 算 per-debt trend,见 A4 GetReceivablesSummary 扩展或 DebtDTO 加 remaining_trend_cents)+ 右侧 4-tile(年利率/月供/到期/已收期数)
- **D2**:`_statsRow` 改金额维度(5 卡:借出本金/已收合计 green/待收合计/累计利息 green/逾期 red — 从 schedule 聚合,client 算 Σ paid principal+interest / unpaid / overdue)
- **D3**:body 加右侧 side panel(grid-2:左 schedule / 右 side)— 收款账户卡(收款至 collectionAccountId 解析账户名 / 应收账户 accountId)+ 借款信息卡(债务人/contact/借出/到期/摊还/contract_ref)
- **D4**:确认收款触发改 OD 行内 link-btn 样式(`_scheduleAction` 已是 link 样式 ✓)— `RecordPayment(from_account_id = debt.collectionAccountId)`,**无 dialog 直接 dispatch + toast**;若 collectionAccountId 为空 fallback 弹 dialog(防御)

**per-debt trend 数据源**:DebtDTO.`remaining_trend_cents`(21,server 从 snapshot 算 per-debt 本月 vs 上月)— detail hero delta 直接读此字段。**已 resolved**(见 A1)。

### B6. `receivable_form_page.dart`(F1-F2 + 3 字段输入)
- **F1**:`_RadioChip` 升级为 `_RadioCard`(32px icon tile + label + 可选 desc);类型 4(私人/商业/亲友/其他,icon)+ 摊还 3(等额本息"每期合计相同"/等额本金"本金相同 利息递减"/一次性"到期一次结清",icon + desc)
- **F2**:`_CollectionPreview` header 下加 `pv-sum` 2×2 grid(月供/总利息 green/期数/总还款),替代当前 tags
- **新字段输入**:基本信息 section 加 contact(textField)+ contract_ref(textField,可选)+ collection_account_id(下拉,asset active 列表,创建模式必填;默认 = sourceAccountId 或用户选)

---

## 关联影响清单(不遗漏 — 分模块)

### debt(borrowedIn)模块 — 共享 DebtDTO/entity/proto
- **proto DebtDTO 通用扩** → debt 模块 mapper 也读(DebtRemoteDataSource.debtDtoToEntity 填 6 字段,即使 borrowIn 数据这些为空)
- **NewDebtDetails 签名改** → `debt/application.CreateDebt`(borrowedIn)调用适配:`contact=""` `contractRef=""` `collectionAccountID=nil`
- **ent debt schema 加 3 字段** → 共享,borrowIn 数据这些字段空;debt repo Save/FindAll 自动读写(ent generate 后)
- **debt UI**(DebtsPage / DebtDetailPage / DebtFormPage) **暂不显**新字段(后续 debt 模块自己的对齐 ticket 用);仅确保 entity 加字段后 debt mapper 不崩、debt widget test 不破

### server — interface 加方法(CLAUDE.md 约束 6)
- 若 `DebtRepository` interface 加 `SaveSnapshot/FindSnapshotRange/FindLatestByDebt` → **grep 全 implementer**:
  - `debt/adapter/driven/repository/debt_repo.go`(真实现)
  - **所有 test fake** holding/cross-package 持有 `DebtRepository` 的(debt handler test fake / goal test 若引用 / 任何 stub)
- **implementer 跑全量 suite**(非 scoped):`go test ./...` 全绿,否则跨包 fake 漏改致 build fail(D-budget Task1 教训)

### server — ent generate
- `cd yucai/server && go generate ./internal/debt/...`(debt schema 改 + 新 snapshot 表)
- 确认 ent client 生成 DebtProgressSnapshot;`go build ./...` 绿

### server — wire 接线
- providers.go:3 新 provider(snapshotRepo / debtScheduler / summaryHandler)+ provideDebtService 加 snapshotRepo 参数
- wire_gen.go 手改:声明顺序(snapshotRepo / debtScheduler 在 debtService 适当前;summaryHandler 在 debtService 后)+ NewApp 加 DebtScheduler
- app.go / main.go:DebtScheduler 字段 + Start

### client — entity 共享
- `Debt` entity 加 6 字段 → debt 模块(borrowedIn)mapper 也填(读 proto 新字段);debt widget test seed Debt(...) 构造函数加默认值(向后兼容,新字段可选默认)
- build_runner 重生成(新 ReceivablesSummaryDataSource/Repo 注册)

### client — DebtBloc / detail data
- detail 现有 `LoadDebtRequested` 走 DebtDetailDTO(含 schedule)→ D2 金额聚合 client 算 ✓(无需新 RPC)
- list overview summary 走新 ReceivablesSummary Repo(新数据源)

### client — 路由
- 不改(receivables 路由已接入 `/receivables` `/receivables/new` `/receivables/:id` `/receceivables/:id/edit`)
- 测试 router_test 不破(若注册了 fake DebtRepo,加新 interface 方法须 stub — 见上方 server interface 关联)

---

## 测试策略

### server(Go)
- **domain**:NewDebtDetails 新签名(contact/contract/collection 校验:receivable collection 必填 / borrowIn nil)
- **enttest**:contact/contract_ref/collection_account_id 读写;debt_progress_snapshot 建表 + UNIQUE(debt_id, snapshot_date)
- **application**:
  - DebtToDTO next_payment 算法(最早 !paid / 全 paid 空)
  - GetReceivablesSummary 聚合 + trend(本月 vs 上月快照)+ overdue 统计
  - SyncAllDebts best-effort(per-debt err skip)+ snapshot upsert(delete-then-insert / create→ConstraintError→update)
  - CreateDebt 透传新字段
- **scheduler**:照 goal scheduler 5 测(atomic + waitForCalls + fan-out per-tenant err continue)
- **handler**:GetReceivablesSummary(ReturnsSummary + Unauthenticated)

### client(Flutter)
- **mapper**:debtDtoToEntity 6 新字段(Int64/空处理)
- **summary ds/repo**:response-wiring + success/failure
- **list_page widget**:avatar tile 渲染 / stat strip 4 卡 / 横向 row + foot callout / overview trend / 筛选 4-seg(逾期)
- **detail_page widget**:hero avatar/delta/4-tile / 5-stat 金额维度 / side panel / 行内确认收款(无 dialog)+ toast
- **form_page widget**:radio cards(icon+desc)/ preview 2×2 sum / contact+contract+collection 输入 + 提交透传
- **回归**:debt(borrowedIn)模块 widget test 不破(Debt entity 加字段默认值)

### e2e(我自做,验证 task)
- server 启动 + scheduler snapshot 跑(count > 0)
- grpcurl GetReceivablesSummary 返 trend
- flutter run 验证 3 页视觉对齐 OD

---

## Non-goals / Defer(本次不做)

1. **debt(borrowedIn)模块 UI 对齐**(差距报告 debt #4)— 本次仅确保 debt 模块因 entity/proto 扩展不崩,UI 对齐是单独 ticket
2. **debt 模块也用 snapshot trend 显**(本次 receivable 用,debt 后续)
3. ~~DebtDTO 加 `remaining_trend_cents`(21)~~ — **已 resolved**:加 field 21(A1),detail hero delta 用 server per-debt snapshot trend,准确
4. **per-account 收款账户历史**(collection_account_id 仅持久化默认值,不记每次收款实际入账账户 — RecordPayment 仍可被用户在 detail 临时改,但行内确认用默认)
5. **3 预存 fail**(account/debt/transaction_detail_page — out-of-scope,D-currency item6 已证)
6. **OD 原型 mobile step wizard vs Flutter 现状**:Flutter form mobile 有 3-step wizard,OD mobile 是单列堆叠 — 本次保留 Flutter step wizard(更友好),仅 desktop/tablet 对齐 OD 双列

---

## 风险

1. **工作量大**(跨前后端:proto/ent/domain/application/scheduler/handler/wire + client entity/data/3 页 UI + 关联 debt 适配)→ plan 分 task:后端(proto+ent+domain+repo+summary+scheduler+wire)→ client(data+entity)→ list → detail → form → e2e;subagent-driven + TDD
2. **ent 无 OnConflict**(sql/upsert 扩展未启用)→ snapshot upsert 用 delete-then-insert 或 per-row create→ConstraintError→update fallback(照 holding_snapshot C Task10 教训)
3. **snapshot 与 SyncPrices 竞态**(同日 UNIQUE 冲突)→ best-effort slog.Warn 不 fatal(开发重启同日冲突,生产 IntervalSource 门控每日一次不冲突)
4. **collection_account_id 会计语义**:receivable 创建时 collection 必填(否则行内确认无默认 → fallback dialog);双写 RecordPayment 用 collection 作 from_account_id(钱进 collection 账户);若 collection 未设 fallback 现 dialog
5. **trend "上月"定义**:snapshot_date <= 上月今日 取最新(无则 trend = 0 或显 "—")
6. **proto regen 无网 fallback**:buf remote 无网 → 本地 protoc + 手修 `package debtv1`(照 D-budget Task2 教训)
7. **关联 debt 模块适配遗漏** → implementer 跑全量 suite 非 scoped(CLAUDE.md 约束 6);plan 每 task 验证 `go test ./...` + `flutter test` + `flutter analyze`

---

## Self-Review

**Spec coverage**:list L1-L4 / detail D1-D4 / form F1-F2 全覆盖 + 3 后端扩展(contact/contract/collection + snapshot/trend + summary RPC)+ D4 真·行内确认(持久化)+ 行业最佳实践(snapshot)。✓

**Internal consistency**:collection_account_id 在 proto/ent/domain/form/detail 一致(contact/contract 同);snapshot 表通用(debt 不分方向)与 receivable filter borrowedOut 一致;NewDebtDetails 签名扩 → 关联清单 debt/borrowedIn 适配一致。✓

**Scope**:单一模块(receivables)全量对齐 + 必要后端扩展 + 关联 debt 适配(仅不崩)。可一个 plan 覆盖(plan 分 ~8-10 task)。✓

**Ambiguity**:DebtDTO `remaining_trend_cents`(21)标为 open 决策点(plan 定,推荐加);其余字段/算法明确。✓

**Placeholder**:无 TBD/TODO(open 决策点已标 Non-goals #3)。✓
