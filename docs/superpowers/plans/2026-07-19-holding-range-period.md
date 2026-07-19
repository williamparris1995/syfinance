# holding range-period coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 range XIRR/CAGR 覆盖(performance 套件只 full)。方案 A 单 trade,精确 0.30。

**Architecture:** 复用 `setupPerformanceHarness`(performance 套件)+ re-SetNow(2023-01-02 避 2/29)+ trade@2021-06-01(<rangeStart 2022-01-02)+ price seed。portfolio range XIRR/CAGR=0.30 + range TWR=nil + holding range 非伪非空。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:仅 `holding_performance_integration_test.go`(+1 test 追加)
- **复用** `setupPerformanceHarness` + `seedPriceHistory` + `approxFloat` + `seedBaselineHolding`(performance 套件,不改)
- **re-SetNow(2023-01-02)**:避 2/29 干净 365 天(MONTH rangeStart=2022-01-02,2022 非闰年);trade@2021-06-01 < rangeStart
- **rangeStart>trade**:避 QtyAtDate strict-< qty=0 degrade + holding 伪非空
- **price_history seed(2022-01-02)**:priceAtOrBefore(rangeStart)需 row
- **range TWR degrade nil**(单 trade effectiveDays=0):断言 nil
- **holding range 非伪非空**:rangeStart>trade qty>0 → 真 range;approxFloat 0.30(若 fallback full≈0.175 则 fail → 检测伪非空)
- 零 proto/schema(纯 test)
- TDD;commit multi -m

## File Structure

| 文件 | 改动 |
|---|---|
| [holding_performance_integration_test.go](../../yucai/server/tests/holding_performance_integration_test.go) | +`TestRangePeriod_XIRR_CAGR`(追加) |

---

## Task 1: TestRangePeriod_XIRR_CAGR

**Files:**
- Modify: `holding_performance_integration_test.go`(追加)

**Interfaces:**
- Consumes:`setupPerformanceHarness`(6 返值)+ `seedPriceHistory` + `approxFloat` + `svc.SetNow` + `svc.CreateSecurity`/`UpdateSecurityPrice`/`BuyHolding` + `holdRepo.FindByAccountAndSecurity` + `svc.GetHoldingPerformance`/`GetPortfolioPerformance`

- [ ] **Step 1: 写 TestRangePeriod_XIRR_CAGR**

追加:
```go
// TestRangePeriod_XIRR_CAGR verifies range-period XIRR/CAGR (performance suite
// only tested full). Fixture: re-SetNow(2023-01-02) avoids 2/29 (MONTH rangeStart
// = 2022-01-02 = 365 days, 2022 non-leap); trade@2021-06-01 < rangeStart (avoids
// QtyAtDate strict-< qty=0 degrade + holding range XIRR fallback-full 伪非空).
//
// Expected (single flow, 365 days):
//   portfolio range XIRR = 0.30 (rangeCfs [{2022-01-02,-1e6},{2023-01-02,+1.3e6}])
//   portfolio range CAGR = 0.30 ((1.3e6/1e6)^(365/365)-1)
//   portfolio range TWR = nil (single trade, effectiveDays empty → degrade)
//   holding range XIRR = 0.30 (qty@rangeStart=100>0, 非 fallback full; full XIRR≈0.175 over 578d)
//   holding range CAGR = 0.30 (price ratio 10000→13000)
func TestRangePeriod_XIRR_CAGR(t *testing.T) {
	svc, _, phRepo, holdRepo, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

	// re-SetNow 2023-01-02 (避 2/29; rangeStart=2022-01-02 365天; trade<rangeStart).
	eval2023, err := time.Parse("2006-01-02", "2023-01-02")
	if err != nil {
		t.Fatalf("parse eval 2023: %v", err)
	}
	svc.SetNow(func() time.Time { return eval2023.UTC() })

	// seed security + current price 13000.
	sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Range Test", SecurityType: domain.SecurityTypeStock,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	if err := svc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}

	// buy 100 @ 10000 @ 2021-06-01 (< rangeStart 2022-01-02; qty@rangeStart=100).
	if _, err := svc.BuyHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: sec.ID,
		Quantity: 100, PriceCents: 10000, TradeDate: day(t, "2021-06-01"),
	}); err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}

	// price_history seed at rangeStart 2022-01-02 (priceAtOrBefore rebuild opening MV).
	seedPriceHistory(t, phRepo, sec.ID, day(t, "2022-01-02"), 10000)

	holding, err := holdRepo.FindByAccountAndSecurity(ctx, tenantID, accountID, sec.ID)
	if err != nil || holding == nil {
		t.Fatalf("find holding: %v", err)
	}

	// GetHoldingPerformance + GetPortfolioPerformance (MONTH range).
	hPerf, err := svc.GetHoldingPerformance(ctx, holding.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance: %v", err)
	}
	pPerf, err := svc.GetPortfolioPerformance(ctx, tenantID, &accountID, "MONTH", false, "CNY")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}

	// Portfolio range XIRR = 0.30 (rangeCfs single flow, 365 days).
	approxFloat(t, pPerf.RangeAnnualizedPct, 0.30, "portfolio range XIRR")
	// Portfolio range CAGR = 0.30 ((1.3e6/1e6)^(365/365)-1).
	approxFloat(t, pPerf.RangeCagrAnnualizedPct, 0.30, "portfolio range CAGR")
	// Portfolio range TWR = nil (single trade, effectiveDays empty → degrade).
	if pPerf.RangeTwrAnnualizedPct != nil {
		t.Errorf("portfolio range TWR: got %v, want nil (single trade effectiveDays=0 degrade)", *pPerf.RangeTwrAnnualizedPct)
	}

	// Holding range XIRR = 0.30 (非 fallback full; qty@rangeStart=100>0).
	// 若 fallback full(≈0.175 over 578d)则 approxFloat 0.30 fail → 检测伪非空.
	approxFloat(t, hPerf.RangeAnnualizedPct, 0.30, "holding range XIRR (非伪非空)")
	// Holding range CAGR = 0.30 (price ratio 10000→13000).
	approxFloat(t, hPerf.RangeCagrAnnualizedPct, 0.30, "holding range CAGR")
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestRangePeriod_XIRR_CAGR -v -count=1`
Expected: PASS。若 range XIRR/CAGR 偏 → 查 fixture(re-SetNow 2023-01-02?trade<rangeStart?price seed 2022-01-02?)。若 holding range XIRR == full(伪非空)→ rangeStart>trade 未满足(qty@rangeStart=0)。

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS(performance S1-S4 + sell + price+snapshot + goal + lot + buy doublewrite + 新 range test + 零回归)。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_performance_integration_test.go
git commit -m "test(holding): range-period XIRR/CAGR e2e (方案 A 单 trade 0.30)" -m "TestRangePeriod_XIRR_CAGR: re-SetNow(2023-01-02 避 2/29 365天)+ trade@2021-06-01(<rangeStart 2022-01-02)+ price seed 10000@2022-01-02 + current 13000 -> portfolio range XIRR/CAGR=0.30(单 flow)+ range TWR=nil(单 trade effectiveDays=0)+ holding range XIRR 0.30 非伪非空(rangeStart>trade qty>0, fallback full≈0.175 则 approxFloat fail 检测). performance 套件 range defer 补."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run "TestRangePeriod|TestS[1-4]" -v -count=1` — range + performance 套件 PASS
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
