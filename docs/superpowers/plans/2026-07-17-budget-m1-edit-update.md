# budget M1 · edit delete+recreate → UpdateBudget · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 budget 编辑(整体 name+currency+items)的 **DeleteBudget + CreateBudget(delete+recreate)** 改成真正的 **`UpdateBudget` RPC**(单 RPC、原子、budget ID 不变),根除 ID 变 / 竞态 / 非原子。

**Architecture:** 自底向上 + 端到端:server domain `Budget.Update`(校验+替换 items+重算 total+IncrementVersion)+ repo `Update` 补 `SetCurrencyCode`/修 delete err → proto `UpdateBudget` RPC + Go regen + application `Service.UpdateBudget` + handler → client Dart regen + remote_ds/repo/bloc + form `_submit` 改用 update + month 锁 + 去 `_editCreateCount` hack。**month 不可改**(proto 无 month + form disabled);**items 全量替换**(repo 删旧+建新,item ID 变但 budget ID 稳);**version 锁 server 端**(repo `WHERE Version(v-1)`,client 不传 version,照 budget `AddBudgetItem`/`RemoveBudgetItem` 现状)。

**Tech Stack:** Go(ent + DDD 四层 + wire 手改判定本次**不改**)· proto3(Go+Dart stub regen,protoc_plugin 25.0.0)· Flutter(flutter_bloc + injectable)· TDD

---

## Global Constraints

(每个 task 隐含包含;从 spec §3/§9 + CLAUDE.md 提取)

1. **英文结构化日志** —— slog,log 串**无 CJK**。
2. **proto regen**:Go `cd yucai/server && buf generate --template buf.gen.go.yaml`(无网 fallback:本地 protoc + protoc-gen-go/-grpc,手修 `package budgetv1`);Dart `cd yucai && make gen-dart`(**protoc_plugin 25.0.0**,21.x 格式化全 .pb.dart 坏)。改 proto 后 **Go + Dart stub 都 regen**。
3. **proto UpdateBudget RPC 照现有风格,无 `google.api.http` option** —— 现有 9 RPC 都是纯 gRPC(proto 未 import `google/api/annotations.proto`),加 http option 会编译错。
4. **month 锁** —— `UpdateBudgetRequest` **无 month 字段**;form edit 时 month picker disabled。双向保证(proto 无 field + UI 禁用)。
5. **items 全量替换** —— repo `Update` 删旧 items + 建新(item ID 变,**budget ID 稳定** —— M1 主目标)。actuals 读时算(M2 batch)无 item 级持久引用,用户无感。
6. **version 锁 server 端** —— repo `Where(budget.Version(b.Version - 1))`,**client 不传 version**(照 budget `AddBudgetItem`/`RemoveBudgetItem` 现状;与 debt/template 传 version 不同)。`domain.Update` → `IncrementVersion`(v→v+1),repo `WHERE Version(v)`(=(v+1)-1)匹配。
7. **wire 不改** —— `NewService` 签名 M2 已加 `entryMonthFunc`,M1 不动 → `providers.go` + `wire_gen.go` **不改**(memory `yucai-wire-handmaintained` 无触发)。
8. **约束 6** —— `BudgetRepository` interface **无新方法**(`Update` 已存在)→ 无 implementer 影响。proto 加 RPC → regen 自动给 `UnimplementedBudgetServiceServer` 加默认方法(handler 替换它)。**NewService 不变** → 无调用方迁移(M2 教训:签名变更 grep 全调用方含 tests/ 集成测;本次无签名变更)。
9. **commit message 用 multi `-m` flag**(Bash 工具下 PowerShell here-string 解析成 literal `@`,budget M2 Task 2 踩过)。
10. **TDD + frequent commits** —— 每 task:red test → green → commit。conventional commit `feat(scope): ...`。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [budget/domain/entity.go](../../yucai/server/internal/budget/domain/entity.go) | `Budget` aggregate | +`Update(name, currencyCode, items)` 方法 |
| [budget/domain/domain_test.go](../../yucai/server/internal/budget/domain/domain_test.go) | domain 单测 | +`TestBudget_Update` |
| [budget/adapter/driven/repository/budget_repo.go](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go) | ent repo | `Update` 补 `SetCurrencyCode` + 修 delete items err 检查 |
| [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) | integration test | +`TestBudgetRepoUpdate`(Task 1 直接 repo)+ `TestBudgetUpdate`(Task 2 经 service) |
| [proto/budget/v1/budget.proto](../../yucai/proto/budget/v1/budget.proto) | proto 定义 | +`rpc UpdateBudget` + `UpdateBudgetRequest` message(无 http option) |
| server/internal/proto/budget/v1/*.pb.go(gen) | Go stub | regen(buf generate) |
| [budget/application/dto.go](../../yucai/server/internal/budget/application/dto.go) | application DTO | +`UpdateBudgetRequest` struct |
| [budget/application/service.go](../../yucai/server/internal/budget/application/service.go) | `Service` | +`UpdateBudget(ctx, UpdateBudgetRequest) (*BudgetDTO, error)` |
| [budget/adapter/driving/grpc/budget_handler.go](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go) | gRPC handler | +`UpdateBudget` handler |
| client/lib/proto/budget/v1/*.pb*.dart(gen) | Dart stub | regen(make gen-dart,protoc_plugin 25.0.0) |
| [client/lib/budget/data/budget_remote_ds.dart](../../yucai/client/lib/budget/data/budget_remote_ds.dart) | remote data source | +`updateBudget(...)` |
| [client/lib/budget/domain/repositories/budget_repository.dart](../../yucai/client/lib/budget/domain/repositories/budget_repository.dart) | abstract repo | +`updateBudget(...)` |
| [client/lib/budget/data/budget_repository_impl.dart](../../yucai/client/lib/budget/data/budget_repository_impl.dart) | repo impl | +`updateBudget(...)`(`_guard`) |
| [client/lib/budget/presentation/bloc/budget_event.dart](../../yucai/client/lib/budget/presentation/bloc/budget_event.dart) | bloc events | +`UpdateBudgetRequested` |
| [client/lib/budget/presentation/bloc/budget_bloc.dart](../../yucai/client/lib/budget/presentation/bloc/budget_bloc.dart) | bloc | +`on<UpdateBudgetRequested>` `_onUpdate` |
| [client/lib/budget/presentation/pages/budget_form_page.dart](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart) | form page | `_submit` edit 改 dispatch update;`_onBudgetStateChanged` 去 `_editCreateCount`;month picker `_isEdit` disabled;删 `_editCreateCount` field |
| client/test/budget/... | widget/bloc test | +UpdateBudgetRequested bloc test + form edit 路径 test |

---

## Task 1: server domain `Budget.Update` + repo `Update` 补 currency/err

纯 server domain+repo,无 proto/无 interface 改动 → build 绿 + 独立测试。

**Files:**
- Modify: [budget/domain/entity.go](../../yucai/server/internal/budget/domain/entity.go)(+`Update` 方法,加在 `UpdateItemAmount` line 112 之后)
- Modify: [budget/domain/domain_test.go](../../yucai/server/internal/budget/domain/domain_test.go)(+`TestBudget_Update`)
- Modify: [budget/adapter/driven/repository/budget_repo.go](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go)(`Update` line 165-199:补 `SetCurrencyCode` + 修 delete items err)
- Modify: [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)(+`TestBudgetRepoUpdate`,直接 repo 验证 currency 持久 + items 替换 + version 锁)

**Interfaces:**
- Consumes: 现有 `trimAndCheck` / `IncrementVersion` / `uuid.New`(entity.go);`budgetitem`/`budget` ent predicate + `r.client`(budget_repo.go);`setupBudgetTestDB` + `budgetrepo.NewBudgetRepository`(budget_integration_test.go)
- Produces: `(*Budget).Update(name, currencyCode, items)`(Task 2 `Service.UpdateBudget` 消费);repo `Update` 持久化 currency(Task 2 integration 验证)

- [ ] **Step 1: 写 domain 测试(失败态)**

追加到 [domain_test.go](../../yucai/server/internal/budget/domain/domain_test.go)(照现有 `TestBudget_AddRemoveItem` 范式):

```go
func TestBudget_Update(t *testing.T) {
	b, err := NewBudget(uuid.New(), "原预算", "2026-05", "CNY", []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
	})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	origID := b.ID
	origMonth := b.Month
	origVersion := b.Version

	err = b.Update("改名", "USD", []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if b.Name != "改名" {
		t.Errorf("name: got %q, want 改名", b.Name)
	}
	if b.CurrencyCode != "USD" {
		t.Errorf("currency: got %q, want USD", b.CurrencyCode)
	}
	if len(b.Items) != 2 {
		t.Fatalf("items: got %d, want 2 (full replace)", len(b.Items))
	}
	for _, it := range b.Items {
		if it.BudgetID != origID {
			t.Errorf("item BudgetID: got %s, want %s", it.BudgetID, origID)
		}
		if it.ID == uuid.Nil {
			t.Error("item ID not assigned")
		}
	}
	if b.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000 (30000+20000)", b.TotalAmountCents)
	}
	if b.Version != origVersion+1 {
		t.Errorf("version: got %d, want %d (bumped)", b.Version, origVersion+1)
	}
	if b.Month != origMonth {
		t.Errorf("month mutated: got %s, want %s (immutable)", b.Month, origMonth)
	}
	if b.ID != origID {
		t.Errorf("ID mutated: got %s, want %s (stable)", b.ID, origID)
	}

	// Validation: empty name → err
	if err := b.Update("   ", "USD", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}}); err == nil {
		t.Error("empty name: expected error, got nil")
	}
	// Validation: empty items → err
	if err := b.Update("ok", "USD", []BudgetItem{}); err == nil {
		t.Error("empty items: expected error, got nil")
	}
}
```

- [ ] **Step 2: 跑测试看失败**

Run: `cd yucai/server && go test ./internal/budget/domain/... -run TestBudget_Update -count=1`
Expected: FAIL / 编译错 `b.Update undefined`

- [ ] **Step 3: 加 domain `Update` 方法**

[entity.go](../../yucai/server/internal/budget/domain/entity.go):加在 `UpdateItemAmount`(line 112)之后,`TotalActual` 之前。

```go
// Update replaces editable fields (name, currency, items) in place. Month is
// immutable (budget identity). Validates like NewBudget (name non-empty,
// items ≥ 1), reassigns item IDs/BudgetID, recomputes TotalAmountCents, and
// bumps the optimistic-lock version. Items are fully replaced — the repo
// deletes old items and inserts new ones, so item IDs change but the budget
// ID stays stable (the whole point of M1: no delete+recreate of the budget).
func (b *Budget) Update(name, currencyCode string, items []BudgetItem) error {
	name = trimAndCheck(name)
	if name == "" {
		return fmt.Errorf("budget name must not be empty")
	}
	if len(items) == 0 {
		return fmt.Errorf("budget must have at least 1 item")
	}
	var total int64
	for i := range items {
		if items[i].ID == uuid.Nil {
			items[i].ID = uuid.New()
		}
		items[i].BudgetID = b.ID
		total += items[i].PlannedAmountCents
	}
	b.Name = name
	b.CurrencyCode = currencyCode
	b.Items = items
	b.TotalAmountCents = total
	b.IncrementVersion()
	return nil
}
```

- [ ] **Step 4: 跑 domain 测试看通过**

Run: `cd yucai/server && go test ./internal/budget/domain/... -run TestBudget_Update -count=1`
Expected: PASS

- [ ] **Step 5: 修 repo `Update` 补 SetCurrencyCode + 修 delete items err**

[budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165) 整段替换:

```go
// Update persists changes to a budget (optimistic lock via version) and
// fully replaces its items (delete-all-then-insert). M1 fix: now persists
// CurrencyCode (was missing) and checks the delete-items error (was ignored).
func (r *BudgetRepository) Update(ctx context.Context, b *domain.Budget) error {
	// Delete old items (FIX: previously the error was discarded).
	if _, err := r.client.BudgetItem.Delete().
		Where(budgetitem.BudgetID(b.ID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete old budget items: %w", err)
	}

	// Insert new items (full replace — item IDs change, budget ID stable).
	for _, item := range b.Items {
		_, err := r.client.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("insert budget item: %w", err)
		}
	}

	// Update budget (FIX: added SetCurrencyCode — currency edits now persist).
	_, err := r.client.Budget.UpdateOneID(b.ID).
		Where(budget.Version(b.Version - 1)). // optimistic lock
		SetName(b.Name).
		SetCurrencyCode(b.CurrencyCode). // FIX: previously missing
		SetTotalAmountCents(b.TotalAmountCents).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update budget: %w", err)
	}
	return nil
}
```

- [ ] **Step 6: 写 repo integration 测试(直接 repo,验证 currency 持久 + items 替换 + version 锁)**

追加到 [budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)。需补 import `budgetdomain "github.com/yucai/server/internal/budget/domain"`。

```go
// TestBudgetRepoUpdate verifies the repo persists CurrencyCode on Update
// (M1 fix: previously dropped) and fully replaces items + honors the
// optimistic-lock version predicate. Exercises repo.Update directly (no
// service.UpdateBudget yet — added in Task 2).
func TestBudgetRepoUpdate(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, err := budgetdomain.NewBudget(tenantID, "原预算", "2026-05", "CNY", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
	})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}
	versionBefore := b.Version

	// Edit in place: change currency + replace items (1 → 2).
	if err := b.Update("改名", "USD", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	}); err != nil {
		t.Fatalf("Update: %v", err)
	}
	if err := repo.Update(ctx, b); err != nil {
		t.Fatalf("repo.Update: %v", err)
	}

	got, err := repo.FindByID(ctx, tenantID, b.ID)
	if err != nil {
		t.Fatalf("FindByID: %v", err)
	}
	if got.CurrencyCode != "USD" {
		t.Errorf("currency persisted: got %q, want USD (M1 fix)", got.CurrencyCode)
	}
	if got.Name != "改名" {
		t.Errorf("name: got %q, want 改名", got.Name)
	}
	if len(got.Items) != 2 {
		t.Errorf("items replaced: got %d, want 2", len(got.Items))
	}
	if got.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000", got.TotalAmountCents)
	}
	if got.Version != versionBefore+1 {
		t.Errorf("version bumped: got %d, want %d", got.Version, versionBefore+1)
	}
	if got.Month != "2026-05" {
		t.Errorf("month mutated: got %s, want 2026-05 (immutable)", got.Month)
	}
}

// TestBudgetRepoUpdate_OptimisticLock verifies a stale version is rejected:
// a second Update built from the pre-bump version must fail to match the
// WHERE version predicate.
func TestBudgetRepoUpdate_OptimisticLock(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, _ := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 10000}})
	repo.Save(ctx, b)

	// Stale snapshot: simulate a concurrent edit by bumping version once more
	// than the predicate expects. domain.Update sets Version = v+1; repo WHERE
	// matches v. If we manually set Version = v+2 without a real intervening
	// write, WHERE v+1 finds no row → error.
	stale := *b
	stale.Update("B2", "CNY", []budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 20000}})
	// Now corrupt: pretend version is one ahead of what DB has.
	stale.Version = b.Version + 2 // repo WHERE Version(stale.Version-1) = v+1, DB still v → no match
	err := repo.Update(ctx, &stale)
	if err == nil {
		t.Fatal("optimistic lock: expected error on stale version, got nil")
	}
}
```

- [ ] **Step 7: 跑测试 + 全量 build**

Run: `cd yucai/server && go test ./internal/budget/... -count=1`
Expected: PASS(domain `TestBudget_Update` + 现有 domain/application/adapter 测试)

Run: `cd yucai/server && go test ./tests/... -run TestBudget -count=1`
Expected: PASS(`TestBudgetRepoUpdate` + `TestBudgetRepoUpdate_OptimisticLock` 新增;现有 `TestBudgetCRUD`/`TestBudgetList`/`TestBudgetCloneToMonth`/`TestBudgetTenantIsolation` 不回归 —— 它们走 `AddBudgetItem`/`RemoveBudgetItem` 也调 `repo.Update`,补的 currency/err 不破坏)

Run: `cd yucai/server && go build ./...`
Expected: 成功(`BudgetRepository` interface 未改 → 无 implementer 影响;`NewService` 未改 → wire 不动)

- [ ] **Step 8: Commit**

```bash
cd yucai/server
git add internal/budget/domain/entity.go \
  internal/budget/domain/domain_test.go \
  internal/budget/adapter/driven/repository/budget_repo.go \
  tests/budget_integration_test.go
git commit -m "feat(budget/domain): Budget.Update + repo currency/err fix (M1 Task 1)" -m "Add domain Budget.Update (name+currency+items full replace, month immutable, version bump). Fix repo.Update: persist SetCurrencyCode (was dropped — currency edits silently lost) + check delete-items error (was discarded). Items fully replaced (IDs change, budget ID stable). No interface/NewService change -> wire untouched."
```

---

## Task 2: server proto `UpdateBudget` RPC + application + handler

proto regen(Go)+ DTO + service + handler + integration test(经 service 全链)。

**Files:**
- Modify: [proto/budget/v1/budget.proto](../../yucai/proto/budget/v1/budget.proto)(+RPC + message)
- Regen: `server/internal/proto/budget/v1/budget.pb.go` + `budget_grpc.pb.go`(buf generate)
- Modify: [budget/application/dto.go](../../yucai/server/internal/budget/application/dto.go)(+`UpdateBudgetRequest`)
- Modify: [budget/application/service.go](../../yucai/server/internal/budget/application/service.go)(+`UpdateBudget`)
- Modify: [budget/adapter/driving/grpc/budget_handler.go](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go)(+`UpdateBudget` handler)
- Modify: [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)(+`TestBudgetUpdate`)

**Interfaces:**
- Consumes: Task 1 `(*Budget).Update` + repo `Update`(currency fix);现有 `CreateBudget` handler 解析范式 + `mapError` + `budgetToProto` + `BudgetItemInput` DTO
- Produces: `UpdateBudget` RPC(server,Task 3 client 调用)

- [ ] **Step 1: 改 proto — 加 UpdateBudget RPC + Request(无 http option)**

[budget.proto](../../yucai/proto/budget/v1/budget.proto):service 加 RPC(line 20 `CloneBudgetToMonth` 之后)、加 message(`CloneBudgetRequest` line 100 之后)。

service(line 20 后加):
```proto
  rpc UpdateBudget(UpdateBudgetRequest) returns (BudgetResponse);
```

message(在 `CloneBudgetRequest` 之后,`BudgetResponse` 之前加):
```proto
// UpdateBudgetRequest edits a budget's editable fields in place (no ID change,
// no delete+recreate). Month is immutable (budget identity); not present here.
// items is a full replacement (old items deleted, new inserted — item IDs
// change, budget ID stable). No client version: optimistic lock is server-side
// (repo WHERE version = v-1), matching AddBudgetItem/RemoveBudgetItem.
message UpdateBudgetRequest {
  string id = 1;
  string name = 2;
  string currency_code = 3;
  repeated BudgetItemInput items = 4;
}
```

**不要加 `option (google.api.http)`** —— 现有 9 RPC 都无(proto 未 import annotations)。

- [ ] **Step 2: regen Go stub**

Run: `cd yucai/server && buf generate --template buf.gen.go.yaml`
Expected: 成功。无网 fallback:本地 `protoc --go_out=. --go-grpc_out=. proto/budget/v1/budget.proto`,手修 `package budgetv1`(全 sibling 一致)。

验证:`server/internal/proto/budget/v1/budget_grpc.pb.go` 出现 `UpdateBudget(context.Context, *UpdateBudgetRequest) (*BudgetResponse, error)` 接口方法 + `UnimplementedBudgetServiceServer.UpdateBudget` 默认实现。`budget.pb.go` 出现 `UpdateBudgetRequest` message。

- [ ] **Step 3: 写 application integration 测试(失败态)**

追加到 [budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go):

```go
// TestBudgetUpdate verifies the full UpdateBudget service path: edits a
// budget in place (name + currency + items full replace), budget ID stable,
// month immutable, version bumped + persisted. Replaces the client form's
// old delete+recreate (which changed the ID).
func TestBudgetUpdate(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	created, err := svc.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID: tenantID, Name: "原预算", Month: "2026-05", CurrencyCode: "CNY",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 50000},
		},
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}
	id := created.ID
	versionBefore := created.Version

	updated, err := svc.UpdateBudget(ctx, application.UpdateBudgetRequest{
		TenantID: tenantID, BudgetID: id,
		Name: "改名", CurrencyCode: "USD",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 30000},
			{AccountID: uuid.New(), PlannedAmountCents: 20000},
		},
	})
	if err != nil {
		t.Fatalf("UpdateBudget: %v", err)
	}
	if updated.ID != id {
		t.Errorf("ID changed: got %s, want %s (delete+recreate regression)", updated.ID, id)
	}
	if updated.Name != "改名" {
		t.Errorf("name: got %s, want 改名", updated.Name)
	}
	if updated.CurrencyCode != "USD" {
		t.Errorf("currency: got %s, want USD", updated.CurrencyCode)
	}
	if len(updated.Items) != 2 {
		t.Errorf("items: got %d, want 2", len(updated.Items))
	}
	if updated.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000", updated.TotalAmountCents)
	}
	if updated.Version != versionBefore+1 {
		t.Errorf("version: got %d, want %d", updated.Version, versionBefore+1)
	}

	// Persisted (re-fetch by the same ID — would fail under delete+recreate).
	got, err := svc.GetBudget(ctx, tenantID, id)
	if err != nil {
		t.Fatalf("GetBudget after update: %v", err)
	}
	if got.Budget.CurrencyCode != "USD" {
		t.Errorf("persisted currency: got %s, want USD", got.Budget.CurrencyCode)
	}
	if got.Budget.Month != "2026-05" {
		t.Errorf("month mutated: got %s, want 2026-05 (immutable)", got.Budget.Month)
	}
}
```

- [ ] **Step 4: 跑测试看失败**

Run: `cd yucai/server && go test ./tests/... -run TestBudgetUpdate -count=1`
Expected: FAIL / 编译错 `svc.UpdateBudget undefined` / `application.UpdateBudgetRequest undefined`

- [ ] **Step 5: 加 application DTO `UpdateBudgetRequest`**

[dto.go](../../yucai/server/internal/budget/application/dto.go):加在 `AddBudgetItemRequest`(line 33)之后(或 `CreateBudgetRequest` 之后)。

```go
// UpdateBudgetRequest holds input for editing a budget in place (M1).
type UpdateBudgetRequest struct {
	TenantID     uuid.UUID
	BudgetID     uuid.UUID
	Name         string
	CurrencyCode string
	Items        []BudgetItemInput
}
```

- [ ] **Step 6: 加 `Service.UpdateBudget`**

[service.go](../../yucai/server/internal/budget/application/service.go):加在 `AddBudgetItem`(line 112)之前(整体编辑入口,逻辑上在单 item 操作之前)。

```go
// UpdateBudget edits a budget's name/currency/items in place (no ID change,
// no delete+recreate). Month is immutable. Optimistic lock: domain.Update
// bumps version (v→v+1), repo.Update matches WHERE version = v-1, so a
// concurrent edit since FindByID is rejected. Read-time actuals are not
// recomputed here (next GetBudget computes them via the M2 batch path).
func (s *Service) UpdateBudget(ctx context.Context, req UpdateBudgetRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}
	items := make([]domain.BudgetItem, len(req.Items))
	for i, input := range req.Items {
		items[i] = domain.BudgetItem{
			AccountID:          input.AccountID,
			PlannedAmountCents: input.PlannedAmountCents,
			Notes:              input.Notes,
		}
	}
	if err := budget.Update(req.Name, req.CurrencyCode, items); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}
	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("persist budget: %w", err)
	}
	dto := BudgetToDTO(budget)
	return &dto, nil
}
```

- [ ] **Step 7: 加 handler `UpdateBudget`**

[budget_handler.go](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go):加在 `AddBudgetItem` handler(line 146)之前,对齐 `CreateBudget` handler(line 31)解析范式。

```go
// UpdateBudget edits a budget in place (no delete+recreate).
func (h *BudgetHandler) UpdateBudget(ctx context.Context, req *pb.UpdateBudgetRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	budgetID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}
	items := make([]application.BudgetItemInput, len(req.Items))
	for i, item := range req.Items {
		aid, err := uuid.Parse(item.AccountId)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid account_id in item %d", i)
		}
		items[i] = application.BudgetItemInput{
			AccountID:          aid,
			PlannedAmountCents: item.PlannedAmountCents,
			Notes:              item.Notes,
		}
	}
	resp, err := h.service.UpdateBudget(ctx, application.UpdateBudgetRequest{
		TenantID:     tenantID,
		BudgetID:     budgetID,
		Name:         req.Name,
		CurrencyCode: req.CurrencyCode,
		Items:        items,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}
```

> `mapError` 已在 budget_handler.go(现有 `CreateBudget`/`AddBudgetItem` 用)。`domain.Update` 的错误("budget name must not be empty" / "budget must have at least 1 item")经 `mapError` → 确认映射 `InvalidArgument`(budget `mapError` 含 "must not be empty" → InvalidArgument;若缺,Task 2 reviewer 会 flag)。

- [ ] **Step 8: 跑测试看通过 + 全量 build**

Run: `cd yucai/server && go test ./tests/... -run TestBudgetUpdate -count=1`
Expected: PASS

Run: `cd yucai/server && go build ./...`
Expected: 成功(handler 替换 Unimplemented 默认;`NewService` 未改 → wire 不动)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(Task 1 repo/domain + Task 2 service/handler 全链;现有 budget 测试不回归)

- [ ] **Step 9: Commit**

```bash
cd e:/projects/syfinance
git add yucai/proto/budget/v1/budget.proto \
  yucai/server/internal/proto/budget/v1/budget.pb.go \
  yucai/server/internal/proto/budget/v1/budget_grpc.pb.go \
  yucai/server/internal/budget/application/dto.go \
  yucai/server/internal/budget/application/service.go \
  yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go \
  yucai/server/tests/budget_integration_test.go
git commit -m "feat(budget): UpdateBudget RPC + service/handler (M1 Task 2)" -m "proto UpdateBudget RPC (id+name+currency_code+items, no month, no http option) + Go regen + UpdateBudgetRequest DTO + Service.UpdateBudget (FindByID -> domain.Update -> repo.Update) + handler. Budget ID stable (no delete+recreate). Wire/ent schema untouched."
```

---

## Task 3: client Dart regen + remote_ds/repo/bloc/form

Dart stub regen + client 全链接 UpdateBudget + form edit 改用 update + month 锁 + 去 hack。

**Files:**
- Regen: `client/lib/proto/budget/v1/budget.pb.dart` + `budget.pbgrpc.dart`(`make gen-dart`)
- Modify: [client/lib/budget/data/budget_remote_ds.dart](../../yucai/client/lib/budget/data/budget_remote_ds.dart)(+`updateBudget`)
- Modify: [client/lib/budget/domain/repositories/budget_repository.dart](../../yucai/client/lib/budget/domain/repositories/budget_repository.dart)(+abstract `updateBudget`)
- Modify: [client/lib/budget/data/budget_repository_impl.dart](../../yucai/client/lib/budget/data/budget_repository_impl.dart)(+`updateBudget`)
- Modify: [client/lib/budget/presentation/bloc/budget_event.dart](../../yucai/client/lib/budget/presentation/bloc/budget_event.dart)(+`UpdateBudgetRequested`)
- Modify: [client/lib/budget/presentation/bloc/budget_bloc.dart](../../yucai/client/lib/budget/presentation/bloc/budget_bloc.dart)(+`_onUpdate`)
- Modify: [client/lib/budget/presentation/pages/budget_form_page.dart](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart)(`_submit` + `_onBudgetStateChanged` + month disabled + 删 `_editCreateCount`)
- Modify: client test(bloc + form edit 路径)

**Interfaces:**
- Consumes: Task 2 `UpdateBudget` RPC + Dart stub;现有 `createBudget` remote_ds/repo 范式 + `_guard` + `BudgetView`/`budgetDtoToView`;现有 `_onAddItem` handler(getBudget → BudgetDetailLoaded)范式
- Produces: client edit 走 UpdateBudget(无 delete+recreate)

- [ ] **Step 1: regen Dart stub**

Run: `cd yucai && make gen-dart`
Expected: 成功(**protoc_plugin 25.0.0**;21.x 格式化全 .pb.dart 坏 — CLAUDE.md)。验证 `client/lib/proto/budget/v1/budget.pb.dart` 含 `UpdateBudgetRequest`,`budget.pbgrpc.dart` 含 `updateBudget` client method。

- [ ] **Step 2: remote_ds `updateBudget`**

[budget_remote_ds.dart](../../yucai/client/lib/budget/data/budget_remote_ds.dart):加在 `createBudget`(line 88)之后。对齐 `createBudget`(返回 `budgetDtoToView(res.budget)`,因为 UpdateBudgetResponse = BudgetResponse.budget = BudgetDTO 无 items)。

```dart
  /// 编辑预算(整体 name+currency+items 原地更新,不删旧重建)。
  /// 返回 BudgetResponse.budget(BudgetDTO 无 items)—— 调用方(bloc)
  /// 成功后重新 getBudget 回填 items,照 addItem/removeItem 范式。
  Future<BudgetView> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateBudget(pb.UpdateBudgetRequest(
        id: id,
        name: name,
        currencyCode: currencyCode,
        items: items
            .map((i) => pb.BudgetItemInput(
                  accountId: i.accountId,
                  plannedAmountCents: Int64(i.plannedAmountCents),
                  notes: i.notes ?? '',
                ))
            .toList(),
      ));
      return budgetDtoToView(res.budget);
    });
  }
```

更新文件顶注释 "7 RPCs" → "8 RPCs"(line 16)+ 加 `updateBudget`。

- [ ] **Step 3: abstract repo `updateBudget`**

[budget_repository.dart](../../yucai/client/lib/budget/domain/repositories/budget_repository.dart):加在 `createBudget`(line 18-23)之后。

```dart
  Future<Either<Failure, BudgetView>> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  });
```

- [ ] **Step 4: repo impl `updateBudget`**

[budget_repository_impl.dart](../../yucai/client/lib/budget/data/budget_repository_impl.dart):加在 `createBudget`(line 29-40)之后。

```dart
  @override
  Future<Either<Failure, BudgetView>> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _guard(() => _remote.updateBudget(
            id: id,
            name: name,
            currencyCode: currencyCode,
            items: items,
          ));
```

- [ ] **Step 5: bloc event `UpdateBudgetRequested`**

[budget_event.dart](../../yucai/client/lib/budget/presentation/bloc/budget_event.dart):加在 `CreateBudgetRequested`(line 41)之后。

```dart
/// 编辑预算(整体 name+currency+items 原地更新,不删旧重建)。
/// month 不可改(budget 身份);items 全量替换。
class UpdateBudgetRequested extends BudgetEvent {
  const UpdateBudgetRequested({
    required this.budgetId,
    required this.name,
    required this.currencyCode,
    required this.items,
  });
  final String budgetId;
  final String name;
  final String currencyCode;
  final List<({String accountId, int plannedAmountCents, String? notes})> items;

  @override
  List<Object?> get props => [budgetId, name, currencyCode, items];
}
```

- [ ] **Step 6: bloc `_onUpdate` handler**

[budget_bloc.dart](../../yucai/client/lib/budget/presentation/bloc/budget_bloc.dart):
- line 16 后注册:`on<UpdateBudgetRequested>(_onUpdate);`(加在 `on<CreateBudgetRequested>` 之后)
- 加 handler(照 `_onAddItem` line 65-83 成功后重拉 detail 范式):

```dart
  /// updateBudget 返回 BudgetDTO(无 items),重新拉完整 budget 回填 items
  /// (照 _onAddItem/_onRemoveItem)。edit 成功 → BudgetDetailLoaded(带新数据,
  /// form 据此 pop 返回 detail 页)。
  Future<void> _onUpdate(UpdateBudgetRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.updateBudget(
      id: event.budgetId,
      name: event.name,
      currencyCode: event.currencyCode,
      items: event.items,
    );
    await result.fold(
      (failure) async => emit(BudgetError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getBudget(event.budgetId);
        detail.fold(
          (failure) => emit(BudgetError(failure.displayMessage)),
          (budget) => emit(BudgetDetailLoaded(budget)),
        );
      },
    );
  }
```

- [ ] **Step 7: form `_submit` 改用 update + month disabled + 去 `_editCreateCount`**

[budget_form_page.dart](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart):

**7a.** 删除 `_editCreateCount` field(在 State 类字段区,grep `_editCreateCount` 找声明,删整行)。

**7b.** `_submit()`(line 263-275)替换 —— edit 改 dispatch `UpdateBudgetRequested`(不再 delete+recreate):

```dart
    // 在 dispatch 前捕获 bloc(避免跨 async gap 用 BuildContext)。
    final bloc = context.read<BudgetBloc>();
    if (_isEdit) {
      // 编辑模式:原地 UpdateBudget(不再 delete+recreate —— budget ID 不变、
      // 原子、无 _editCreateCount 竞态 hack)。
      bloc.add(UpdateBudgetRequested(
        budgetId: widget.budgetId!,
        name: _nameCtrl.text.trim(),
        currencyCode: _currencyCode,
        items: items,
      ));
    } else {
      bloc.add(CreateBudgetRequested(
        name: _nameCtrl.text.trim(),
        month: _month,
        currencyCode: _currencyCode,
        items: items,
      ));
    }
```

**7c.** `_onBudgetStateChanged`(line 146-180)第二段(`_submitted` pop 逻辑,原 line 165-179)替换 —— 去 `_editCreateCount`,edit 接 `BudgetDetailLoaded` pop、create 接 `BudgetListLoaded` pop。**第一段(line 148-164,`BudgetDetailLoaded` + `_existingBudget == null` 预填 load)保留不动**(edit 提交后 `_existingBudget != null`,第一段不触发):

```dart
    // 提交成功:edit → BudgetDetailLoaded(update 后重拉);create → BudgetListLoaded。
    // (旧 delete+recreate 触发 2 次 BudgetListLoaded + _editCreateCount 计数 —— 已删。)
    if (_submitted && _isEdit && state is BudgetDetailLoaded) {
      _submitted = false;
      Navigator.of(context).pop(true);
      return;
    }
    if (_submitted && !_isEdit && state is BudgetListLoaded) {
      _submitted = false;
      Navigator.of(context).pop(true);
    }
```

**7d.** month picker `_isEdit` 时 disabled。定位 `_basicInfoSection` 内 month 显示/触发组件(`_pickMonth` 的入口 —— 通常是 `InkWell`/`GestureDetector` 包 month 文本 + `_pickMonth` onTap)。用 `AbsorbPointer` 包它,edit 时吸收点击 + 视觉灰显:

```dart
// 在 _basicInfoSection 的 month 行(触发 _pickMonth 的 widget 外层):
AbsorbPointer(
  absorbing: _isEdit, // edit 时 month 不可改(budget 身份)
  child: Opacity(
    opacity: _isEdit ? 0.5 : 1.0,
    child: /* 原 month 触发组件(InkWell/GestureDetector → _pickMonth) */,
  ),
)
```

(implementer 定位 `_basicInfoSection` 中 month 的具体 widget,用上述 Wrap。若 month 在 create 模式也是 picker、edit 模式应纯展示,此 Wrap 同时满足。)

- [ ] **Step 8: 写 client 测试**

[budget_bloc_test](../../yucai/client/test/budget/...)(照现有 budget bloc test 的 mock repo 范式):`UpdateBudgetRequested` → mock repo `updateBudget` 返 Right → emit `BudgetLoading` → (getBudget) → `BudgetDetailLoaded`。失败 → `BudgetError`。

[budget_form_page_test](../../yucai/client/test/budget/presentation/pages/budget_form_page_test.dart)(照现有):edit 模式(budgetId 非 null)+ fill name/items → submit → 验证 `UpdateBudgetRequested` dispatched(**非** `DeleteBudgetRequested` + `CreateBudgetRequested`);month picker edit 时不可点(AbsorbPointer)。

(注:client test 基线有预存 fail — CLAUDE.md 4 fail / 3 文件;M1 不引入新 fail。)

- [ ] **Step 9: 跑 client analyze + test + build**

Run: `cd yucai/client && flutter analyze`
Expected: 22 error 基线(全 `*.pbserver.dart`)无新增(M1 不碰 .pbserver)。

Run: `cd yucai/client && flutter test test/budget/`
Expected: PASS(新 bloc/form test 过;预算基线 fail 不在 budget 文件)

Run: `cd yucai/client && flutter build windows --debug`
Expected: 成功

- [ ] **Step 10: Commit**

```bash
cd e:/projects/syfinance
git add yucai/client/lib/proto/budget/v1/budget.pb.dart \
  yucai/client/lib/proto/budget/v1/budget.pbgrpc.dart \
  yucai/client/lib/budget/data/budget_remote_ds.dart \
  yucai/client/lib/budget/domain/repositories/budget_repository.dart \
  yucai/client/lib/budget/data/budget_repository_impl.dart \
  yucai/client/lib/budget/presentation/bloc/budget_event.dart \
  yucai/client/lib/budget/presentation/bloc/budget_bloc.dart \
  yucai/client/lib/budget/presentation/pages/budget_form_page.dart \
  yucai/client/test/budget/
git commit -m "feat(budget/client): edit form UpdateBudget + month lock (M1 Task 3)" -m "Dart regen (protoc_plugin 25.0.0) + remote_ds/repo updateBudget + bloc UpdateBudgetRequested (_onUpdate -> getBudget -> BudgetDetailLoaded) + form _submit edit path dispatches UpdateBudget (no delete+recreate) + _onBudgetStateChanged simplified (drop _editCreateCount hack) + month picker disabled in edit mode (AbsorbPointer). Budget ID stable, atomic, no race."
```

---

## Spec coverage 矩阵

| spec 决策/章节 | 落地 task | 备注 |
|---|---|---|
| §3 #1 范围=整体 UpdateBudget | Task 2(service)+ Task 3(client form) | name+currency+items |
| §3 #2 month 锁 | Task 2(proto 无 month)+ Task 3(form disabled) | 双向保证 |
| §3 #3 items 全量替换 | Task 1(repo Update 删旧+建新)+ Task 2(domain Update 替换) | budget ID 稳 |
| §3 #4 无单 item edit | 全 plan 无 UpdateBudgetItem | 范围外 |
| §3 #5 version 锁(client 不传) | Task 1(repo WHERE v-1)+ Task 2(proto 无 version field) | 照 budget 现状 |
| §3 #6 proto + regen | Task 2(Go)+ Task 3(Dart) | 25.0.0 |
| §3 #7 edit → BudgetDetailLoaded | Task 3 `_onUpdate`(getBudget) | 照 _onAddItem |
| §5 七层改动 | Task 1(domain+repo)+ Task 2(proto+app+handler)+ Task 3(client data+presentation) | |
| §6.1 proto | Task 2 Step 1-2 | **修正:无 google.api.http option** |
| §6.2 domain Update | Task 1 Step 3 | |
| §6.3 repo 补 currency/err | Task 1 Step 5 | 2 现有缺陷顺修 |
| §6.4 service UpdateBudget | Task 2 Step 6 | |
| §6.5 handler | Task 2 Step 7 | |
| §6.6 client remote_ds/repo | Task 3 Step 2-4 | |
| §6.7 client bloc + form | Task 3 Step 5-7 | 去 _editCreateCount + month disabled |
| §8 测试(domain/repo/service/handler/client) | Task 1(domain+repo)+ Task 2(integration)+ Task 3(client) | |
| §8 约束 6 无 implementer 影响 | Task 2(interface 不变,handler 替换 Unimplemented) | NewService 不变 |
| §9 风险 1-7 | 全 task | #1 regen;#2 version 锁语义(Task 1 Step 6 测);#3 wire 不改;#4 month 双向保证;#5 item ID 变;#6 edit 返 BudgetDetailLoaded;#7 budget_integration_test Task 1/2 加 |
