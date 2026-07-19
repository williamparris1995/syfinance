# networth 多币种 e2e Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 networth 多币种 cross-module integration(4 ent + GetNetWorth base CNY 聚合)。

**Architecture:** `setupNetWorthHarness`(account+holding+debt+currency 4 ent shared driver + 真 service + `networthapp.NewService` + `debtSvc.SetAccountLookup`)+ `TestNetWorth_MultiCurrency`(seed account CNY + holding USD + debt CNY + rate USD=7 → GetNetWorth base CNY)。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:仅 `yucai/server/tests/networth_multicurrency_integration_test.go`(新,`package tests`)
- **4 ent shared driver**:account/holding/debt/currency(networth 无 ent,纯聚合);照 [holding_doublewrite](../../yucai/server/tests/holding_doublewrite_integration_test.go)/[goal_holding](../../yucai/server/tests/goal_holding_scheduler_integration_test.go) 范式
- **debt `SetAccountLookup(accountRepo)`**(否则 currency 默认 CNY;USD debt 错归)
- **rate 过去日期 seed**(`GetNetWorth FindRate(time.Now)` 硬编码;fixture seed `<= now` 过去日期,否则 1.0 fallback)
- **逐条 round**(base CNY 数字干净 10000+7000=17000)
- 零 proto/schema(纯 test)
- TDD;commit multi -m

## File Structure

| 文件 | 责任 |
|---|---|
| `yucai/server/tests/networth_multicurrency_integration_test.go`(新) | `setupNetWorthHarness` + `TestNetWorth_MultiCurrency` |

---

## Task 1: setupNetWorthHarness(4 ent cross-module)

**Files:**
- Create: `yucai/server/tests/networth_multicurrency_integration_test.go`

**Interfaces:**
- Consumes:`accountapp`/`holdingapp`/`debtapp`/`networthapp`/`currencyrepo` + 4 ent client(account/holding/debt/currency)
- Produces:`setupNetWorthHarness`(返 networthSvc + acctSvc/holdSvc/debtSvc + currencyClient + tenantID)

- [ ] **Step 1: 写文件骨架 + harness**

创建 `yucai/server/tests/networth_multicurrency_integration_test.go`:
```go
package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountapp "github.com/yucai/server/internal/account/application"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent"
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	currencyent "github.com/yucai/server/internal/currency/ent"
	debtapp "github.com/yucai/server/internal/debt/application"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtent "github.com/yucai/server/internal/debt/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingent "github.com/yucai/server/internal/holding/ent"
	networthapp "github.com/yucai/server/internal/networth/application"
)

// setupNetWorthHarness wires real ent-backed account + holding + debt + currency
// services against ONE in-memory sqlite (4 ent clients share the driver — networth
// has no ent, pure aggregation). debt.SetAccountLookup is required so non-CNY debt
// resolves its currency from the account. Mirrors setupHoldingDoubleWriteTestDB /
// setupGoalHoldingHarness multi-client pattern.
func setupNetWorthHarness(t *testing.T) (
	networthSvc *networthapp.Service,
	acctSvc *accountapp.Service, holdSvc *holdingapp.Service, debtSvc *debtapp.Service,
	currencyClient *currencyent.Client,
	tenantID uuid.UUID,
) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:net_worth_dw?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	acctClient := accountent.NewClient(accountent.Driver(drv))
	holdClient := holdingent.NewClient(holdingent.Driver(drv))
	debtClient := debtent.NewClient(debtent.Driver(drv))
	currencyClient = currencyent.NewClient(currencyent.Driver(drv))

	ctx := context.Background()
	for _, c := range []*struct{ name string; create func() error }{
		{"account", acctClient.Schema.Create},
		{"holding", holdClient.Schema.Create},
		{"debt", debtClient.Schema.Create},
		{"currency", currencyClient.Schema.Create},
	} {
		if err := c.create(); err != nil {
			t.Fatalf("create %s schema: %v", c.name, err)
		}
	}
	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	t.Cleanup(func() { debtClient.Close() })
	t.Cleanup(func() { currencyClient.Close() })

	// account service
	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = accountapp.NewService(accountRepo, chartRepo)

	// holding service
	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc = holdingapp.NewService(secRepo, holdRepo, tradeRepo)

	// debt service — MUST SetAccountLookup so non-CNY debt resolves currency
	debtRepo := debtrepo.NewDebtRepository(debtClient)
	debtSvc = debtapp.NewService(debtRepo)
	debtSvc.SetAccountLookup(accountRepo)

	// currency rate repo
	rateRepo := currencyrepo.NewRateHistoryRepository(currencyClient)

	// networth aggregation (no ent, pure port consumption)
	networthSvc = networthapp.NewService(acctSvc, holdSvc, debtSvc, rateRepo, nil)

	tenantID = uuid.New()
	return networthSvc, acctSvc, holdSvc, debtSvc, currencyClient, tenantID
}

var _ = time.Time{} // placeholder (test in Task 2 uses time)
```

- [ ] **Step 2: build/vet 确认**

Run: `cd yucai/server && go vet ./tests/ && go test -run None ./tests/ -count=1`
Expected: clean(tests-only,无 test 函数也编译;若 "imported and not used" 删未用 import/占位)。

- [ ] **Step 3: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/networth_multicurrency_integration_test.go
git commit -m "test(networth): 4-ent cross-module harness (setupNetWorthHarness)" -m "setupNetWorthHarness: 单 sqlite + account/holding/debt/currency 4 ent shared driver + 真 service + networthapp.NewService + debtSvc.SetAccountLookup(USD debt currency). 照 holding_doublewrite/goal_holding 多 client 范式. networth 无 ent 纯聚合."
```

---

## Task 2: TestNetWorth_MultiCurrency

**Files:**
- Modify: `networth_multicurrency_integration_test.go`

**Interfaces:**
- Consumes:Task 1 harness;`acctSvc.CreateAccount` + `holdSvc.CreateSecurity`/`UpdateSecurityPrice`/`BuyHolding` + `debtSvc.CreateDebt`(或 debtRepo seed)+ `currencyClient.RateHistory.Create`(seedRate)+ `networthSvc.GetNetWorth`

- [ ] **Step 1: 写 TestNetWorth_MultiCurrency**

追加:
```go
import (
	// ... existing ...
	accountdomain "github.com/yucai/server/internal/account/domain"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
)

// seedRate writes a currency rate history row (过去日期 <= time.Now,否则 FindRate
// forward-fill miss → 1.0 fallback). GetNetWorth calls FindRate(code, time.Now())
// hardcoded — fixture MUST seed a past date.
func seedRate(t *testing.T, client *currencyent.Client, code string, rateDate time.Time, rate float64) {
	t.Helper()
	ctx := context.Background()
	if _, err := client.RateHistory.Create().
		SetCurrencyCode(code).SetRateDate(rateDate).SetExchangeRate(rate).
		Save(ctx); err != nil {
		t.Fatalf("seed rate %s: %v", code, err)
	}
}

// TestNetWorth_MultiCurrency drives networth.GetNetWorth with real ent-backed
// account/holding/debt + currency rate history, verifying multi-currency
// aggregation to base CNY.
//
// Fixture: account CNY 10000 + security USD + holding USD (mv 1000) + debt CNY 5000
// + rate USD=7 → base CNY assets=17000 (10000+7000) / liab=5000 / net=12000.
func TestNetWorth_MultiCurrency(t *testing.T) {
	networthSvc, acctSvc, holdSvc, debtSvc, currencyClient, tenantID := setupNetWorthHarness(t)
	ctx := context.Background()

	// seed account CNY savings 10000 (asset).
	acc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantID, Name: "CNY Savings",
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY", InitialBalanceCents: 10000,
	})
	if err != nil {
		t.Fatalf("CreateAccount CNY: %v", err)
	}
	_ = acc

	// seed security USD + price 10 cents + holding 100 qty (mv = 100×10 = 1000 cents USD).
	sec, err := holdSvc.CreateSecurity(ctx, holdingapp.CreateSecurityRequest{
		Symbol: "AAPL", Name: "Apple", SecurityType: holdingdomain.SecurityTypeStock,
		Exchange: "NASDAQ", CurrencyCode: "USD",
	})
	if err != nil {
		t.Fatalf("CreateSecurity USD: %v", err)
	}
	if err := holdSvc.UpdateSecurityPrice(ctx, sec.ID, 10); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}
	// BuyHolding needs an investment account; create USD investment account.
	usdAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantID, Name: "USD Investment",
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategoryInvestment,
		CurrencyCode: "USD",
	})
	if err != nil {
		t.Fatalf("CreateAccount USD: %v", err)
	}
	if _, err := holdSvc.BuyHolding(ctx, holdingapp.HoldingTradeRequest{
		TenantID: tenantID, AccountID: usdAcc.ID, SecurityID: sec.ID,
		Quantity: 100, PriceCents: 10, TradeDate: time.Now(),
	}); err != nil {
		t.Fatalf("BuyHolding USD: %v", err)
	}

	// seed debt CNY 5000 (remaining). debtSvc.CreateDebt 或 debtRepo seed — 照 debt_doublewrite 范式.
	// (implementer:确认 debt seed API;目标 debt CNY remaining=5000 under a CNY account)
	// [implementer 调通:debtSvc.CreateDebt 或 debtRepo 直 seed remaining 5000]

	// seed rate USD=7 (过去日期 <= time.Now;GetNetWorth FindRate(time.Now) 硬编码).
	pastDate := time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC)
	seedRate(t, currencyClient, "USD", pastDate, 7.0)

	// GetNetWorth base CNY.
	result, err := networthSvc.GetNetWorth(ctx, tenantID, "CNY")
	if err != nil {
		t.Fatalf("GetNetWorth: %v", err)
	}

	// Verify: assets = account CNY 10000 + holding USD 1000×7 = 17000.
	if result.TotalAssetsCents != 17000 {
		t.Errorf("TotalAssetsCents: got %d, want 17000 (account CNY 10000 + holding USD 1000×7)", result.TotalAssetsCents)
	}
	// liab = debt CNY 5000.
	if result.TotalLiabilitiesCents != 5000 {
		t.Errorf("TotalLiabilitiesCents: got %d, want 5000 (debt CNY 5000)", result.TotalLiabilitiesCents)
	}
	// net = 17000 − 5000 = 12000.
	if result.NetWorthCents != 12000 {
		t.Errorf("NetWorthCents: got %d, want 12000 (17000 − 5000)", result.NetWorthCents)
	}
	if result.Currency != "CNY" {
		t.Errorf("Currency: got %q, want \"CNY\"", result.Currency)
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestNetWorth_MultiCurrency -v -count=1`
Expected: PASS。调通点:
- **debt seed**:debtSvc.CreateDebt 或 debtRepo seed remaining 5000(照 debt_doublewrite 范式;目标 debt CNY remaining=5000)
- **debt currency**:debt 挂 CNY account(SetAccountLookup 已 wire;debt.SumRemainingByCurrency 归 CNY)
- **holding mv**:BuyHolding 100 qty × price 10 = 1000 cents USD;SumMarketValueByCurrency 归 USD;toBase(USD, 7) = 7000
- **account**:SumBalancesByCurrency 归 CNY(asset)+ USD(asset)
- 若 USD 不折算(rate miss)→ 查 seedRate 过去日期(pastDate <= time.Now())

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS(holding e2e 套件 + future + 新 networth test + 零回归)。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/networth_multicurrency_integration_test.go
git commit -m "test(networth): 多币种 e2e (GetNetWorth base CNY cross-module aggregation)" -m "TestNetWorth_MultiCurrency: account CNY 10000 + security USD + holding USD(mv 1000)+ debt CNY 5000 + rate USD=7(过去日期 seed) -> GetNetWorth base CNY assets=17000(account 10000 + holding 7000)/ liab=5000 / net=12000. cross-module 4 ent(account/holding/debt/currency) + networth 纯聚合. debt SetAccountLookup(USD debt currency)+ rate 过去日期(FindRate time.Now 硬编码). networth future(独立)."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run TestNetWorth_MultiCurrency -v -count=1` — PASS
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
