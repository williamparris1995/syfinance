# holding-backed goal scheduler e2e Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 holding-backed goal scheduler cross-module integration test —— investment goal → `SyncAllGoals` → holding `GetAccountsMarketValue` → `goal.current_amount` = Σ holdings mv。

**Architecture:** cross-module harness(单 sqlite + account/holding/goal ent client shared driver,照 holding_doublewrite 范式)+ 真 service + `goalSvc.SetAccountMarketValueSource(holdSvc)` structural。`SyncAllGoals(ctx, tenantID)` service 核心(单 tenant)。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:仅 `yucai/server/tests/goal_holding_scheduler_integration_test.go`(新,`package tests`)
- **cross-module harness**:account + holding + goal ent client **shared driver**(单 sqlite,各自 Schema.Create);照 [holding_doublewrite_integration_test.go:33-66](../../yucai/server/tests/holding_doublewrite_integration_test.go)
- **`goalSvc.SetAccountMarketValueSource(holdSvc)`**(structural;holding Service 满足 `goal/domain.AccountMarketValueSource`,无 adapter)
- **mv 原币不折算**(service.go:1660;期望值 Σ qty×price 原币)
- **LinkedAccountIDs 真 accountID**(harness 真 investment account,非随机 uuid.New)
- **IncrementVersion**:SyncAllGoals 已做(L255-257);e2e 只调 SyncAllGoals
- 零 proto/schema/production 改(纯 test)
- TDD;commit multi -m

## File Structure

| 文件 | 责任 |
|---|---|
| `yucai/server/tests/goal_holding_scheduler_integration_test.go`(新) | `setupGoalHoldingHarness` + `TestGoalScheduler_HoldingBackedCurrentAmount` |

---

## Task 1: setupGoalHoldingHarness(cross-module)

**Files:**
- Create: `yucai/server/tests/goal_holding_scheduler_integration_test.go`

**Interfaces:**
- Consumes:`accountapp.NewService`/`holdingapp.NewService`/`goalapp.NewService` + `goalSvc.SetAccountMarketValueSource`;3 ent client(account/holding/goal)shared driver
- Produces:`setupGoalHoldingHarness`(返 goalSvc/goalRepo/holdSvc/acctSvc/tenantID/accountID)

- [ ] **Step 1: 写文件骨架 + harness**

创建 `yucai/server/tests/goal_holding_scheduler_integration_test.go`:
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
	"github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalapp "github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// setupGoalHoldingHarness wires real ent-backed account + holding + goal services
// against ONE in-memory sqlite (3 ent clients share the same driver so cross-module
// data is visible — mirrors setupHoldingDoubleWriteTestDB). goalSvc consumes
// holding's GetAccountsMarketValue via structural AccountMarketValueSource port.
func setupGoalHoldingHarness(t *testing.T) (
	goalSvc *goalapp.Service, goalRepo *repository.GoalRepository,
	holdSvc *holdingapp.Service, acctSvc *accountapp.Service,
	tenantID uuid.UUID,
) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:goal_hold_dw?mode=memory")
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
	goalClient := goalent.NewClient(goalent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	if err := goalClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create goal schema: %v", err)
	}
	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	t.Cleanup(func() { goalClient.Close() })

	// account service
	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = accountapp.NewService(accountRepo, chartRepo)

	// holding service
	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc = holdingapp.NewService(secRepo, holdRepo, tradeRepo)

	// goal service — inject holding as AccountMarketValueSource (structural)
	goalRepo = repository.NewGoalRepository(goalClient)
	goalSvc = goalapp.NewService(goalRepo)
	goalSvc.SetAccountMarketValueSource(holdSvc)

	tenantID = uuid.New()
	return goalSvc, goalRepo, holdSvc, acctSvc, tenantID
}

var _ = time.Time{} // placeholder import use (test in Task 2 uses time)
```

- [ ] **Step 2: 跑 `go vet ./tests/` + `go test -run None ./tests/` 确认 harness 编译**

Run: `cd yucai/server && go vet ./tests/ && go test -run None ./tests/ -count=1`
Expected: clean(tests-only package,无 test 函数也编译;若 "imported and not used" 删未用 import/占位 `var _ = time.Time{}`)。

- [ ] **Step 3: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/goal_holding_scheduler_integration_test.go
git commit -m "test(goal): goal+holding cross-module harness (setupGoalHoldingHarness)" -m "setupGoalHoldingHarness(单 sqlite + account/holding/goal ent shared driver + 真 service + goalSvc.SetAccountMarketValueSource(holdSvc) structural). 照 holding_doublewrite 多 client shared driver 范式. 套件系列第 4 spec Task 1."
```

---

## Task 2: TestGoalScheduler_HoldingBackedCurrentAmount

**Files:**
- Modify: `goal_holding_scheduler_integration_test.go`

**Interfaces:**
- Consumes:Task 1 harness;`acctSvc.CreateAccount`(investment)+ `holdSvc.CreateSecurity`/`UpdateSecurityPrice`/`BuyHolding`;`goaldomain.NewGoal`/`goalRepo.Save`;`goalSvc.SyncAllGoals`;`goalRepo.FindAll`

- [ ] **Step 1: 写 TestGoalScheduler_HoldingBackedCurrentAmount**

追加:
```go
import (
	// ... existing ...
	accountdomain "github.com/yucai/server/internal/account/domain"
	goaldomain "github.com/yucai/server/internal/goal/domain"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
)

// TestGoalScheduler_HoldingBackedCurrentAmount drives goalSvc.SyncAllGoals for an
// Investment goal linked to a real holding account, then verifies the scheduler
// pulled Σ holdings market value via the holding AccountMarketValueSource port
// and wrote it to goal.CurrentAmountCents.
//
// MV source = sec.CurrentPriceCents (NOT priceHistoryRepo); mv 原币不折算.
// Expected: 100 qty × 13000 cents = 1,300,000 cents.
func TestGoalScheduler_HoldingBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, holdSvc, acctSvc, tenantID := setupGoalHoldingHarness(t)
	ctx := context.Background()

	// seed investment account.
	acc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:    tenantID,
		Name:        "投资账户",
		AccountType: accountdomain.AccountTypeAsset,
		Category:    accountdomain.AccountCategoryInvestment,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	accountID := acc.ID

	// seed security + current price 13000.
	sec, err := holdSvc.CreateSecurity(ctx, holdingapp.CreateSecurityRequest{
		Symbol: "600519", Name: "Moutai", SecurityType: holdingdomain.SecurityTypeStock,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	if err := holdSvc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}

	// seed holding 100 qty under the investment account.
	if _, err := holdSvc.BuyHolding(ctx, holdingapp.HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: sec.ID,
		Quantity: 100, PriceCents: 10000, TradeDate: time.Now(),
	}); err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}

	// seed Investment goal linked to the real accountID (NOT random uuid.New).
	goal, err := goaldomain.NewGoal(tenantID, "投资目标", goaldomain.GoalTypeInvestment,
		2000000 /*target*/, "CNY", nil /*deadline*/, []uuid.UUID{accountID}, nil /*debts*/, "" /*notes*/)
	if err != nil {
		t.Fatalf("NewGoal: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: scheduler core (single tenant). computeGoalProgress →
	// mvSrc.GetAccountsMarketValue([accountID]) = Σ holdings mv = 100×13000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count < 1 {
		t.Errorf("SyncAllGoals count=%d, want >= 1", count)
	}

	// Verify goal.CurrentAmountCents = 100 × 13000 = 1,300,000.
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, domain.PageRequest{PageSize: 10})
	if err != nil || len(got.Goals) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Goals))
	}
	if got.Goals[0].CurrentAmountCents != 1300000 {
		t.Errorf("goal.CurrentAmountCents: got %d, want 1300000 (100×13000)",
			got.Goals[0].CurrentAmountCents)
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestGoalScheduler_HoldingBackedCurrentAmount -v -count=1`
Expected: PASS。若 API 签名不符(accountapp.NewService 返 *Service?/CreateAccountRequest 字段/goaldomain.NewGoal 9 参/goalRepo.FindAll 返 PaginatedResult?/SyncAllGoals)照实际调整。若 mv=0 → 确认 LinkedAccountIDs=真 accountID(非随机)+ sec.CurrentPrice=13000。

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(performance S1-S4 + sell 双写 + price+snapshot + buy doublewrite + 新 goal test + 零回归)。

Run: `cd yucai/server && go build ./...`
Expected: 绿。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/goal_holding_scheduler_integration_test.go
git commit -m "test(goal): holding-backed goal scheduler e2e (current_amount=mv)" -m "TestGoalScheduler_HoldingBackedCurrentAmount: seed investment account + security(price 13000) + holding(100 qty) + investment goal(LinkedAccountIDs=[accountID]) -> goalSvc.SyncAllGoals -> computeGoalProgress -> mvSrc.GetAccountsMarketValue=100x13000 -> goal.CurrentAmountCents=1300000. cross-module holding-backed goal scheduler integration (holding e2e 套件系列第 4 spec)."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run TestGoalScheduler_HoldingBackedCurrentAmount -v -count=1` — PASS
- [ ] `cd yucai/server && go test ./tests/ -run "TestS[1-4]|TestHoldingSell|TestHoldingBuy|TestSyncPrices|TestSnapshotNow" -v -count=1` — 既有套件不破
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
