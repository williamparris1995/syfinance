# template 完整实现 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** template client UI + server record + autoRecord scheduler —— client 管理(创建/编辑/删除/暂停/恢复 周期交易模板)+ 手动 record(从模板生成 transaction)+ autoRecord(server scheduler 周期自动 record + nextDate 推进)。

**Architecture:** server 填充骨架(RecordTransaction RPC via TransactionRecorder port → transaction create + nextDate 推进;autoRecord scheduler daily tick)+ client DDD 四层(对齐 tag/debt;TemplatePage/Form + 手动 record + pause/resume)+ proto 加 RecordTransaction RPC。

**Tech Stack:** Go(gRPC + ent + wire 手维护)+ Flutter(flutter_bloc + injectable)+ proto3。

## Global Constraints

- **proto 改动**:加 `RecordTransaction(RecordTemplateRequest) returns (RecordTransactionResponse)`;regen Go(`cd yucai/proto && buf generate`)+ Dart(`cd yucai && make gen-dart`,protoc_plugin 25.0.0)
- **DDD port**:template application 定义 `TransactionRecorder` port(template 不 import transaction);transaction application 实现(对齐 backup TenantDataPort)
- **wire 手改**:TransactionRecorder port + TemplateScheduler 注入(wire_gen.go 手改,memory `yucai-wire-handmaintained`)
- **零 schema**:复用现有 ent(transaction_templates 表已有)
- **中文 UI 直写**;英文结构化日志(slog)
- **复用第一**:DataCard/Failure/AuthRetryCaller/GrpcClient;server scheduler 对齐 CurrencyScheduler/HoldingScheduler(main.go Start)
- **测试**:Go 单测 + 集成(enttest);client mocktail/blocTest/widget
- **回归基线**:server `go test ./...` exit 0;client `flutter test` 1 预存 fail(account_detail);analyze 22 基线
- **数据文件**:`docs/superpowers/specs/2026-07-14-template-ui-design.md`

---

## File Structure

### server 新建/修改

| 文件 | 职责 |
|---|---|
| `yucai/proto/template/v1/template.proto` | 加 RecordTransaction RPC + messages |
| `yucai/server/internal/template/domain/record_port.go` | TransactionRecorder port + RecordRequest + advanceNextDate |
| `yucai/server/internal/transaction/application/recorder_adapter.go` | TransactionRecorder 实现(direction → create expense/income/transfer) |
| `yucai/server/internal/template/application/service.go` | 改:RecordTransaction(port + nextDate + lastTxnId) |
| `yucai/server/internal/template/adapter/driving/grpc/template_handler.go` | 加 RecordTransaction handler |
| `yucai/server/internal/template/scheduler/scheduler.go` | TemplateScheduler(daily tick) |
| `yucai/server/cmd/server/main.go` | 加 TemplateScheduler.Start |
| `yucai/server/wire/providers.go` | provideTemplateService 加 recorder + provideTemplateScheduler |
| `yucai/server/wire/wire_gen.go` | 手改(recorder + scheduler 声明) |

### client 新建(`lib/template/` 全新)

| 文件 | 职责 |
|---|---|
| `lib/template/domain/entities/template_entity.dart` | Template(20 字段) |
| `lib/template/domain/repositories/template_repository.dart` | TemplateRepository abstract(8 method) |
| `lib/template/data/mappers/template_mapper.dart` | proto→entity |
| `lib/template/data/template_remote_ds.dart` | TemplateRemoteDataSource(8 RPC) |
| `lib/template/data/template_repository_impl.dart` | TemplateRepositoryImpl |
| `lib/template/presentation/bloc/template_{event,state,bloc}.dart` | TemplateBloc |
| `lib/template/presentation/pages/template_page.dart` | TemplatePage(列表) |
| `lib/template/presentation/widgets/template_card.dart` | TemplateCard |
| `lib/template/presentation/widgets/template_form.dart` | TemplateForm(创建/编辑) |

---

## Task 1: proto RecordTransaction RPC + regen

**Files:** Modify `yucai/proto/template/v1/template.proto`;regen Go/Dart stub。

**Interfaces:** Produces: `RecordTransaction` RPC in service;`RecordTemplateRequest{string template_id=1}`;`RecordTransactionResponse{string transaction_id=1;google.protobuf.Timestamp next_date=2}`。

- [ ] **Step 1**: proto 加 RPC + messages(在 service 加 `rpc RecordTransaction(RecordTemplateRequest) returns (RecordTransactionResponse);` + 两 message)
- [ ] **Step 2**: regen Go `cd yucai/proto && buf generate --template buf.gen.go.yaml`;regen Dart `cd yucai && make gen-dart`(protoc_plugin 25.0.0)
- [ ] **Step 3**: 验证 stub 含 RecordTransaction;`go build ./...`
- [ ] **Step 4**: commit `feat(template/proto): RecordTransaction RPC + regen Go/Dart`

---

## Task 2: server domain — advanceNextDate + TransactionRecorder port

**Files:** Create `yucai/server/internal/template/domain/record_port.go`;test。

**Interfaces:**
- Produces: `func advanceNextDate(current time.Time, cycle Cycle, cycleDays int32) time.Time`;`type RecordRequest struct{...}`;`type TransactionRecorder interface{ Record(ctx, tenantID uuid.UUID, req RecordRequest) (txnID uuid.UUID, err error) }`

- [ ] **Step 1**: Write `advanceNextDate` test(weekly +7d / monthly +1月 / yearly +1年 / custom +cycleDays / unspecified 不变)
- [ ] **Step 2**: Run fail
- [ ] **Step 3**: Create `record_port.go` with advanceNextDate + RecordRequest + TransactionRecorder interface
- [ ] **Step 4**: Run pass
- [ ] **Step 5**: commit `feat(template/server): domain advanceNextDate + TransactionRecorder port`

---

## Task 3: server transaction — TransactionRecorder 实现

**Files:** Create `yucai/server/internal/transaction/application/recorder_adapter.go`;test。

**Interfaces:**
- Consumes: existing transaction application Service(create expense/income/transfer);Task 2 RecordRequest/TransactionRecorder
- Produces: `TransactionRecorderAdapter` struct implementing `template domain.TransactionRecorder`

- [ ] **Step 1**: Read transaction application Service existing create method signatures(recordExpense/recordIncome/recordTransfer or equivalent)
- [ ] **Step 2**: Create `recorder_adapter.go` — `Record(ctx, tenantID, req RecordRequest)` → switch Direction → call existing Service create(expense: debit category + credit asset;income: debit asset + credit income;transfer: debit dest + credit source)→ return txnID
- [ ] **Step 3**: Write test(mock transaction Service or enttest;verify direction → correct entries)
- [ ] **Step 4**: Run pass;`go build ./...`
- [ ] **Step 5**: commit `feat(transaction/server): TransactionRecorder adapter(template → txn via port)`

---

## Task 4: server template — Service.RecordTransaction + handler

**Files:** Modify `template/application/service.go`(加 recorder field + RecordTransaction method);`template/adapter/driving/grpc/template_handler.go`(加 RecordTransaction handler)。

**Interfaces:**
- Consumes: Task 2 port + advanceNextDate;Task 3 TransactionRecorder impl;Task 1 proto RecordTransaction
- Produces: `Service.RecordTransaction(ctx, tenantID, templateID) (*RecordResult, error)`

- [ ] **Step 1**: Modify Service struct:加 `recorder domain.TransactionRecorder` field;NewService 加参数
- [ ] **Step 2**: Implement RecordTransaction:FindByID → if Paused return ErrTemplatePaused → recorder.Record(direction/amount/accounts/category/date=NextDate) → LastTransactionID = txnID → NextDate = advanceNextDate → repo.Update
- [ ] **Step 3**: Add handler RecordTransaction(解 req.TemplateId → service.RecordTransaction → response transaction_id + next_date)
- [ ] **Step 4**: Write test(fakeRecorder mock + fakeRepo;verify record + nextDate + lastTxnId + paused reject)
- [ ] **Step 5**: Run pass;`go build ./...`
- [ ] **Step 6**: commit `feat(template/server): RecordTransaction(port record + nextDate + handler)`

---

## Task 5: server TemplateScheduler + wire + main.go

**Files:** Create `yucai/server/internal/template/scheduler/scheduler.go`;modify `main.go`(Start);modify `wire/providers.go` + `wire_gen.go`(手改)。

**Interfaces:**
- Consumes: Task 4 Service.RecordTransaction
- Produces: `TemplateScheduler.Start(ctx)`(daily tick → autoRecord templates → record)

- [ ] **Step 1**: Create `scheduler.go` — TemplateScheduler struct{service;tenantLister};Start(ctx):daily ticker;checkAndRecord:query autoRecord && !paused && nextDate<=today templates → RecordTransaction per template(对齐 CurrencyScheduler.Start pattern)
- [ ] **Step 2**: Read CurrencyScheduler.Start(main.go:66-70)作模板;Read template repo FindAll(all tenants for scheduler)
- [ ] **Step 3**: Add main.go `go app.TemplateScheduler.Start(schedCtx)`(after HoldingScheduler)
- [ ] **Step 4**: providers.go:provideTemplateService 加 recorder param;provideTemplateScheduler;wire_gen.go 手改(recorder + scheduler 声明,对齐 backup server wire Task 10)
- [ ] **Step 5**: `go build ./... && go test ./...`(exit 0)
- [ ] **Step 6**: commit `feat(template/server): TemplateScheduler(daily autoRecord)+ wire 注入 recorder+scheduler`

---

## Task 6: client domain + data(entity/repo/mapper/remote_ds/repo_impl)

**Files:** Create `lib/template/domain/` + `lib/template/data/` + tests。

**Interfaces:**
- Produces: Template entity(20 字段);TemplateRepository abstract(8 method:list/create/update/delete/pause/resume/get/record);TagRemoteDataSource 8 RPC;TemplateRepositoryImpl

- [ ] **Step 1-5**: 照 tag Task 1 模板(domain entity + repo + mapper + remote_ds 8 RPC + repo_impl _guard + mapper test + repo test)。**逐字照 tag plan Task 1 结构**(改 module name tag→template + 8 RPC)
- [ ] **Step 6**: commit `feat(template/client): domain+data 层(entity/repo 8 method/mapper/remote_ds)+ 测`

> **照 tag plan Task 1 完整代码模板**(`docs/superpowers/plans/2026-07-14-tag-ui.md` Task 1),改:module tag→template;7→8 RPC(+record);proto path tag→template;TagDTO→TemplateDTO(20 字段:Read proto confirm)。

---

## Task 7: client TemplateBloc

**Files:** Create `lib/template/presentation/bloc/`。照 tag Task 2。

- [ ] event 7(Load/Create/Update/Delete/Pause/Resume/RecordRequested)
- [ ] state 7(Initial/Loading/Loaded/Submitting/ActionSuccess/Error)
- [ ] TemplateBloc @injectable(7 handler fold + refresh)
- [ ] bloc test
- [ ] commit

> 照 tag plan Task 2 改 tag→template + 加 Pause/Resume/Record events。ActionSuccess message:模板已创建/已更新/已删除/已暂停/已恢复/已记录(下次 X)。

---

## Task 8: client TemplatePage + TemplateCard + TemplateForm

**Files:** Create `lib/template/presentation/pages/` + `widgets/`。照 tag Task 3。

- [ ] TemplatePage(topbar + 三态 body + BlocListener→SnackBar;对齐 tag TagPage)
- [ ] TemplateCard(name + amount + cycleDisplay + nextDate + autoRecord/paused chip;trailing:record play + pause/play + edit pencil + delete trash2)
- [ ] TemplateForm(全字段:name/description/amount/direction dropdown/source_account dropdown/dest_account(transfer)/cycle dropdown/cycleDays(custom)/billingDay(monthly)/startDate/endDate/autoRecord toggle/category;复用 transaction form account dropdown + amount 格式)
- [ ] widget test(列表/空/错误)
- [ ] commit

> 照 tag plan Task 3 改。TemplateForm 复杂(全字段),Read transaction_form_page account dropdown + amount 格式 作参考。

---

## Task 9: client router /settings/templates + settings tile + DI

**Files:** Modify `router.dart` + `settings_page.dart` + `injection.config.dart`。照 tag Task 4。

- [ ] router settings branch 加 templates 子路由(BlocProvider<TemplateBloc>)
- [ ] settings_page 加「周期模板」_NavRow tile
- [ ] build_runner DI(TemplateRemoteDataSource/TemplateRepositoryImpl/TemplateBloc)
- [ ] 回归 flutter test + analyze
- [ ] commit

> 照 tag plan Task 4 改。settings _NavRow:backup + 标签管理 + 周期模板(三 tile 同卡 Column + Divider)。

---

## Task 10: e2e + 回归

- [ ] rebuild server.exe + restart
- [ ] e2e grpcurl:CreateTemplate(autoRecord:true,cycle:MONTHLY)→ RecordTransaction(手动,验 transaction_id + next_date 推进)→ ListTemplates(验 last_transaction_id 更新)→ Pause → RecordTransaction(paused reject)
- [ ] server `go test ./...` exit 0
- [ ] client `flutter test`(1 预存 fail)+ analyze 22 基线
- [ ] commit `test(template): e2e record + nextDate 推进 + autoRecord scheduler`

---

## Self-Review

### 1. Spec coverage
| spec | Task |
|---|---|
| §6 RecordTransaction RPC(port + nextDate) | T2(port)+T3(adapter)+T4(service+handler) |
| §7 autoRecord scheduler | T5 |
| §8 proto | T1 |
| §9 client DDD 四层 | T6(domain/data)+T7(bloc)+T8(page/card/form) |
| §10 router | T9 |
| §11 测试 + 回归 | 各 task 含测 + T10 e2e |

### 2. Placeholder scan
⚠️ Task 6-9 照 tag plan 模板(改 module name)。这是合理的 DRY(同 DDD 范式,8 module 已验证)。implementer 读 tag plan 对应 task + 改 tag→template。T8 TemplateForm 全字段需 Read transaction_form_page 参考(account dropdown/amount 格式)。

### 3. Type consistency
- TransactionRecorder port(T2)→ adapter(T3)→ service.RecordTransaction(T4)→ handler(T4)→ scheduler(T5)✅
- proto RecordTransaction(T1)→ client record(T6 remote_ds)→ bloc RecordRequested(T7)→ UI record button(T8)✅
- Template entity 20 字段(T6)→ DTO(T1 proto)✅

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-07-14-template-ui.md`。Two options:

**1. Subagent-Driven (recommended)** — 每 task fresh subagent + review。

**2. Inline Execution** — 当前 session executing-plans。

Which approach?
