# template 完整实现 · 设计 spec

- **日期**: 2026-07-14
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: template client UI + server record + autoRecord scheduler。server 填充骨架(RecordTransaction RPC + scheduler + nextDate 推进)+ client DDD 四层新建(CRUD + List/Detail + 手动 record + pause/resume)+ proto 加 RecordTransaction RPC
- **前置**: tag client UI 已完成(2026-07-14)。template 是 backup/sync decompose 外的独立模块(server TransactionTemplateService 7 RPC CRUD 骨架已实现)

## 1. 背景

御财 server **TransactionTemplateService 全实现 CRUD**(7 RPC:Create/Update/Delete/Pause/Resume/Get/List),client proto stub 全有(`lib/proto/template/v1/template.pbgrpc.dart`),但:
- **client 无 template UI**(`lib/template/` 不存在)
- **server 无 RecordTransaction RPC**(7 RPC 是 CRUD+Pause/Resume,**无手动 record** 从模板生成 transaction)
- **server 无 autoRecord scheduler**(`auto_record` 字段存,main.go 只有 Currency/Holding/Snapshot scheduler,无 TemplateScheduler)

memory `holding-asset-management-todo`:template UI 待独立 spec(server 有,client 无)。本 spec 完整实现(client UI + server record + scheduler)。

## 2. 目标

template 完整可用:client 管理(创建/编辑/删除/暂停/恢复 周期交易模板)+ 手动 record(从模板生成 transaction)+ autoRecord(server scheduler 周期自动 record + nextDate 推进)。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| server RecordTransaction RPC(template → transaction via port + nextDate 推进) | template 执行历史(record log) |
| server autoRecord scheduler(daily tick,到期 record) | template 导入/导出 |
| server nextDate 推进逻辑(cycle:weekly/monthly/yearly/custom) | catch-up record(多次到期补多次,本 spec 每 tick 一次) |
| proto 加 RecordTransaction RPC + regen | template 模板市场/预设 |
| client DDD 四层(Template entity/repo/remote_ds/mapper/Bloc/Page/Form) | |
| client 手动 record button + pause/resume + autoRecord 标记 | |
| client route /settings/templates + DI | |

**proto + server 改动**(加 RecordTransaction RPC + scheduler;复用 transaction create via port)。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | scope | 完整(client UI + server record + autoRecord scheduler) | template 核心价值是 record;MVP CRUD 只存配置无实际价值 |
| 2 | record 方式 | server RecordTransaction RPC(template → transaction via TransactionRecorder port) | DDD port(template 不 import transaction),对齐 backup TenantDataPort |
| 3 | autoRecord | server scheduler(daily tick) | 自动周期 record;client 不触发(后台) |
| 4 | nextDate 推进 | record 后推进(cycle 规则) | 避重复 record;cycle 语义 |
| 5 | client 入口 | settings 子页 /settings/templates | 低频管理,对齐 tag/backup |
| 6 | catch-up | defer(每 tick 一次) | 简单;catch-up(多次到期补)复杂,defer |

## 5. 架构(server + client DDD)

### server(template + transaction via port)

| 层 | 组件 | 职责 |
|---|---|---|
| **proto** | `RecordTransaction(RecordTemplateRequest{template_id})` 新 RPC | template → transaction |
| **template domain** | `TransactionRecorder` port interface | Record(ctx, tenantID, RecordRequest) → txnID(template 不 import transaction) |
| **template application** | `Service.RecordTransaction`(调 port + 推进 nextDate + lastTxnId)+ scheduler 接口 | record 编排 + nextDate 推进 |
| **transaction application** | `TransactionRecorder` 实现(Record → create expense/income/transfer via existing Service) | 复用 transaction create,port adapter |
| **scheduler** | `TemplateScheduler`(daily tick,查到期 → RecordTransaction) | autoRecord |
| **wire** | 注入 TransactionRecorder + TemplateScheduler | port + scheduler |

### client(DDD 四层,对齐 tag/debt)

| 层 | 组件 | 职责 |
|---|---|---|
| **domain** | `Template` entity(20 字段)+ `TemplateRepository` abstract(8 method) | entity + repo 接口 |
| **data** | `TemplateRemoteDataSource`(@LazySingleton 8 RPC)+ `TemplateRepositoryImpl`(@LazySingleton(as:)) + `template_mapper` | 8 RPC + Either<Failure> + proto→entity |
| **presentation** | `TemplateBloc`(@injectable)+ `TemplatePage` + `TemplateCard` + `TemplateForm` | event/state + UI(CRUD + record + pause/resume) |
| **core** | DI + router `/settings/templates` | route + settings 入口 |

## 6. server RecordTransaction RPC

### 6.1 流程
```
RecordTransaction(ctx, tenantID, templateID):
  1. template = repo.FindByID(templateID)
  2. if template.Paused: return ErrTemplatePaused
  3. txnID = recorder.Record(ctx, tenantID, RecordRequest{
       Direction: template.Direction,
       AmountCents: template.AmountCents,
       SourceAccountID: template.SourceAccountID,
       DestinationAccountID: template.DestinationAccountID,
       Category: template.Category,
       Date: template.NextDate,
     })
  4. template.LastTransactionID = txnID
  5. template.NextDate = advanceNextDate(template.NextDate, template.Cycle, template.CycleDays, template.BillingDay)
  6. repo.Update(template)
  7. return txnID
```

### 6.2 TransactionRecorder port(template domain)
```go
type RecordRequest struct {
    Direction         TemplateDirection
    AmountCents       int64
    SourceAccountID   uuid.UUID
    DestinationAccountID uuid.UUID  // transfer 用
    Category          string
    Date              time.Time
}
type TransactionRecorder interface {
    Record(ctx context.Context, tenantID uuid.UUID, req RecordRequest) (txnID uuid.UUID, err error)
}
```
transaction application 实现(Record → switch Direction → create expense/income/transfer via existing Service methods)。

### 6.3 nextDate 推进(advanceNextDate)
```go
func advanceNextDate(current time.Time, cycle Cycle, cycleDays int32, billingDay int32) time.Time {
    switch cycle {
    case CycleWeekly:   return current.AddDate(0, 0, 7)
    case CycleMonthly:  return current.AddDate(0, 1, 0)  // 保 day;若 billingDay 设,用 billingDay
    case CycleYearly:   return current.AddDate(1, 0, 0)
    case CycleCustom:   return current.AddDate(0, 0, int(cycleDays))
    default:            return current  // 不推进(避免无限)
    }
}
```

## 7. autoRecord scheduler

### 7.1 TemplateScheduler
```go
type TemplateScheduler struct {
    service *templateapp.Service
    ticker  *time.Ticker
}
func (s *TemplateScheduler) Start(ctx context.Context) {
    ticker := time.NewTicker(24 * time.Hour)  // daily
    // 首次立即执行(启动时检查)
    s.checkAndRecord(ctx)
    for { select { case <-ticker.C: s.checkAndRecord(ctx); case <-ctx.Done(): ticker.Stop(); return } }
}
func (s *TemplateScheduler) checkAndRecord(ctx context.Context) {
    // 查所有 tenant 的 autoRecord && !paused && nextDate <= today 模板
    // → RecordTransaction + 推进(每 tick 一次,catch-up defer)
}
```

### 7.2 main.go 启动
```go
go app.TemplateScheduler.Start(schedCtx)
```
对齐 CurrencyScheduler/HoldingScheduler 模式。

## 8. proto 改动

`proto/template/v1/template.proto`:
```proto
service TransactionTemplateService {
  // ... 现有 7 RPC ...
  rpc RecordTransaction(RecordTemplateRequest) returns (RecordTransactionResponse);  // 新
}

message RecordTemplateRequest { string template_id = 1; }
message RecordTransactionResponse {
  string transaction_id = 1;
  google.protobuf.Timestamp next_date = 2;  // 推进后的下次日期
}
```

regen:Go(`buf generate`)+ Dart(`make gen-dart` protoc_plugin 25.0.0)。

## 9. client UI(DDD 四层,对齐 tag/debt)

### 9.1 Template entity
```dart
class Template extends Equatable {
  const Template({required this.id, required this.name, ...});  // 20 字段
  final String id, name, description;
  final int amountCents;
  final TemplateDirection direction;
  final String? sourceAccountId, destinationAccountId;
  final TemplateCycle cycle;
  final int cycleDays, billingDay;
  final DateTime? nextDate, startDate, endDate;
  final bool autoRecord, paused;
  final String? lastTransactionId;
  final String category;
  final int version;
  String get amountDisplay => ...;  // 元格式
  String get cycleDisplay => ...;   // 周期中文
}
```

### 9.2 TemplateRepository(8 method)
list/create/update/delete/pause/resume/get/**record**(templateId → txnID + nextDate)

### 9.3 TemplatePage(列表,对齐 tag TagPage)
- header:标题「周期模板」+「新建模板」FilledButton
- ListView:TemplateCard[](name/amount/cycle/nextDate/autoRecord/paused 标记 + record/pause-resume/edit/delete)
- 三态(loading/空/错误)

### 9.4 TemplateCard
- name + amount + cycle + nextDate
- autoRecord/paused chip 标记
- trailing:record(lucide `play`)+ pause/resume(lucide `pause`/`play`)+ edit(`pencil`)+ delete(`trash2`)

### 9.5 TemplateForm(创建/编辑)
- 全字段:name/description/amount/direction(expense/income/transfer dropdown)/source_account/destination_account(transfer)/cycle(weekly/monthly/yearly/custom)/cycleDays(custom)/billingDay/monthly/startDate/endDate/autoRecord(toggle)/category
- 复用 transaction form 的 account dropdown / amount 格式

### 9.6 交互
| 操作 | 流程 |
|---|---|
| 创建 | form → CreateTransactionTemplate → 刷新 + SnackBar |
| 编辑 | form(预填)→ UpdateTransactionTemplate |
| 删除 | confirm → DeleteTransactionTemplate |
| 手动 record | card record icon → confirm(可选)→ RecordTransaction → SnackBar「已记录,下次 X」|
| pause/resume | toggle → Pause/Resume RPC → 刷新 |
| in-progress | AbsorbPointer + spinner |

## 10. client route

router `/settings/templates` 子路由(BlocProvider<TemplateBloc> 路由层,对齐 tag /settings/tags + backup /settings/backup)。settings_page 加「周期模板」_NavRow tile。

## 11. 测试

### server
- **TransactionRecorder**(port impl):Record(direction → expense/income/transfer correct entries)
- **advanceNextDate**:cycle 推进(weekly/monthly/yearly/custom)
- **RecordTransaction**(集成:port + nextDate + lastTxnId)
- **TemplateScheduler**:到期 record + 非 autoRecord/paused 跳过
- **handler**:RecordTransaction(InvalidArgument on missing template)

### client
- **TemplateBloc**:load/create/update/delete/record/pause/resume + state 流
- **TemplatePage**:列表渲染 + record dialog + pause/resume + empty/error
- **TemplateForm**:字段渲染 + 提交
- **mapper**:TemplateDTO → Template

### 回归
- server `go test ./...` exit 0
- client `flutter test`(1 预存 fail account_detail)+ analyze 22 基线

## 12. 风险

1. **TransactionRecorder port**(template → transaction)—— DDD port,wire 注入(对齐 backup TenantDataPort);transaction application 实现 Record(direction → create)
2. **autoRecord scheduler catch-up**(多次到期)—— 本 spec 每 tick 一次(简单);catch-up defer
3. **nextDate 推进 monthly billingDay**(月末 31 → 次月无 31)—— 简单 AddDate(0,1,0)保 day;若 billingDay 设用 billingDay(clamp 月末);spec 用 AddDate(保 day,billingDay follow-up)
4. **record 失败**(port create fail)—— 不推进 nextDate(可重试);lastTxnId 不更新
5. **scheduler daily tick 时区**—— server UTC;nextDate 比较 UTC date
6. **proto regen**—— RecordTransaction RPC;Go + Dart stub;protoc_plugin 25.0.0
7. **wire 手改**—— TransactionRecorder port + TemplateScheduler 注入;wire_gen.go 手改(memory `yucai-wire-handmaintained`)
8. **transaction create 复用**(port Record → existing Service create expense/income/transfer)—— 复用现有 logic(entries + balance);不重写

## 13. 参考

- proto:[template.proto TransactionTemplateService 7 RPC + TemplateDTO](../../yucai/proto/template/v1/template.proto)
- client stub:[TemplateServiceClient](../../yucai/client/lib/proto/template/v1/template.pbgrpc.dart)
- 范式:tag client UI([2026-07-13-tag-ui-design.md](2026-07-13-tag-ui-design.md),DDD 四层 + settings 子页)+ backup server([2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md),port + scheduler + 填充骨架)
- scheduler 范式:CurrencyScheduler/HoldingScheduler(main.go Start)
- memory:[[holding-asset-management-todo]](template UI 待独立 spec)
