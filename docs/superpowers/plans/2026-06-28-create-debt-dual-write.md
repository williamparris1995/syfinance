# CreateDebt 双写(borrowedOut 借出 → 应收)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `CreateDebt` 在创建借出债权(borrowedOut)时同步记一笔复式 transaction(`credit` 资金来源账户现金 − + `debit` 应收账户 +),金额 = 借出本金,使应收账户余额从创建起即 = 借出本金,根治「RecordPayment 减应收 → 负余额」bug。

**Architecture:** 完全对称已实现的 RecordPayment 双写:双写逻辑全在 gRPC handler 层(`debt_handler.go`),`application.CreateDebt` service 不变。`CreateDebtRequest` 加 `source_account_id`(borrowedOut 必填,borrowedIn 忽略)。handler 先 `validateSourceAccount`(fail-fast,失败则 debt 不创建),再 `service.CreateDebt`,再 `recordCreateTransaction`(best-effort,失败 log+吞)。

**Tech Stack:** Go (ent + wire + gRPC) backend, Flutter (bloc + protobuf) client, buf 生成 proto stubs。

## Global Constraints

- **proto 生成**(`make` 在 Git Bash 不可用,用直接命令):Go stubs 用 `cd yucai/proto && buf generate --template buf.gen.go.yaml`;Dart stubs 用 `bash yucai/proto/gen-dart.sh`(脚本自己 cd 到 proto/)。两者都要跑。Dart 生成会打印预存的 unused-import 警告(auth/common/currency proto),非本次引入,可忽略。
- **Go 测试**:`cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run <TestName> -v -count=1`
- **Go 编译**:`cd yucai/server && go build ./...`
- **Flutter 测试**:`cd yucai/client && flutter test test/debt/presentation/pages/receivable_form_page_test.dart`
- **Flutter 静态检查**:`cd yucai/client && flutter analyze lib/debt`
- **日志**:English structured(`slog.Error` 带 `"operation"` + 相关 id + `"amount_cents"` + `"error"`,参照现有 `recordPaymentTransaction`)。
- **前端 UI 文本**:中文直接字符串(御财惯例,不用 i18n `t()` —— 区别于 syfinance Tauri)。
- **复式平衡**:debit sum = credit sum(enforce_double_entry trigger);borrowedOut 双写两条 entry 金额必须相等。
- **commit**:中文 conventional commits(参照 `feat(debt): ...`)。
- **DebtType 语义**:`BorrowedIn` = 我欠债(负债),`BorrowedIn` = 我借出(应收)。本期只对 `BorrowedOut` 双写。
- **金额单位**:int64 cents,全部用 `_00` 后缀字面量(如 `1_000_00` = 1000.00)。

---

## File Structure

### 后端(Go)
- **Modify** `yucai/proto/debt/v1/debt.proto` — `CreateDebtRequest` 加 `source_account_id = 10`
- **Regenerate** `yucai/server/internal/proto/debt/v1/debt.pb.go`(`make proto`,Task 1,产物不改手)
- **Modify** `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go` — `CreateDebt` 双写接线 + 新增 `validateSourceAccount` / `recordCreateTransaction` / `buildCreateEntries`
- **Modify** `yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go` — 复用现有 fakes(`fakeDebtRepo`/`fakeAccountLookup`/`recordingTxnRepo`/`mutatingBalanceUpdater`/`failingTxnRepo`),加 `setupCreateDebtHarness` + CreateDebt 测试

### 前端(Flutter)
- **Regenerate** `yucai/client/lib/proto/debt/v1/debt.pb.dart`(`make gen-dart`,Task 1,产物不改手)
- **Modify** `yucai/client/lib/debt/presentation/bloc/debt_event.dart` — `CreateDebtParams` 加 `sourceAccountId`
- **Modify** `yucai/client/lib/debt/domain/repositories/debt_repository.dart` — `create` 加 `sourceAccountId` 参数
- **Modify** `yucai/client/lib/debt/data/debt_repository_impl.dart` — `create` 透传 `sourceAccountId`
- **Modify** `yucai/client/lib/debt/data/debt_remote_ds.dart` — `create` 加 `sourceAccountId` → `pb.CreateDebtRequest`
- **Modify** `yucai/client/lib/debt/presentation/bloc/debt_bloc.dart` — `_onCreate` 传 `sourceAccountId`
- **Modify** `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart` — 来源账户选择器 + state + 提交传参
- **Modify** `yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart` — 来源选择 → 提交带 `sourceAccountId` 的 widget test

---

## Task 1: proto `source_account_id` 字段 + 重新生成 stubs

**Files:**
- Modify: `yucai/proto/debt/v1/debt.proto:67-77`
- Regenerate: `yucai/server/internal/proto/debt/v1/debt.pb.go`, `yucai/client/lib/proto/debt/v1/debt.pb.dart`

**Interfaces:**
- Produces: `pb.CreateDebtRequest.SourceAccountId`(Go 字段,`string`)/ Dart `CreateDebtRequest.sourceAccountId`(`String`)。后续 Task 3(handler)/ Task 5(remote_ds)依赖此字段。

> 这是基础设施 task:proto 是类型定义,无单元测试。验证 = 生成成功 + 双端编译通过。后续 task 的测试依赖这些生成类型。

- [ ] **Step 1: 在 CreateDebtRequest 加 source_account_id 字段**

修改 `yucai/proto/debt/v1/debt.proto`,`message CreateDebtRequest` 末尾(`subtype = 9;` 之后)加一行:

```proto
message CreateDebtRequest {
  string account_id = 1;
  string counterparty = 2;
  double interest_rate = 3;
  AmortizationMethod amortization_method = 4;
  string start_date = 5;
  string due_date = 6;
  int64 total_principal_cents = 7;
  DebtType debt_type = 8;
  string subtype = 9;
  // borrowedOut 双写:借出资金的来源账户(cash asset)。borrowedOut 必填;
  // borrowedIn 忽略(不双写)。空字符串 = 不双写。
  string source_account_id = 10;
}
```

- [ ] **Step 2: 生成 Go + Dart stubs**

Run:
```bash
cd yucai/proto && buf generate --template buf.gen.go.yaml && bash /e/projects/syfinance/yucai/proto/gen-dart.sh
```
Expected: Go 生成成功;Dart 生成成功(打印预存的 auth/common/currency unused-import 警告,可忽略)。`debt.pb.go` 里出现 `CreateDebtRequest.SourceAccountId` 字段 + getter;`debt.pb.dart` 里出现 `sourceAccountId` 的 tagNumber 10 getter/setter。

- [ ] **Step 3: 验证双端编译**

Run:
```bash
cd yucai/server && go build ./...
```
Expected: 编译通过(无错误)。

Run:
```bash
cd yucai/client && flutter analyze lib/debt lib/proto
```
Expected: 无 error(warning 可忽略)。

- [ ] **Step 4: Commit**

```bash
git add yucai/proto/debt/v1/debt.proto yucai/server/internal/proto yucai/client/lib/proto
git commit -m "feat(debt-proto): CreateDebtRequest 加 source_account_id(borrowedOut 双写准备)"
```

---

## Task 2: `buildCreateEntries` 纯函数(borrowedOut 复式 entry 构造)

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`(在 `buildPaymentEntries` 之后加新函数)
- Test: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go`

**Interfaces:**
- Produces: `buildCreateEntries(sourceAcc, debtAcc accountdomain.Account, amountCents int64) []transactionApp.EntryInput`。Task 3 的 `recordCreateTransaction` 调用它。

- [ ] **Step 1: 写失败测试**

在 `debt_handler_test.go` 末尾加:

```go
// TestBuildCreateEntries_BorrowedOut verifies the borrowedOut creation
// double-entry pair: credit source (cash out) + debit receivable (asset +),
// balanced, with each account's ChartCode carried through. This is the
// inverse of buildPaymentEntries for BorrowedOut.
func TestBuildCreateEntries_BorrowedOut(t *testing.T) {
	src := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"}
	rcv := accountdomain.Account{ID: uuid.New(), ChartCode: "1122"}
	const amount int64 = 1_000_00

	entries := buildCreateEntries(src, rcv, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	// entries[0]: source — credit only (cash out).
	if entries[0].AccountID != src.ID {
		t.Errorf("entries[0] account: got %s, want source %s", entries[0].AccountID, src.ID)
	}
	if entries[0].ChartOfAccountCode != "1001" {
		t.Errorf("entries[0] chart code: got %q, want 1001", entries[0].ChartOfAccountCode)
	}
	if entries[0].CreditCents != amount || entries[0].DebitCents != 0 {
		t.Errorf("source entry: expected credit=%d debit=0, got credit=%d debit=%d",
			amount, entries[0].CreditCents, entries[0].DebitCents)
	}
	// entries[1]: receivable — debit only (asset +).
	if entries[1].AccountID != rcv.ID {
		t.Errorf("entries[1] account: got %s, want receivable %s", entries[1].AccountID, rcv.ID)
	}
	if entries[1].ChartOfAccountCode != "1122" {
		t.Errorf("entries[1] chart code: got %q, want 1122", entries[1].ChartOfAccountCode)
	}
	if entries[1].DebitCents != amount || entries[1].CreditCents != 0 {
		t.Errorf("receivable entry: expected debit=%d credit=0, got debit=%d credit=%d",
			amount, entries[1].DebitCents, entries[1].CreditCents)
	}
	// Balanced: source credit == receivable debit.
	if entries[0].CreditCents != entries[1].DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", entries[0].CreditCents, entries[1].DebitCents)
	}
}
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestBuildCreateEntries_BorrowedOut -v -count=1
```
Expected: FAIL / 编译错误 `undefined: buildCreateEntries`。

- [ ] **Step 3: 实现 buildCreateEntries**

在 `debt_handler.go` 的 `buildPaymentEntries` 函数之后加:

```go
// buildCreateEntries constructs the borrowedOut creation double-entry pair.
// amountCents is the lent principal (TotalPrincipalCents). It is the inverse
// of buildPaymentEntries for BorrowedOut:
//
//	credit source_account  (asset −, cash out)
//	debit  debt.account_id (asset receivable +)
//
// Each entry carries the account's ChartOfAccountCode so the transaction
// service can persist and route it correctly.
func buildCreateEntries(sourceAcc, debtAcc accountdomain.Account, amountCents int64) []transactionApp.EntryInput {
	return []transactionApp.EntryInput{
		{AccountID: sourceAcc.ID, ChartOfAccountCode: sourceAcc.ChartCode, CreditCents: amountCents},
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: amountCents},
	}
}
```

- [ ] **Step 4: 跑测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestBuildCreateEntries_BorrowedOut -v -count=1
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go
git commit -m "feat(debt): buildCreateEntries(borrowedOut 借出复式 entries 构造)"
```

---

## Task 3: CreateDebt 双写 handler 接线(validate + record + happy path)

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go` — 改 `CreateDebt`(:36-72)+ 加 `validateSourceAccount` + `recordCreateTransaction`
- Test: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go` — 加 `setupCreateDebtHarness` + 3 个测试

**Interfaces:**
- Consumes: `buildCreateEntries`(Task 2),`h.accountLookup.FindByID`,`h.transactionSvc.RecordTransaction`,`accountdomain.AccountTypeAsset`
- Produces: `CreateDebt` borrowedOut 路径双写;`validateSourceAccount(ctx, tenantID, sourceAccountID, debtAccountID uuid.UUID, principalCents int64) (*accountdomain.Account, error)`;`recordCreateTransaction(ctx, tenantID, sourceAccountID uuid.UUID, sourceAcc *accountdomain.Account, debtAccountID uuid.UUID, principalCents int64)`

- [ ] **Step 1: 加 setupCreateDebtHarness + 写 happy-path 失败测试**

在 `debt_handler_test.go` 末尾加 harness + 第一个测试:

```go
// ---------------------------------------------------------------------------
// CreateDebt double-write tests (create-debt-dual-write)
// ---------------------------------------------------------------------------

// setupCreateDebtHarness wires a DebtHandler with empty debt repo, a fake
// account lookup seeding a receivable (debt) account [req.AccountId] + a cash
// source account [req.source_account_id], and a real transaction service
// backed by a recording repo + mutating balance updater. No debt is pre-seeded
// (CreateDebt creates it). Returns debtRepo so fail-fast tests can assert no
// debt was persisted.
func setupCreateDebtHarness(t *testing.T) (
	h *DebtHandler,
	tenantID, sourceAccID, debtAccID uuid.UUID,
	txnRepo *recordingTxnRepo,
	accLookup *fakeAccountLookup,
	debtRepo *fakeDebtRepo,
) {
	t.Helper()
	tenantID = uuid.New()

	// Receivable account = req.AccountId (asset / otherAsset).
	rcvAcc, err := accountdomain.NewAccount(tenantID, "receivable account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed receivable account: %v", err)
	}
	rcvAcc.ChartCode = "1122" // receivable-ish chart code placeholder
	debtAccID = rcvAcc.ID

	// Source account = req.source_account_id (cash asset), ample balance.
	srcAcc, err := accountdomain.NewAccount(tenantID, "cash account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed source account: %v", err)
	}
	srcAcc.ChartCode = "1001"
	srcAcc.CurrentBalanceCents = 10_000_00
	sourceAccID = srcAcc.ID

	accLookup = newFakeAccountLookup()
	accLookup.seed(rcvAcc)
	accLookup.seed(srcAcc)

	debtRepo = newFakeDebtRepo()
	txnRepo = &recordingTxnRepo{}
	txnSvc := txnApp.NewService(txnRepo, accLookup, mutatingBalanceUpdater{lookup: accLookup})
	debtSvc := application.NewService(debtRepo)
	h = NewDebtHandler(debtSvc, txnSvc, accLookup)
	return
}

// TestCreateDebt_BorrowedOut_DoubleWrite: creating a borrowedOut debt records
// a balancing transaction crediting source (cash −) and debiting the receivable
// account (+principal), and both balances move accordingly.
func TestCreateDebt_BorrowedOut_DoubleWrite(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, _ :=
		setupCreateDebtHarness(t)

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(),
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
		Subtype:             domain.ReceivableSubtypePersonal,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("CreateDebt returned empty debt")
	}

	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	srcEntry, rcvEntry := entryPair(txnRepo.saved, sourceAccID, debtAccID)
	if srcEntry.CreditCents == 0 || srcEntry.DebitCents != 0 {
		t.Errorf("source entry: expected credit only, got debit=%d credit=%d",
			srcEntry.DebitCents, srcEntry.CreditCents)
	}
	if rcvEntry.DebitCents == 0 || rcvEntry.CreditCents != 0 {
		t.Errorf("receivable entry: expected debit only, got debit=%d credit=%d",
			rcvEntry.DebitCents, rcvEntry.CreditCents)
	}
	if srcEntry.CreditCents != rcvEntry.DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", srcEntry.CreditCents, rcvEntry.DebitCents)
	}
	if srcEntry.CreditCents != 1_000_00 {
		t.Errorf("amount: got %d, want 100000", srcEntry.CreditCents)
	}

	// Balances: source (cash) decreased by principal; receivable increased.
	const srcBefore int64 = 10_000_00
	if got := accLookup.byID[sourceAccID].CurrentBalanceCents; got != srcBefore-1_000_00 {
		t.Errorf("source balance: got %d, want %d", got, srcBefore-1_000_00)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != 1_000_00 {
		t.Errorf("receivable balance: got %d, want 100000", got)
	}
}
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestCreateDebt_BorrowedOut_DoubleWrite -v -count=1
```
Expected: FAIL(`txnRepo.saved == nil` —— CreateDebt 还没双写)。

- [ ] **Step 3: 改 CreateDebt handler 接线 + 加 validateSourceAccount + recordCreateTransaction**

替换 `debt_handler.go` 的 `CreateDebt` 函数(原 :35-72 整体替换):

```go
// CreateDebt creates a new debt with amortization schedule.
//
// borrowedOut double-write (create-debt-dual-write): when creating a loan the
// user lent out, a balancing transaction moves the lent principal from the
// source (cash) account to the receivable account, so the receivable balance
// reflects the principal from creation (fixes the negative-receivable bug
// where RecordPayment reduced a zero-initial receivable).
//
// Flow:
//  1. Parse source_account_id (borrowedOut required; borrowedIn ignores it).
//  2. validateSourceAccount BEFORE service.CreateDebt — fail fast so an
//     invalid source leaves no debt persisted.
//  3. service.CreateDebt generates schedule + persists (unchanged).
//  4. recordCreateTransaction (best-effort): on failure, log + swallow; the
//     debt is already created and is not rolled back (mirrors RecordPayment).
func (h *DebtHandler) CreateDebt(ctx context.Context, req *pb.CreateDebtRequest) (*pb.DebtResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	accountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	startDate, err := parseDate(req.StartDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid start_date")
	}
	dueDate, err := parseDate(req.DueDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid due_date")
	}

	debtType := protoToDebtType(req.DebtType)

	// borrowedOut: validate the cash source BEFORE creating the debt so an
	// invalid source fails fast and no debt is persisted. borrowedIn ignores
	// the source entirely (no double-write).
	var sourceAcc *accountdomain.Account
	var sourceAccountID uuid.UUID
	if debtType == domain.BorrowedOut {
		sourceAccountID, err = uuid.Parse(req.SourceAccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid source_account_id")
		}
		sourceAcc, err = h.validateSourceAccount(ctx, tenantID, sourceAccountID, accountID, req.TotalPrincipalCents)
		if err != nil {
			return nil, err
		}
	}

	resp, err := h.service.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        req.Counterparty,
		InterestRate:        req.InterestRate,
		AmortizationMethod:  protoToMethod(req.AmortizationMethod),
		StartDate:           startDate,
		DueDate:             dueDate,
		TotalPrincipalCents: req.TotalPrincipalCents,
		DebtType:            debtType,
		Subtype:             req.Subtype,
	})
	if err != nil {
		return nil, mapError(err)
	}

	// Double-write: move the lent principal from source (cash) to receivable.
	// Best-effort (debt already created); see recordCreateTransaction doc.
	if debtType == domain.BorrowedOut {
		h.recordCreateTransaction(ctx, tenantID, sourceAccountID, sourceAcc, accountID, req.TotalPrincipalCents)
	}

	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
}

// validateSourceAccount reads the source + receivable (debt) accounts and
// enforces the CreateDebt borrowedOut invariants BEFORE service.CreateDebt, so
// an invalid source fails fast and no debt is persisted.
//
//  1. source must exist (NotFound otherwise).
//  2. source must be an asset account (InvalidArgument otherwise).
//  3. source must differ from the receivable account (InvalidArgument — no
//     self-transfer).
//  4. source and the receivable account must share a currency (InvalidArgument
//     otherwise — cross-currency needs manual FX handling).
//  5. source balance must cover the lent principal (FailedPrecondition).
//
// debtAccountID is req.AccountId (the receivable account for borrowedOut).
// Returns nil,(nil,nil) if accountLookup is unwired (defensive, mirrors
// validateFromAccount) so unit tests without deps skip validation.
func (h *DebtHandler) validateSourceAccount(ctx context.Context, tenantID, sourceAccountID, debtAccountID uuid.UUID, principalCents int64) (*accountdomain.Account, error) {
	if h.accountLookup == nil {
		return nil, nil
	}

	sourceAcc, err := h.accountLookup.FindByID(ctx, tenantID, sourceAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "source_account not found: "+err.Error())
	}
	if sourceAcc.AccountType != accountdomain.AccountTypeAsset {
		return nil, status.Error(codes.InvalidArgument, "source_account must be asset")
	}
	if sourceAccountID == debtAccountID {
		return nil, status.Error(codes.InvalidArgument, "source_account must differ from receivable account")
	}

	debtAcc, err := h.accountLookup.FindByID(ctx, tenantID, debtAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "receivable account not found: "+err.Error())
	}
	if sourceAcc.CurrencyCode != debtAcc.CurrencyCode {
		return nil, status.Error(codes.InvalidArgument, "cross-currency, manual handling required")
	}

	if sourceAcc.CurrentBalanceCents < principalCents {
		return nil, status.Error(codes.FailedPrecondition, "source_account balance insufficient")
	}

	return sourceAcc, nil
}

// recordCreateTransaction builds the borrowedOut double-entry pair (credit
// source / debit receivable) via buildCreateEntries and records it through the
// transaction service. It is best-effort: any failure (account lookup or the
// transaction write) is logged with English structured fields and swallowed so
// the already-created debt is not rolled back. Returns nothing — callers
// ignore the outcome by design.
//
// sourceAcc is the source already fetched + validated by CreateDebt; passing
// it in avoids a redundant lookup here.
func (h *DebtHandler) recordCreateTransaction(ctx context.Context, tenantID, sourceAccountID uuid.UUID, sourceAcc *accountdomain.Account, debtAccountID uuid.UUID, principalCents int64) {
	if h.transactionSvc == nil || h.accountLookup == nil {
		return
	}
	if sourceAcc == nil {
		return
	}

	debtAcc, err := h.accountLookup.FindByID(ctx, tenantID, debtAccountID)
	if err != nil {
		slog.Error("create debt double-write: receivable account lookup failed",
			"operation", "debt.CreateDebt.recordCreateTransaction",
			"source_account_id", sourceAccountID.String(),
			"debt_account_id", debtAccountID.String(),
			"amount_cents", principalCents,
			"error", err.Error())
		return
	}

	entries := buildCreateEntries(*sourceAcc, *debtAcc, principalCents)
	if _, err := h.transactionSvc.RecordTransaction(ctx, transactionApp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "CreateDebt double-write",
		Entries:         entries,
	}); err != nil {
		slog.Error("create debt double-write: transaction write failed",
			"operation", "debt.CreateDebt.recordCreateTransaction",
			"source_account_id", sourceAccountID.String(),
			"debt_account_id", debtAccountID.String(),
			"amount_cents", principalCents,
			"error", err.Error())
	}
}
```

- [ ] **Step 4: 跑 happy-path 测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestCreateDebt_BorrowedOut_DoubleWrite -v -count=1
```
Expected: PASS。

- [ ] **Step 5: 加 borrowedIn 不双写 + best-effort 测试**

在 `debt_handler_test.go` 末尾加:

```go
// TestCreateDebt_BorrowedIn_NoDoubleWrite: borrowedIn ignores the source
// (even when supplied) and records NO transaction — debt is created, balances
// untouched. borrowedIn balances are driven by consumption transactions.
func TestCreateDebt_BorrowedIn_NoDoubleWrite(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, _ :=
		setupCreateDebtHarness(t)

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(), // supplied but must be ignored
		Counterparty:        "银行",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_IN,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("CreateDebt returned empty debt")
	}
	if txnRepo.saved != nil {
		t.Error("borrowedIn must NOT create a transaction")
	}
	const srcBefore int64 = 10_000_00
	if got := accLookup.byID[sourceAccID].CurrentBalanceCents; got != srcBefore {
		t.Errorf("source balance must be unchanged: got %d, want %d", got, srcBefore)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != 0 {
		t.Errorf("receivable balance must be unchanged: got %d, want 0", got)
	}
}

// TestCreateDebt_BestEffortTxnFailureSwallowed: when the transaction write
// fails AFTER the debt is created, CreateDebt still returns success — the
// error is logged, not surfaced.
func TestCreateDebt_BestEffortTxnFailureSwallowed(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, _, _, _ :=
		setupCreateDebtHarness(t)

	// Swap in a failing txn repo; keep the same handler wiring.
	failingRepo := &failingTxnRepo{err: fmt.Errorf("simulated txn write failure")}
	h.transactionSvc = txnApp.NewService(failingRepo, h.accountLookup, mutatingBalanceUpdater{lookup: h.accountLookup.(*fakeAccountLookup)})

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(),
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
	})
	if err != nil {
		t.Fatalf("CreateDebt should swallow best-effort txn failure, got: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("debt should still be created despite txn write failure")
	}
}
```

- [ ] **Step 6: 跑全部 CreateDebt 测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestCreateDebt -v -count=1
```
Expected: 3 个测试全 PASS(DoubleWrite / NoDoubleWrite / BestEffortTxnFailureSwallowed)。

- [ ] **Step 7: Commit**

```bash
git add yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go
git commit -m "feat(debt): CreateDebt borrowedOut 双写(validate fail-fast + best-effort transaction)"
```

---

## Task 4: CreateDebt 验证失败分支测试(fail-fast 不变量)

**Files:**
- Test: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go`

**Interfaces:**
- Consumes: `validateSourceAccount`(Task 3)、`setupCreateDebtHarness`、`requireNotPaid` 的等价模式(此处用 `len(debtRepo.byID) == 0` 断言 debt 未持久化)

> 这些测试验证 Task 3 已实现的 `validateSourceAccount` 的 5 个失败分支。每个断言:gRPC error code + debt 未创建(`debtRepo.byID` 空)+ 无 transaction(`txnRepo.saved == nil`)。

- [ ] **Step 1: 写 5 个失败分支测试**

在 `debt_handler_test.go` 末尾加:

```go
// ---------------------------------------------------------------------------
// CreateDebt validation fail-fast tests (create-debt-dual-write)
//
// Validation runs BEFORE service.CreateDebt, so an invalid source fails fast
// and no debt is persisted. Each test asserts the gRPC error code AND that no
// debt was saved AND no transaction was recorded.
// ---------------------------------------------------------------------------

// borrowedOut base request builder (valid except the field under test).
func newBorrowedOutCreateReq(debtAccID, sourceAccID string) *pb.CreateDebtRequest {
	return &pb.CreateDebtRequest{
		AccountId:           debtAccID,
		SourceAccountId:     sourceAccID,
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
	}
}

// requireNoDebtAndNoTxn asserts the fail-fast invariant: nothing persisted.
func requireNoDebtAndNoTxn(t *testing.T, resp *pb.DebtResponse, err error, debtRepo *fakeDebtRepo, txnRepo *recordingTxnRepo) {
	t.Helper()
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
	if resp != nil {
		t.Errorf("expected nil response on validation failure, got %+v", resp)
	}
	if len(debtRepo.byID) != 0 {
		t.Errorf("fail-fast: no debt should be persisted, got %d", len(debtRepo.byID))
	}
	if txnRepo.saved != nil {
		t.Error("fail-fast: no transaction should be recorded")
	}
}

// TestCreateDebt_MissingSource_Rejects: borrowedOut with empty source is
// rejected with InvalidArgument (source is required for borrowedOut).
func TestCreateDebt_MissingSource_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	req := newBorrowedOutCreateReq(debtAccID.String(), "")
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_NonAssetSource_Rejects: a source whose AccountType is not
// asset is rejected with InvalidArgument before the debt is created.
func TestCreateDebt_NonAssetSource_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	liabAcc, err := accountdomain.NewAccount(tenantID, "liability source", accountdomain.AccountTypeLiability, "CNY")
	if err != nil {
		t.Fatalf("seed liability account: %v", err)
	}
	liabAcc.ChartCode = "2202"
	liabAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(liabAcc)

	req := newBorrowedOutCreateReq(debtAccID.String(), liabAcc.ID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_InsufficientBalance_Rejects: a source whose balance is below
// the lent principal is rejected with FailedPrecondition before the debt is
// created.
func TestCreateDebt_InsufficientBalance_Rejects(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	// Drop source balance below the 1000.00 principal.
	accLookup.byID[sourceAccID].CurrentBalanceCents = 500_00

	req := newBorrowedOutCreateReq(debtAccID.String(), sourceAccID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.FailedPrecondition {
		t.Errorf("error code: got %v, want FailedPrecondition", err)
	}
}

// TestCreateDebt_CrossCurrency_Rejects: a source whose currency differs from
// the receivable account is rejected with InvalidArgument.
func TestCreateDebt_CrossCurrency_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	usdAcc, err := accountdomain.NewAccount(tenantID, "usd cash", accountdomain.AccountTypeAsset, "USD")
	if err != nil {
		t.Fatalf("seed usd account: %v", err)
	}
	usdAcc.ChartCode = "1001"
	usdAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(usdAcc)

	req := newBorrowedOutCreateReq(debtAccID.String(), usdAcc.ID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_SelfTransfer_Rejects: source == receivable account is
// rejected with InvalidArgument (no self-transfer).
func TestCreateDebt_SelfTransfer_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	// Point source at the receivable account itself.
	req := newBorrowedOutCreateReq(debtAccID.String(), debtAccID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_SourceNotFound_Rejects: a source account id that the lookup
// has no account for is rejected with NotFound before the debt is created.
func TestCreateDebt_SourceNotFound_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	// A valid UUID the lookup has no account for.
	missing := uuid.New()
	req := newBorrowedOutCreateReq(debtAccID.String(), missing.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.NotFound {
		t.Errorf("error code: got %v, want NotFound", err)
	}
}
```

- [ ] **Step 2: 跑全部 CreateDebt 测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/debt/adapter/driving/grpc/... -run TestCreateDebt -v -count=1
```
Expected: 9 个 CreateDebt 测试全 PASS(DoubleWrite / NoDoubleWrite / BestEffort + 6 个失败分支:Missing / NonAsset / Insufficient / CrossCurrency / SelfTransfer / SourceNotFound)。

- [ ] **Step 3: 跑整个 debt handler 测试包确认无回归**

Run:
```bash
cd yucai/server && go test ./internal/debt/... -v -count=1
```
Expected: 全部 PASS(含原有 RecordPayment 测试 + 新 CreateDebt 测试,无回归)。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go
git commit -m "test(debt): CreateDebt borrowedOut 验证失败分支(missing/non-asset/insufficient/cross-currency/self-transfer)"
```

---

## Task 5: 前端数据链路 — `sourceAccountId` 贯穿 event/repo/impl/remote_ds/bloc

**Files:**
- Modify: `yucai/client/lib/debt/presentation/bloc/debt_event.dart`(`CreateDebtParams`)
- Modify: `yucai/client/lib/debt/domain/repositories/debt_repository.dart`(`create`)
- Modify: `yucai/client/lib/debt/data/debt_repository_impl.dart`(`create`)
- Modify: `yucai/client/lib/debt/data/debt_remote_ds.dart`(`create`)
- Modify: `yucai/client/lib/debt/presentation/bloc/debt_bloc.dart`(`_onCreate`)

**Interfaces:**
- Consumes: `pb.CreateDebtRequest.sourceAccountId`(Task 1 生成)
- Produces: `CreateDebtParams.sourceAccountId`(`String?`)贯穿到 `pb.CreateDebtRequest.sourceAccountId`。Task 6 的 `ReceivableFormPage` 依赖 `CreateDebtParams.sourceAccountId`。

> 这是 plumbing task:`sourceAccountId` 一路透传,类型由编译器保证。验证 = `flutter analyze` 通过;端到端行为测试在 Task 6(widget test 验证表单提交带 `sourceAccountId`)。

- [ ] **Step 1: CreateDebtParams 加 sourceAccountId**

修改 `debt_event.dart` 的 `CreateDebtParams`。构造函数加参数 + 字段 + props:

```dart
class CreateDebtParams extends Equatable {
  const CreateDebtParams({
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortizationIndex,
    required this.startDateOption,
    required this.dueDateOption,
    required this.totalPrincipalCents,
    this.type = DebtType.borrowedIn,
    this.subtype = '',
    this.sourceAccountId,
  });
  final String accountId;
  final String counterparty;
  final double interestRate;
  final int amortizationIndex; // AmortizationMethod.index
  final DateTime? startDateOption;
  final DateTime? dueDateOption;
  final int totalPrincipalCents;
  /// 债务方向。默认 borrowedIn → 既有 debts_page/form 行为不变;
  /// receivables 表单显式传 borrowedOut。
  final DebtType type;
  /// 债务子类型(纯 String,无枚举映射)。默认 '' → 既有调用点编译不变。
  final String subtype;
  /// borrowedOut 双写:借出资金的来源账户(cash asset)。borrowedOut 必填;
  /// borrowedIn 忽略(不双写)。null → 空字符串 → 不双写。
  final String? sourceAccountId;

  @override
  List<Object?> get props => [
        accountId,
        counterparty,
        interestRate,
        amortizationIndex,
        startDateOption,
        dueDateOption,
        totalPrincipalCents,
        type,
        subtype,
        sourceAccountId,
      ];
}
```

- [ ] **Step 2: DebtRepository.create 抽象加 sourceAccountId**

修改 `debt_repository.dart` 的 `create` 签名,在 `subtype = '',` 之后加 `sourceAccountId`:

```dart
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
  });
```

- [ ] **Step 3: DebtRepositoryImpl.create 透传 sourceAccountId**

修改 `debt_repository_impl.dart` 的 `create`,签名加 `String? sourceAccountId,` 并透传给 `_remote.create`:

```dart
  @override
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
  }) =>
      _guard(() => _remote.create(
            accountId: accountId,
            counterparty: counterparty,
            interestRate: interestRate,
            amortizationIndex: amortizationIndex,
            startDate: startDate,
            dueDate: dueDate,
            totalPrincipalCents: totalPrincipalCents,
            type: type,
            subtype: subtype,
            sourceAccountId: sourceAccountId,
          ));
```

- [ ] **Step 4: DebtRemoteDataSource.create 加 sourceAccountId → pb**

修改 `debt_remote_ds.dart` 的 `create`,签名加参数并传给 `pb.CreateDebtRequest`(null → 空字符串,borrowedIn 时):

```dart
  Future<Debt> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
  }) async {
    return _retry.call(() async {
      final res = await _client.createDebt(pb.CreateDebtRequest(
        accountId: accountId,
        counterparty: counterparty,
        interestRate: interestRate,
        amortizationMethod: DebtMapper.amortToProto(
          AmortizationMethod.values[amortizationIndex],
        ),
        startDate: _fmtDate(startDate),
        dueDate: _fmtDate(dueDate),
        totalPrincipalCents: Int64(totalPrincipalCents),
        debtType: DebtMapper.debtTypeToProto(type),
        // subtype 纯 String 直传(无映射),默认 '' 与 domain Debt.subtype 默认一致。
        subtype: subtype,
        // source_account_id:borrowedOut 双写资金来源(cash asset);borrowedIn
        // 或未选 → '' → 后端不双写。
        sourceAccountId: sourceAccountId ?? '',
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }
```

- [ ] **Step 5: DebtBloc._onCreate 传 sourceAccountId**

修改 `debt_bloc.dart` 的 `_onCreate`,在 `_repo.create(...)` 调用里加 `sourceAccountId: p.sourceAccountId,`:

```dart
    final result = await _repo.create(
      accountId: p.accountId,
      counterparty: p.counterparty,
      interestRate: p.interestRate,
      amortizationIndex: p.amortizationIndex,
      startDate: p.startDateOption!,
      dueDate: p.dueDateOption!,
      totalPrincipalCents: p.totalPrincipalCents,
      type: p.type,
      subtype: p.subtype,
      sourceAccountId: p.sourceAccountId,
    );
```

- [ ] **Step 6: 修复既有 create mock 回归(mocktail named args 加 sourceAccountId)**

`create` 加了 `sourceAccountId` 参数后,mocktail 要求每个 `when(() => ...create(...))` / `verify(...)` 的 named args 覆盖新参数,否则现有测试抛 MissingStubError。共 **9 处**(已 grep 确认),每处在 `subtype: any(named: 'subtype'),` 之后加一行 `sourceAccountId: any(named: 'sourceAccountId'),`:

- `test/debt/presentation/pages/receivable_form_page_test.dart:351`
- `test/debt/presentation/pages/debt_form_page_test.dart:356, 790`
- `test/debt/presentation/bloc/debt_bloc_test.dart:135, 161, 187, 205, 233, 314`

receivable_form_page_test.dart:351 补丁示例(其余 8 处同模式,在 `subtype` 行后加 `sourceAccountId` 行):

```dart
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'))).thenAnswer((inv) {
```

> `debt_bloc_test.dart` 的 mock 是 `repo.create(...)`(非 `debtRepo`),同样在 `subtype` 行后加 `sourceAccountId: any(named: 'sourceAccountId'),`。

- [ ] **Step 7: 验证编译 + 静态检查**

Run:
```bash
cd yucai/client && flutter analyze lib/debt
```
Expected: 无 error。

- [ ] **Step 8: 跑既有 debt 测试确认无回归**

Run:
```bash
cd yucai/client && flutter test test/debt
```
Expected: 全部 PASS(9 处 create mock 已补 `sourceAccountId` matcher;既有断言不变 —— `sourceAccountId` 可选)。

- [ ] **Step 9: Commit**

```bash
git add yucai/client/lib/debt yucai/client/test/debt
git commit -m "feat(debt-client): sourceAccountId 贯穿 create 链路(borrowedOut 双写准备)"
```

---

## Task 6: ReceivableFormPage 来源账户选择器 UI

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart` — state `_sourceAccountId`/`_sourceAccounts` + `_loadSourceAccounts` + 选择器 widget + 提交校验/传参
- Test: `yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart`

**Interfaces:**
- Consumes: `CreateDebtParams.sourceAccountId`(Task 5)、`AccountRepository.list()`、`Account.accountType == AccountType.asset && category != AccountCategory.otherAsset`(来源候选 filter)

- [ ] **Step 1: 写失败 widget test**

该文件已有 harness(`_harness(debtRepo, accountRepo, startDate, dueDate, accountId, existing)` + mocktail `_MockDebtRepo`/`_MockAccountRepo` + `_receivableAccount` + `_emptyDetail`)。先扩展 `_harness` 加 `sourceAccountId` 参数(透传 Step 3 新增的 `ReceivableFormPage.initialSourceAccountId`);再加来源账户 helper + 测试。

扩展 `_harness`(加 `sourceAccountId` 参数 + 透传):

```dart
Widget _harness({
  required _MockDebtRepo debtRepo,
  required _MockAccountRepo accountRepo,
  DateTime? startDate,
  DateTime? dueDate,
  String? accountId,
  String? sourceAccountId,
  Debt? existing,
}) {
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
        BlocProvider<CurrencyBloc>.value(
          value: _FakeCurrencyBloc(const CurrencyState()),
        ),
      ],
      child: ReceivableFormPage(
        existing: existing,
        initialStartDate: startDate,
        initialDueDate: dueDate,
        initialAccountId: accountId,
        initialSourceAccountId: sourceAccountId,
      ),
    ),
  );
}
```

加来源账户 helper(savings asset,非 otherAsset):

```dart
/// 借出来源账户(asset / savings)—— 现金来源候选。
Account _sourceAccount({
  String id = 'src-1',
  String name = '招商银行储蓄',
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 10000000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
```

在 `group('提交 CreateDebtRequested (type: borrowedOut)')` 内加测试:

```dart
    testWidgets(
        'fill form → repo.create called with sourceAccountId(borrowedOut 双写来源)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            _sourceAccount(id: 'src-1'),
          ]));
      String? capturedSource;
      String? capturedAccount;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'))).thenAnswer((inv) {
        capturedSource = inv.namedArguments[#sourceAccountId] as String?;
        capturedAccount = inv.namedArguments[#accountId] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        accountId: 'recv-1',
        sourceAccountId: 'src-1',
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      final submitFinder = find
              .byKey(const ValueKey('submitButton'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('创建债权');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && capturedSource == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(capturedAccount, 'recv-1');
      expect(capturedSource, 'src-1');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
```

> 测试用 `initialSourceAccountId` seed 来源账户(避免 dropdown 交互,对称现有 `initialAccountId` seed 应收账户)。`_harness` 加 `sourceAccountId` 参数后,既有调用点(不传)默认 null,编译不变。

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/client && flutter test test/debt/presentation/pages/receivable_form_page_test.dart
```
Expected: FAIL —— 表单还没有「来源」账户选择器,`captured.sourceAccountId` 为 null。

- [ ] **Step 3: 加 state + _loadSourceAccounts**

修改 `receivable_form_page.dart` 的 `_ReceivableFormPageState`。在现有 `_accountId` / `_accounts` 声明附近加:

```dart
  /// 关联应收账户（asset / otherAsset）。null = 未选。
  String? _accountId;
  /// borrowedOut 双写:借出资金来源账户（cash asset,非应收）。null = 未选。
  String? _sourceAccountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  /// 应收账户候选（AccountRepository.list filter category == otherAsset）。
  List<Account> _accounts = const [];
  /// 来源账户候选（asset 且 category != otherAsset:储蓄/投资等流动资产）。
  List<Account> _sourceAccounts = const [];
  bool _accountsLoading = true;
```

先给 `ReceivableFormPage` 构造加 `initialSourceAccountId`(对称 `initialAccountId`,供测试 seed 来源账户,避免 dropdown 交互):

```dart
  const ReceivableFormPage({
    super.key,
    this.existing,
    this.initialStartDate,
    this.initialDueDate,
    this.initialAccountId,
    this.initialSourceAccountId,
  });

  final Debt? existing;
  final DateTime? initialStartDate;
  final DateTime? initialDueDate;
  final String? initialAccountId;
  /// 测试 seed:借出来源账户(仅创建模式生效,避免 dropdown 交互)。
  final String? initialSourceAccountId;
```

然后 `initState` 创建模式预填 `_sourceAccountId`,并在 `_loadAccounts();` 后加 `_loadSourceAccounts();`:

```dart
    } else {
      // 创建模式：测试 seed 参数。
      _startDate = widget.initialStartDate;
      _dueDate = widget.initialDueDate;
      _accountId = widget.initialAccountId;
      _sourceAccountId = widget.initialSourceAccountId;
    }
    _loadAccounts();
    _loadSourceAccounts();
```

在 `_loadAccounts` 方法之后加新方法:

```dart
  Future<void> _loadSourceAccounts() async {
    // 来源账户 = 流动资产（储蓄/投资/黄金等 asset），排除应收（otherAsset）。
    // 借出本金从这类账户扣减；应收账户不应作为自己的来源。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _sourceAccounts = list
            .where((a) =>
                a.accountType == AccountType.asset &&
                a.category != AccountCategory.otherAsset)
            .toList();
      });
    } catch (_) {
      // 加载失败静默（_sourceAccounts 保持空，提交时校验会拦截）。
    }
  }
```

> 注意 `_loadSourceAccounts` 不碰 `_accountsLoading`(应收候选的 loading 标志由 `_loadAccounts` 管);来源候选加载独立,失败时 `_sourceAccounts` 保持空。

- [ ] **Step 4: 加来源账户选择器 widget(复用应收下拉模式)**

在 build 方法的表单里,「应收账户」选择器(`_accountId` 的那个 DropdownButtonFormField / 下拉)之后,加一个同模式的「借出来源账户」选择器。具体定位:找到现有 `_accountId` 下拉所在 `FormSection` / 表单项,在其后插入:

```dart
                // 借出来源账户（borrowedOut 双写:现金来源,asset 非 otherAsset）。
                DropdownButtonFormField<String>(
                  value: _sourceAccountId,
                  decoration: const InputDecoration(labelText: '借出来源账户'),
                  items: _sourceAccounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _sourceAccountId = v),
                  validator: (v) => v == null || v.isEmpty ? '请选择借出来源账户' : null,
                ),
```

> 实现者:把这段插入到 `_accountId` 下拉之后、同 `FormSection` 内,样式对齐既有应收下拉(同一 `DropdownButtonFormField` 模式 + InputDecoration)。mobile step wizard 若应收选择器在特定 step,来源选择器放同一 step。

- [ ] **Step 5: 提交校验 + 传 sourceAccountId**

在 `_submit`(或提交方法,位于 line ~290-342)里,创建模式的 `CreateDebtRequested` 调用加校验 + `sourceAccountId`。在现有 `_dueDate` 校验之后、`_formKey.currentState?.validate()` 之前加来源校验;在 `CreateDebtParams(...)` 构造里加 `sourceAccountId`:

校验(在 `if (_dueDate!.isBefore(_startDate!)) { ... }` 之后加):

```dart
    if (_sourceAccountId == null) {
      AppToast.show(context, '请选择借出来源账户', type: ToastType.warning);
      return;
    }
```

`CreateDebtParams` 构造(创建模式分支,加 `sourceAccountId: _sourceAccountId`):

```dart
      context.read<DebtBloc>().add(CreateDebtRequested(CreateDebtParams(
            accountId: _accountId!,
            counterparty: _counterpartyCtrl.text.trim(),
            interestRate: rate,
            amortizationIndex: _amortization.index,
            startDateOption: _startDate,
            dueDateOption: _dueDate,
            totalPrincipalCents: principalCents,
            type: DebtType.borrowedOut,
            subtype: _subtypeKey,
            sourceAccountId: _sourceAccountId,
          )));
```

> 编辑模式(`UpdateDebtRequested`)不加 source —— 后端 UpdateDebt 不改账户关联,来源仅在创建时确定。

- [ ] **Step 6: 跑 widget test 确认通过**

Run:
```bash
cd yucai/client && flutter test test/debt/presentation/pages/receivable_form_page_test.dart
```
Expected: PASS(新测试 + 既有测试均通过)。

- [ ] **Step 7: 跑全部 debt 前端测试 + analyze 确认无回归**

Run:
```bash
cd yucai/client && flutter analyze lib/debt && flutter test test/debt
```
Expected: 无 error;全部测试 PASS。

- [ ] **Step 8: Commit**

```bash
git add yucai/client/lib/debt/presentation/pages/receivable_form_page.dart yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart
git commit -m "feat(receivable-form): 借出来源账户选择器(borrowedOut 双写 UI)"
```

---

## 完成验证(Task 6 之后)

- [ ] 后端全量:`cd yucai/server && go test ./... -count=1`(全部 PASS)
- [ ] 前端全量:`cd yucai/client && flutter test`(全部 PASS)
- [ ] 手动验证(可选,御财 dev 环境):创建一个 borrowedOut 债权 → 应收账户余额 = 借出本金(非 0)→ 对该债权 RecordPayment 收款 → 应收账户余额减少但**不为负**。

## 范围外(不做,见 spec §8/§11)

- borrowedIn 双写(无 bug 驱动,与消费驱动设计冲突)
- 已有数据回填(王五异常 / seed 临时修复账户)—— 单独清理任务
- 跨域 DB 事务(debt + transaction 同 tx)
- UpdateDebt / DeleteDebt 双写
