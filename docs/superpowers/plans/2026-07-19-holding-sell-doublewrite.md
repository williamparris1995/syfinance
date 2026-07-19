# holding sell 双写 black-box e2e Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 holding sell 双写 integration test(照 buy [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go) 范式),验 sell cross-module 双写正确性 + fail-fast。

**Architecture:** 复用 `setupHoldingDoubleWriteHarness`(真 ent + BalanceUpdater + txnSvc + accountRepo,共享 sqlite)。handler 层 `SellHolding`,black-box 经 `acctSvc.GetAccount` 验余额 + `ListHoldings` 验 Quantity。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权,直接 main commit),commit `multi -m`
- **file scope**:仅 `yucai/server/tests/holding_doublewrite_integration_test.go`(+2 test,同文件追加)
- **复用** `setupHoldingDoubleWriteHarness`(L73-123,不改)+ `TestHoldingBuy_DoubleWrite_EndToEnd` 范式(L133-183)
- **scope:sell only** —— dividend/split handler 设计不双写(非范围)
- 零 proto/schema/production 改(纯 test 追加)
- English slog(无 CJK 在 log)—— 本 task 不涉 slog
- TDD:failing test → 调通 → pass → commit

## File Structure

| 文件 | 改动 |
|---|---|
| [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go) | +`TestHoldingSell_DoubleWrite_EndToEnd` + `TestHoldingSell_QuantityInsufficient_FailFast` |

---

## Task 1: TestHoldingSell_DoubleWrite_EndToEnd(happy path)

**Files:**
- Modify: [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(文件末尾追加)

**Interfaces:**
- Consumes:`setupHoldingDoubleWriteHarness` 返 `(h *HoldingHandler, acctSvc accountapp.Service, tenantID, fromAccID, holdAccID uuid.UUID)`;`h.CreateSecurity` / `h.BuyHolding` / `h.SellHolding` / `h.ListHoldings`;`acctSvc.GetAccount`;`authgrpc.WithTenantID` / `WithUserID`(照 buy test L148-149)

- [ ] **Step 1: 写 TestHoldingSell_DoubleWrite_EndToEnd(照 buy test L133-183 范式)**

文件末尾追加:
```go
// TestHoldingSell_DoubleWrite_EndToEnd drives SellHolding through the real gRPC
// handler wired to real ent-backed repos + BalanceUpdater, then asserts the
// sell amount flows through to account balances (black-box: GetAccount) and
// holding Quantity decrements.
//
// Expected (sell double-write, cash in from + investment out holding):
//   - buy 10 @ 5000 builds holding: from 100000→50000, holding 0→50000, qty 10
//   - sell 5 @ 6000 (amount 30000): from 50000→80000, holding 50000→20000, qty 10→5
func TestHoldingSell_DoubleWrite_EndToEnd(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600002", Name: "Sell Test",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	// buy 10 qty @ 5000 cents/share → amount 50000 (builds holding).
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10,
		PriceCents:    5000,
		TradeDate:     "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding (setup): %v", err)
	}

	// sell 5 qty @ 6000 cents/share → amount 5*6000 = 30000.
	const sellAmount int64 = 5 * 6000
	if _, err := h.SellHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      5,
		PriceCents:    6000,
		TradeDate:     "2026-06-29",
	}); err != nil {
		t.Fatalf("SellHolding: %v", err)
	}

	// Black-box: from balance = 50000 (after buy) + 30000 (sell cash in) = 80000.
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if want := int64(50000 + sellAmount); gotFrom.CurrentBalanceCents != want {
		t.Errorf("from balance: got %d, want %d (sell cash in)", gotFrom.CurrentBalanceCents, want)
	}

	// Black-box: holding balance = 50000 (after buy) - 30000 (investment out) = 20000.
	gotHold, err := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if want := int64(50000 - sellAmount); gotHold.CurrentBalanceCents != want {
		t.Errorf("holding balance: got %d, want %d (investment out)", gotHold.CurrentBalanceCents, want)
	}

	// holding.Quantity: 10 → 5.
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil {
		t.Fatalf("ListHoldings: %v", err)
	}
	if len(list.Holdings) != 1 || list.Holdings[0].Quantity != 5 {
		t.Errorf("holding quantity: got len=%d qty=%v, want qty=5", len(list.Holdings), func() []float64 {
			q := make([]float64, len(list.Holdings))
			for i, h := range list.Holdings {
				q[i] = h.Quantity
			}
			return q
		}())
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestHoldingSell_DoubleWrite_EndToEnd -v -count=1`
Expected: PASS。若 from/holding 余额方向反向(sell holding +/from − 而非预期 holding −/from +),**调整断言方向**(诚实报告实际双写方向,照 buy 反向是预期但 implementer 验实际)。

- [ ] **Step 3: 跑 buy doublewrite test 确认不破**

Run: `cd yucai/server && go test ./tests/ -run "TestHoldingBuy" -v -count=1`
Expected: buy test 仍 PASS(零回归,harness 复用)。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_doublewrite_integration_test.go
git commit -m "test(holding): sell double-write black-box e2e (happy path)" -m "TestHoldingSell_DoubleWrite_EndToEnd: buy 10@5000 建 holding + sell 5@6000, black-box 经 acctSvc.GetAccount 验 from +amount (cash in) + holding -amount (investment out) + ListHoldings 验 Quantity 10->5. 照 buy doublewrite test 范式, 复用 setupHoldingDoubleWriteHarness."
```

---

## Task 2: TestHoldingSell_QuantityInsufficient_FailFast

**Files:**
- Modify: [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(文件末尾追加)

**Interfaces:**
- Consumes:同 Task 1(harness + handler methods + GetAccount)

- [ ] **Step 1: 写 TestHoldingSell_QuantityInsufficient_FailFast(照 buy fail-fast L189-235 范式)**

文件末尾追加:
```go
// TestHoldingSell_QuantityInsufficient_FailFast asserts that when sell quantity
// exceeds holding position, SellHolding rejects BEFORE any trade or account
// change is made (fail-fast): holding Quantity unchanged and balances unchanged.
// Sell does not check from balance (validateTradeFromAccount isBuy=false); the
// fail comes from service.SellHolding quantity check, before recordTradeTransaction.
func TestHoldingSell_QuantityInsufficient_FailFast(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600003", Name: "Fail Fast",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	// buy 10 qty @ 5000 → from 100000→50000, holding 0→50000.
	const buyAmount int64 = 10 * 5000
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10,
		PriceCents:    5000,
		TradeDate:     "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding (setup): %v", err)
	}

	// sell 20 qty > holding 10 → service.SellHolding must fail.
	_, err = h.SellHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      20,
		PriceCents:    6000,
		TradeDate:     "2026-06-29",
	})
	if err == nil {
		t.Fatal("expected quantity-insufficient error, got nil")
	}

	// fail-fast: holding Quantity unchanged (still 10).
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil {
		t.Fatalf("ListHoldings: %v", err)
	}
	if len(list.Holdings) != 1 || list.Holdings[0].Quantity != 10 {
		t.Errorf("fail-fast: holding quantity should be unchanged (10), got len=%d", len(list.Holdings))
	}

	// fail-fast: from balance unchanged (50000 after buy).
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if gotFrom.CurrentBalanceCents != 100000-buyAmount {
		t.Errorf("from balance should be unchanged: got %d, want %d", gotFrom.CurrentBalanceCents, 100000-buyAmount)
	}

	// fail-fast: holding balance unchanged (50000 after buy).
	gotHold, err := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if gotHold.CurrentBalanceCents != buyAmount {
		t.Errorf("holding balance should be unchanged: got %d, want %d", gotHold.CurrentBalanceCents, buyAmount)
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestHoldingSell_QuantityInsufficient_FailFast -v -count=1`
Expected: PASS(quantity 不足 fail + 无副作用)。若 service.SellHolding 不 fail(quantity 不足未校验)→ 暴露 production bug(报告)。

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(buy + sell doublewrite + 套件 S1-S4 + 零回归)。

Run: `cd yucai/server && go build ./...`
Expected: 绿。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_doublewrite_integration_test.go
git commit -m "test(holding): sell quantity-insufficient fail-fast e2e" -m "TestHoldingSell_QuantityInsufficient_FailFast: sell 20 qty > holding 10 -> service.SellHolding fail + 无 trade/账户变化(fail-fast; sell 不查 from 余额, fail 在 service quantity, 先于 recordTradeTransaction). 照 buy fail-fast 范式."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run "TestHoldingSell|TestHoldingBuy" -v -count=1` — buy + sell doublewrite 全 PASS
- [ ] `cd yucai/server && go test ./tests/ -run "TestS[1-4]" -v -count=1` — performance 套件不破
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
