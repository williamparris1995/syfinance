# Holding 子项目 D-budget · budget actuals 接通 + 投资排除 + Flutter UI 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接通 budget actuals(entryFunc nil → 委托 transaction.Service.SpendingByAccount, 读时算)+ 投资双写不污染(budget item 按 expense 账户粒度, transfer 天然排除)+ Flutter budget UI 完整多页(list/detail/create, sidebar 入口)。零新表/字段(仅 proto BudgetDTO 加 2 字段)。

**Architecture:** server:transaction 加 `SpendingByAccount`(按 account+日期 Σ entry debit/credit)+ 新 entry repo `SumEntryTotalsByAccount`;budget application GetBudget/GetBudgetByMonth/ListBudgets 读时算 actuals 填 DTO(不 persist);wire `provideBudgetService` 注入闭包委托 SpendingByAccount(budget 不 import transaction, 函数注入照 D-goal/D-currency port 模式)。Flutter:DDD 四层(照 debt/holding)+ 3 页面 + sidebar branch 6。

**Tech Stack:** Go(ent + grpc + slog)+ proto3 + Flutter(flutter_bloc + injectable + grpc stub + lucide icons)

**Spec:** [docs/superpowers/specs/2026-07-01-holding-budget-design.md](../specs/2026-07-01-holding-budget-design.md)

## Global Constraints

- **分支**:`holding-asset-management`(A/B/C/D-goal/D-currency 已完成, D-budget 续做)
- **零新表/字段**：复用 `budgets` + `budget_items`(`ActualAmountCents` 已有) + `transaction_entries`。唯一 schema 变 = proto `BudgetDTO` 加 `total_actual_cents` + `usage_pct` 2 字段
- **budget 现状**：模块完整建好(domain/repo/service/handler/proto/main 注册), 但 `provideBudgetService` ([wire/providers.go:287](../../yucai/server/wire/providers.go#L287)) `NewService(repo, nil)` —— **entryFunc nil**, `ComputeBudgetActuals` RPC 调必 nil-panic
- **EntryTotalsFunc 签名**([budget/application/service.go:13](../../yucai/server/internal/budget/application/service.go#L13))：`func(ctx, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)` —— SpendingByAccount 必须精确匹配
- **budget item 粒度 = expense 账户(category)**：御财 account-as-category 模型, `AccountTypeExpense` ([account/domain/valueobject.go:11](../../yucai/server/internal/account/domain/valueobject.go#L11))。Transfer = asset→asset ([transaction/domain/repository.go:33](../../yucai/server/internal/transaction/domain/repository.go#L33)), **从不 touch expense 账户** → holding 双写(cash asset → investment asset)自动排除, 不需显式 transfer 过滤
- **transaction entry 无 sum-by-account 方法**：现仅 `loadEntriesByTransaction` ([transaction_repo.go:283](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go#L283))。D-budget Task 1 加 `SumEntryTotalsByAccount`
- **budget proto 现有字段**：`BudgetItemDTO.actual_amount_cents` ✓ + `BudgetDetailDTO.total_actual_cents/total_remaining_cents/usage_pct` ✓;**`BudgetDTO`(list 用)缺 actuals** → Task 2 加 2 字段
- **budget Dart stub 已生成**(proto 改后 Task 2 regen)
- **wire 工具链坏**：`wire_gen.go` 手改镜像 D-currency/B/C/D-goal, 不跑 wire CLI(见 [[yucai-wire-handmaintained]])
- **Dart stub regen**：`cd /e/projects/syfinance/yucai && make gen-dart`(protoc_plugin 25.0.0; make 不在 Bash PATH 用底层命令, 见 [[yucai-dev-env]])。Go stub：`cd yucai/server && buf generate --template buf.gen.go.yaml`(或手改 .pb.go 加字段)
- **English 结构化日志**(CLAUDE.md AI 约束#2)
- **复用第一**：SpendingByAccount 复用 entry ent 查询;budget application 复用现有 domain `TotalActual`/`UsagePct`/`TotalRemaining`;Flutter 复用 holding/debt DDD 范式 + CurrencySettings 设计语言
- **每 task 末尾 commit**：中文 conventional(`feat(holding-d-budget-server): ...` / `feat(holding-d-budget-flutter): ...`)
- **flutter analyze 基线 = 22 error**(全 `*.pbserver.dart`, 客户端未用)

## File Structure

### server 新建
- `yucai/server/internal/transaction/application/spending_test.go` — SpendingByAccount 单测(可并入现有 service_test.go)

### server 修改
- `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go` — 加 `SumEntryTotalsByAccount(ctx, accountID, from, to) (debit, credit int64, err)`
- `yucai/server/internal/transaction/application/service.go` — 加 `SpendingByAccount`(委托 repo)
- `yucai/server/internal/budget/application/service.go` — GetBudget/GetBudgetByMonth/ListBudgets 读时算 actuals(填 DTO + nil/err 降级)
- `yucai/proto/budget/v1/budget.proto` — `BudgetDTO` 加 `total_actual_cents` + `usage_pct`
- `yucai/server/wire/providers.go` + `wire/wire_gen.go`(手改) — `provideBudgetService` 注入 txnSvc 闭包

### Flutter 新建(照 debt/holding DDD 四层)
- `yucai/client/lib/budget/data/budget_remote_ds.dart` — proto budget RPC 调用
- `yucai/client/lib/budget/data/budget_repository_impl.dart` — repo 实现
- `yucai/client/lib/budget/domain/entities/budget_entity.dart` — `BudgetView` + `BudgetItemView` entity
- `yucai/client/lib/budget/domain/repositories/budget_repository.dart` — abstract interface
- `yucai/client/lib/budget/presentation/bloc/budget_bloc.dart` + `budget_event.dart` + `budget_state.dart`
- `yucai/client/lib/budget/presentation/pages/budget_list_page.dart`
- `yucai/client/lib/budget/presentation/pages/budget_detail_page.dart`
- `yucai/client/lib/budget/presentation/pages/budget_form_page.dart`

### Flutter 修改
- `yucai/client/lib/app/router.dart` — 加 `/budgets` branch 6(+ 子路由 `/new` `/:id` `/edit`)
- `yucai/client/lib/app/widgets/app_shell.dart` — sidebar "预算" 入口(lucide `wallet`)

---

## Task 0: 前置(确认 + 清工作区)

**Files:** 无改动(验证 task)

- [ ] **Step 1: 确认 budget 模块现状 + Task 0 findings**

```bash
grep -n "NewService(repo, nil)" /e/projects/syfinance/yucai/server/wire/providers.go
grep -n "func (s \*Service) ComputeActuals\|type EntryTotalsFunc" /e/projects/syfinance/yucai/server/internal/budget/application/service.go
grep -n "loadEntriesByTransaction" /e/projects/syfinance/yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go
grep -n "AccountTypeExpense" /e/projects/syfinance/yucai/server/internal/account/domain/valueobject.go
grep -nE "total_actual_cents|usage_pct" /e/projects/syfinance/yucai/proto/budget/v1/budget.proto
```
Expected:`NewService(repo, nil)` 在 providers.go;`EntryTotalsFunc` + `ComputeActuals` 在 service.go;`loadEntriesByTransaction` 存在(无 sum-by-account, Task 1 加);`AccountTypeExpense` 存在;budget.proto **BudgetDTO 无** total_actual_cents/usage_pct(Task 2 加, BudgetDetailDTO 有)。

- [ ] **Step 2: 确认工作区干净 + server build 绿**

```bash
git -C /e/projects/syfinance status --short
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:干净 + build 绿。记 HEAD(D-budget 起点 = `aaf3400` spec commit 后)。

(本 task 无 commit —— 纯验证)

---

## Task 1: transaction.Service.SpendingByAccount + repo SumEntryTotalsByAccount

**Files:**
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`(加 `SumEntryTotalsByAccount`)
- Modify: `yucai/server/internal/transaction/domain/repository.go`(加接口方法)
- Modify: `yucai/server/internal/transaction/application/service.go`(加 `SpendingByAccount`)
- Test: `yucai/server/internal/transaction/application/service_test.go`(或新 spending_test.go)

**Interfaces:**
- Produces(repo)：`SumEntryTotalsByAccount(ctx context.Context, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)`
- Produces(service)：`SpendingByAccount(ctx, accountID, from, to) (debitTotal, creditTotal int64, err error)` —— 签名**精确匹配 budget.EntryTotalsFunc**(Task 4 闭包委托)。Task 3/4 消费。

**背景**：budget item 是 expense 账户(category), actuals = 该账户范围内 debit 总和(支出)。Transfer(asset→asset)不 touch expense 账户, 天然排除, 不需过滤。

- [ ] **Step 1: 写失败测试(service_test.go, mock repo)**

照现有 service_test.go 的 mock repo 模式(读 `internal/transaction/application/service_test.go` 确认 fake repo 命名)。加：
```go
func TestSpendingByAccount(t *testing.T) {
	repo := &fakeRepo{} // 复用现有 fake, 加 SumEntryTotalsByAccount stub
	repo.sumByAccount = func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 50000, 5000, nil // ¥500 支出, ¥50 退款
	}
	svc := application.NewService(repo, nil /* 其他依赖照现有构造 */)
	debit, credit, err := svc.SpendingByAccount(context.Background(), uuid.New(), time.Now(), time.Now())
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if debit != 50000 || credit != 5000 {
		t.Fatalf("got debit=%d credit=%d, want 50000/5000", debit, credit)
	}
}
```
(实现者读现有 service_test.go 调整 fake repo 构造 + 现有依赖参数)

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/transaction/application/ -run SpendingByAccount -v -count=1
```
Expected:FAIL(`SpendingByAccount undefined`)。

- [ ] **Step 3: domain repository.go 加接口方法**

在 `TransactionRepository` interface 加：
```go
// SumEntryTotalsByAccount returns the total debit/credit cents of entries
// posted to accountID with transaction_date in [from, to]. Used by budget
// actuals (budget items track Expense accounts = categories).
SumEntryTotalsByAccount(ctx context.Context, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)
```

- [ ] **Step 4: repo 实现 SumEntryTotalsByAccount(transaction_repo.go)**

照现有 ent 查询模式(读 `loadEntriesByTransaction` + entry ent schema `internal/transaction/ent/transactionentry` 确认字段名 `debit_cents`/`credit_cents`/`account_id` + transaction `transaction_date` join)。实现：
```go
// SumEntryTotalsByAccount sums debit_cents/credit_cents of entries on accountID
// whose transaction's date is in [from, to]. Budget actuals consume this
// (budget items track Expense accounts; transfers are asset→asset and never
// touch Expense accounts, so they are excluded automatically — no type filter).
func (r *TransactionRepository) SumEntryTotalsByAccount(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
	var res struct {
		Debit  int64
		Credit int64
	}
	// ent query: join transaction_entries ↔ transactions on transaction_id,
	// where account_id = ? and transaction_date between from and to,
	// sum(debit_cents), sum(credit_cents). 照 r.client 的 ent 查询惯例。
	err := r.client.TransactionEntry.Query().
		Where(transactionentry.HasTransactionWith(
			transaction.TransactionDateGTE(from),
			transaction.TransactionDateLTE(to),
		), transactionentry.AccountIDEQ(accountID)).
		Aggregate(ent.Sum(transactionentry.FieldDebitCents), ent.Sum(transactionentry.FieldCreditCents)).
		Scan(ctx, &res)
	if err != nil {
		return 0, 0, fmt.Errorf("sum entry totals by account: %w", err)
	}
	return res.Debit, res.Credit, nil
}
```
(实现者读 transaction_repo.go 现有 import + ent predicate 命名调整;`ent` alias 照现有文件。若 entry 无直接 date 字段需 join transaction, 照上面 HasTransactionWith 模式。)

- [ ] **Step 5: application service 加 SpendingByAccount**

`internal/transaction/application/service.go`：
```go
// SpendingByAccount returns debit/credit totals of entries on accountID in
// [from, to]. Used by budget actuals (budget items track Expense accounts =
// categories; transfers asset→asset never touch Expense accounts → excluded
// automatically). Signature matches budget.EntryTotalsFunc for direct delegate.
func (s *Service) SpendingByAccount(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
	return s.repo.SumEntryTotalsByAccount(ctx, accountID, from, to)
}
```

- [ ] **Step 6: 跑测试验证 PASS + 全量 transaction 测绿**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/transaction/... -count=1
go build ./...
```
Expected:PASS + build 绿。

- [ ] **Step 7: 集成测(enttest, 可选但推荐)**

照现有 transaction_repo 集成测模式(若有 enttest harness), 加 `TestSumEntryTotalsByAccount`:seed 2 txn(餐饮 expense debit 50000 + 退款 credit 5000)+ 验返 (50000, 5000)。若现 repo 无集成测 harness, defer 到 Task 5 e2e 覆盖。

- [ ] **Step 8: Commit**

```bash
git add yucai/server/internal/transaction/
git commit -m "feat(holding-d-budget-server): transaction SpendingByAccount + repo SumEntryTotalsByAccount(Task 1)"
```

---

## Task 2: budget proto BudgetDTO 加 actuals 字段 + regen stub

**Files:**
- Modify: `yucai/proto/budget/v1/budget.proto`(`BudgetDTO` 加 2 字段)
- Regen: `yucai/server/internal/proto/budget/v1/budget.pb.go` + `yucai/client/lib/proto/budget/v1/budget.pb.dart` 等

**Interfaces:**
- Produces：`BudgetDTO.total_actual_cents` (int64, field 10) + `BudgetDTO.usage_pct` (double, field 11)。Task 3 填, Flutter Task 6/8 读。

**背景**：BudgetDetailDTO 已有 actuals 字段(GetBudget/GetBudgetByMonth 用), 但 ListBudgets 返 BudgetDTO 无 actuals → list 页无法显总进度。加 2 字段。

- [ ] **Step 1: 改 proto BudgetDTO**

`yucai/proto/budget/v1/budget.proto` 的 `message BudgetDTO` 加 2 字段(在 field 9 后)：
```proto
message BudgetDTO {
  string id = 1;
  string name = 2;
  string month = 3;
  int64 total_amount_cents = 4;
  string currency_code = 5;
  bool is_active = 6;
  int64 version = 7;
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp updated_at = 9;
  int64 total_actual_cents = 10;  // D-budget: 读时算 actuals(list 页总进度)
  double usage_pct = 11;          // D-budget: total_actual/total_amount %
}
```

- [ ] **Step 2: regen Go stub**

```bash
cd /e/projects/syfinance/yucai/server && buf generate --template buf.gen.go.yaml
```
(若 buf 不在 PATH, 手改 `internal/proto/budget/v1/budget.pb.go` 加 TotalActualCents/UsagePct 字段 + getter, 照现有 field 模式。验证：`go build ./internal/proto/budget/v1/`)

- [ ] **Step 3: regen Dart stub**

```bash
cd /e/projects/syfinance/yucai && make gen-dart
```
(protoc_plugin 25.0.0, 见 [[yucai-dev-env]]。验证 `budget.pb.dart` 含 `totalActualCents`/`usagePct` getter)

- [ ] **Step 4: 确认 server + client 编译**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/client && flutter analyze lib/proto/budget/ 2>&1 | grep -E "error -" | grep -v pbserver
```
Expected:build 绿 + 无新 error(pbserver 基线除外)。

- [ ] **Step 5: Commit**

```bash
git add yucai/proto/budget/ yucai/server/internal/proto/budget/ yucai/client/lib/proto/budget/
git commit -m "feat(holding-d-budget-proto): BudgetDTO 加 total_actual_cents + usage_pct(Task 2)"
```

---

## Task 3: budget application actuals 读时算 + nil/err 降级

**Files:**
- Modify: `yucai/server/internal/budget/application/service.go`(GetBudget/GetBudgetByMonth/ListBudgets 读时算 + nil/err 降级)
- Modify: `yucai/server/internal/budget/application/dto.go`(BudgetToDTO 填 actuals, 若需)
- Test: `yucai/server/internal/budget/application/service_test.go`

**Interfaces:**
- Consumes：Task 1 `entryFunc`(EntryTotalsFunc, Task 4 接真)。本 task 用 mock entryFunc 测。
- Produces：GetBudget/GetBudgetByMonth/ListBudgets 返 DTO 含读时算 actuals。

**背景**：现 GetBudget 返存储的 stale ActualAmountCents。改为读后逐 item 调 entryFunc 算(不 persist, 避 version 抖)。nil entryFunc → actuals 0 不 panic。err → 该 item 0 + 日志。budget.Month = "YYYY-MM" → monthStart/monthEnd。

- [ ] **Step 1: 写失败测试(service_test.go, mock entryFunc)**

```go
func TestGetBudgetComputesActualsReadTime(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 200000},
		},
		TotalAmountCents: 200000,
	}}
	// mock entryFunc: 返 debit 50000(¥500 支出), credit 0
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 50000, 0, nil
	}
	svc := application.NewService(repo, entryFunc)

	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Items[0].ActualAmountCents != 50000 {
		t.Fatalf("item actual: got %d, want 50000", dto.Items[0].ActualAmountCents)
	}
	if dto.TotalActualCents != 50000 {
		t.Fatalf("total actual: got %d, want 50000", dto.TotalActualCents)
	}
	// usage_pct = 50000/200000*100 = 25
	if dto.UsagePct != 25.0 {
		t.Fatalf("usage_pct: got %f, want 25", dto.UsagePct)
	}
}

func TestGetBudgetActualsNilEntryFuncFallback(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{Month: "2026-07", Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}}, TotalAmountCents: 100000}}
	svc := application.NewService(repo, nil) // nil entryFunc
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Items[0].ActualAmountCents != 0 {
		t.Fatalf("nil entryFunc: got %d, want 0", dto.Items[0].ActualAmountCents)
	}
}

func TestGetBudgetActualsEntryFuncErrGraceful(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{Month: "2026-07", Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}}, TotalAmountCents: 100000}}
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 0, 0, fmt.Errorf("boom")
	}
	svc := application.NewService(repo, entryFunc)
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("should not propagate entryFunc err: %v", err)
	}
	if dto.Items[0].ActualAmountCents != 0 {
		t.Fatalf("err fallback: got %d, want 0", dto.Items[0].ActualAmountCents)
	}
}
```
(实现者读现有 service_test.go 调整 fakeBudgetRepo 构造)

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/budget/application/ -run GetBudget -v -count=1
```
Expected:FAIL(actuals 未读时算, 返 stale 0 或不填)。

- [ ] **Step 3: 加 actuals 读时算 helper(service.go)**

```go
import "log/slog"

// monthRange 解析 "YYYY-MM" → [月初 00:00, 月末 23:59:59.999]。
// 失败返 zero time(实际不应发生, domain 已 regex 校验)。
func monthRange(month string) (time.Time, time.Time) {
	t, err := time.Parse("2006-01", month)
	if err != nil {
		return time.Time{}, time.Time{}
	}
	from := t
	to := t.AddDate(0, 1, -1).Add(24*time.Hour - time.Nanosecond)
	return from, to
}

// computeActualsReadTime 用 entryFunc 逐 item 算 ActualAmountCents(填入 items,
// 不 persist)。nil entryFunc → 全 0 不 panic;单 item err → 该 item 0 + 日志(best-effort)。
// actual = debit − credit(支出 − 退款, 净消费)。
func (s *Service) computeActualsReadTime(ctx context.Context, b *domain.Budget) {
	if s.entryFunc == nil {
		return // actuals 保持 0(存储值或零值)
	}
	from, to := monthRange(b.Month)
	for i := range b.Items {
		debit, credit, err := s.entryFunc(ctx, b.Items[i].AccountID, from, to)
		if err != nil {
			slog.Error("budget actuals: entryFunc failed",
				"operation", "budget.computeActualsReadTime",
				"budget_id", b.ID.String(), "item_id", b.Items[i].ID.String(),
				"error", err.Error())
			b.Items[i].ActualAmountCents = 0
			continue
		}
		b.Items[i].ActualAmountCents = debit - credit
	}
}
```

- [ ] **Step 4: GetBudget/GetBudgetByMonth/ListBudgets 调 computeActualsReadTime**

GetBudgetByMonth(service.go, 现有)在 `repo.FindByMonth` 后、`BudgetToDetailDTO` 前加：
```go
	budget, err := s.repo.FindByMonth(ctx, tenantID, month)
	if err != nil {
		return nil, fmt.Errorf("budget not found for month %s: %w", month, err)
	}
	s.computeActualsReadTime(ctx, budget) // D-budget: 读时算
	dto := BudgetToDetailDTO(budget)
	return &dto, nil
```
GetBudget 同(在 FindByID 后加 `s.computeActualsReadTime`)。

ListBudgets(现有)在 `repo.FindAll` 后, 逐 budget 算 + 填 BudgetDTO 的 total_actual/usage_pct：
```go
	result, err := s.repo.FindAll(ctx, req.TenantID, req.ActiveOnly, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list budgets: %w", err)
	}
	dtos := make([]BudgetDTO, len(result.Items))
	for i, b := range result.Items {
		s.computeActualsReadTime(ctx, &b) // D-budget: 读时算(填 items + 派生 total)
		dtos[i] = BudgetToDTO(&b)         // BudgetToDTO 读 b.TotalActual() + b.UsagePct()
	}
```

- [ ] **Step 5: dto.go BudgetToDTO 填新字段(若需)**

读 `internal/budget/application/dto.go` 的 `BudgetToDTO`, 确保填 `TotalActualCents: b.TotalActual()` + `UsagePct: b.UsagePct()`(domain 方法已存在, entity.go:115/129)。若 BudgetToDTO 现未填这 2 字段(Task 2 新加的), 补：
```go
func BudgetToDTO(b *domain.Budget) BudgetDTO {
	return BudgetDTO{
		// ... 现有字段 ...
		TotalActualCents: b.TotalActual(),
		UsagePct:         b.UsagePct(),
	}
}
```

- [ ] **Step 6: 跑测试验证 PASS + 全量 budget 测绿**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/budget/... -count=1
go build ./...
```
Expected:新测 PASS + 现有 budget 测不破。

- [ ] **Step 7: Commit**

```bash
git add yucai/server/internal/budget/
git commit -m "feat(holding-d-budget-server): budget actuals 读时算 + nil/err 降级(Task 3)"
```

---

## Task 4: wire + main budget entryFunc 接线

**Files:**
- Modify: `yucai/server/wire/providers.go`(`provideBudgetService` 加 txnSvc 参数 + 注入闭包)
- Modify: `yucai/server/wire/wire_gen.go`(手改:provideBudgetService 传 txnService + 声明顺序)

**Interfaces:**
- Consumes：Task 1 `transaction.Service.SpendingByAccount` + Task 3 budget `NewService(repo, entryFunc)`
- Produces：budget application.Service entryFunc 接真(不再 nil)。

**背景**：budget application 不 import transaction(函数注入 port 模式, 照 D-currency networth)。wire 在 provideBudgetService 注入闭包委托 SpendingByAccount。wire_gen 手改(工具链坏, 见 [[yucai-wire-handmaintained]])。

- [ ] **Step 1: 改 provideBudgetService(providers.go)**

```go
// before(Task 0 确认):
// func provideBudgetService(repo *budgetrepo.BudgetRepository) *budgetapp.Service {
//     return budgetapp.NewService(repo, nil) // entryFunc nil for now
// }

// after:
func provideBudgetService(repo *budgetrepo.BudgetRepository, txnSvc *txnapp.Service) *budgetapp.Service {
	return budgetapp.NewService(repo, func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return txnSvc.SpendingByAccount(ctx, accountID, from, to)
	})
}
```
加 import：`txnapp "github.com/yucai/server/internal/transaction/application"` + `"github.com/google/uuid"`(若未有)。

- [ ] **Step 2: 手改 wire_gen.go**

读 `wire/wire_gen.go`, 找 `budgetService := provideBudgetService(budgetRepo)`(约 line 98)。改为：
```go
budgetService := provideBudgetService(budgetRepo, transactionService)
```
**关键**：`transactionService` 变量名 + 声明顺序 —— 读 wire_gen.go 确认 transactionService 在 budgetService 之前声明(若 budgetService 声明在 transactionService 之前, 把 budgetService 块移到 transactionService 之后)。镜像 D-currency networth 接线模式(provideNetWorthService 消费 holdingService/accountService/debtService, 声明顺序在后)。

- [ ] **Step 3: build + 跑 budget/transaction/wire 相关测**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
go test ./internal/budget/... ./internal/transaction/... -count=1
```
Expected:build 绿(entryFunc 接真)+ 测绿。

- [ ] **Step 4: 启动 server 健康检查**

照 [[yucai-dev-env]] 启 server(DATABASE_URL + JWT_SECRET + GRPC_PORT), 确认 `RegisterBudgetServiceServer` 不崩 + schedulers 跑。TaskStop。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/wire/
git commit -m "feat(holding-d-budget-server): wire budget entryFunc 委托 SpendingByAccount(Task 4)"
```

---

## Task 5: server 端到端验证(我自做, 无 commit)

**Files:** 无改动(验证 task)

**背景**：验证 actuals 接通端到端 + 投资不污染。需 server 运行 + DB seed。

- [ ] **Step 1: 启 server(照 [[yucai-dev-env]])**

```bash
# bash run_in_background, 绝对路径 cd
cd /e/projects/syfinance/yucai/server && \
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && \
export JWT_SECRET='dev-secret-change-me-32chars-minimum-aaaa' && \
export GRPC_PORT=9090 && \
./bin/server.exe 2>&1
```
(若 server.exe 旧, 先 `go build -o bin/server.exe ./cmd/server`)

- [ ] **Step 2: grpcurl CreateBudget(餐饮 category expense 账户, ¥2000)**

需先确认一个 expense 账户 id(餐饮 category)。`podman exec yucai-pg psql -U yucai -d yucai -c "select id, name, account_type from accounts where account_type='expense' limit 3"`。grpcurl CreateBudget(items=[{account_id=<餐饮 id>, planned=200000}], month=2026-07)。记 budget id。

- [ ] **Step 3: 记一笔餐饮支出 ¥500**

经 client 或 grpcurl 记一笔 transaction(debit 餐饮 expense 50000, credit asset)。确认 entry 落 transaction_entries。

- [ ] **Step 4: grpcurl GetBudgetByMonth(2026-07) 验 actuals=50000**

Expected:`items[0].actual_amount_cents = 50000` + `total_actual_cents = 50000` + `usage_pct = 25`。**actuals 接通确认**。

- [ ] **Step 5: buy holding(cash → investment)+ GetBudgetByMonth 验 actuals 不变**

经 client buy holding(fromAccount=cash asset, quantity/price)。再 grpcurl GetBudgetByMonth。Expected:`actuals 仍 = 50000`(holding 双写 cash→investment 是 transfer, 不 touch 餐饮 expense 账户 → 不污染)。**投资排除确认**。

- [ ] **Step 6: 记日志到 progress.md**

(本 task 无 commit —— 纯 e2e 验证。结果记 `.superpowers/sdd/progress.md` D-budget section。)

---

## Task 6: Flutter data 层(BudgetRemoteDataSource + Repository + BudgetView)

**Files:**
- Create: `yucai/client/lib/budget/domain/entities/budget_entity.dart`
- Create: `yucai/client/lib/budget/domain/repositories/budget_repository.dart`
- Create: `yucai/client/lib/budget/data/budget_remote_ds.dart`
- Create: `yucai/client/lib/budget/data/budget_repository_impl.dart`
- Test: `yucai/client/test/budget/data/budget_remote_ds_test.dart` + mapper test

**Interfaces:**
- Consumes：budget proto Dart stub(Task 2 regen, `BudgetServiceClient` + `BudgetDTO`/`BudgetDetailDTO`/`BudgetItemDTO`)
- Produces：`BudgetView`/`BudgetItemView` entity + `BudgetRepository` abstract + impl。Task 7 bloc 消费。

**背景**：照 holding/debt DDD 范式(`lib/holding/data/holding_remote_ds.dart` + `holding_repository_impl.dart` 作模板)。GrpcClient + AuthRetryCaller + getIt 注入。

- [ ] **Step 1: BudgetView + BudgetItemView entity**

`budget/domain/entities/budget_entity.dart`(照 `holding/domain/entities/holding_entity.dart` Equatable 模式)：
```dart
import 'package:equatable/equatable.dart';

class BudgetItemView extends Equatable {
  const BudgetItemView({
    required this.id,
    required this.accountId,
    this.accountName,
    required this.plannedAmountCents,
    required this.actualAmountCents,
    this.notes,
  });
  final String id;
  final String accountId;
  final String? accountName;
  final int plannedAmountCents;
  final int actualAmountCents;
  final String? notes;

  int get remainingCents => plannedAmountCents - actualAmountCents;
  double get usagePct => plannedAmountCents == 0 ? 0 : actualAmountCents / plannedAmountCents * 100;
  bool get isOverBudget => actualAmountCents > plannedAmountCents;

  @override
  List<Object?> get props => [id, accountId, accountName, plannedAmountCents, actualAmountCents, notes];
}

class BudgetView extends Equatable {
  const BudgetView({
    required this.id,
    required this.name,
    required this.month,
    required this.currencyCode,
    required this.totalAmountCents,
    this.totalActualCents = 0,
    this.usagePct = 0,
    this.items = const [],
  });
  final String id;
  final String name;
  final String month;
  final String currencyCode;
  final int totalAmountCents;
  final int totalActualCents;
  final double usagePct;
  final List<BudgetItemView> items;

  int get totalRemainingCents => totalAmountCents - totalActualCents;
  bool get isOverBudget => totalActualCents > totalAmountCents;

  @override
  List<Object?> get props => [id, name, month, currencyCode, totalAmountCents, totalActualCents, usagePct, items];
}
```

- [ ] **Step 2: BudgetRepository abstract**

`budget/domain/repositories/budget_repository.dart`：
```dart
abstract class BudgetRepository {
  Future<List<BudgetView>> listBudgets({bool activeOnly = false});
  Future<BudgetView> getBudget(String id);
  Future<BudgetView> getBudgetByMonth(String month);
  Future<BudgetView> createBudget({required String name, required String month, required String currencyCode, required List<({String accountId, int plannedAmountCents, String? notes})> items});
  Future<void> deleteBudget(String id);
  Future<BudgetView> addItem({required String budgetId, required String accountId, required int plannedAmountCents, String? notes});
  Future<BudgetView> removeItem({required String budgetId, required String itemId});
}
```

- [ ] **Step 3: BudgetRemoteDataSource(照 holding_remote_ds.dart)**

`budget/data/budget_remote_ds.dart`：GrpcClient + AuthRetryCaller 自建 `BudgetServiceClient`(照 `HoldingRemoteDataSource` 范式)。proto DTO → BudgetView mapper(`budgetDtoToView` / `budgetDetailDtoToView`, Int64→int `.toInt()`)。
```dart
// 关键 mapper(照 holding_mapper 范式):
BudgetView budgetDtoToView(BudgetDTO dto) => BudgetView(
  id: dto.id, name: dto.name, month: dto.month, currencyCode: dto.currencyCode,
  totalAmountCents: dto.totalAmountCents.toInt(),
  totalActualCents: dto.totalActualCents.toInt(),
  usagePct: dto.usagePct,
);
BudgetView budgetDetailDtoToView(BudgetDetailDTO dto) => BudgetView(
  id: dto.budget.id, name: dto.budget.name, /* ... */
  totalAmountCents: dto.budget.totalAmountCents.toInt(),
  totalActualCents: dto.totalActualCents.toInt(),
  usagePct: dto.usagePct,
  items: dto.items.map((i) => BudgetItemView(
    id: i.id, accountId: i.accountId,
    plannedAmountCents: i.plannedAmountCents.toInt(),
    actualAmountCents: i.actualAmountCents.toInt(),
    notes: i.notes.isEmpty ? null : i.notes,
  )).toList(),
);
```
(实现者照 `holding_remote_ds.dart` 完整 RPC 调用 + AuthRetryCaller `_retry` 包装。createBudget 的 items 用 proto `BudgetItemInput`。)

- [ ] **Step 4: BudgetRepositoryImpl**

`budget/data/budget_repository_impl.dart`(照 `holding_repository_impl.dart`)：构造注入 `BudgetRemoteDataSource`, 实现 abstract, 委托 ds。加 `_guard`(照 holding)。

- [ ] **Step 5: build_runner 注册(@LazySingleton/@Injectable)**

`budget_remote_ds.dart` + `budget_repository_impl.dart` 加 `@LazySingleton()` 注解(照 holding)。跑 `dart run build_runner build --delete-conflicting-outputs`。

- [ ] **Step 6: 写测(mapper + ds constructibility)**

`test/budget/data/budget_remote_ds_test.dart`(照 `holding_remote_ds_test.dart`):mapper 测(Int64→int, 空 notes, items 映射)+ ds 构造测。

- [ ] **Step 7: 跑测 + analyze**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/budget/
flutter analyze lib/budget/ test/budget/ 2>&1 | grep -E "error -" | grep -v pbserver
```
Expected:测绿 + 无新 error。

- [ ] **Step 8: Commit**

```bash
git add yucai/client/lib/budget/ yucai/client/test/budget/
git commit -m "feat(holding-d-budget-flutter): data 层 BudgetRemoteDataSource + Repository + BudgetView(Task 6)"
```

---

## Task 7: Flutter BudgetBloc + events/states

**Files:**
- Create: `yucai/client/lib/budget/presentation/bloc/budget_bloc.dart` + `budget_event.dart` + `budget_state.dart`
- Test: `yucai/client/test/budget/presentation/bloc/budget_bloc_test.dart`

**Interfaces:**
- Consumes：Task 6 `BudgetRepository`
- Produces：`BudgetBloc` + events(LoadListRequested/LoadDetailRequested/CreateBudgetRequested/DeleteBudgetRequested/AddItemRequested/RemoveItemRequested)+ states。Task 8/9/10 页面消费。

**背景**：照 `holding/presentation/bloc/holding_bloc.dart` 范式(flutter_bloc, Equatable states, 事件→repo 调用→state)。

- [ ] **Step 1: events(budget_event.dart)**

```dart
abstract class BudgetEvent extends Equatable { const BudgetEvent(); @override List<Object?> get props => []; }
class LoadListRequested extends BudgetEvent { final bool activeOnly; LoadListRequested({this.activeOnly = false}); @override List<Object?> get props => [activeOnly]; }
class LoadDetailRequested extends BudgetEvent { final String id; const LoadDetailRequested(this.id); @override List<Object?> get props => [id]; }
class CreateBudgetRequested extends BudgetEvent {
  final String name, month, currencyCode;
  final List<({String accountId, int plannedAmountCents, String? notes})> items;
  const CreateBudgetRequested({required this.name, required this.month, required this.currencyCode, required this.items});
  @override List<Object?> get props => [name, month, currencyCode, items];
}
class DeleteBudgetRequested extends BudgetEvent { final String id; const DeleteBudgetRequested(this.id); @override List<Object?> get props => [id]; }
class AddItemRequested extends BudgetEvent { final String budgetId, accountId; final int plannedAmountCents; final String? notes; const AddItemRequested({required this.budgetId, required this.accountId, required this.plannedAmountCents, this.notes}); @override List<Object?> get props => [budgetId, accountId, plannedAmountCents, notes]; }
class RemoveItemRequested extends BudgetEvent { final String budgetId, itemId; const RemoveItemRequested({required this.budgetId, required this.itemId}); @override List<Object?> get props => [budgetId, itemId]; }
```

- [ ] **Step 2: states(budget_state.dart)**

```dart
abstract class BudgetState extends Equatable { const BudgetState(); @override List<Object?> get props => []; }
class BudgetInitial extends BudgetState {}
class BudgetLoading extends BudgetState {}
class BudgetListLoaded extends BudgetState { final List<BudgetView> budgets; const BudgetListLoaded(this.budgets); @override List<Object?> get props => [budgets]; }
class BudgetDetailLoaded extends BudgetState { final BudgetView budget; const BudgetDetailLoaded(this.budget); @override List<Object?> get props => [budget]; }
class BudgetError extends BudgetState { final String message; const BudgetError(this.message); @override List<Object?> get props => [message]; }
```

- [ ] **Step 3: bloc(budget_bloc.dart, 照 holding_bloc)**

```dart
class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  BudgetBloc(this._repo) : super(BudgetInitial()) {
    on<LoadListRequested>(_onLoadList);
    on<LoadDetailRequested>(_onLoadDetail);
    on<CreateBudgetRequested>(_onCreate);
    on<DeleteBudgetRequested>(_onDelete);
    on<AddItemRequested>(_onAddItem);
    on<RemoveItemRequested>(_onRemoveItem);
  }
  final BudgetRepository _repo;

  Future<void> _onLoadList(LoadListRequested e, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    try { emit(BudgetListLoaded(await _repo.listBudgets(activeOnly: e.activeOnly))); }
    catch (err) { emit(BudgetError(err.toString())); }
  }
  // _onLoadDetail → getBudget → BudgetDetailLoaded
  // _onCreate → createBudget → emit + re-load list
  // _onDelete → deleteBudget → re-load list
  // _onAddItem / _onRemoveItem → 调 repo → re-load detail(emit BudgetDetailLoaded)
}
```
(实现者照 holding_bloc 完整各 handler, 失败 emit BudgetError。)

- [ ] **Step 4: build_runner + DI 注册**

budget_bloc 加 `@Injectable()`(照 holding_bloc)。`dart run build_runner build --delete-conflicting-outputs`。

- [ ] **Step 5: 写测(budget_bloc_test, 照 holding_bloc_test)**

mock BudgetRepository(fake), 验各 event → state。`test/budget/presentation/bloc/budget_bloc_test.dart`。

- [ ] **Step 6: 跑测 + analyze + Commit**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/budget/presentation/bloc/
git add yucai/client/lib/budget/presentation/bloc/ yucai/client/test/budget/presentation/bloc/
git commit -m "feat(holding-d-budget-flutter): BudgetBloc + events/states(Task 7)"
```

---

## Task 8: Flutter BudgetListPage

**Files:**
- Create: `yucai/client/lib/budget/presentation/pages/budget_list_page.dart`
- Test: `yucai/client/test/budget/presentation/pages/budget_list_page_test.dart`

**Interfaces:**
- Consumes：Task 7 `BudgetBloc` + Task 6 `BudgetView`。AccountBloc(若需账户名 lookup, defer — 列表用 budget.Name/Month/总额即可)。
- Produces：`/budgets` list 页(月份切换 + 卡片 + 新建入口)。Task 11 router 挂载。

**背景**：御财设计语言(金 #b08d57/衬线/米白, lucide icons, 照 holding UI)。月份切换客户端 filter budgets by month(或 RPC activeOnly)。卡片显 BudgetView 总进度环 + UsagePct% + 超支色。

- [ ] **Step 1: BudgetListPage widget(照 holding list 卡片范式)**

`budget_list_page.dart`：
- StatefulWidget, initState dispatch `LoadListRequested`
- BlocBuilder<BudgetBloc>: loading → CircularProgressIndicator; error → 错误态 + 重试; loaded → 月份切换(← month →)+ ListView of budget cards
- 每卡:Name + Month + 总进度(剩余/总额)+ UsagePct% + 进度条(超支红 `#c0392b` / 正常金/绿)+ onTap → push `/budgets/:id`
- AppBar: 标题"预算" + action "新建"(lucide `plus`)→ push `/budgets/new`
- 进度条 widget(照 holding 卡片 sparkline/bar 范式, 用 `LinearProgressIndicator` 或自定义)

(实现者照 `holdings_page.dart` 或 `debts_page.dart` 的 list + 卡片 + AppBar 范式。)

- [ ] **Step 2: 写测(budget_list_page_test, 照 holdings_page_test)**

mock BudgetBloc(seed BudgetListLoaded with 2 budgets: 一个正常 25% 一个超支 120%), 验:渲染卡片 + 月份 + UsagePct% + 超支红色 + 新建按钮 tap → push `/budgets/new` + 卡片 tap → push `/budgets/:id`。需注册 fake CurrencySettings(照 home_page_test 范式, 若页面读 settings)。

- [ ] **Step 3: 跑测 + analyze + Commit**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/budget/presentation/pages/budget_list_page_test.dart
git add yucai/client/lib/budget/presentation/pages/budget_list_page.dart yucai/client/test/budget/presentation/pages/
git commit -m "feat(holding-d-budget-flutter): BudgetListPage(月份切换+卡片+进度)(Task 8)"
```

---

## Task 9: Flutter BudgetDetailPage

**Files:**
- Create: `yucai/client/lib/budget/presentation/pages/budget_detail_page.dart`
- Test: `yucai/client/test/budget/presentation/pages/budget_detail_page_test.dart`

**Interfaces:**
- Consumes：BudgetBloc(LoadDetailRequested by id)+ BudgetView + account name lookup(读 account 仓库名, 或 defer 显示 accountId)。Task 11 router 挂载 `/budgets/:id`。
- Produces：详情页(总进度环 + per-item 列表)。

- [ ] **Step 1: BudgetDetailPage widget(照 holding_detail_page 范式)**

- StatefulWidget(id), initState dispatch `LoadDetailRequested(id)`
- BlocBuilder: loading/error/loaded(BudgetDetailLoaded)
- 头:Name + Month + 总进度环(圆形 `CircularProgressIndicator` 或 fl_chart Pie, 显 UsagePct%)+ TotalActual/TotalAmount + Remaining
- per-item 列表:每行 category 账户名(+ account name lookup via AccountBloc/ListAccounts, 或显示 account 最后 4 位 defer)+ Planned + Actual + 进度条 + 占比% + 剩余 + 超支标记
- AppBar: 编辑(lucide `pencil`)→ push `/budgets/:id/edit`; 删 → dispatch DeleteBudgetRequested + pop

- [ ] **Step 2: account name lookup(简化)**

per-item 显账户名需 account lookup。简化:BudgetItemView.accountName 由 ds 在 mapper 时填(需 ds 调 account repo batch lookup)—— **defer**, 首批显 accountId 前 8 位 或 "账户"(占位)。或读 AccountBloc state(若已 load)。**MVP**:显 accountName ?? '分类账户'(占位), 真名 lookup defer。Note 在 progress。

- [ ] **Step 3: 写测(照 holding_detail_page_test)**

mock BudgetBloc(seed BudgetDetailLoaded with budget 2 items: 一个 50% 一个超支), 验:总进度环渲染 + per-item 进度条 + 超支标记 + 编辑 tap → push edit + 删 → dispatch。

- [ ] **Step 4: 跑测 + analyze + Commit**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/budget/presentation/pages/budget_detail_page_test.dart
git add yucai/client/lib/budget/presentation/pages/budget_detail_page.dart yucai/client/test/budget/presentation/pages/budget_detail_page_test.dart
git commit -m "feat(holding-d-budget-flutter): BudgetDetailPage(总进度环+per-item 进度)(Task 9)"
```

---

## Task 10: Flutter BudgetFormPage(创建/编辑 + account picker 过滤 expense)

**Files:**
- Create: `yucai/client/lib/budget/presentation/pages/budget_form_page.dart`
- Test: `yucai/client/test/budget/presentation/pages/budget_form_page_test.dart`

**Interfaces:**
- Consumes：BudgetBloc(CreateBudgetRequested / AddItemRequested / RemoveItemRequested)+ AccountBloc(ListAccounts, filter `accountType == expense`)。
- Produces：创建/编辑表单页。Task 11 router 挂载 `/budgets/new` + `/budgets/:id/edit`。

**背景**：**account picker 只列 expense 账户(category)** —— 自动排除投资/wallet(spec 决策 ④/⑥)。复用 AccountBloc accounts, 客户端 filter `accountType == expense`。

- [ ] **Step 1: BudgetFormPage widget(照 debt/holding form 范式)**

- StatefulWidget(optional budgetId for edit)
- Name TextField + Month picker(YYYY-MM, 默认当月)+ CurrencyCode(CNY 默认, dropdown)
- Items 编辑:每 item 一行 = account dropdown(只列 expense 账户)+ PlannedAmount TextField + 删按钮。"+ 加项"按钮加新 item 行。
- 提交:dispatch CreateBudgetRequested(name, month, currency, items)→ 成功 pop 回 list。编辑模式(有 budgetId):加载现有 → 改 → 提交(AddItem/RemoveItem 增量 或 简化为 delete+recreate; **MVP 简化: 编辑 = 删旧 + 重建** defer 增量)。

- [ ] **Step 2: account picker 过滤 expense(关键)**

```dart
// 读 AccountBloc state(已 LoadAccounts), filter expense:
final expenseAccounts = state.accounts.where((a) => a.accountType == AccountType.expense).toList();
// DropdownButton items = expenseAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
```
(确认 AccountEntity.accountType 字段名 + AccountType.expense 枚举, 读 `lib/account/domain/entities/account_entity.dart` + `value_objects.dart`。)

- [ ] **Step 3: 写测(照 debt_form_page_test)**

mock BudgetBloc + AccountBloc(seed accounts: 2 expense + 1 asset + 1 investment), 验:account picker **只列 2 expense**(排除 asset/investment)+ 填表 + 提交 → dispatch CreateBudgetRequested + pop。空 items 禁用提交(domain 要求 ≥1 item)。

- [ ] **Step 4: 跑测 + analyze + Commit**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/budget/presentation/pages/budget_form_page_test.dart
git add yucai/client/lib/budget/presentation/pages/budget_form_page.dart yucai/client/test/budget/presentation/pages/budget_form_page_test.dart
git commit -m "feat(holding-d-budget-flutter): BudgetFormPage(account picker 过滤 expense)(Task 10)"
```

---

## Task 11: router + app_shell sidebar budget 入口(branch 6)

**Files:**
- Modify: `yucai/client/lib/app/router.dart`(加 `/budgets` branch 6 + 子路由)
- Modify: `yucai/client/lib/app/widgets/app_shell.dart`(sidebar "预算" 入口, lucide `wallet`)
- Test: `yucai/client/test/app/router_test.dart`(加 budget route 解析测)

**Interfaces:**
- Consumes：Task 7-10 三页面 + BudgetBloc(router 提供, 照 holdings branch)。
- Produces：`/budgets` 路由可达 + sidebar 入口。

**背景**：router.dart 现 6 branch(home/accounts/transactions/debts/receivables/holdings)。加 branch 6 = budget。**子路由 `/new` `/:id` `/edit` 静态在 `/:id` 前**(照 holdings branch 5 路由模式, 见 D-goal/A-flutter 教训)。**仅 sidebar, 不进 bottom nav**(避免 7 拥挤)。

- [ ] **Step 1: router.dart 加 budget branch 6**

读 `lib/app/router.dart`, 照 holdings branch(StatefulShellBranch + routes)。加：
```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
  branches: [
    // ... 现有 6 branch ...
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (ctx, s) => BlocProvider<BudgetBloc>(create: (_) => getIt<BudgetBloc>()..add(LoadListRequested()), child: const BudgetListPage()),
          routes: [
            GoRoute(path: 'new', builder: (ctx, s) => const BudgetFormPage()),           // 静态在 :id 前
            GoRoute(path: ':id', builder: (ctx, s) => BlocProvider<BudgetBloc>(create: (_) => getIt<BudgetBloc>()..add(LoadDetailRequested(s.pathParameters['id']!)), child: BudgetDetailPage(id: s.pathParameters['id']!)), routes: [
              GoRoute(path: 'edit', builder: (ctx, s) => BudgetFormPage(budgetId: s.pathParameters['id'])),
            ]),
          ],
        ),
      ],
    ),
  ],
)
```
(实现者照 holdings branch 精确范式 + branch index 调整。BudgetBloc DI 已 Task 7 注册。)

- [ ] **Step 2: app_shell.dart sidebar 加"预算"入口**

读 `lib/app/widgets/app_shell.dart`, sidebar NavigationDestination 加"预算"(lucide `wallet` icon, branch index 6)。**不进 bottom nav**(bottom nav 仍 6 个, 预算仅 sidebar 可达 —— 若 sidebar/bottom nav 共享 destinations, 调整为 sidebar-only;照现有 sidebar/bottom nav 分离逻辑)。

- [ ] **Step 3: router_test 加 budget 测**

`test/app/router_test.dart` 加:`/budgets resolves to budget branch`, `/budgets/new`, `/budgets/:id`, sidebar 预算 tap navigates。**需注册 fake CurrencySettings + fake BudgetRepository**(照 home_page_test fake 模式, 因 budget 页可能读 settings/repo)。

- [ ] **Step 4: 跑 router_test + app_shell_test + analyze + Commit**

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/app/
flutter analyze lib/app/ 2>&1 | grep -E "error -" | grep -v pbserver
git add yucai/client/lib/app/ yucai/client/test/app/
git commit -m "feat(holding-d-budget-flutter): router /budgets branch 6 + sidebar 入口(Task 11)"
```

---

## Task 12: 全链路 + final review

**Files:** 无新改动(验证 + review task)

- [ ] **Step 1: server 全量测 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./... -count=1 && go build ./...
```
Expected:全绿。

- [ ] **Step 2: client 全量测 + analyze**

```bash
cd /e/projects/syfinance/yucai/client && flutter test
flutter analyze 2>&1 | grep -E "error -" | grep -v pbserver | grep -v "\.pb\.dart"
```
Expected:全绿(已知 3 预存 fail:account/debt/transaction_detail_page_test —— 非 D-budget 引入, 照 D-currency defer 记录);analyze 非 pbserver error = 0。

- [ ] **Step 3: 端到端手动验证(flutter run + 启 server)**

照 [[yucai-dev-env]] debug 模式启 client + server。验证:
1. sidebar"预算"→ BudgetListPage 空 → "新建"
2. BudgetFormPage 选 month + 加 expense category item(餐饮 ¥2000)→ 提交 → 回 list 见卡片
3. 记一笔餐饮支出 ¥500(经 transactions)→ 回 budget detail 见 actuals=¥500(25%)
4. buy holding(cash→investment)→ 回 budget detail actuals 不变(投资排除)

- [ ] **Step 4: final whole-branch review(opus, subagent-driven-development 的 reviewer 阶段)**

review 范围 = D-budget 起点(aaf3400 spec commit 后)→ HEAD。照 D-currency/D-goal final review 模式:correctness 抽样(actuals 读时算 + transfer 自动排除 + picker 过滤 expense + 路由优先级静态在 :id 前 + DI 注册 + fl_chart/proto 对齐)+ defer 项记录。Ready to merge 判定。

- [ ] **Step 5: 记 progress.md + 更新 memory**

`.superpowers/sdd/progress.md` 加 D-budget section(per-task ledger)。更新 memory `holding-asset-management-todo.md`(D-budget ✅, Holding 全子项目完整)。

---

## 风险/教训(plan 执行时留意, 照 D-currency/D-goal 教训)

- **wire_gen 手改**:provideBudgetService 加 txnSvc 参数, 声明顺序 budgetService 在 transactionService 之后(镜像 D-currency networth)。不跑 wire CLI。
- **ent 查询 join**(Task 1):entry 无直接 date 字段需 HasTransactionWith join transaction_date。读 transaction_repo.go 现有 join 模式 + ent predicate 命名。
- **budget item = expense 账户**:UI 层硬过滤(Task 10 picker)。若误允许 asset 账户, actuals 语义错(asset debit = 钱 in, 非 spending)。Task 10 测断言排除 asset/investment。
- **actuals 读时算性能**(Task 3 ListBudgets):N 预算 × M item × SpendingByAccount。MVP N 小可接受, 优化 defer(per-task review 留意)。
- **flutter analyze 基线 22 error**(全 pbserver)+ 3 预存 fail(account/debt/transaction_detail)—— 非 D-budget 引入, 不修。
- **proto regen**(Task 2):protoc_plugin 25.0.0(Dart), buf(Go)。stub 基线变化留意 analyze。
- **路由优先级**(Task 11):`/new` `/edit` 静态必须在 `/:id` 前(照 holdings branch 教训), 否则 "new" 被当 :id。
- **依赖**:[[yucai-wire-handmaintained]] + [[yucai-dev-env]](protoc_plugin 25.0.0, make 不在 PATH)+ [[od-prototype-to-flutter]]
