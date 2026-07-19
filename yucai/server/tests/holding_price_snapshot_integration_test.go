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

	evalTime, _ := time.Parse("2006-01-02", psEvalDate)
	svc.SetNow(func() time.Time { return evalTime.UTC() })

	tenantID, accountID = uuid.New(), uuid.New()
	return svc, client, secRepo, holdRepo, snapRepo, phRepo, tenantID, accountID
}
