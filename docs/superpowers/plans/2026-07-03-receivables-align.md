# Receivables 全模块对齐 OD 原型 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** receivables 三页(list/detail/form)全量对齐 OD 原型,含后端扩展(contact/contract_ref/collection_account_id + next_payment×3 + remaining_trend + debt_progress_snapshot 表 + GetReceivablesSummary RPC + SyncAllDebts scheduler)。

**Architecture:** server DDD 四层扩(proto + ent + domain + application + scheduler + handler + wire 手改);client DDD 四层(entity + data mapper + summary ds/repo + 3 页 UI 改);关联 debt(borrowedIn)模块适配 NewDebtDetails 签名扩 + entity 加字段(U 暂不动)。trend 用历史快照表(行业最佳实践,照 holding_snapshot/goal_progress_snapshot)。D4 真·行内确认(collection_account_id 持久化)。

**Tech Stack:** Go(ent + grpc + slog + wire 手改)+ proto3(buf + protoc_plugin 25.0.0)+ Flutter(flutter_bloc + injectable + lucide + 御财设计语言)

**Spec:** [docs/superpowers/specs/2026-07-03-receivables-align-design.md](../specs/2026-07-03-receivables-align-design.md)

## Global Constraints

- **分支** `holding-asset-management`(主 checkout,不建 worktree)
- **schema 用 ent**(非 SQL migration);`cd yucai/server && go generate ./internal/debt/...`
- **wire 手改** `wire_gen.go`(工具链坏,见 memory `yucai-wire-handmaintained`);新 provider 声明在依赖方之后
- **proto regen** Go(`cd yucai/proto && buf generate --template buf.gen.go.yaml`,无网 fallback 本地 protoc + 手修 `package debtv1`)+ Dart(`cd yucai && make gen-dart`,**protoc_plugin 25.0.0**;make 不在 PATH 用 `bash yucai/proto/gen-dart.sh`)
- **interface 加方法 → grep 全 implementer(含 test fake)**;implementer 跑**全量 suite**(`go test ./...`)非 scoped(D-budget Task1 教训)
- **English 结构化日志**(slog,无 CJK)
- **复用第一**:ent snapshot 照 `goal_progress_snapshot.go`;scheduler 照 `goal/scheduler.go`;summary ds 照 `holding GoalViewDataSource`;avatar/badge 升级 `receivables_page._Badge/_inferBadge`
- **路由优先级**:静态 `/new` `/edit` 在 `/:id` 前(receivables 路由已接入,不改)
- **flutter analyze 基线 22 error**(全 pbserver)+ 3 预存 fail(account/debt/transaction_detail_page,非本 plan 引入)
- **每 task commit**(中文 conventional `feat(holding-receivables-...): ...`)
- **多币种 — 不硬编码**:所有货币显示走 `currencySymbol(code)`(禁裸 `¥`/`$`);币种字符串走变量(preferred / Debt.currencyCode / 集中常量),禁散落 `'CNY'`。summary/trend 折算到 preferred(复用 D-currency `convertToBase` / `toPreferredCents`)。Debt 无 currencyCode → `toPreferredCents(cents, debt.currencyCode ?? 'CNY', rates, preferred)` 留口;snapshot 存原币 cents,client 折算 preferred 显示
- **bash 工具无 make / cwd 持久但会变** → git 用 `git -C /e/projects/syfinance`,命令用绝对 cd

## File Structure

### server 新建
- `yucai/server/internal/debt/ent/schema/debt_progress_snapshot.go` — snapshot 表 ent schema
- `yucai/server/internal/debt/domain/snapshot.go` — DebtProgressSnapshot entity
- `yucai/server/internal/debt/adapter/driven/repository/debt_snapshot_repo.go` — snapshot ent repo

### server 修改
- `yucai/proto/debt/v1/debt.proto` — DebtDTO 加 7 字段(15-21)+ CreateDebt(11-13)+ UpdateDebt(5-7)+ GetReceivablesSummary RPC + messages
- `yucai/server/internal/debt/ent/schema/debt.go` — 加 contact/contract_ref/collection_account_id
- `yucai/server/internal/debt/domain/entity.go` — DebtDetails 加 3 字段 + NewDebtDetails 签名扩
- `yucai/server/internal/debt/domain/repository.go` — DebtRepository 加 snapshot 方法 + SnapshotRepo 接口
- `yucai/server/internal/debt/adapter/driven/repository/debt_repo.go` — 读写新字段
- `yucai/server/internal/debt/application/service.go` — DebtToDTO next_payment + GetReceivablesSummary + SyncAllDebts + CreateDebt/UpdateDebt 透传 + 3 setter
- `yucai/server/internal/debt/application/dto.go` — DTO 加字段
- `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go` — GetReceivablesSummary handler
- `yucai/server/internal/debt/scheduler/scheduler.go` — DebtScheduler(照 goal)
- `yucai/server/wire/providers.go` + `wire/wire_gen.go`(手改)— snapshot repo + scheduler + summary handler + provideDebtService 加 snapshotRepo

### client 新建
- `yucai/client/lib/debt/domain/entities/receivables_summary.dart` — ReceivablesSummary entity
- `yucai/client/lib/debt/data/receivables_summary_data_source.dart` + `receivables_summary_repository.dart`

### client 修改
- `yucai/client/lib/proto/debt/v1/debt.pb.dart` 等 — stub regen
- `yucai/client/lib/debt/domain/entities/debt_entity.dart` — Debt 加 7 字段
- `yucai/client/lib/debt/data/debt_mapper.dart` — 填新字段
- `yucai/client/lib/debt/presentation/pages/receivables_page.dart` — L1-L4
- `yucai/client/lib/debt/presentation/pages/receivable_detail_page.dart` — D1-D4
- `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart` — F1-F2 + 3 字段输入

---

## Task 0: 前置验证(无 commit,纯验证)

**Files:** 无改动

- [ ] **Step 1: 确认现状 + 干净工作区**

```bash
git -C /e/projects/syfinance status --short
grep -n "message DebtDTO\|message RecordPaymentRequest\|NewDebtDetails" yucai/proto/debt/v1/debt.proto yucai/server/internal/debt/domain/entity.go | head
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:干净;DebtDTO 14 字段(到 subtype=14);RecordPaymentRequest 3 字段(debt_id/schedule_entry_id/from_account_id);NewDebtDetails 9 参数(无 contact/contract/collection)。记 HEAD(receivables 对齐起点 = `f0b0c1d` spec 修订后)。

(无 commit — 纯验证)

---

## Task 1: proto 扩 + Go/Dart regen

**Files:**
- Modify: `yucai/proto/debt/v1/debt.proto`
- Regen: Go stub `yucai/server/internal/proto/debt/v1/` + Dart stub `yucai/client/lib/proto/debt/v1/`

**Interfaces:**
- Produces:DebtDTO 21 字段 + CreateDebtRequest 13 + UpdateDebtRequest 7 + GetReceivablesSummary RPC + ReceivablesSummaryDTO/Response/Request messages。Task 2-7 (server) + Task 8 (client) 用。

- [ ] **Step 1: 改 proto**

`yucai/proto/debt/v1/debt.proto` — DebtDTO 加 field 15-21:
```proto
message DebtDTO {
  // 1-14 现有(id/account_id/counterparty/interest_rate/amortization_method/start_date/due_date/total_principal_cents/remaining_principal_cents/version/created_at/updated_at/debt_type/subtype)
  string contact = 15;
  string contract_ref = 16;
  string collection_account_id = 17;
  string next_payment_date = 18;
  int64 next_payment_amount_cents = 19;
  int32 next_payment_period_no = 20;
  int64 remaining_trend_cents = 21;
}
```
CreateDebtRequest 加 11-13:`string contact = 11;` `string contract_ref = 12;` `string collection_account_id = 13;`
UpdateDebtRequest 加 5-7:`string contact = 5;` `string contract_ref = 6;` `string collection_account_id = 7;`

service 加 RPC + 3 messages:
```proto
service DebtService {
  // ... 现有 7 RPC ...
  rpc GetReceivablesSummary(GetReceivablesSummaryRequest) returns (ReceivablesSummaryResponse);
}
message GetReceivablesSummaryRequest {}
message ReceivablesSummaryDTO {
  int64 total_principal_cents = 1;
  int64 total_remaining_cents = 2;
  int64 total_collected_cents = 3;
  int64 pending_interest_cents = 4;
  int32 count = 5;
  int32 overdue_count = 6;
  int64 overdue_amount_cents = 7;
  int64 principal_trend_cents = 8;
  int64 remaining_trend_cents = 9;
  string next_payment_date = 10;
  int64 next_payment_amount_cents = 11;
  string next_payment_counterparty = 12;
  int32 next_payment_period_no = 13;
}
message ReceivablesSummaryResponse { ReceivablesSummaryDTO summary = 1; }
```

- [ ] **Step 2: regen Go stub**

```bash
cd /e/projects/syfinance/yucai/proto && buf generate --template buf.gen.go.yaml
```
无网 fallback:本地 `protoc --go_out=... --go-grpc_out=... debt/v1/debt.proto` + 手修 emit 的 `package v1` → `package debtv1`(照 D-budget Task2 教训;descriptor metadata 丢仅非 Go 影响,cosmetic)。

- [ ] **Step 3: regen Dart stub**

```bash
cd /e/projects/syfinance && make gen-dart
```
make 不在 PATH:`cd /e/projects/syfinance/yucai/proto && bash gen-dart.sh`(protoc_plugin **25.0.0**,路径 `C:\Users\andy\AppData\Local\Pub\Cache\bin\protoc-gen-dart.bat`)。

- [ ] **Step 4: 验证 stub + build 绿**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/client && flutter analyze lib/proto/debt/ 2>&1 | grep -E "error -" | grep -v pbserver
grep -n "GetReceivablesSummary\|remaining_trend_cents\|collection_account_id" yucai/client/lib/proto/debt/v1/debt.pbgrpc.dart yucai/client/lib/proto/debt/v1/debt.pb.dart | head
```
Expected:go build 绿(DebtHandler 嵌入 Unimplemented,RPC 加后仍绿,Task 7 实现真 handler);Dart analyze 无新 error(22 pbserver 基线);grep 见 3 新成员。

- [ ] **Step 5: Commit**

```bash
git -C /e/projects/syfinance add yucai/proto/debt/ yucai/server/internal/proto/debt/ yucai/client/lib/proto/debt/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-proto): DebtDTO 扩 7 字段 + GetReceivablesSummary RPC + regen(Task 1)"
```

---

## Task 2: ent schema(debt 加 3 字段 + debt_progress_snapshot 表)

**Files:**
- Modify: `yucai/server/internal/debt/ent/schema/debt.go`
- Create: `yucai/server/internal/debt/ent/schema/debt_progress_snapshot.go`
- Regen: `internal/debt/ent/*`

**Interfaces:**
- Produces:debt ent client 含 contact/contract_ref/collection_account_id;DebtProgressSnapshot ent client(id/tenant_id/debt_id/snapshot_date/total_principal/remaining/paid_total/created_at + UNIQUE)。Task 3-5 用。

- [ ] **Step 1: debt.go 加 3 nullable 字段**

读 `internal/debt/ent/schema/debt.go`,在 Fields() 末尾加:
```go
field.String("contact").Optional().Default(""),
field.String("contract_ref").Optional().Default(""),
field.UUID("collection_account_id", uuid.UUID{}).Optional().Nillable(),
```

- [ ] **Step 2: debt_progress_snapshot.go(照 goal_progress_snapshot.go)**

读 `internal/goal/ent/schema/goal_progress_snapshot.go` 作模板(确认 TenantMixin + Unique index 写法)。新建 `internal/debt/ent/schema/debt_progress_snapshot.go`:
```go
package schema

import (
	"time"
	"github.com/google/uuid"
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/yucai/server/internal/common/mixin" // 确认 TenantMixin 实际 import 路径(读 goal snapshot)
)

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
func (DebtProgressSnapshot) Mixin() []schema.Mixin {
	return []schema.Mixin{mixin.TenantMixin{}} // 照 goal snapshot
}
func (DebtProgressSnapshot) Indexes() []schema.Index {
	return []schema.Index{index.Unique().Fields("debt_id", "snapshot_date")}
}
```
(import 路径以 goal_progress_snapshot.go 实际为准 — 实现者先读该文件)

- [ ] **Step 3: ent generate + build**

```bash
cd /e/projects/syfinance/yucai/server && go generate ./internal/debt/...
go build ./...
```
Expected:ent 生成 DebtProgressSnapshot client;build 绿。

- [ ] **Step 4: enttest(写表 + UNIQUE 验)**

新建 `internal/debt/ent/schema/debt_progress_snapshot_test.go` 或加到现有 schema test:
```go
func TestDebtProgressSnapshotSchema(t *testing.T) {
	// enttest 建表 + 插入 2 条同 (debt_id, snapshot_date) → 第二条 ConstraintError
	// 验 contact/contract_ref/collection_account_id 可空写入 debt 表
}
```
照 `internal/holding/ent/schema/holding_snapshot_test.go` 范式(若存在)或 goal。`go test ./internal/debt/ent/... -count=1`。

- [ ] **Step 5: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/ent/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): ent debt 加 3 字段 + debt_progress_snapshot 表(Task 2)"
```

---

## Task 3: domain(DebtDetails 加字段 + NewDebtDetails 签名 + DebtProgressSnapshot entity + repo interface)

**Files:**
- Modify: `yucai/server/internal/debt/domain/entity.go`
- Modify: `yucai/server/internal/debt/domain/repository.go`
- Create: `yucai/server/internal/debt/domain/snapshot.go`
- Test: `yucai/server/internal/debt/domain/entity_test.go`

**Interfaces:**
- Consumes:Task 2 ent schema。
- Produces:`DebtDetails` 加 Contact/ContractRef/CollectionAccountID;`NewDebtDetails` 12 参数签名;`DebtProgressSnapshot` entity;`DebtRepository` 加 `SaveSnapshot/FindSnapshotRange/FindLatestByDebt`;新 `DebtSnapshotRepository` 接口。Task 4-5 用。
- **关联**:`NewDebtDetails` 全 caller 适配(debt CreateDebt borrowIn + receivable + test fake)。

- [ ] **Step 1: 写失败测试(NewDebtDetails 新签名 + 校验 + 关联)**

`entity_test.go` 加:
```go
func TestNewDebtDetailsWithContactContractCollection(t *testing.T) {
	tid, aid := uuid.New(), uuid.New()
	coll := uuid.New()
	dl := time.Now().Add(30 * 24 * time.Hour)

	// receivable(borrowedOut)带 contact/contract/collection
	d, err := NewDebtDetails(tid, aid, "李四", 8.0, AmortizationEqualPrincipalInterest,
		time.Now(), dl, 1000000, BorrowedOut, "business",
		"138****6677", "BO-2026-0215.pdf", &coll)
	if err != nil || d.Contact != "138****6677" || d.ContractRef != "BO-2026-0215.pdf" || *d.CollectionAccountID != coll {
		t.Fatalf("receivable: err=%v d=%+v", err, d)
	}

	// borrowIn 传空(nil collection)OK
	d2, err := NewDebtDetails(tid, aid, "房贷", 4.5, AmortizationEqualPrincipalInterest,
		time.Now(), dl, 5000000, BorrowedIn, "",
		"", "", nil)
	if err != nil || d2.Contact != "" || d2.CollectionAccountID != nil {
		t.Fatalf("borrowIn: err=%v d2=%+v", err, d2)
	}
}
```

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/debt/domain/ -run NewDebtDetailsWithContact -v -count=1
```
Expected:FAIL(NewDebtDetails 签名不匹配 / Contact undefined)。

- [ ] **Step 3: 改 entity.go(DebtDetails 加字段 + NewDebtDetails 签名扩)**

```go
type DebtDetails struct {
	// ... 现有字段 ...
	Contact            string
	ContractRef        string
	CollectionAccountID *uuid.UUID
}

func NewDebtDetails(
	tenantID, accountID uuid.UUID,
	counterparty string,
	interestRate float64,
	method AmortizationMethod,
	startDate, dueDate time.Time,
	totalPrincipalCents int64,
	debtType DebtType,
	subtype string,
	contact string,
	contractRef string,
	collectionAccountID *uuid.UUID,
) (*DebtDetails, error) {
	// ... 现有校验(counterparty/totalPrincipal/interestRate/dueDate)...
	// contact/contractRef 透传(可选,无校验);collectionAccountID 透传(receivable 必填校验放 application CreateDebt 而非 domain,domain 允许 nil)
	return &DebtDetails{
		// ... 现有 ...
		Contact: contact, ContractRef: contractRef, CollectionAccountID: collectionAccountID,
	}, nil
}
```

- [ ] **Step 4: 新建 snapshot.go(DebtProgressSnapshot entity)**

```go
package domain

import (
	"time"
	"github.com/google/uuid"
)

type DebtProgressSnapshot struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	DebtID              uuid.UUID
	SnapshotDate        time.Time
	TotalPrincipalCents int64
	RemainingCents      int64
	PaidTotalCents      int64
	CreatedAt           time.Time
}
```

- [ ] **Step 5: 改 repository.go(DebtRepository 加 snapshot 方法 + 新接口)**

读 `internal/debt/domain/repository.go`,加到 `DebtRepository` interface(或独立接口,决策:独立 `DebtSnapshotRepository` 更干净,照 holding snapshot repo 模式):
```go
type DebtSnapshotRepository interface {
	SaveSnapshot(ctx context.Context, snap *DebtProgressSnapshot) error
	FindLatestByDebt(ctx context.Context, tenantID, debtID uuid.UUID, asOf time.Time) (*DebtProgressSnapshot, error)
	FindSnapshotRange(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID, from, to time.Time) ([]DebtProgressSnapshot, error)
}
```

- [ ] **Step 6: 关联 — grep 全 NewDebtDetails caller 适配**

```bash
grep -rn "NewDebtDetails(" /e/projects/syfinance/yucai/server --include="*.go"
```
每个 caller 加 3 参数:
- `internal/debt/application/service.go` CreateDebt:从 CreateDebtRequest 读 Contact/ContractRef/CollectionAccountID(uuid.Parse,空 → nil)传
- borrowIn 调用点(debt 模块,若无单独 borrowIn CreateDebt 则同 service.go):透传 req 字段(borrowIn 数据这些空)
- **所有 test**:debt domain/application test 的 NewDebtDetails 调用加 `"", "", nil`(borrowIn 测)或真值(receivable 测)

- [ ] **Step 7: 跑 domain 测 + 全量 build(验关联)**

```bash
go test ./internal/debt/domain/... -count=1
go build ./...
```
Expected:domain 测 PASS;build 绿(全 caller 适配)。**若 build 红是 caller 漏适配 → grep 补**。

- [ ] **Step 8: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/domain/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): domain DebtDetails 加 3 字段 + NewDebtDetails 签名 + DebtProgressSnapshot + 关联 caller 适配(Task 3)"
```

---

## Task 4: repo 实现(debt_repo 新字段 + snapshot_repo)

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driven/repository/debt_repo.go`
- Create: `yucai/server/internal/debt/adapter/driven/repository/debt_snapshot_repo.go`
- Test: `internal/debt/adapter/driven/repository/debt_repo_test.go` + `debt_snapshot_repo_test.go`

**Interfaces:**
- Consumes:Task 2 ent + Task 3 domain。
- Produces:`debtRepo` 读写 contact/contract_ref/collection_account_id;`debtSnapshotRepo` 实现 DebtSnapshotRepository。Task 5 application 用。
- **关联**:若 DebtRepository interface 加方法 → 全 implementer(test fake)stub。本 task 用独立 DebtSnapshotRepository(规避 DebtRepository 改)。

- [ ] **Step 1: debt_repo.go 读写 3 新字段**

读 `debt_repo.go` 的 Save/FindAll/FindByID(照现有 ent ↔ domain 映射),加:
- toEnt:写 contact/contract_ref/collection_account_id
- toDomain:读 contact/contract_ref/collection_account_id(uuid.Nullable 处理:nil → domain nil)

- [ ] **Step 2: debt_snapshot_repo.go(照 holding snapshot repo)**

读 `internal/holding/adapter/driven/repository/holding_snapshot_repo.go`(或 goal)作模板:
```go
type debtSnapshotRepo struct {
	client *ent.Client // 或 *debtent.Client,看 debt ent client 命名
}

func NewDebtSnapshotRepository(client *ent.Client) domain.DebtSnapshotRepository {
	return &debtSnapshotRepo{client: client}
}

func (r *debtSnapshotRepo) SaveSnapshot(ctx context.Context, snap *domain.DebtProgressSnapshot) error {
	// upsert:ent 无 OnConflict → delete-then-insert 或 per-row create→ConstraintError→update fallback
	// 照 holding_snapshot C Task10 教训
}

func (r *debtSnapshotRepo) FindLatestByDebt(ctx context.Context, tenantID, debtID uuid.UUID, asOf time.Time) (*domain.DebtProgressSnapshot, error) {
	// WHERE tenant_id=tenantID AND debt_id=debtID AND snapshot_date <= asOf ORDER BY snapshot_date DESC LIMIT 1
}

func (r *debtSnapshotRepo) FindSnapshotRange(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID, from, to time.Time) ([]domain.DebtProgressSnapshot, error) {
	// WHERE tenant_id=tenantID AND debt_id IN debtIDs AND snapshot_date BETWEEN from AND to
}
```

- [ ] **Step 3: enttest 测**

`debt_repo_test.go`:Save 带 contact/contract/collection → FindByID 读回一致(nil/值 两路径)。
`debt_snapshot_repo_test.go`:SaveSnapshot upsert(同日重复不冲突) + FindLatestByDebt(取 <= asOf 最新) + FindSnapshotRange(区间)。
照 `holding_snapshot_repo_test.go` 范式。`go test ./internal/debt/adapter/driven/repository/... -count=1`。

- [ ] **Step 4: 全量 build + test(关联验证)**

```bash
go build ./...
go test ./internal/debt/... -count=1
```
Expected:全绿。**若跨包 fake 漏改(interface 加方法)→ 补 stub**(本 task 用独立接口,应无影响;但 grep 确认)。

- [ ] **Step 5: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/adapter/driven/repository/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): debt_repo 读写 3 字段 + debt_snapshot_repo(upsert/range)(Task 4)"
```

---

## Task 5: application(DebtToDTO next_payment + GetReceivablesSummary + SyncAllDebts + CreateDebt/UpdateDebt 透传)

**Files:**
- Modify: `yucai/server/internal/debt/application/service.go`
- Modify: `yucai/server/internal/debt/application/dto.go`
- Test: `internal/debt/application/service_test.go`

**Interfaces:**
- Consumes:Task 3 domain + Task 4 repo。
- Produces:`DebtToDTO` 填 next_payment×3 + remaining_trend + contact/contract/collection;`GetReceivablesSummary`;`SyncAllDebts`(scheduler 算子)+ 3 setter(SetSnapshotRepo)。Task 6 scheduler + Task 7 handler 用。

- [ ] **Step 1: 写失败测试(3 函数)**

`service_test.go` 加:
```go
func TestDebtToDTOFillsNextPayment(t *testing.T) {
	// debt schedule:3 entries,entry[1] !paid 最早 → next_payment = entry[1]
	// debt contact/contract/collection 透传
}

func TestGetReceivablesSummary(t *testing.T) {
	// 3 borrowedOut debts + fakeSnapshotRepo(本月/上月)
	// 验 totalPrincipal/remaining/collected/pendingInterest/count/overdue + trend + next_payment(全局最早)
}

func TestSyncAllDebts(t *testing.T) {
	// fakeRepo 3 debts + fakeSnapshotRepo
	// 验 per-debt snapshot 写入(remaining/paidTotal)+ best-effort(err skip)
}
```

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
go test ./internal/debt/application/ -run "NextPayment|ReceivablesSummary|SyncAllDebts" -v -count=1
```
Expected:FAIL(函数 undefined)。

- [ ] **Step 3: service.go 加字段 + 3 setter + 3 函数**

```go
type Service struct {
	debtRepo    domain.DebtRepository
	snapshotRepo domain.DebtSnapshotRepository // nil = snapshot skip
	// ... 现有 ...
}

func (s *Service) SetSnapshotRepo(r domain.DebtSnapshotRepository) { s.snapshotRepo = r }

// DebtToDTO 填 next_payment(最早 !paid entry)+ contact/contract/collection
// remaining_trend 由 GetReceivablesSummary/snapshot 算(单 debt DTO 算时无 snapshot 上下文 → 0 或单独算)
func DebtToDTO(d *domain.DebtDetails) *pb.DebtDTO {
	// ... 现有映射 ...
	// next_payment:
	var nextEntry *domain.PaymentScheduleEntry
	for i := range d.Schedule {
		if !d.Schedule[i].Paid {
			nextEntry = &d.Schedule[i]; break
		}
	}
	if nextEntry != nil {
		dto.NextPaymentDate = nextEntry.PaymentDate.Format("2006-01-02")
		dto.NextPaymentAmountCents = nextEntry.TotalCents
		dto.NextPaymentPeriodNo = int32(index + 1) // 实现者用真 index
	}
	dto.Contact = d.Contact
	dto.ContractRef = d.ContractRef
	if d.CollectionAccountID != nil {
		dto.CollectionAccountId = d.CollectionAccountID.String()
	}
	return dto
}

// GetReceivablesSummary
func (s *Service) GetReceivablesSummary(ctx context.Context, tenantID uuid.UUID) (*pb.ReceivablesSummaryDTO, error) {
	debts, _ := s.debtRepo.FindAll(ctx, tenantID, domain.BorrowedOut) // 确认 FindAll filter 签名
	// 聚合 totalPrincipal/remaining/collected/pendingInterest/count/overdue
	// trend:snapshotRepo.FindLatestByDebt 本月 vs 上月 → Σ principal_trend/remaining_trend
	// next_payment:跨所有 debts schedule 全局最早 !paid
}

// SyncAllDebts scheduler 算子(照 goal SyncAllGoals)
func (s *Service) SyncAllDebts(ctx context.Context, tenantID uuid.UUID) (int, error) {
	debts, err := s.debtRepo.FindAll(ctx, tenantID, 0) // 全部 debt(不分方向,通用 snapshot)
	if err != nil { return 0, err }
	count := 0
	for _, d := range debts {
		remaining := d.RemainingPrincipal()
		paidTotal := d.TotalPrincipalCents - remaining
		snap := &domain.DebtProgressSnapshot{
			ID: uuid.New(), TenantID: tenantID, DebtID: d.ID,
			SnapshotDate: truncateToDate(time.Now()),
			TotalPrincipalCents: d.TotalPrincipalCents,
			RemainingCents: remaining, PaidTotalCents: paidTotal,
		}
		if err := s.snapshotRepo.SaveSnapshot(ctx, snap); err != nil {
			slog.Warn("debt snapshot save failed", "debt_id", d.ID.String(), "error", err.Error())
			continue
		}
		count++
	}
	return count, nil
}
```

CreateDebt/UpdateDebt:透传 req.Contact/ContractRef/CollectionAccountID 到 NewDebtDetails(空 collection → nil)。

- [ ] **Step 4: dto.go 加字段(若 DTO struct 单独)**

application 的 DebtToDTO 返 proto,若中间用 application DTO struct,加对应字段。

- [ ] **Step 5: 跑测试 + 全量 build**

```bash
go test ./internal/debt/application/... -count=1
go build ./...
```
Expected:PASS + build 绿。

- [ ] **Step 6: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/application/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): DebtToDTO next_payment + GetReceivablesSummary + SyncAllDebts(Task 5)"
```

---

## Task 6: scheduler(DebtScheduler 照 goal)

**Files:**
- Create: `yucai/server/internal/debt/scheduler/scheduler.go`
- Test: `internal/debt/scheduler/scheduler_test.go`

**Interfaces:**
- Consumes:Task 5 SyncAllDebts。
- Produces:`NewScheduler(syncer, lister, src)` + Start/SyncNow。Task 7 wire 用。
- 复用 goal scheduler 模式 1:1。

- [ ] **Step 1: 读 goal scheduler 作模板**

```bash
cat yucai/server/internal/goal/scheduler/scheduler.go
```

- [ ] **Step 2: 写 scheduler.go(照 goal 1:1,改 SyncAllGoals → SyncAllDebts)**

3 本地接口(包内,不 import auth/goal):
```go
type DebtSyncer interface {
	SyncAllDebts(ctx context.Context, tenantID uuid.UUID) (int, error)
}
type TenantLister interface {
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
}
type IntervalSource interface {
	MinIntervalHours() int
}
type Scheduler struct { ... } // 照 goal
func NewScheduler(syncer DebtSyncer, lister TenantLister, src IntervalSource) *Scheduler
func (s *Scheduler) Start() / SyncNow() / doSync() // doSync: FindAllIDs → per-tenant SyncAllDebts → Σ;per-tenant err continue
```

- [ ] **Step 3: 5 测(照 goal scheduler_test.go 1:1)**

atomic + waitForCalls + fan-out(TestSyncNowContinuesPastTenantError)。`go test ./internal/debt/scheduler/... -count=1`。

- [ ] **Step 4: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/scheduler/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): DebtScheduler(照 goal fan-out per-tenant)(Task 6)"
```

---

## Task 7: handler + wire + main + server e2e

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`
- Modify: `yucai/server/wire/providers.go` + `wire/wire_gen.go`(手改)
- Modify: `yucai/server/cmd/server/app.go` + `cmd/server/main.go`
- Test: `internal/debt/adapter/driving/grpc/debt_handler_test.go`

**Interfaces:**
- Consumes:Task 5 service + Task 6 scheduler。
- Produces:`GetReceivablesSummary` handler(替 Unimplemented 默认);wire 注入 snapshotRepo + DebtScheduler;main go Start。server 端闭环。

- [ ] **Step 1: handler GetReceivablesSummary(照 goal SyncInvestmentGoals handler 模式)**

```go
func (h *DebtHandler) GetReceivablesSummary(ctx context.Context, req *pb.GetReceivablesSummaryRequest) (*pb.ReceivablesSummaryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.GetReceivablesSummary(ctx, tenantID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	return &pb.ReceivablesSummaryResponse{Summary: dto}, nil
}
```

- [ ] **Step 2: handler test(ReturnsSummary + Unauthenticated)**

照 `debt_handler_test.go` 现有 harness(real Service + fakeRepo/fakeSnapshotRepo)。`go test ./internal/debt/adapter/driving/grpc/... -count=1`。

- [ ] **Step 3: providers.go**

读 `wire/providers.go` 现有 provideDebtService。加:
```go
func provideDebtSnapshotRepo(client *ent.Client) domain.DebtSnapshotRepository {
	return repository.NewDebtSnapshotRepository(client)
}
func provideDebtScheduler(svc *debtapp.Service, lister domain.TenantLister, src IntervalSource) *scheduler.Scheduler {
	return scheduler.NewScheduler(svc, lister, src)
}
func provideReceivablesSummaryHandler(svc *debtapp.Service) *grpc.DebtHandler // 或合并到现有 provideDebtHandler
```
provideDebtService 加 snapshotRepo 参数 + `svc.SetSnapshotRepo(snapshotRepo)`。

- [ ] **Step 4: wire_gen.go 手改**

读 `wire/wire_gen.go` 现有 debt 声明,加:
```go
debtSnapshotRepo := provideDebtSnapshotRepo(client)
debtService := provideDebtService(debtRepo, ..., debtSnapshotRepo) // 加参数
debtScheduler := provideDebtScheduler(debtService, tenantRepo, tenantIntervalSource)
receivablesSummaryHandler := ...
```
**声明顺序**:debtSnapshotRepo / debtScheduler 在 debtService 适当前(若 debtService 消耗 snapshotRepo)。NewApp 加 DebtScheduler 参数。**镜像 currency/goal scheduler 模式**(见 memory `yucai-wire-handmaintained`)。

- [ ] **Step 5: app.go + main.go**

```go
// app.go
type App struct {
	// ... 现有 4 scheduler ...
	DebtScheduler *scheduler.Scheduler
}
// main.go
go app.DebtScheduler.Start() // 在 goal/holding scheduler 之后
```

- [ ] **Step 6: build + 全量 test + server 启动验证**

```bash
cd /e/projects/syfinance/yucai/server && go build ./... && go test ./... -count=1
# 启动 server(照 yucai-dev-env)
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && export JWT_SECRET='...' && export GRPC_PORT=9090 && ./bin/server.exe
```
server 启动前 rebuild:`go build -o bin/server.exe ./cmd/server`。验证:scheduler 跑(debt snapshot count>0,若有 debt 数据);无 panic。

- [ ] **Step 7: Commit**

```bash
git -C /e/projects/syfinance add yucai/server/internal/debt/adapter/driving/ yucai/server/wire/ yucai/server/cmd/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-server): GetReceivablesSummary handler + wire snapshotRepo/scheduler + main(Task 7)"
```

- [ ] **Step 8: e2e(我自做,无 commit)**

server 跑 + grpcurl GetReceivablesSummary(需 auth token,照 yucai-dev-env)。验证返 trend(若有 debt 数据)。记 progress.md。

---

## Task 8: client entity + data(Debt 加字段 + mapper + summary ds/repo)

**Files:**
- Modify: `yucai/client/lib/debt/domain/entities/debt_entity.dart`
- Create: `yucai/client/lib/debt/domain/entities/receivables_summary.dart`
- Modify: `yucai/client/lib/debt/data/debt_mapper.dart`
- Create: `yucai/client/lib/debt/data/receivables_summary_data_source.dart` + `receivables_summary_repository.dart`
- Test: `test/debt/data/`

**Interfaces:**
- Consumes:Task 1 Dart stub(DebtDTO 21 字段 + GetReceivablesSummary client)。
- Produces:`Debt` 加 7 字段;`ReceivablesSummary` entity;mapper 填新字段;summary ds/repo。Task 9-11 UI 用。

- [ ] **Step 1: debt_entity.dart 加 7 字段**

```dart
class Debt extends Equatable {
  const Debt({
    // ... 现有 ...
    this.contact = '',
    this.contractRef = '',
    this.collectionAccountId,
    this.nextPaymentDate,
    this.nextPaymentAmountCents = 0,
    this.nextPaymentPeriodNo = 0,
    this.remainingTrendCents = 0,
  });
  // ... 现有 ...
  final String contact;
  final String contractRef;
  final String? collectionAccountId;
  final DateTime? nextPaymentDate;
  final int nextPaymentAmountCents;
  final int nextPaymentPeriodNo;
  final int remainingTrendCents;
  @override List<Object?> get props => [...现有..., contact, contractRef, collectionAccountId, nextPaymentDate, nextPaymentAmountCents, nextPaymentPeriodNo, remainingTrendCents];
}
```

- [ ] **Step 2: receivables_summary.dart(照 holding GoalView / budget BudgetView Equatable)**

13 字段对齐 ReceivablesSummaryDTO + getters(totalRemaining, progressPct 等)。

- [ ] **Step 3: debt_mapper.dart 填新字段**

```dart
Debt debtDtoToEntity(DebtDTO dto) {
  return Debt(
    // ... 现有 ...
    contact: dto.contact,
    contractRef: dto.contractRef,
    collectionAccountId: dto.collectionAccountId.isEmpty ? null : dto.collectionAccountId,
    nextPaymentDate: dto.nextPaymentDate.isEmpty ? null : DateTime.tryParse(dto.nextPaymentDate),
    nextPaymentAmountCents: dto.nextPaymentAmountCents.toInt(),
    nextPaymentPeriodNo: dto.nextPaymentPeriodNo,
    remainingTrendCents: dto.remainingTrendCents.toInt(),
  );
}
```
**注意 debt 模块(borrowedIn)mapper 也用此函数** → borrowIn 数据新字段空/0,自动适配。

- [ ] **Step 4: receivables_summary_data_source.dart(照 holding GoalViewDataSource)**

```dart
@LazySingleton
class ReceivablesSummaryDataSource {
  ReceivablesSummaryDataSource(this._client, this._retry);
  final GrpcClient _client;
  final AuthRetryCaller _retry;
  Future<ReceivablesSummary> fetch() async {
    final resp = await _retry.call((c) =>
      DebtServiceClient(c).getReceivablesSummary(GetReceivablesSummaryRequest()));
    return _summaryToEntity(resp.summary);
  }
}
```

- [ ] **Step 5: receivables_summary_repository.dart(abstract + impl _guard,照 holding repo)**

- [ ] **Step 6: build_runner + 测**

```bash
cd /e/projects/syfinance/yucai/client && dart run build_runner build --delete-conflicting-outputs
flutter test test/debt/data/
flutter analyze lib/debt 2>&1 | grep -E "error -" | grep -v pbserver
```
测:mapper 7 字段(Int64→int,空处理)+ summary ds response-wiring + repo success/failure。

- [ ] **Step 7: Commit**

```bash
git -C /e/projects/syfinance add yucai/client/lib/debt/domain/entities/ yucai/client/lib/debt/data/ yucai/client/test/debt/data/
git -C /e/projects/syfinance commit -m "feat(holding-receivables-flutter): Debt 加 7 字段 + ReceivablesSummary entity + summary ds/repo(Task 8)"
```

---

## Task 9: list_page(L1-L4)

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/receivables_page.dart`
- Test: `test/debt/presentation/pages/receivables_page_test.dart`

**Interfaces:**
- Consumes:Task 8 Debt(新字段)+ ReceivablesSummary Repo。
- Produces:list 页对齐 OD(L1 avatar / L2 stat strip / L3 横向 row + foot / L4 trend + 4-seg)。

- [ ] **Step 1: L1 — `_ReceivableCard` 加 44px avatar tile**

升级现有 `_fullCard`:头部 `Row` 加 avatar(债务人首字 `counterparty.characters.first`,类型色:_inferBadge 已返商业蓝/亲友绿/私人金/其他 gray;**加 other gray 色** `Color(0xFF7A776E)`)。

- [ ] **Step 2: L2 — overview 下加 `_StatStrip`(4-card)**

```dart
Widget _statStrip(ReceivablesSummary s, String preferred) {
  return GridView.count(crossAxisCount: 4, ...,
    children: [
      _StatCard('债权笔数', '${s.count}', sub: '私人·商业·亲友'),
      _StatCard('已收本息', _fmtSymbol(s.totalCollectedCents, preferred), color: positive),
      _StatCard('待收利息', _fmtSymbol(s.pendingInterestCents, preferred)),
      _StatCard('逾期应收', _fmtSymbol(s.overdueAmountCents, preferred), color: negative, sub: '${s.overdueCount} 笔'),
    ]);
}
```
**多币种**:_fmtSymbol 用 `currencySymbol(preferred)`(禁硬编码 ¥);数据来源 summary(server 已折算 preferred 或原币 — client 折算)。

- [ ] **Step 3: L3 — 卡片改横向 4-col row + foot callout**

`_fullCard` 内部改 4-col `Row`(avatar+name+badge | 剩余应收大字 | 收回进度+已收 | meta2 利率/到期)+ foot(下次收款 `debt.nextPaymentDate/Amount/PeriodNo` + 逾期天数 + 收款 CTA)。mobile 保留 `_compactCard`(竖向,但加 avatar)。

- [ ] **Step 4: L4 — overview trend + breakdown + 下次收款 callout + 4-seg**

`_OverviewCard` 加:
- trend「较上月」(`summary.principalTrendCents`,正绿负红,`_fmtSymbol` 带 +/− 符号)
- 待收利息 breakdown(剩余应收下「含待收利息 ¥X」)
- foot callout(下次收款 `summary.nextPaymentDate/Amount/Counterparty/PeriodNo` + "查看收款计划" CTA → push detail)
- `_ListFilterSegmented` 加「逾期」tab(`_ListFilter` enum 加 overdue;过滤 `dueDate < now && !settled`)

- [ ] **Step 5: initState 加载 summary**

```dart
ReceivablesSummary? _summary;
@override void initState() {
  super.initState();
  context.read<DebtBloc>().add(const LoadDebtsRequested(typeFilter: DebtType.borrowedOut));
  _loadSummary();
}
Future<void> _loadSummary() async {
  final repo = getIt<ReceivablesSummaryRepository>();
  final result = await repo.fetch();
  if (!mounted) return;
  result.fold((_) => null, (s) => setState(() => _summary = s));
}
```
UI:`_summary == null` 时 stat strip/trend 显 loading/—(不阻塞列表)。

- [ ] **Step 6: widget test**

```dart
// seed Debt 4 笔(张三/李四/王五/赵六 mock,带 nextPayment*字段)+ ReceivablesSummary mock
// 验:avatar tile 渲染(find.text('张'))/ stat strip 4 卡 / 横向 row foot callout / overview trend / 筛选 4-seg(逾期 tab)
```
`flutter test test/debt/presentation/pages/receivables_page_test.dart`。

- [ ] **Step 7: analyze + commit**

```bash
flutter analyze lib/debt test/debt 2>&1 | grep -E "error -" | grep -v pbserver
git -C /e/projects/syfinance add yucai/client/lib/debt/presentation/pages/receivables_page.dart yucai/client/test/debt/presentation/pages/receivables_page_test.dart
git -C /e/projects/syfinance commit -m "feat(holding-receivables-flutter): list 对齐 OD(avatar/stat-strip/横向 row+foot/trend+4-seg)(Task 9)"
```

---

## Task 10: detail_page(D1-D4)

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/receivable_detail_page.dart`
- Test: `test/debt/presentation/pages/receivable_detail_page_test.dart`

**Interfaces:**
- Consumes:Task 8 Debt(含 remainingTrendCents/contact/contractRef/collectionAccountId)。
- Produces:detail 页对齐 OD(D1 hero 双列 / D2 5-stat 金额 / D3 side panel / D4 行内确认)。

- [ ] **Step 1: D1 — hero 改双列(avatar + delta + 4-tile)**

`_hero` 改 `Row`(左:avatar 50px + name + delta pill「↓¥X 较上月减少」用 `debt.remainingTrendCents` + 剩余应收大字 + progress;右:`_heroSide` 4-tile grid 年利率/月供/到期/已收期数)。mobile 单列(avatar + delta + 4-tile 2×2)。

- [ ] **Step 2: D2 — `_statsRow` 改金额维度(从 schedule 聚合)**

```dart
final paidPrincipal = detail.schedule.where((e) => e.paid).fold(0, (s,e) => s + e.principalCents);
final paidInterest = detail.schedule.where((e) => e.paid).fold(0, (s,e) => s + e.interestCents);
final pendingPrincipal = debt.totalPrincipalCents - paidPrincipal - ... ; // 或 schedule unpaid Σ
final overdue = detail.schedule.where((e) => e.status == overdue && !e.paid);
final stats = [
  _Stat('借出本金', _fmtSymbol(debt.totalPrincipalCents, preferred)),
  _Stat('已收合计', _fmtSymbol(paidPrincipal+paidInterest, preferred), color: positive),
  _Stat('待收合计', _fmtSymbol(pending..., preferred)),
  _Stat('累计利息收入', _fmtSymbol(paidInterest, preferred), color: positive),
  _Stat('逾期应收', _fmtSymbol(overdue Σ, preferred), color: negative, sub: '${overdue.length} 期'),
];
```

- [ ] **Step 3: D3 — body 加右侧 side panel**

`_body` 改 `Row`(左 expanded:hero + stats + schedule;右 320 fixed:`_sidePanel`)。
```dart
Widget _sidePanel(DebtDetail detail) {
  return Column(children: [
    // 收款账户卡:收款至 collectionAccountId 解析账户名(需 _accounts lookup) / 应收账户 accountId 名
    // 借款信息卡:债务人/联系方式 debt.contact/借出/到期/摊还/合同 debt.contractRef
  ]);
}
```
**多币种**:金额 `_fmtSymbol(_, preferred)`。

- [ ] **Step 4: D4 — 确认收款改行内 link-btn 直接确认(无 dialog)**

`_scheduleAction` 待收/逾期分支:
```dart
if (debt.collectionAccountId != null && debt.collectionAccountId!.isNotEmpty) {
  // 真·行内:dispatch RecordPayment(from=collectionAccountId)→ toast
  return OutlinedButton.icon(
    onPressed: () {
      context.read<DebtBloc>().add(RecordPaymentRequested(
        debtId: widget.id, scheduleEntryId: e.id,
        fromAccountId: debt.collectionAccountId!,
      ));
      AppToast.show(context, '已确认收款 ¥${e.totalCents/100}', type: ToastType.success);
    },
    icon: Icon(LucideIcons.check, size: 13),
    label: Text('确认收款'),
    style: overdue ? negativeStyle : goldStyle,
  );
}
// fallback:collection 为空 → 保留现有 dialog(防御,legacy 数据)
return _existingDialogFlow(e);
```
删 `_ConfirmReceiptDialog` 主路径(保留作 fallback)。

- [ ] **Step 5: widget test**

```dart
// seed DebtDetail:debt 带 remainingTrendCents/contact/contractRef/collectionAccountId + schedule 12 期
// 验:hero avatar + delta pill + 4-tile / 5-stat 金额(green/red)/ side panel(收款账户 + 借款信息 contact/contract)/ 行内确认收款(tap → dispatch RecordPayment + toast,无 dialog)
```
`flutter test test/debt/presentation/pages/receivable_detail_page_test.dart`。

- [ ] **Step 6: analyze + commit**

```bash
flutter analyze lib/debt test/debt 2>&1 | grep -E "error -" | grep -v pbserver
git -C /e/projects/syfinance add yucai/client/lib/debt/presentation/pages/receivable_detail_page.dart yucai/client/test/debt/presentation/pages/receivable_detail_page_test.dart
git -C /e/projects/syfinance commit -m "feat(holding-receivables-flutter): detail 对齐 OD(hero 双列/5-stat 金额/side panel/行内确认)(Task 10)"
```

---

## Task 11: form_page(F1-F2 + 3 字段输入)

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart`
- Test: `test/debt/presentation/pages/receivable_form_page_test.dart`

**Interfaces:**
- Consumes:Task 8 Debt。
- Produces:form 对齐 OD(F1 radio cards / F2 preview 2×2 sum / contact+contract+collection 输入)。

- [ ] **Step 1: F1 — `_RadioChip` 升级为 `_RadioCard`(icon tile + desc)**

```dart
class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.icon, required this.label, this.desc, required this.selected, required this.onTap});
  final IconData icon; final String label; final String? desc; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    // 32px icon tile(选中 gold 实心)+ label + desc(可选)
  }
}
```
类型 4(私人 LucideIcons.user / 商业 briefcase / 亲友 users / 其他 help-circle)+ 摊还 3(等额本息"每期合计相同" / 等额本金"本金相同 利息递减" / 一次性"到期一次结清")。

- [ ] **Step 2: F2 — `_CollectionPreview` 加 pv-sum 2×2 grid**

`_header()` 下加 `_sumGrid()`:
```dart
Widget _sumGrid(_Preview p) {
  return GridView.count(crossAxisCount: 2, shrinkWrap: true, ...,
    children: [
      _sumCell('月供/期供', _fmtYuan(p.headlineAmount), gold),
      _sumCell('总利息收入', _fmtYuan(p.totalInterest), green),
      _sumCell('期数', '${p.n} 期'),
      _sumCell('总还款', _fmtYuan(p.totalPayment), gold),
    ]);
}
```
替代现有 tags(`_tag` 调用)。

- [ ] **Step 3: 加 contact + contract_ref + collection_account_id 输入**

基本信息 section 加:
- `contact` TextFormField(可选,"联系方式")
- `contract_ref` TextFormField(可选,"合同/借据编号")
- `collection_account_id` DropdownButtonFormField(asset active 列表,创建模式必填;默认 = `_sourceAccountId` 或用户选;编辑模式预填 `debt.collectionAccountId`)
```dart
final _contactCtrl = TextEditingController();
final _contractRefCtrl = TextEditingController();
String? _collectionAccountId;
```
`_submit()`:CreateDebtRequested 透传 `contact: _contactCtrl.text` `contractRef: _contractRefCtrl.text` `collectionAccountId: _collectionAccountId`(UpdateDebt 同;校验 collection 创建模式必填)。

- [ ] **Step 4: widget test**

```dart
// 验:radio cards 渲染(icon+desc)/ preview 2×2 sum grid / contact+contract+collection 输入 + 提交透传(CreateDebtRequested 带 collectionAccountId)
```
`flutter test test/debt/presentation/pages/receivable_form_page_test.dart`。

- [ ] **Step 5: analyze + commit**

```bash
flutter analyze lib/debt test/debt 2>&1 | grep -E "error -" | grep -v pbserver
git -C /e/projects/syfinance add yucai/client/lib/debt/presentation/pages/receivable_form_page.dart yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart
git -C /e/projects/syfinance commit -m "feat(holding-receivables-flutter): form 对齐 OD(radio cards/preview 2×2 sum/contact+contract+collection 输入)(Task 11)"
```

---

## Task 12: 全链路 + final review

**Files:** 无新改动(验证 + review)

- [ ] **Step 1: server 全量 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./... -count=1 && go build ./...
```
Expected:全绿(206+ 包,新增 debt scheduler/snapshot 包)。

- [ ] **Step 2: client 全量 + analyze**

```bash
cd /e/projects/syfinance/yucai/client && flutter test && flutter analyze 2>&1 | grep -E "error -" | grep -v "pbserver\|\.pb\.dart"
```
Expected:仅 3 预存 fail(account/debt/transaction_detail_page);analyze 非 pbserver error=0。**debt 套件全绿(含 receivables 3 页 + debt borrowIn 回归)**。

- [ ] **Step 3: e2e(app)验证**

启 flutter client(windows debug)+ server。创建债权(填 contact/contract/collection)→ list 看 avatar/stat-strip/trend/横向 row → detail 看 hero 双列/5-stat/side panel/行内确认收款(toast)→ form 看 radio cards/preview 2×2。

- [ ] **Step 4: final whole-branch review(opus,f0b0c1d..HEAD)**

review 范围 = receivables 对齐起点(spec 修订后 `f0b0c1d`)→ HEAD。照 goal/holding final review:correctness 抽样(snapshot trend 算法 / next_payment / collection 双写 / 多币种不硬编码 / 行内确认 / 关联 debt borrowIn 不破)+ defer 项。Ready to merge 判定。

- [ ] **Step 5: 记 progress.md + 更新 memory**

`.superpowers/sdd/progress.md` 加 receivables align section。memory `ui-align-visual-companion-workflow` 更新 receivables ✅(下个优先级:transaction #2)。

---

## Self-Review

**Spec coverage**:
- A1 proto(DebtDTO 15-21 + CreateDebt 11-13 + UpdateDebt 5-7 + summary RPC)→ Task 1 ✓
- A2 ent(debt 3 字段 + snapshot 表)→ Task 2 ✓
- A3 domain(DebtDetails + NewDebtDetails + DebtProgressSnapshot + interface)→ Task 3 ✓
- A4 application(DebtToDTO next_payment + summary + SyncAllDebts + 透传)→ Task 5 ✓
- repo 实现 → Task 4 ✓
- A5 handler → Task 7 ✓
- A6 scheduler → Task 6 ✓
- A7 wire/main → Task 7 ✓
- B1 stub regen → Task 1(含)✓
- B2 entity → Task 8 ✓
- B3 data → Task 8 ✓
- B4 list(L1-L4)→ Task 9 ✓
- B5 detail(D1-D4)→ Task 10 ✓
- B6 form(F1-F2 + 字段)→ Task 11 ✓
- 关联清单(NewDebtDetails caller + interface implementer + debt borrowIn 适配)→ Task 3/4 + 每 task 全量测 ✓
- 多币种(Global Constraint #11)→ Task 9/10/11 UI `_fmtSymbol(_, preferred)` + summary 折算 ✓
- 测试 → 每 task TDD ✓

**Placeholder**:无 TBD;server Go 代码给关键算法(proto/ent/domain/scheduler/handler),实现者照 goal/holding 范式补全;client Dart 给关键 widget,照 receivables 现有升级。

**Type consistency**:`NewDebtDetails` 12 参数(Task 3)→ CreateDebt caller 透传(Task 5);`DebtSnapshotRepository` 接口(Task 3)→ ent repo 实现(Task 4)→ service.SetSnapshotRepo(Task 5)→ wire(Task 7);Debt 7 字段(Task 8)→ list/detail/form 读;`remaining_trend_cents`(Task 1 proto)→ mapper(Task 8)→ detail delta(Task 10)。一致。

## 风险(执行时)
- ent 无 OnConflict → snapshot upsert 用 delete-then-insert / create→ConstraintError→update(Task 4,照 holding C Task10)
- NewDebtDetails 签名改 → grep 全 caller(Task 3 Step 6,含 test)
- wire 声明顺序(snapshotRepo/scheduler 在 debtService 适当前;Task 7)
- proto regen 无网 fallback(Task 1)
- D4 行内确认 collection_account_id 为空(legacy)→ fallback dialog(Task 10 Step 4 防御)
- 多币种:summary trend 折算需 server 算(Task 5 GetReceivablesSummary 折算 preferred 或原币 Σ;snapshot 存原币)
