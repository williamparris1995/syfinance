package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
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

	evalTime, err := time.Parse("2006-01-02", psEvalDate)
	if err != nil {
		t.Fatalf("parse eval date: %v", err)
	}
	svc.SetNow(func() time.Time { return evalTime.UTC() })

	tenantID, accountID = uuid.New(), uuid.New()
	return svc, client, secRepo, holdRepo, snapRepo, phRepo, tenantID, accountID
}

// TestSyncPrices_PersistsPriceHistoryAndCurrentPrice drives service.SyncPrices
// with a fake priceProvider that returns 15000 cents for "600519", then verifies
// both the security's CurrentPriceCents is updated AND a price_history row is
// persisted for today (the double-write SyncPrices does).
func TestSyncPrices_PersistsPriceHistoryAndCurrentPrice(t *testing.T) {
	svc, _, secRepo, _, _, phRepo, _, _ := setupPriceSnapshotHarness(t)
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
			if p.Source != "fake" {
				t.Errorf("price_history Source: got %q, want \"fake\" (FetchPrice source, not hardcoded \"sina\")", p.Source)
			}
			break
		}
	}
	if !found {
		t.Errorf("price_history missing 15000 entry; got %d rows", len(ph))
	}
}

// TestSnapshotNow_PersistsHoldingSnapshot drives SnapshotAllHoldings
// (cross-tenant fan-out via fakeTenantLister) and verifies a holding_snapshot
// row is persisted with market value = qty × security.CurrentPriceCents.
//
// MV source: sec.CurrentPriceCents (NOT priceHistoryRepo — confirmed in service.go:529).
// SnapshotAllHoldings requires SetTenantLister (nil → error). prod FindAll(uuid.Nil)
// returns empty, so test seeds a real holding with the tenant ID the fake lister returns.
func TestSnapshotNow_PersistsHoldingSnapshot(t *testing.T) {
	svc, _, _, holdRepo, snapRepo, _, tenantID, accountID := setupPriceSnapshotHarness(t)
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
