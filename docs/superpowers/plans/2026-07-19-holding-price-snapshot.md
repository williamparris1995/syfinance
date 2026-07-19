# holding price+snapshot 合并 e2e Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 B-价格 sync + C-snapshot 跨层 integration test(合并 1 spec)。fake Provider → SyncPrices → price_history + CurrentPrice;cross-tenant SnapshotAllHoldings → holding_snapshot MV。

**Architecture:** 真在 enttest SQLite 中,wire 真 repo + service setter(`SetPriceRouter` fake / `SetSnapshotRepository` / `SetPriceHistoryRepository` / `SetTenantLister` fake / `SetNow`)。tests 包内自定义 `fakePriceRouter` + `fakeTenantLister`(application/scheduler 的 fake 未 export)。**MV 来源 = `sec.CurrentPriceCents`**(snapshot 路径不查 priceHistoryRepo)。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:仅 `yucai/server/tests/holding_price_snapshot_integration_test.go`(新,`package tests`)
- **MV 来源 = `sec.CurrentPriceCents`**(service.go:532 `h.MarketValue(sec.CurrentPriceCents)`);snapshot 路径**不查 priceHistoryRepo**(调研确认)
- **`SnapshotAllHoldings` 需 `SetTenantLister`**(service.go:561 nil → error);prod `HoldingRepository.FindAll(uuid.Nil)` 返空(非 all)→ test 用真 ent + fakeTenantLister + 多 tenant holding(TenantID 字段)
- **fakePriceRouter 直接 `SetPriceRouter`**(免 CompositeRouter;application fakePriceRouter 未 export → tests 包自定义)
- `SetNow` 复用(Task 1 now 注入,固定评估日;SnapshotDate = `truncateToDate(s.now())`)
- 零 proto/schema/production 改(纯 test)
- TDD;commit multi -m

## File Structure

| 文件 | 责任 |
|---|---|
| `yucai/server/tests/holding_price_snapshot_integration_test.go`(新) | `setupPriceSnapshotHarness` + `fakePriceRouter` + `fakeTenantLister` + 2 test |

---

## Task 1: setupPriceSnapshotHarness + fakes

**Files:**
- Create: `yucai/server/tests/holding_price_snapshot_integration_test.go`

**Interfaces:**
- Consumes:`application.NewService` + `SetSnapshotRepository`/`SetPriceHistoryRepository`/`SetTenantLister`/`SetNow`(Task 1 now 注入,performance 套件);`repository.NewSecurityRepository`/`NewHoldingRepository`/`NewTradeRepository`/`NewSnapshotRepository`/`NewPriceHistoryRepository`(holdingent.Client)
- Produces:`setupPriceSnapshotHarness`、`fakePriceRouter`、`fakeTenantLister`(Task 2/3 用)

- [ ] **Step 1: 写文件骨架 + harness + fakes**

创建 `yucai/server/tests/holding_price_snapshot_integration_test.go`:
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
	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
)

const psEvalDate = "2021-01-01"

// fakePriceRouter is a test double for priceprovider.Router (tests-package copy
// of application/fakePriceRouter — that one is unexported). Returns configured
// price by symbol; unknown symbol → ErrNoSource (keep old price).
type fakePriceRouter struct {
	prices map[string]int64 // symbol → priceCents
}

func (r *fakePriceRouter) FetchPrice(_ context.Context, v priceprovider.PriceView) (int64, string, error) {
	if p, ok := r.prices[v.Symbol]; ok {
		return p, "fake", nil
	}
	return 0, "", priceprovider.ErrNoSource
}

// fakeTenantLister is a test double for domain.TenantLister (cross-tenant
// SnapshotAllHoldings fan-out). Copy of goal/scheduler mockTenantLister.
type fakeTenantLister struct{ ids []uuid.UUID }

func (m *fakeTenantLister) FindAllIDs(_ context.Context) ([]uuid.UUID, error) {
	return m.ids, nil
}

// setupPriceSnapshotHarness wires a real ent-backed holding Service against one
// in-memory sqlite. Returns the service, ent client (for seed), the wired repos,
// and a fresh tenant/account. priceRouter is LEFT UNSET — B-price test calls
// svc.SetPriceRouter itself; C-snapshot does not need it (MV = sec.CurrentPriceCents).
func setupPriceSnapshotHarness(t *testing.T) (
	svc *application.Service, client *holdingent.Client,
	secRepo *repository.SecurityRepository, holdRepo *repository.HoldingRepository,
	snapRepo *repository.SnapshotRepository, phRepo *repository.PriceHistoryRepository,
	tenantID, accountID uuid.UUID,
) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:hold_ps_"+t.Name()+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client = holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })

	secRepo = repository.NewSecurityRepository(client)
	holdRepo = repository.NewHoldingRepository(client)
	tradeRepo := repository.NewTradeRepository(client)
	snapRepo = repository.NewSnapshotRepository(client)
	phRepo = repository.NewPriceHistoryRepository(client)

	svc = application.NewService(secRepo, holdRepo, tradeRepo)
	svc.SetSnapshotRepository(snapRepo)
	svc.SetPriceHistoryRepository(phRepo)
	// priceRouter: B-price test sets it; C-snapshot does not need it.
	svc.SetTenantLister(&fakeTenantLister{}) // test overrides via re-set if needed
	// rateRepo nil: CNY only.

	evalTime, _ := time.Parse("2006-01-02", psEvalDate)
	svc.SetNow(func() time.Time { return evalTime.UTC() })

	tenantID, accountID = uuid.New(), uuid.New()
	return svc, client, secRepo, holdRepo, snapRepo, phRepo, tenantID, accountID
}
```

- [ ] **Step 2: 跑 `go build ./tests/` 确认 harness + fakes 编译**

Run: `cd yucai/server && go build ./tests/`
Expected: clean(无 test 函数也能 build;若 Go 报 "declared and not used",删未用 import/变量)。

- [ ] **Step 3: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_price_snapshot_integration_test.go
git commit -m "test(holding): price+snapshot harness + fakes (setupPriceSnapshotHarness)" -m "setupPriceSnapshotHarness(真 ent + service setter: SetSnapshot/PriceHistory/TenantLister/Now; priceRouter 留 B-price test 设)+ fakePriceRouter(tests 包 copy,免 CompositeRouter)+ fakeTenantLister(cross-tenant fan-out). 套件系列第 3 spec(price+snapshot)Task 1."
```

---

## Task 2: TestSyncPrices_PersistsPriceHistoryAndCurrentPrice(B-price)

**Files:**
- Modify: `holding_price_snapshot_integration_test.go`

**Interfaces:**
- Consumes:Task 1 harness + `fakePriceRouter`;`svc.SyncPrices`;`secRepo.FindByID`;`phRepo.FindBySecurity`

- [ ] **Step 1: 写 TestSyncPrices_PersistsPriceHistoryAndCurrentPrice**

追加:
```go
// TestSyncPrices_PersistsPriceHistoryAndCurrentPrice drives service.SyncPrices
// with a fake priceProvider that returns 15000 cents for "600519", then verifies
// both the security's CurrentPriceCents is updated AND a price_history row is
// persisted for today (the double-write SyncPrices does).
func TestSyncPrices_PersistsPriceHistoryAndCurrentPrice(t *testing.T) {
	svc, client, secRepo, _, _, phRepo, _, _ := setupPriceSnapshotHarness(t)
	ctx := context.Background()

	// seed security (CreateSecurityRequest has no price field; CurrentPrice defaults to 0).
	created, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai", SecurityType: domain.SecurityTypeStock,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := created.ID

	// fake price provider returns 15000 cents for 600519.
	svc.SetPriceRouter(&fakePriceRouter{prices: map[string]int64{"600519": 15000}})

	// SyncPrices must pick up the fake price and persist.
	count, err := svc.SyncPrices(ctx)
	if err != nil {
		t.Fatalf("SyncPrices: %v", err)
	}
	if count < 1 {
		t.Errorf("SyncPrices synced_count=%d, want >= 1", count)
	}

	// Verify security.CurrentPriceCents updated to 15000.
	gotSec, err := secRepo.FindByID(ctx, secID)
	if err != nil || gotSec == nil {
		t.Fatalf("secRepo.FindByID: %v", err)
	}
	if gotSec.CurrentPriceCents != 15000 {
		t.Errorf("security.CurrentPriceCents: got %d, want 15000 (SyncPrices update)", gotSec.CurrentPriceCents)
	}

	// Verify price_history persisted (today's price = 15000).
	// SetNow injected 2021-01-01; SyncPrices writes today = truncateToDate(s.now()).
	ph, err := phRepo.FindBySecurity(ctx, secID, time.Time{}, time.Now())
	if err != nil {
		t.Fatalf("phRepo.FindBySecurity: %v", err)
	}
	found := false
	for _, p := range ph {
		if p.PriceCents == 15000 {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("price_history missing 15000 entry; got %d rows", len(ph))
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestSyncPrices_PersistsPriceHistoryAndCurrentPrice -v -count=1`
Expected: PASS。若 CreateSecurity 签名(CurrentPriceCents 字段?)/ SyncPrices 签名 / phRepo.FindBySecurity 签名 不符 → 照 service.go 实际调整(CreateSecurity 不含 CurrentPriceCents → seed 后 CurrentPrice=0;SyncPrices 返 (count, err);FindBySecurity(securityID, from, to))。

- [ ] **Step 3: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_price_snapshot_integration_test.go
git commit -m "test(holding): B-price SyncPrices e2e (price_history + CurrentPrice persist)" -m "TestSyncPrices_PersistsPriceHistoryAndCurrentPrice: fakePriceRouter 返 15000 -> svc.SyncPrices -> 验 security.CurrentPriceCents=15000 + price_history 含 15000. B-price sync 跨层 integration."
```

---

## Task 3: TestSnapshotNow_PersistsHoldingSnapshot(C-snapshot)

**Files:**
- Modify: `holding_price_snapshot_integration_test.go`

**Interfaces:**
- Consumes:Task 1 harness + `fakeTenantLister`;`svc.SnapshotAllHoldings`(cross-tenant);`snapRepo.FindSnapshots`;`secRepo.UpdateSecurityPrice`

- [ ] **Step 1: 写 TestSnapshotNow_PersistsHoldingSnapshot**

追加:
```go
// TestSnapshotNow_PersistsHoldingSnapshot drives SnapshotAllHoldings
// (cross-tenant fan-out via fakeTenantLister) and verifies a holding_snapshot
// row is persisted with market value = qty × security.CurrentPriceCents.
//
// MV source: sec.CurrentPriceCents (NOT priceHistoryRepo — confirmed in service.go:532).
// SnapshotAllHoldings requires SetTenantLister (nil → error). prod FindAll(uuid.Nil)
// returns empty, so test seeds a real holding with the tenant ID the fake lister returns.
func TestSnapshotNow_PersistsHoldingSnapshot(t *testing.T) {
	svc, client, secRepo, holdRepo, snapRepo, _, tenantID, accountID := setupPriceSnapshotHarness(t)
	ctx := context.Background()

	// Override the harness's empty fakeTenantLister with one returning our tenantID.
	svc.SetTenantLister(&fakeTenantLister{ids: []uuid.UUID{tenantID}})

	// seed security with CurrentPriceCents=13000 (MV source).
	sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai", SecurityType: domain.SecurityTypeStock,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	if err := svc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}

	// seed holding: 100 qty under (tenantID, accountID).
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: sec.ID,
		Quantity: 100, AvgCostCents: 10000,
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}

	// SnapshotAllHoldings (cross-tenant fan-out: fakeTenantLister → tenantID → SnapshotHoldings).
	count, err := svc.SnapshotAllHoldings(ctx)
	if err != nil {
		t.Fatalf("SnapshotAllHoldings: %v", err)
	}
	if count < 1 {
		t.Errorf("snapshot count=%d, want >= 1", count)
	}

	// Verify holding_snapshot persisted with MV = 100 × 13000 = 1,300,000.
	snaps, err := snapRepo.FindSnapshots(ctx, tenantID, time.Time{}, time.Now(), &accountID, nil)
	if err != nil {
		t.Fatalf("snapRepo.FindSnapshots: %v", err)
	}
	found := false
	for _, sn := range snaps {
		if sn.HoldingID == holdingID && sn.MarketValueCents == 1300000 {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("holding_snapshot missing MV=1300000 for holding %s; got %d rows", holdingID, len(snaps))
	}
}
```

- [ ] **Step 2: 跑 test,调通至 PASS**

Run: `cd yucai/server && go test ./tests/ -run TestSnapshotNow_PersistsHoldingSnapshot -v -count=1`
Expected: PASS。若 SnapshotAllHoldings err("tenant lister not configured")→ 确认 SetTenantLister 在 SnapshotAllHoldings 调用前(setup 后 re-set);若 MV 偏 → 确认 sec.CurrentPriceCents=13000(UpdateSecurityPrice)。

- [ ] **Step 3: 全量回归**

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(performance 套件 S1-S4 + sell 双写 + buy doublewrite + 新 B/C test + 零回归)。

Run: `cd yucai/server && go build ./...`
Expected: 绿。

- [ ] **Step 4: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/holding_price_snapshot_integration_test.go
git commit -m "test(holding): C-snapshot SnapshotAllHoldings e2e (cross-tenant MV persist)" -m "TestSnapshotNow_PersistsHoldingSnapshot: seed tenant/holding(100qty)/security(CurrentPrice=13000)+ fakeTenantLister{tenantID} -> svc.SnapshotAllHoldings(cross-tenant fan-out) -> 验 holding_snapshot MV=100x13000=1300000. MV 来源 sec.CurrentPriceCents(非 priceHistoryRepo). 套件系列第 3 spec Task 3."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run "TestSyncPrices|TestSnapshotNow" -v -count=1` — B + C PASS
- [ ] `cd yucai/server && go test ./tests/ -run "TestS[1-4]|TestHoldingSell|TestHoldingBuy" -v -count=1` — 既有套件不破
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
