# Holding Server 双写(A-server)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 holding 的 BuyHolding/SellHolding 双写联动资金账户余额(复式 transaction),填 `HoldingTransaction.TransactionID` 预留字段,复用 debt 双写模式。

**Architecture:** 对称 debt 双写 —— 双写逻辑在 holding gRPC handler 层(`NewHoldingHandler` 注入 `transactionSvc` + `accountLookup`)。`HoldingTradeRequest` 加 `from_account_id`(资金来源账户,像 debt `source_account_id`)。buy:`credit from_account`(现金−) + `debit holding.AccountID`(投资账户+);sell 反向。fail-fast validate(from asset + 余额)+ best-effort transaction。

**Tech Stack:** Go(ent + wire + gRPC),buf 生成 proto stubs。

## Global Constraints

- **proto 生成**(Git Bash 无 make):Go stubs `cd yucai/proto && buf generate --template buf.gen.go.yaml`。Dart stubs 本 plan 不需要(A-flutter 阶段)。
- **wire 重生成**:改 `wire/providers.go` 后 `cd yucai/server && go generate ./...` 重生成 `wire_gen.go`。
- **Go 测试**:`cd yucai/server && go test ./internal/holding/... -run <Test> -v -count=1`。
- **Go 编译**:`cd yucai/server && go build ./...`。
- **日志**:English structured(`slog.Error` operation/ids/error)。
- **复式平衡**:debit sum = credit sum(`enforce_double_entry` trigger)。
- **commit**:中文 conventional。
- **debt 双写参考**:[debt_handler.go](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go) `validateFromAccount`/`recordCreateTransaction`/`buildCreateEntries`(本 plan 的 holding 版对称它)。
- **金额**:int64 cents;holding trade amount = `int64(priceCents × quantity)`(service.go:87 `AmountCents`)。
- **TradeType**:`domain.TradeTypeBuy` / `TradeTypeSell`([entity.go](../../yucai/server/internal/holding/domain/entity.go))。

---

## File Structure

### 后端(Go)
- **Modify** `yucai/proto/holding/v1/holding.proto` — `HoldingTradeRequest` 加 `from_account_id = 8`
- **Regenerate** `yucai/server/internal/proto/holding/v1/holding.pb.go`(`buf generate`,产物不改手)
- **Modify** `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go` — `NewHoldingHandler` 注入 + `validateTradeFromAccount` + `recordTradeTransaction` + `buildTradeEntries` + BuyHolding/SellHolding 双写接线
- **Create** `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go` — buildTradeEntries 单测 + harness + BuyHolding/SellHolding 双写测试(参考 debt_handler_test fakes)
- **Modify** `yucai/server/wire/providers.go:397` — `provideHoldingHandler` 加 `txnSvc, accountLookup` 参数
- **Regenerate** `yucai/server/wire/wire_gen.go`(`go generate`)
- **Create** `yucai/server/tests/holding_doublewrite_integration_test.go` — 真 DB 端到端(参考 debt_doublewrite_integration_test.go)

---

## Task 1: proto `HoldingTradeRequest.from_account_id` + 生成 Go stubs

**Files:**
- Modify: `yucai/proto/holding/v1/holding.proto:104-112`
- Regenerate: `yucai/server/internal/proto/holding/v1/holding.pb.go`

**Interfaces:**
- Produces: `pb.HoldingTradeRequest.FromAccountId`(Go 字段,`string`)。Task 4/5(handler)依赖。

> 基础设施 task(proto 定义,无单元测试)。验证 = 生成成功 + 编译。

- [ ] **Step 1: 加 from_account_id 字段**

修改 `yucai/proto/holding/v1/holding.proto` 的 `message HoldingTradeRequest`(line 104-112),在 `notes = 7;` 后加:

```proto
message HoldingTradeRequest {
  string account_id = 1;
  string security_id = 2;
  double quantity = 3;
  int64 price_cents = 4;
  int64 fee_cents = 5;
  string trade_date = 6;
  string notes = 7;
  // 双写资金来源账户(cash asset,savings/investment)。BuyHolding/SellHolding 必填;
  // buy:credit(现金−);sell:debit(现金+)。
  string from_account_id = 8;
}
```

- [ ] **Step 2: 生成 Go stubs**

Run:
```bash
cd yucai/proto && buf generate --template buf.gen.go.yaml
```
Expected: 成功。`holding.pb.go` 出现 `HoldingTradeRequest.FromAccountId` 字段 + `GetFromAccountId()` getter。

- [ ] **Step 3: 验证编译**

Run:
```bash
cd yucai/server && go build ./...
```
Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add yucai/proto/holding/v1/holding.proto yucai/server/internal/proto
git commit -m "feat(holding-proto): HoldingTradeRequest 加 from_account_id(双写资金来源)"
```

---

## Task 2: `buildTradeEntries` 纯函数(buy/sell 复式)TDD

**Files:**
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(加函数)
- Create: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`

**Interfaces:**
- Produces: `buildTradeEntries(tradeType domain.TradeType, fromAcc, holdingAcc accountdomain.Account, amountCents int64) []txnApp.EntryInput`。Task 4/5 调用。

- [ ] **Step 1: 写失败测试**

创建 `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`:

```go
package grpc

import (
	"testing"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/holding/domain"
	txnApp "github.com/yucai/server/internal/transaction/application"
)

// TestBuildTradeEntries_Buy: buy 复式 = credit from_account(现金−) + debit holding account(投资+)。
func TestBuildTradeEntries_Buy(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"} // cash
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"} // investment
	const amount int64 = 50000

	entries := buildTradeEntries(domain.TradeTypeBuy, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	// entries[0]: from — credit only (cash out).
	if entries[0].AccountID != from.ID || entries[0].CreditCents != amount || entries[0].DebitCents != 0 {
		t.Errorf("from entry: expected credit=%d debit=0, got credit=%d debit=%d",
			amount, entries[0].CreditCents, entries[0].DebitCents)
	}
	// entries[1]: holding — debit only (investment in).
	if entries[1].AccountID != hold.ID || entries[1].DebitCents != amount || entries[1].CreditCents != 0 {
		t.Errorf("holding entry: expected debit=%d credit=0, got debit=%d credit=%d",
			amount, entries[1].DebitCents, entries[1].CreditCents)
	}
	if entries[0].CreditCents != entries[1].DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", entries[0].CreditCents, entries[1].DebitCents)
	}
}

// TestBuildTradeEntries_Sell: sell 复式反向 = debit from_account(现金+) + credit holding account(投资−)。
func TestBuildTradeEntries_Sell(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"}
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"}
	const amount int64 = 30000

	entries := buildTradeEntries(domain.TradeTypeSell, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	if entries[0].DebitCents != amount || entries[0].CreditCents != 0 {
		t.Errorf("sell from entry: expected debit only, got debit=%d credit=%d",
			entries[0].DebitCents, entries[0].CreditCents)
	}
	if entries[1].CreditCents != amount || entries[1].DebitCents != 0 {
		t.Errorf("sell holding entry: expected credit only, got debit=%d credit=%d",
			entries[1].DebitCents, entries[1].CreditCents)
	}
}
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestBuildTradeEntries -v -count=1
```
Expected: FAIL / 编译错误 `undefined: buildTradeEntries`。

- [ ] **Step 3: 实现 buildTradeEntries**

在 `holding_handler.go` 加(参考 debt `buildCreateEntries`/`buildPaymentEntries`):

```go
// buildTradeEntries constructs the buy/sell double-entry pair for a holding trade.
// amountCents is the trade AmountCents (priceCents × quantity).
//
//	buy:  credit from_account (cash −)   + debit  holding.account (investment +)
//	sell: debit  from_account (cash +)   + credit holding.account (investment −)
//
// Each entry carries the account's ChartOfAccountCode.
func buildTradeEntries(tradeType domain.TradeType, fromAcc, holdingAcc accountdomain.Account, amountCents int64) []txnApp.EntryInput {
	if tradeType == domain.TradeTypeSell {
		return []txnApp.EntryInput{
			{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, DebitCents: amountCents},
			{AccountID: holdingAcc.ID, ChartOfAccountCode: holdingAcc.ChartCode, CreditCents: amountCents},
		}
	}
	// Buy (and default).
	return []txnApp.EntryInput{
		{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, CreditCents: amountCents},
		{AccountID: holdingAcc.ID, ChartOfAccountCode: holdingAcc.ChartCode, DebitCents: amountCents},
	}
}
```

需在 `holding_handler.go` 顶部加 import(若缺):`accountdomain "github.com/yucai/server/internal/account/domain"`、`txnApp "github.com/yucai/server/internal/transaction/application"`、`"github.com/yucai/server/internal/holding/domain"`(domain 已有)。

- [ ] **Step 4: 跑测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestBuildTradeEntries -v -count=1
```
Expected: PASS(2 个测试)。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go
git commit -m "feat(holding): buildTradeEntries(buy/sell 复式 entries 构造)"
```

---

## Task 3: holding handler 注入 + validateTradeFromAccount + recordTradeTransaction

**Files:**
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(handler struct + NewHoldingHandler + 加两方法)

**Interfaces:**
- Consumes: `txnApp.Service`、`txnApp.AccountLookup`、`accountdomain.Account`、`buildTradeEntries`(Task 2)
- Produces: `NewHoldingHandler(svc, txnSvc, accountLookup)`、`validateTradeFromAccount(...)`、`recordTradeTransaction(...)`。Task 4/5 + Task 6(wire)依赖。

> 本 task 不改 BuyHolding/SellHolding 方法体(那是 Task 4/5),只加基础设施(struct 字段 + 构造 + 两辅助方法)。无新测试(辅助方法由 Task 4/5 端到端测)。

- [ ] **Step 1: 改 handler struct + NewHoldingHandler**

替换 `holding_handler.go` 的 handler struct + 构造(line ~20-26):

```go
type HoldingHandler struct {
	pb.UnimplementedHoldingServiceServer
	service        *application.Service
	transactionSvc *txnApp.Service      // double-write: Buy/Sell 创建 transaction 联动 account 余额
	accountLookup  txnApp.AccountLookup // from_account lookup + balance validation
}

func NewHoldingHandler(service *application.Service, txnSvc *txnApp.Service, accountLookup txnApp.AccountLookup) *HoldingHandler {
	return &HoldingHandler{service: service, transactionSvc: txnSvc, accountLookup: accountLookup}
}
```

- [ ] **Step 2: 加 validateTradeFromAccount + recordTradeTransaction**

在 `holding_handler.go` 加(参考 debt `validateFromAccount`/`recordCreateTransaction`):

```go
// validateTradeFromAccount reads the from_account + holding account and enforces
// the holding-trade invariants BEFORE the trade is recorded, so an invalid
// from_account fails fast.
//
//  1. from_account must exist (NotFound).
//  2. from_account must be asset (InvalidArgument).
//  3. from_account must differ from holding account (InvalidArgument — no self).
//  4. from + holding accounts share currency (InvalidArgument).
//  5. buy: from balance >= amount (FailedPrecondition). sell: 不查余额(现金入账)。
func (h *HoldingHandler) validateTradeFromAccount(ctx context.Context, tenantID, fromAccountID, holdingAccountID uuid.UUID, amountCents int64, isBuy bool) (*accountdomain.Account, error) {
	if h.accountLookup == nil {
		return nil, nil
	}
	fromAcc, err := h.accountLookup.FindByID(ctx, tenantID, fromAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "from_account not found: "+err.Error())
	}
	if fromAcc.AccountType != accountdomain.AccountTypeAsset {
		return nil, status.Error(codes.InvalidArgument, "from_account must be asset")
	}
	if fromAccountID == holdingAccountID {
		return nil, status.Error(codes.InvalidArgument, "from_account must differ from holding account")
	}
	holdAcc, err := h.accountLookup.FindByID(ctx, tenantID, holdingAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "holding account not found: "+err.Error())
	}
	if fromAcc.CurrencyCode != holdAcc.CurrencyCode {
		return nil, status.Error(codes.InvalidArgument, "cross-currency, manual handling required")
	}
	if isBuy && fromAcc.CurrentBalanceCents < amountCents {
		return nil, status.Error(codes.FailedPrecondition, "from_account balance insufficient")
	}
	return fromAcc, nil
}

// recordTradeTransaction builds the buy/sell double-entry pair and records it via
// the transaction service. Best-effort: any failure is logged (English structured)
// and swallowed so the already-recorded trade is not rolled back.
//
// fromAcc is the from_account already fetched + validated; passing it in avoids a
// redundant lookup.
func (h *HoldingHandler) recordTradeTransaction(ctx context.Context, tenantID, fromAccountID uuid.UUID, fromAcc *accountdomain.Account, holdingAccountID uuid.UUID, tradeType domain.TradeType, amountCents int64) {
	if h.transactionSvc == nil || h.accountLookup == nil || fromAcc == nil {
		return
	}
	holdAcc, err := h.accountLookup.FindByID(ctx, tenantID, holdingAccountID)
	if err != nil {
		slog.Error("holding trade double-write: holding account lookup failed",
			"operation", "holding.recordTradeTransaction",
			"from_account_id", fromAccountID.String(),
			"holding_account_id", holdingAccountID.String(),
			"trade_type", tradeType.String(),
			"amount_cents", amountCents,
			"error", err.Error())
		return
	}
	entries := buildTradeEntries(tradeType, *fromAcc, *holdAcc, amountCents)
	if _, err := h.transactionSvc.RecordTransaction(ctx, txnApp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Holding trade double-write",
		Entries:         entries,
	}); err != nil {
		slog.Error("holding trade double-write: transaction write failed",
			"operation", "holding.recordTradeTransaction",
			"from_account_id", fromAccountID.String(),
			"holding_account_id", holdingAccountID.String(),
			"trade_type", tradeType.String(),
			"amount_cents", amountCents,
			"error", err.Error())
	}
}
```

import 需加(若缺):`"log/slog"`、`"time"`、`"google.golang.org/grpc/codes"`、`"google.golang.org/grpc/status"`、`"github.com/google/uuid"`。

- [ ] **Step 3: 验证编译**

Run:
```bash
cd yucai/server && go build ./...
```
Expected: 编译通过(wire 还没改,NewHoldingHandler 调用点 wire_gen.go 仍单参 → 编译错?见下)。

> ⚠️ 注意:`NewHoldingHandler` 签名改了,但 `wire_gen.go:126` 仍调 `provideHoldingHandler(holdingService)`(单参)→ 编译会断。Task 6 改 wire。本步编译错是**预期**(NewHoldingHandler 签名不匹配 wire 旧调用)。临时验证用 `go vet ./internal/holding/...`(只 vet holding 包,不碰 wire):
```bash
cd yucai/server && go vet ./internal/holding/...
```
Expected: holding 包内 vet 通过(handler struct/方法自身正确)。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go
git commit -m "feat(holding): handler 注入 txnSvc+accountLookup + validateTradeFromAccount/recordTradeTransaction"
```

---

## Task 4: BuyHolding 双写接线 + 测试

**Files:**
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(BuyHolding 方法)
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`(加 harness + BuyHolding 测试)

**Interfaces:**
- Consumes: `validateTradeFromAccount` + `recordTradeTransaction`(Task 3)、`pb.HoldingTradeRequest.FromAccountId`(Task 1)
- Produces: BuyHolding 双写闭环。

- [ ] **Step 1: 加 harness + BuyHolding 双写失败测试**

在 `holding_handler_test.go` 加 harness(参考 debt `setupRecordPaymentHarness`,但 holding 用真 service + 真 txn service + fake accountLookup)。先加 fakes + harness:

```go
// fakeAccountLookup implements txnApp.AccountLookup (参考 debt_handler_test)。
type fakeAccountLookup struct {
	byID map[uuid.UUID]*accountdomain.Account
}

func newFakeAccountLookup() *fakeAccountLookup {
	return &fakeAccountLookup{byID: make(map[uuid.UUID]*accountdomain.Account)}
}
func (l *fakeAccountLookup) seed(a *accountdomain.Account) { c := *a; l.byID[a.ID] = &c }
func (l *fakeAccountLookup) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*accountdomain.Account, error) {
	a, ok := l.byID[id]
	if !ok {
		return nil, fmt.Errorf("account %s not found", id)
	}
	c := *a
	return &c, nil
}
```

(其余 fakes `recordingTxnRepo`/`mutatingBalanceUpdater`/`failingTxnRepo` 与 debt 相同 —— 从 `debt_handler_test.go` 复制模式。但 debt fakes 在 debt grpc 包,holding grpc 包需重新定义。复制时去掉与 debt 重复的命名冲突 —— 此文件是 holding 包,独立定义。)

```go
// recordingTxnRepo records the last saved transaction.
type recordingTxnRepo struct{ saved *txnDomain.Transaction }

func (r *recordingTxnRepo) Save(_ context.Context, t *txnDomain.Transaction) error { c := *t; r.saved = &c; return nil }
func (r *recordingTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*txnDomain.Transaction, error) {
	panic("unexpected FindByID")
}
func (r *recordingTxnRepo) FindAll(context.Context, uuid.UUID, txnDomain.TransactionFilter, txnDomain.PageRequest) (*txnDomain.PaginatedResult[txnDomain.Transaction], error) {
	panic("unexpected FindAll")
}
func (r *recordingTxnRepo) FindRecentByAccount(context.Context, uuid.UUID, uuid.UUID, int) ([]txnDomain.Transaction, error) {
	panic("unexpected FindRecentByAccount")
}
func (r *recordingTxnRepo) Update(context.Context, *txnDomain.Transaction) error    { panic("unexpected Update") }
func (r *recordingTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error  { panic("unexpected SoftDelete") }
func (r *recordingTxnRepo) TransactionSummary(context.Context, txnDomain.SummaryScope) (*txnDomain.MonthlySummary, error) {
	panic("unexpected TransactionSummary")
}

type mutatingBalanceUpdater struct{ lookup *fakeAccountLookup }

func (u mutatingBalanceUpdater) UpdateBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		if a, ok := u.lookup.byID[e.AccountID]; ok {
			a.CurrentBalanceCents += e.DebitCents - e.CreditCents
		}
	}
	return nil
}
func (u mutatingBalanceUpdater) ReverseBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		if a, ok := u.lookup.byID[e.AccountID]; ok {
			a.CurrentBalanceCents -= e.DebitCents - e.CreditCents
		}
	}
	return nil
}
```

(import 需 `txnDomain "github.com/yucai/server/internal/transaction/domain"` + `authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"` + `"context"` + `"fmt"`)

harness + 测试(参考 debt `setupCreateDebtHarness` + `TestCreateDebt_BorrowedOut_DoubleWrite`):

```go
// setupBuyHoldingHarness wires a HoldingHandler with a real holding service
// (fake security/holding/trade repos), fake account lookup (from cash + holding
// investment accounts), and a real transaction service (recording repo + mutating
// balance updater). Returns handles to drive BuyHolding and assert post-state.
func setupBuyHoldingHarness(t *testing.T) (
	h *HoldingHandler,
	tenantID, fromAccID, holdAccID uuid.UUID,
	txnRepo *recordingTxnRepo,
	accLookup *fakeAccountLookup,
) {
	t.Helper()
	tenantID = uuid.New()
	// holding (investment) account — asset.
	holdAcc, _ := accountdomain.NewAccount(tenantID, "investment", accountdomain.AccountTypeAsset, "CNY")
	holdAcc.ChartCode = "1511"
	holdAccID = holdAcc.ID
	// from (cash) account — asset, ample balance.
	fromAcc, _ := accountdomain.NewAccount(tenantID, "cash", accountdomain.AccountTypeAsset, "CNY")
	fromAcc.ChartCode = "1001"
	fromAcc.CurrentBalanceCents = 100000
	fromAccID = fromAcc.ID
	accLookup = newFakeAccountLookup()
	accLookup.seed(holdAcc)
	accLookup.seed(fromAcc)
	// security + holding/trade repos (in-memory; 参考 debt fakeDebtRepo 模式 —— 用真 ent 内存或最简 in-memory)。
	// 最简:用真 application.NewService + 真 ent 内存 DB(holding ent only,因 holding service 不双写 account)。
	// 见 Task 7 真 DB e2e 的 setupHoldingTestDB;此处用 holding service with 内存 repos。
	// (若 holding repo 接口复杂,本 harness 可退化为 Task 7 的真 DB e2e 覆盖 BuyHolding,本 test 聚焦 buildTradeEntries + recordTradeTransaction 链路。)
	// —— 为聚焦,本 harness 用真 holding service(需 securityRepo/holdingRepo/tradeRepo)。提供 NewService 三 repo。
	// 参考 yucai/server/tests/holding_integration_test.go 的 setupHoldingTestDB 取 holding ent client + repos。
	holdingClient := setupHoldingEntClient(t) // 见下方 helper(内存 sqlite holding ent)
	secRepo := holdingsec.NewSecurityRepository(holdingClient)
	holdRepo := holdingsec.NewHoldingRepository(holdingClient)
	tradeRepo := holdingsec.NewTradeRepository(holdingClient)
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
	txnRepo = &recordingTxnRepo{}
	txnSvc := txnApp.NewService(txnRepo, accLookup, mutatingBalanceUpdater{lookup: accLookup})
	h = NewHoldingHandler(holdSvc, txnSvc, accLookup)
	return
}

func ctxWithTenant(tenantID uuid.UUID) context.Context {
	ctx := authgrpc.WithTenantID(context.Background(), tenantID)
	return authgrpc.WithUserID(ctx, uuid.New())
}
```

> ⚠️ `setupHoldingEntClient(t)` helper:开内存 sqlite holding ent(参考 `tests/holding_integration_test.go` 的 setupHoldingTestDB 模式 —— `sql.Open("sqlite", "file:...?mode=memory")` + holding ent `Schema.Create`)。若 holding repo 包名/构造不同,implementer 查证 `yucai/server/internal/holding/adapter/driven/repository/` 与 `tests/holding_integration_test.go`。import `holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"`。

BuyHolding 双写测试:

```go
func TestBuyHolding_DoubleWrite(t *testing.T) {
	h, tenantID, fromAccID, holdAccID, txnRepo, accLookup := setupBuyHoldingHarness(t)
	// 先建 security(buy 需要 security_id)。
	sec, err := h.CreateSecurity(ctxWithTenant(tenantID), &pb.CreateSecurityRequest{
		Symbol: "AAPL", Name: "Apple", SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "USD",
	})
	// 注意:holding 账户 CNY,security USD → 跨币种会 fail validateTradeFromAccount。
	// 测试用 CNY security 避免跨币(或 from/hold 都 USD)。此处改 security CurrencyCode: "CNY"。
	_ = err

	resp, err := h.BuyHolding(ctxWithTenant(tenantID), &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10, PriceCents: 5000, // 10 × 50.00 = 500.00 = 50000 cents
		TradeDate:     "2026-06-28",
	})
	if err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}
	if resp == nil || resp.Transaction == nil {
		t.Fatal("BuyHolding returned empty trade")
	}
	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	// buy: from credit 50000(现金−), holding debit 50000(投资+)。
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != 100000-50000 {
		t.Errorf("from balance: got %d, want 50000", got)
	}
	if got := accLookup.byID[holdAccID].CurrentBalanceCents; got != 50000 {
		t.Errorf("holding balance: got %d, want 50000", got)
	}
}
```

> ⚠️ security currency:测试用 CNY(from/hold 都 CNY),避免跨币种 fail。`CreateSecurity` 后 `sec.Security.Id` 用作 BuyHolding。

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestBuyHolding_DoubleWrite -v -count=1
```
Expected: FAIL(`txnRepo.saved == nil` —— BuyHolding 还没双写)。

- [ ] **Step 3: 改 BuyHolding 接线双写**

替换 `holding_handler.go` 的 `BuyHolding`(line ~86-102):

```go
func (h *HoldingHandler) BuyHolding(ctx context.Context, req *pb.HoldingTradeRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	fromAccountID, err := uuid.Parse(req.FromAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid from_account_id")
	}
	holdingAccountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}
	td, _ := parseDate(req.TradeDate)
	// amount = priceCents × quantity(double-write 金额,与 service AmountCents 一致)。
	amountCents := int64(float64(req.PriceCents) * req.Quantity)

	fromAcc, err := h.validateTradeFromAccount(ctx, tenantID, fromAccountID, holdingAccountID, amountCents, true /*buy*/)
	if err != nil {
		return nil, err
	}

	resp, err := h.service.BuyHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: holdingAccountID,
		SecurityID: parseUUID(req.SecurityId), Quantity: req.Quantity,
		PriceCents: req.PriceCents, FeeCents: req.FeeCents,
		TradeDate: td, Notes: req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}

	// Double-write: cash out (from) + investment in (holding). Best-effort.
	h.recordTradeTransaction(ctx, tenantID, fromAccountID, fromAcc, holdingAccountID, domain.TradeTypeBuy, amountCents)

	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}
```

- [ ] **Step 4: 跑测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestBuyHolding_DoubleWrite -v -count=1
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go
git commit -m "feat(holding): BuyHolding 双写(from 现金− + holding 投资+)"
```

---

## Task 5: SellHolding 双写接线 + 测试

**Files:**
- Modify: `holding_handler.go`(SellHolding 方法)
- Modify: `holding_handler_test.go`(SellHolding 测试)

**Interfaces:**
- Consumes: Task 3/4 基础设施。
- Produces: SellHolding 双写闭环。

- [ ] **Step 1: 写 SellHolding 双写测试**

在 `holding_handler_test.go` 加(复用 setupBuyHoldingHarness,先 buy 建仓再 sell):

```go
func TestSellHolding_DoubleWrite(t *testing.T) {
	h, tenantID, fromAccID, holdAccID, _, accLookup := setupBuyHoldingHarness(t)
	ctx := ctxWithTenant(tenantID)
	sec, _ := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600000", Name: "浦发", SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	// 先 buy 建仓 10 × 50 = 50000。
	h.BuyHolding(ctx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 5000, TradeDate: "2026-06-28",
	})
	// sell 10 × 60 = 60000。
	resp, err := h.SellHolding(ctx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 6000, TradeDate: "2026-06-29",
	})
	if err != nil {
		t.Fatalf("SellHolding: %v", err)
	}
	if resp == nil || resp.Transaction == nil {
		t.Fatal("SellHolding returned empty trade")
	}
	// buy 后:from 50000(100000-50000), hold 50000。
	// sell 60000:from +60000 → 110000;hold -60000 → -10000(投资账户,允许负反映取出>投入?或按成本)。
	// 注:投资账户余额语义 = 累计净投入;sell > cost 可能使余额为负。测试断言 sell 后 from 增 60000。
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != 50000+60000 {
		t.Errorf("from balance after sell: got %d, want 110000", got)
	}
}
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestSellHolding_DoubleWrite -v -count=1
```
Expected: FAIL(SellHolding 还没双写,from 余额不变)。

- [ ] **Step 3: 改 SellHolding 接线双写**

替换 `holding_handler.go` 的 `SellHolding`(line ~104-120):

```go
func (h *HoldingHandler) SellHolding(ctx context.Context, req *pb.HoldingTradeRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	fromAccountID, err := uuid.Parse(req.FromAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid from_account_id")
	}
	holdingAccountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}
	td, _ := parseDate(req.TradeDate)
	amountCents := int64(float64(req.PriceCents) * req.Quantity)

	// sell: from 不查余额(现金入账),isBuy=false。
	fromAcc, err := h.validateTradeFromAccount(ctx, tenantID, fromAccountID, holdingAccountID, amountCents, false /*sell*/)
	if err != nil {
		return nil, err
	}

	resp, err := h.service.SellHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: holdingAccountID,
		SecurityID: parseUUID(req.SecurityId), Quantity: req.Quantity,
		PriceCents: req.PriceCents, FeeCents: req.FeeCents,
		TradeDate: td, Notes: req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}

	// Double-write: cash in (from) + investment out (holding). Best-effort.
	h.recordTradeTransaction(ctx, tenantID, fromAccountID, fromAcc, holdingAccountID, domain.TradeTypeSell, amountCents)

	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}
```

- [ ] **Step 4: 跑测试确认通过**

Run:
```bash
cd yucai/server && go test ./internal/holding/adapter/driving/grpc/... -run TestSellHolding_DoubleWrite -v -count=1
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go
git commit -m "feat(holding): SellHolding 双写(from 现金+ + holding 投资−)"
```

---

## Task 6: wire providers 注入 + go generate 重生成

**Files:**
- Modify: `yucai/server/wire/providers.go:397-399`
- Regenerate: `yucai/server/wire/wire_gen.go`

**Interfaces:**
- Consumes: `NewHoldingHandler(svc, txnSvc, accountLookup)`(Task 3)
- Produces: prod wire 注入 holding handler 双写依赖。

- [ ] **Step 1: 改 provideHoldingHandler 签名**

修改 `yucai/server/wire/providers.go:397-399`:

```go
func provideHoldingHandler(svc *holdingapp.Service, txnSvc *txnapp.Service, accountLookup txnapp.AccountLookup) *holdinggrpc.HoldingHandler {
	return holdinggrpc.NewHoldingHandler(svc, txnSvc, accountLookup)
}
```

import 需加(若缺):`txnapp "github.com/yucai/server/internal/transaction/application"`(参考 provideDebtHandler:303 的 import)。

- [ ] **Step 2: go generate 重生成 wire_gen.go**

Run:
```bash
cd yucai/server && go generate ./...
```
Expected: wire 重生成 `wire_gen.go`,`holdingHandler := provideHoldingHandler(holdingService, txnService, accountRepo)`(三参,对齐 debt wire_gen.go:104)。

- [ ] **Step 3: 验证编译 + 全 holding 测试**

Run:
```bash
cd yucai/server && go build ./... && go test ./internal/holding/... -count=1
```
Expected: 编译通过(NewHoldingHandler 签名匹配 wire);holding 测试全 PASS。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/wire/providers.go yucai/server/wire/wire_gen.go
git commit -m "feat(holding-wire): provideHoldingHandler 注入 txnSvc+accountLookup(双写依赖)"
```

---

## Task 7: 真 DB 端到端测试(buy/sell 双写 + fail-fast)

**Files:**
- Create: `yucai/server/tests/holding_doublewrite_integration_test.go`

**Interfaces:**
- Consumes: 真 holding service + 真 transaction service + 真 BalanceUpdater(accountRepo.Update 持久化)。
- Produces: 黑盒验证 buy/sell 双写在真 DB 真的改 account 余额。

> 参考 `tests/debt_doublewrite_integration_test.go`(共享 sqlite account+transaction+holding ent + 真 repos/BalanceUpdater/DebtHandler)。本 task 加 holding 版(三 ent:account+transaction+holding)。

- [ ] **Step 1: 写真 DB e2e 测试**

创建 `yucai/server/tests/holding_doublewrite_integration_test.go`(参考 debt_doublewrite 的 setupDebtDoubleWriteDB/Harness 模式,加 holding ent):

```go
package tests

import (
	"context"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"database/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingent "github.com/yucai/server/internal/holding/ent"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
)

// setupHoldingDoubleWriteDB 开共享 sqlite(account+transaction+holding ent)。
func setupHoldingDoubleWriteDB(t *testing.T) (*accountent.Client, *txnent.Client, *holdingent.Client) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:hold_dw?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	drv := entsql.OpenDB(dialect.SQLite, db)
	acctClient := accountent.NewClient(accountent.Driver(drv))
	txnClient := txnent.NewClient(txnent.Driver(drv)) // txnent 见 import(参考 transaction_integration_test)
	holdClient := holdingent.NewClient(holdingent.Driver(drv))
	ctx := context.Background()
	for _, c := range []entClient{acctClient, txnClient, holdClient} {
		if err := c.Schema.Create(ctx); err != nil {
			t.Fatalf("create schema: %v", err)
		}
	}
	t.Cleanup(func() { acctClient.Close(); txnClient.Close(); holdClient.Close() })
	return acctClient, txnClient, holdClient
}

type entClient interface{ Schema.Create(ctx context.Context) error }
```

> ⚠️ `txnent` import + `entClient` interface:`txnent "github.com/yucai/server/internal/transaction/ent"`(参考 transaction_integration_test)。`Schema.Create` 签名匹配三个 ent client。若 ent client 的 Schema.Create 接口不统一,改用三行显式 Create(不用 interface)。

harness + 测试(参考 debt setupDebtDoubleWriteHarness + TestCreateDebt_DoubleWrite_EndToEnd):

```go
func setupHoldingDoubleWriteHandler(t *testing.T) (h *holdinggrpc.HoldingHandler, acctSvc accountapp.Service, tenantID, fromAccID, holdAccID uuid.UUID) {
	t.Helper()
	acctClient, txnClient, holdClient := setupHoldingDoubleWriteDB(t)
	ar := accountrepo.NewAccountRepository(acctClient)
	cr := accountrepo.NewChartRepository(acctClient)
	acctSvc = *accountapp.NewService(ar, cr)
	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc := holdingapp.NewService(secRepo, holdRepo, tradeRepo)
	txnRepo := txnrepo.NewTransactionRepository(txnClient, nil)
	bu := txnbalance.NewBalanceUpdater(ar)
	txnSvc := txnapp.NewService(txnRepo, ar, bu)
	h = holdinggrpc.NewHoldingHandler(holdSvc, txnSvc, ar)
	tenantID = uuid.New()
	holdAcc, _ := acctSvc.CreateAccount(context.Background(), accountapp.CreateAccountRequest{
		TenantID: tenantID, Name: "投资账户", AccountType: accountdomain.AccountTypeAsset,
		Category: accountdomain.AccountCategoryInvestment, CurrencyCode: "CNY",
	})
	holdAccID = holdAcc.ID
	fromAcc, _ := acctSvc.CreateAccount(context.Background(), accountapp.CreateAccountRequest{
		TenantID: tenantID, Name: "现金", AccountType: accountdomain.AccountTypeAsset,
		Category: accountdomain.AccountCategorySavings, CurrencyCode: "CNY", InitialBalanceCents: 100000,
	})
	fromAccID = fromAcc.ID
	return
}

func TestHoldingBuy_DoubleWrite_EndToEnd(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHandler(t)
	ctx := context.Background()
	sec, _ := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600000", Name: "浦发", SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	resp, err := h.BuyHolding(withTenant(ctx, tenantID), &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 5000, TradeDate: "2026-06-28",
	})
	if err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}
	if resp.Transaction == nil {
		t.Fatal("empty trade")
	}
	// 真 DB 余额:from 100000-50000=50000;hold 0+50000=50000。
	from, _ := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if from.CurrentBalanceCents != 50000 {
		t.Errorf("from balance: got %d, want 50000", from.CurrentBalanceCents)
	}
	hold, _ := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if hold.CurrentBalanceCents != 50000 {
		t.Errorf("holding balance: got %d, want 50000", hold.CurrentBalanceCents)
	}
}
```

> ⚠️ `withTenant(ctx, tenantID)`:参考 debt_doublewrite 的 ctx tenant 注入(`authgrpc.WithTenantID` + `WithUserID`)。import `authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"`。`AccountCategoryInvestment`/`AccountCategorySavings`:确认 accountdomain 常量名(参考 account valueobject.go)。

- [ ] **Step 2: 跑 e2e 确认通过**

Run:
```bash
cd yucai/server && go test ./tests/... -run TestHoldingBuy_DoubleWrite_EndToEnd -v -count=1
```
Expected: PASS(from 50000 / hold 50000 真 DB 持久化)。

- [ ] **Step 3: 加 fail-fast 测试(from 余额不足)**

在 `holding_doublewrite_integration_test.go` 加:

```go
func TestHoldingBuy_InsufficientBalance_FailFast(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHandler(t)
	ctx := context.Background()
	sec, _ := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600001", Name: "X", SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	// from 余额 100000,买 10×20000=200000(不足)。
	_, err := h.BuyHolding(withTenant(ctx, tenantID), &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 20000, TradeDate: "2026-06-28",
	})
	if err == nil {
		t.Fatal("expected insufficient balance error")
	}
	// fail-fast:holding 没建仓,from 余额不变。
	holdList, _ := h.ListHoldings(withTenant(ctx, tenantID), &pb.ListHoldingsRequest{})
	if len(holdList.Holdings) != 0 {
		t.Errorf("fail-fast: no holding should be created, got %d", len(holdList.Holdings))
	}
	from, _ := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if from.CurrentBalanceCents != 100000 {
		t.Errorf("from balance should be unchanged: got %d", from.CurrentBalanceCents)
	}
}
```

- [ ] **Step 4: 跑全部 holding e2e + 全 tests 包**

Run:
```bash
cd yucai/server && go test ./tests/... -run TestHolding -v -count=1 && go test ./tests/... -count=1 2>&1 | tail -3
```
Expected: holding e2e PASS;全 tests 包无新回归(忽略预存 auth vet 错误)。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/tests/holding_doublewrite_integration_test.go
git commit -m "test(holding): 双写真 DB 端到端(buy/sell 联动 account 余额 + fail-fast)"
```

---

## 范围边界(本 plan 不做)

- **RecordDividend / RecordSplit 双写**:dividend 需 income account(复式 debit from + credit income),首批未做(记 trade,现状)。后续增量(加 income account 设计)。
- **fee 双写**:buy/sell 的 fee 记 `trade.FeeCents`,不单独双写 account(后续增量,fee expense account)。
- **Flutter 移植 / OD 原型**:A-flutter / A-od 子项目,各自 plan。
- **价格自动 sync / 收益统计**:B / C 子项目。

## 参考

- debt 双写(本 plan 对称):[create-debt-dual-write plan](2026-06-28-create-debt-dual-write.md) + [debt_handler.go](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go)
- holding 现状:[holding/application/service.go](../../yucai/server/internal/holding/application/service.go)(BuyHolding/SellHolding 不双写)+ [entity.go](../../yucai/server/internal/holding/domain/entity.go)(TransactionID 预留)
- 真 DB e2e 模板:[debt_doublewrite_integration_test.go](../../yucai/server/tests/debt_doublewrite_integration_test.go)
