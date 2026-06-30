package application

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	"github.com/yucai/server/internal/holding/domain"
)

// --- test doubles ---

// fakePriceRouter is a test double for priceprovider.Router.
type fakePriceRouter struct {
	// prices maps symbol → price in cents to return.
	prices map[string]int64
	// errOn maps symbol → error to return (real error, not ErrNoSource).
	errOn map[string]error
	// noSource is a set of symbols that return ErrNoSource.
	noSource map[string]bool
}

func (r *fakePriceRouter) FetchPrice(_ context.Context, v priceprovider.PriceView) (int64, string, error) {
	if r.errOn != nil {
		if e, ok := r.errOn[v.Symbol]; ok {
			return 0, "", e
		}
	}
	if r.noSource[v.Symbol] {
		return 0, "", priceprovider.ErrNoSource
	}
	if p, ok := r.prices[v.Symbol]; ok {
		return p, "fake", nil
	}
	return 0, "", priceprovider.ErrNoSource
}

// seedSec describes a security to seed into the fake repo for a test.
type seedSec struct {
	Symbol          string
	Exchange        string
	StartPriceCents int64
	Type            domain.SecurityType
}

// fakeSecurityRepo is an in-memory SecurityRepository for SyncPrices tests.
// FindAll / UpdatePrice drive the SyncPrices path; other methods panic since
// they are not exercised here.
type fakeSecurityRepo struct {
	prices map[string]int64 // symbol → price cents
	ids    map[string]uuid.UUID
	order  []string // stable iteration order
}

func newFakeSecurityRepo(seeds []seedSec) *fakeSecurityRepo {
	r := &fakeSecurityRepo{prices: map[string]int64{}, ids: map[string]uuid.UUID{}}
	for _, s := range seeds {
		r.prices[s.Symbol] = s.StartPriceCents
		r.ids[s.Symbol] = uuid.New()
		r.order = append(r.order, s.Symbol)
	}
	return r
}

func (r *fakeSecurityRepo) priceFor(symbol string) int64 { return r.prices[symbol] }

func (r *fakeSecurityRepo) Save(context.Context, *domain.Security) error {
	panic("not used in SyncPrices test")
}
func (r *fakeSecurityRepo) FindByID(context.Context, uuid.UUID) (*domain.Security, error) {
	panic("not used in SyncPrices test")
}
func (r *fakeSecurityRepo) FindBySymbol(context.Context, string, string) (*domain.Security, error) {
	panic("not used in SyncPrices test")
}
func (r *fakeSecurityRepo) Search(context.Context, string, int) ([]domain.Security, error) {
	panic("not used in SyncPrices test")
}

// FindAll returns the seeded securities as a single page. securityType filtering
// is not needed for SyncPrices tests (the service always passes nil).
func (r *fakeSecurityRepo) FindAll(_ context.Context, _ *domain.SecurityType, _ domain.PageRequest) (*domain.PaginatedResult[domain.Security], error) {
	items := make([]domain.Security, 0, len(r.order))
	for _, sym := range r.order {
		secType := domain.SecurityTypeStock
		items = append(items, domain.Security{
			ID:                r.ids[sym],
			Symbol:            sym,
			Name:              sym,
			SecurityType:      secType,
			Exchange:          "SSE",
			CurrentPriceCents: r.prices[sym],
		})
	}
	return &domain.PaginatedResult[domain.Security]{
		Items:         items,
		NextPageToken: "",
		TotalCount:    int32(len(items)),
	}, nil
}

func (r *fakeSecurityRepo) UpdatePrice(_ context.Context, id uuid.UUID, priceCents int64) error {
	for sym, sid := range r.ids {
		if sid == id {
			r.prices[sym] = priceCents
			return nil
		}
	}
	return errors.New("security not found")
}

// nilHoldingRepo / nilTradeRepo are minimal fakes implementing the holding/trade
// repository interfaces; SyncPrices never touches them so all methods panic.
type nilHoldingRepo struct{}

func (nilHoldingRepo) SaveOrUpdate(context.Context, *domain.Holding) error {
	panic("not used in SyncPrices test")
}
func (nilHoldingRepo) FindByAccountAndSecurity(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) (*domain.Holding, error) {
	panic("not used in SyncPrices test")
}
func (nilHoldingRepo) FindAll(context.Context, uuid.UUID, *uuid.UUID, domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	panic("not used in SyncPrices test")
}

type nilTradeRepo struct{}

func (nilTradeRepo) Save(context.Context, *domain.HoldingTransaction) error {
	panic("not used in SyncPrices test")
}
func (nilTradeRepo) FindAll(context.Context, uuid.UUID, *uuid.UUID, *uuid.UUID, domain.PageRequest) (*domain.PaginatedResult[domain.HoldingTransaction], error) {
	panic("not used in SyncPrices test")
}

func nilHoldingRepoInstance() domain.HoldingRepository { return nilHoldingRepo{} }
func nilTradeRepoInstance() domain.TradeRepository     { return nilTradeRepo{} }

// newTestServiceWithSecurities builds a Service backed by a fake security repo
// seeded with the given securities. Returns the repo (for price assertions) and
// the service.
func newTestServiceWithSecurities(t *testing.T, seeds []seedSec) (*fakeSecurityRepo, *Service) {
	t.Helper()
	repo := newFakeSecurityRepo(seeds)
	svc := NewService(repo, nilHoldingRepoInstance(), nilTradeRepoInstance())
	return repo, svc
}

// --- tests ---

func TestSyncPricesUpdatesCoveredAndSkipsNoSource(t *testing.T) {
	repo, svcs := newTestServiceWithSecurities(t, []seedSec{
		{Symbol: "600519", Exchange: "SSE", StartPriceCents: 100},
		{Symbol: "AAPL", Exchange: "NASDAQ", StartPriceCents: 200},
	})
	svcs.SetPriceRouter(&fakePriceRouter{
		prices:   map[string]int64{"600519": 3480},
		noSource: map[string]bool{"AAPL": true},
	})

	count, err := svcs.SyncPrices(context.Background())
	if err != nil {
		t.Fatalf("SyncPrices error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced count = %d, want 1 (only SSE covered)", count)
	}
	if got := repo.priceFor("600519"); got != 3480 {
		t.Fatalf("600519 price = %d, want 3480", got)
	}
	// AAPL is no-source → price untouched.
	if got := repo.priceFor("AAPL"); got != 200 {
		t.Fatalf("AAPL no-source price should stay 200, got %d", got)
	}
}

func TestSyncPricesContinuesPastRealError(t *testing.T) {
	repo, svcs := newTestServiceWithSecurities(t, []seedSec{
		{Symbol: "600519", Exchange: "SSE", StartPriceCents: 100},
		{Symbol: "510300", Exchange: "SSE", StartPriceCents: 100},
	})
	svcs.SetPriceRouter(&fakePriceRouter{
		prices: map[string]int64{"600519": 3480, "510300": 4250},
		errOn:  map[string]error{"600519": errors.New("upstream 500")},
	})

	count, err := svcs.SyncPrices(context.Background())
	if err != nil {
		t.Fatalf("SyncPrices should not abort on per-security error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced = %d, want 1 (510300 ok, 600519 errored)", count)
	}
	// 600519 errored → price untouched at 100.
	if got := repo.priceFor("600519"); got != 100 {
		t.Fatalf("600519 should stay 100 after error, got %d", got)
	}
	if got := repo.priceFor("510300"); got != 4250 {
		t.Fatalf("510300 should be updated to 4250, got %d", got)
	}
}

func TestSyncPricesWithoutRouterErrors(t *testing.T) {
	// Defensive: if SetPriceRouter was never called, SyncPrices errors clearly
	// (rather than nil-dereferencing). Wire always injects; this guards tests.
	_, svcs := newTestServiceWithSecurities(t, nil)
	if _, err := svcs.SyncPrices(context.Background()); err == nil {
		t.Fatal("SyncPrices without router must error")
	}
}
