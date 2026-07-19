# holding lot 路径 e2e + service newLot ID fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 lot 路径 integration(FIFO lot consume + realized)+ fix 陷阱 A production bug(service newLot ID)。

**Architecture:** fix service.go newLot ID(方案 B,zero Nil → lot_repo Create Default)+ doublewrite harness 加 `NewLotRepository` + `SetLotRepository`(现有 4 test 走 lot 路径)+ 返 `holdClient`/`lotRepo`。`TestLotPath_FIFOConsumeAndRealized` 验 FIFO consume + realized(via tradeRepo)。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:`service.go`(fix newLot ID)+ `holding_doublewrite_integration_test.go`(harness 返值扩展 + 现有 4 test 改解构 + 新 lot test)
- **fix 方案 B**:service.go:106 newLot 去 `ID: uuid.New()`(zero Nil);lot_repo Create 分支(==Nil)走 ent Default。不动 lot_repo
- **harness 加 lotRepo**:`NewLotRepository(holdClient)` + `holdSvc.SetLotRepository(lotRepo)`;返值加 `holdClient`/`lotRepo`;现有 4 test 改 `_` 接住
- **现有 4 test 走 lot 路径**(lotRepo!=nil):fix 后 pass(单 buy/sell lot 路径 vs fallback 同结果)
- **realized via `tradeRepo.FindAll`**(proto `tradeToProto` 剥 RealizedPnLCents;走 tradeRepo domain 字段)
- **FIFO consume 验**:`lotRepo.FindByHolding` RemainingQuantity
- 零 proto/schema(仅 service.go 1 行 + test)
- TDD;commit multi -m

## File Structure

| 文件 | 改动 |
|---|---|
| [service.go](../../yucai/server/internal/holding/application/service.go) | BuyHolding newLot 去 `ID: uuid.New()`(陷阱 A fix) |
| [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go) | `setupHoldingDoubleWriteHarness` 加 lotRepo + 返值;现有 4 test 改解构;+`TestLotPath_FIFOConsumeAndRealized` |

---

## Task 1: fix service newLot ID + harness 加 lotRepo + 现有 4 test 改解构

**Files:**
- Modify: [service.go:104-109](../../yucai/server/internal/holding/application/service.go)(BuyHolding newLot)
- Modify: [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(harness + 4 test 解构)

- [ ] **Step 1: fix service.go newLot 去 ID(陷阱 A 方案 B)**

[service.go:104-109](../../yucai/server/internal/holding/application/service.go) BuyHolding newLot,删 `ID: uuid.New()`:
```go
tradeID := uuid.New()
newLot := domain.HoldingLot{
	// ID 留 zero(uuid.Nil)—— lot_repo SaveAll Create 分支(==Nil)走 ent Default。
	// 修陷阱 A:原 ID: uuid.New() 非 Nil → lot_repo Update 分支 → ent NotFound。
	TenantID: req.TenantID, HoldingID: h.ID, SecurityID: req.SecurityID,
	AcquiredDate: req.TradeDate, AcquiredTradeID: tradeID,
	PriceCents: req.PriceCents, Quantity: req.Quantity, RemainingQuantity: req.Quantity,
}
```

- [ ] **Step 2: harness 加 lotRepo + 返值扩展**

[holding_doublewrite_integration_test.go:73-123](../../yucai/server/tests/holding_doublewrite_integration_test.go) `setupHoldingDoubleWriteHarness`:
- 签名加返值 `holdClient *holdingent.Client, lotRepo *holdingsec.LotRepository`(共 7 返值)
- wire:加 `lotRepo := holdingsec.NewLotRepository(holdClient)` + `holdSvc.SetLotRepository(lotRepo)`(在 `holdSvc := application.NewService(...)` 后)
- 返 `holdClient, lotRepo`(`holdClient` 已在 setupHoldingDoubleWriteTestDB 返,透传)

```go
func setupHoldingDoubleWriteHarness(t *testing.T) (
	h *holdgrpc.HoldingHandler,
	acctSvc accountapp.Service,
	tenantID, fromAccID, holdAccID uuid.UUID,
	holdClient *holdingent.Client, lotRepo *holdingsec.LotRepository,
) {
	// ... existing setupHoldingDoubleWriteTestDB + wire ...
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
	lotRepo = holdingsec.NewLotRepository(holdClient)  // 新加
	holdSvc.SetLotRepository(lotRepo)                   // 新加(FIFO lot 路径)
	h = holdgrpc.NewHoldingHandler(holdSvc, txnSvc, accountRepo)
	// ... seed accounts ...
	return h, acctSvc, tenantID, fromAccID, holdAccID, holdClient, lotRepo
}
```
(import 加 `holdingent` 若未在;`holdClient` 从 `setupHoldingDoubleWriteTestDB` 返值透传 —— 注:setupHoldingDoubleWriteTestDB 返 acctClient/txnClient/holdClient,harness 当前不返 holdClient,需从 setupHoldingDoubleWriteTestDB 拿 holdClient 透传到 harness 返值)

- [ ] **Step 3: 现有 4 test 改解构(接住新返值)**

4 个 test 的 `setupHoldingDoubleWriteHarness(t)` 解构加 `, _, _`(holdClient/lotRepo 不用):
- `TestHoldingBuy_DoubleWrite_EndToEnd`
- `TestHoldingBuy_InsufficientBalance_FailFast`
- `TestHoldingSell_DoubleWrite_EndToEnd`
- `TestHoldingSell_QuantityInsufficient_FailFast`

每改:`h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)` → `h, acctSvc, tenantID, fromAccID, holdAccID, _, _ := setupHoldingDoubleWriteHarness(t)`

- [ ] **Step 4: 验证现有 4 test 走 lot 路径仍 pass**

Run: `cd yucai/server && go test ./tests/ -run "TestHoldingBuy|TestHoldingSell" -v -count=1`
Expected: 4 test PASS(lot 路径:fix service newLot ID 后 BuyHolding 创 lot OK;单 buy/sell lot 路径 vs fallback 同结果 —— 余额/Quantity/fail-fast 不变)。若 fail → 分析(lot 路径行为差异,如 AvgCost/realized message)。

- [ ] **Step 5: 全量 + build**

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS + 绿。

- [ ] **Step 6: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/holding/application/service.go yucai/server/tests/holding_doublewrite_integration_test.go
git commit -m "fix(holding): service newLot ID + doublewrite harness lotRepo (lot 路径)" -m "fix 陷阱 A: service.go BuyHolding newLot 去 ID(uuid.New -> zero Nil), lot_repo Create 分支(==Nil)走 ent Default(原非 Nil ID 走 Update -> ent NotFound). harness setupHoldingDoubleWriteHarness 加 NewLotRepository + SetLotRepository + 返 holdClient/lotRepo. 现有 4 doublewrite test 改解构接住新返值, 走 lot 路径(fix 后 pass). 第 3 production bug 发现(CreatedAt + Source + lot ID)."
```

---

## Task 2: TestLotPath_FIFOConsumeAndRealized

**Files:**
- Modify: `holding_doublewrite_integration_test.go`

**Interfaces:**
- Consumes:Task 1 harness(holdClient/lotRepo)+ handler BuyHolding/SellHolding;`lotRepo.FindByHolding`;`tradeRepo.FindAll`(via holdClient 或新 wire)

- [ ] **Step 1: 写 TestLotPath_FIFOConsumeAndRealized**

追加(照 buy/sell FIFO 范式):
```go
// TestLotPath_FIFOConsumeAndRealized verifies the FIFO lot path (lotRepo!=nil):
// buy 60@10000 (lot1) + buy 40@12000 (lot2) + sell 80@13000 → FIFO consume
// (lot1 全 60 realized (13000-10000)*60=180000 + lot2 20 realized (13000-12000)*20=20000
// = 200000); lot1 remaining=0, lot2 remaining=20; trade.RealizedPnLCents=200000.
//
// realized 验走 tradeRepo.FindAll(proto tradeToProto 剥 RealizedPnLCents).
func TestLotPath_FIFOConsumeAndRealized(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID, holdClient, lotRepo := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()
	_ = acctSvc // not used (lot path test focuses on lots/realized, not account double-write)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600004", Name: "Lot Path Test",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	// buy 60 @ 10000 (lot1).
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 60, PriceCents: 10000, TradeDate: "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding 60@10000: %v", err)
	}
	// buy 40 @ 12000 (lot2).
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 40, PriceCents: 12000, TradeDate: "2026-06-29",
	}); err != nil {
		t.Fatalf("BuyHolding 40@12000: %v", err)
	}

	// sell 80 @ 13000 (FIFO: lot1 全 60 + lot2 20).
	if _, err := h.SellHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 80, PriceCents: 13000, TradeDate: "2026-06-30",
	}); err != nil {
		t.Fatalf("SellHolding 80@13000: %v", err)
	}

	// Verify lot FIFO consume via lotRepo.FindByHolding.
	// 拿 holdingID(via ListHoldings).
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil || len(list.Holdings) != 1 {
		t.Fatalf("ListHoldings: err=%v len=%d", err, len(list.Holdings))
	}
	holdingID := uuid.MustParse(list.Holdings[0].Id)
	lots, err := lotRepo.FindByHolding(ctx, holdingID)
	if err != nil {
		t.Fatalf("lotRepo.FindByHolding: %v", err)
	}
	// FIFO: lot1(2026-06-28) remaining=0, lot2(2026-06-29) remaining=20.
	var lot1Rem, lot2Rem float64
	for _, l := range lots {
		dayStr := l.AcquiredDate.Format("2006-01-02")
		if dayStr == "2026-06-28" {
			lot1Rem = l.RemainingQuantity
		}
		if dayStr == "2026-06-29" {
			lot2Rem = l.RemainingQuantity
		}
	}
	if lot1Rem != 0 {
		t.Errorf("lot1 remaining: got %v, want 0 (FIFO consumed 60)", lot1Rem)
	}
	if lot2Rem != 20 {
		t.Errorf("lot2 remaining: got %v, want 20 (FIFO consumed 20 of 40)", lot2Rem)
	}

	// Verify trade.RealizedPnLCents via tradeRepo.FindAll (proto 不透).
	// tradeRepo 需 wire(harness 不返 tradeRepo;用 holdClient 直查或 harness 加返值).
	// 简化:直 holdClient.HoldingTransaction.Query() 验 RealizedPnLCents=200000.
	trades, err := holdClient.HoldingTransaction.Query().All(ctx)
	if err != nil {
		t.Fatalf("query trades: %v", err)
	}
	var sellRealized int64
	for _, tr := range trades {
		if tr.TradeType == "sell" { // ent 字段 string;照实际 enum 值
			sellRealized = tr.RealizedPnLCents
		}
	}
	if sellRealized != 200000 {
		t.Errorf("sell trade RealizedPnLCents: got %d, want 200000 ((13000-10000)*60 + (13000-12000)*20)", sellRealized)
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestLotPath_FIFOConsumeAndRealized -v -count=1`
Expected: PASS。若 API 不符(holdClient.HoldingTransaction Query / tradeType string / lotRepo.FindByHolding 签名 / ListHoldings Holdings[0].Id)照实际调整。若 lot remaining 偏 → 查 FIFO consume(陷阱:lots 总 remaining == holding.Quantity)。

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS(performance S1-S4 + sell/price+snapshot/goal + buy doublewrite + lot test + 零回归)。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_doublewrite_integration_test.go
git commit -m "test(holding): lot 路径 FIFO consume + realized e2e (lotRepo integration)" -m "TestLotPath_FIFOConsumeAndRealized: buy 60@10000(lot1) + 40@12000(lot2) + sell 80@13000 -> FIFO consume(lot1 remaining 0 + lot2 remaining 20)+ trade.RealizedPnLCents=200000((13000-10000)*60+(13000-12000)*20). lot 路径 integration(lotRepo!=nil, doublewrite harness 扩展). realized via holdClient.HoldingTransaction(proto 不透)."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run "TestLotPath|TestHoldingBuy|TestHoldingSell" -v -count=1` — lot + doublewrite 全 PASS
- [ ] `cd yucai/server && go test ./tests/ -run "TestS[1-4]|TestSyncPrices|TestSnapshotNow|TestGoalScheduler" -v -count=1` — 既有套件不破
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
