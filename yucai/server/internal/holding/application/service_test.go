package application

import (
	"context"
	"errors"
	"testing"
	"time"

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
func (r *fakeSecurityRepo) FindByID(_ context.Context, id uuid.UUID) (*domain.Security, error) {
	for _, sym := range r.order {
		if r.ids[sym] == id {
			secType := domain.SecurityTypeStock
			return &domain.Security{
				ID: r.ids[sym], Symbol: sym, Name: sym,
				SecurityType: secType, Exchange: "SSE",
				CurrencyCode:      "CNY",
				CurrentPriceCents: r.prices[sym],
			}, nil
		}
	}
	return nil, errors.New("security not found")
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
func (nilHoldingRepo) FindByID(context.Context, uuid.UUID) (*domain.Holding, error) {
	panic("not used in SyncPrices test")
}
func (nilHoldingRepo) FindAll(context.Context, uuid.UUID, *uuid.UUID, domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	panic("not used in SyncPrices test")
}
func (nilHoldingRepo) FindAllForBackup(context.Context, uuid.UUID) ([]domain.Holding, []domain.HoldingTransaction, error) {
	panic("not used in SyncPrices test")
}
func (nilHoldingRepo) DeleteByTenant(context.Context, uuid.UUID) error {
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

// --- FIFO lot maintenance tests (Task 5 C) ---

// memHoldingRepo is an in-memory HoldingRepository for Buy/Sell/Split + perf tests.
type memHoldingRepo struct {
	byKey map[string]*domain.Holding // key = accountID|securityID
}

func newMemHoldingRepo() *memHoldingRepo {
	return &memHoldingRepo{byKey: map[string]*domain.Holding{}}
}

func (r *memHoldingRepo) key(accountID, securityID uuid.UUID) string {
	return accountID.String() + "|" + securityID.String()
}

func (r *memHoldingRepo) SaveOrUpdate(_ context.Context, h *domain.Holding) error {
	cp := *h
	r.byKey[r.key(h.AccountID, h.SecurityID)] = &cp
	return nil
}

func (r *memHoldingRepo) FindByAccountAndSecurity(_ context.Context, _, accountID, securityID uuid.UUID) (*domain.Holding, error) {
	if h, ok := r.byKey[r.key(accountID, securityID)]; ok {
		cp := *h
		return &cp, nil
	}
	return nil, errors.New("not found")
}

// FindByID returns the holding with the given primary key.
func (r *memHoldingRepo) FindByID(_ context.Context, holdingID uuid.UUID) (*domain.Holding, error) {
	for _, h := range r.byKey {
		if h.ID == holdingID {
			cp := *h
			return &cp, nil
		}
	}
	return nil, errors.New("not found")
}

// FindAll returns all holdings (optionally filtered by tenantID/accountID).
// tenantID=uuid.Nil means all tenants (scheduler/perf-friendly).
func (r *memHoldingRepo) FindAll(_ context.Context, tenantID uuid.UUID, accountID *uuid.UUID, _ domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	items := make([]domain.Holding, 0, len(r.byKey))
	for _, h := range r.byKey {
		if tenantID != uuid.Nil && h.TenantID != tenantID {
			continue
		}
		if accountID != nil && h.AccountID != *accountID {
			continue
		}
		items = append(items, *h)
	}
	return &domain.PaginatedResult[domain.Holding]{Items: items, TotalCount: int32(len(items))}, nil
}

// FindAllForBackup / DeleteByTenant are backup-only; not exercised by holding
// application tests, so they panic to surface accidental coupling.
func (r *memHoldingRepo) FindAllForBackup(_ context.Context, _ uuid.UUID) ([]domain.Holding, []domain.HoldingTransaction, error) {
	panic("not used in holding application tests")
}
func (r *memHoldingRepo) DeleteByTenant(_ context.Context, _ uuid.UUID) error {
	panic("not used in holding application tests")
}

// memTradeRepo is an in-memory TradeRepository that records saved trades.
type memTradeRepo struct {
	saved []*domain.HoldingTransaction
}

func (r *memTradeRepo) Save(_ context.Context, tr *domain.HoldingTransaction) error {
	cp := *tr
	r.saved = append(r.saved, &cp)
	return nil
}

// FindAll returns saved trades. Filters by tenantID (Nil=all), accountID and
// securityID (both optional).
func (r *memTradeRepo) FindAll(_ context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, _ domain.PageRequest) (*domain.PaginatedResult[domain.HoldingTransaction], error) {
	items := make([]domain.HoldingTransaction, 0, len(r.saved))
	for _, tr := range r.saved {
		if tenantID != uuid.Nil && tr.TenantID != tenantID {
			continue
		}
		if accountID != nil && tr.AccountID != *accountID {
			continue
		}
		if securityID != nil && tr.SecurityID != *securityID {
			continue
		}
		items = append(items, *tr)
	}
	return &domain.PaginatedResult[domain.HoldingTransaction]{Items: items, TotalCount: int32(len(items))}, nil
}

// memLotRepo is an in-memory LotRepository keyed by holdingID.
type memLotRepo struct {
	byHolding map[uuid.UUID][]domain.HoldingLot
}

func newMemLotRepo() *memLotRepo {
	return &memLotRepo{byHolding: map[uuid.UUID][]domain.HoldingLot{}}
}

// seedLot adds a lot to a holding (for test setup, before calling the service).
func (r *memLotRepo) seedLot(l domain.HoldingLot) {
	r.byHolding[l.HoldingID] = append(r.byHolding[l.HoldingID], l)
}

func (r *memLotRepo) FindByHolding(_ context.Context, holdingID uuid.UUID) ([]domain.HoldingLot, error) {
	out := make([]domain.HoldingLot, len(r.byHolding[holdingID]))
	copy(out, r.byHolding[holdingID])
	return out, nil
}

func (r *memLotRepo) SaveAll(_ context.Context, lots []domain.HoldingLot) error {
	// Replace any lots with matching ID; otherwise append.
	for _, l := range lots {
		existing := r.byHolding[l.HoldingID]
		found := false
		for i := range existing {
			if existing[i].ID == l.ID {
				existing[i] = l
				found = true
				break
			}
		}
		if !found {
			r.byHolding[l.HoldingID] = append(r.byHolding[l.HoldingID], l)
		}
	}
	return nil
}

// newLotService builds a Service with working holding/trade/lot repos for
// FIFO tests.
func newLotService() (*memHoldingRepo, *memTradeRepo, *memLotRepo, *Service) {
	hr, tr, lr := newMemHoldingRepo(), &memTradeRepo{}, newMemLotRepo()
	svc := NewService(nil, hr, tr) // securityRepo unused in lot tests
	svc.SetLotRepository(lr)
	return hr, tr, lr, svc
}

func TestBuyHoldingCreatesLotAndDerivesAvgCost(t *testing.T) {
	// seed: existing holding with 60@100cents (one lot). Buy 40@120cents.
	// expect: new lot created (40@120); avg cost = (60*100 + 40*120)/100 = 108 cents.
	hr, _, lr, svc := newLotService()
	tenantID, accountID, securityID := uuid.New(), uuid.New(), uuid.New()

	existingHolding := &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 60, AvgCostCents: 100,
	}
	hr.SaveOrUpdate(context.Background(), existingHolding)
	lr.seedLot(domain.HoldingLot{
		ID: uuid.New(), TenantID: tenantID, HoldingID: existingHolding.ID, SecurityID: securityID,
		AcquiredDate: time.Now().AddDate(0, 0, -10), PriceCents: 100,
		Quantity: 60, RemainingQuantity: 60,
	})

	dto, err := svc.BuyHolding(context.Background(), HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 40, PriceCents: 120, TradeDate: time.Now(),
	})
	if err != nil {
		t.Fatalf("BuyHolding error: %v", err)
	}
	if dto.TradeType != domain.TradeTypeBuy {
		t.Fatalf("trade type = %s, want buy", dto.TradeType)
	}

	// Holding avg cost should be the FIFO-weighted 108 cents.
	h, _ := hr.FindByAccountAndSecurity(context.Background(), tenantID, accountID, securityID)
	if h.AvgCostCents != 108 {
		t.Fatalf("avg cost = %d, want 108", h.AvgCostCents)
	}
	if h.Quantity != 100 {
		t.Fatalf("quantity = %v, want 100", h.Quantity)
	}

	// A new lot (40@120) was persisted.
	lots, _ := lr.FindByHolding(context.Background(), h.ID)
	var newLot *domain.HoldingLot
	for i := range lots {
		if lots[i].Quantity == 40 && lots[i].PriceCents == 120 {
			newLot = &lots[i]
			break
		}
	}
	if newLot == nil {
		t.Fatalf("new buy lot (40@120) not persisted; lots = %+v", lots)
	}
	if newLot.RemainingQuantity != 40 {
		t.Fatalf("new lot remaining = %v, want 40", newLot.RemainingQuantity)
	}
}

func TestSellHoldingFIFORealizedLandedOnTrade(t *testing.T) {
	// seed lots: 60@100cents (older), 40@110cents (newer). Sell 80@130cents.
	// expect: realized = (130-100)*60 + (130-110)*20 = 1800 + 400 = 2200;
	//         lot1 remaining=0, lot2 remaining=20; avg cost = 110 (only lot2).
	hr, tr, lr, svc := newLotService()
	tenantID, accountID, securityID := uuid.New(), uuid.New(), uuid.New()

	existingHolding := &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 100, AvgCostCents: 104, // (60*100+40*110)/100 = 104
	}
	hr.SaveOrUpdate(context.Background(), existingHolding)
	lot1ID := uuid.New()
	lot2ID := uuid.New()
	lr.seedLot(domain.HoldingLot{
		ID: lot1ID, TenantID: tenantID, HoldingID: existingHolding.ID, SecurityID: securityID,
		AcquiredDate: time.Now().AddDate(0, 0, -10), PriceCents: 100,
		Quantity: 60, RemainingQuantity: 60,
	})
	lr.seedLot(domain.HoldingLot{
		ID: lot2ID, TenantID: tenantID, HoldingID: existingHolding.ID, SecurityID: securityID,
		AcquiredDate: time.Now().AddDate(0, 0, -5), PriceCents: 110,
		Quantity: 40, RemainingQuantity: 40,
	})

	dto, err := svc.SellHolding(context.Background(), HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 80, PriceCents: 130, TradeDate: time.Now(),
	})
	if err != nil {
		t.Fatalf("SellHolding error: %v", err)
	}

	// Realized landed on the trade DTO.
	if dto.RealizedPnLCents != 2200 {
		t.Fatalf("realized = %d, want 2200", dto.RealizedPnLCents)
	}
	// And on the persisted trade.
	if len(tr.saved) != 1 || tr.saved[0].RealizedPnLCents != 2200 {
		t.Fatalf("persisted trade realized = %v, want 2200", tr.saved)
	}

	// Lots consumed FIFO: lot1 fully (0 remaining), lot2 = 20 remaining.
	lots, _ := lr.FindByHolding(context.Background(), existingHolding.ID)
	var lot1, lot2 *domain.HoldingLot
	for i := range lots {
		switch lots[i].ID {
		case lot1ID:
			lot1 = &lots[i]
		case lot2ID:
			lot2 = &lots[i]
		}
	}
	if lot1 == nil || lot1.RemainingQuantity != 0 {
		t.Fatalf("lot1 remaining = %v, want 0 (fully consumed FIFO)", valOr(lot1))
	}
	if lot2 == nil || lot2.RemainingQuantity != 20 {
		t.Fatalf("lot2 remaining = %v, want 20", valOr(lot2))
	}

	// Holding avg cost now reflects only lot2 (110); quantity 20.
	h, _ := hr.FindByAccountAndSecurity(context.Background(), tenantID, accountID, securityID)
	if h.AvgCostCents != 110 {
		t.Fatalf("post-sell avg cost = %d, want 110 (only lot2 left)", h.AvgCostCents)
	}
	if h.Quantity != 20 {
		t.Fatalf("post-sell quantity = %v, want 20", h.Quantity)
	}
}

func valOr(l *domain.HoldingLot) float64 {
	if l == nil {
		return -1
	}
	return l.RemainingQuantity
}

func TestRecordSplitAdjustsLots(t *testing.T) {
	// seed lot 100@100cents. Split ratio 2.
	// expect: lot quantity=200, remaining=200, price=50 (100/2);
	//         holding quantity=200, avg cost=50.
	hr, _, lr, svc := newLotService()
	tenantID, accountID, securityID := uuid.New(), uuid.New(), uuid.New()

	existingHolding := &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 100, AvgCostCents: 100,
	}
	hr.SaveOrUpdate(context.Background(), existingHolding)
	lotID := uuid.New()
	lr.seedLot(domain.HoldingLot{
		ID: lotID, TenantID: tenantID, HoldingID: existingHolding.ID, SecurityID: securityID,
		AcquiredDate: time.Now().AddDate(0, 0, -10), PriceCents: 100,
		Quantity: 100, RemainingQuantity: 100,
	})

	if _, err := svc.RecordSplit(context.Background(), RecordSplitRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Ratio: 2, SplitDate: time.Now(),
	}); err != nil {
		t.Fatalf("RecordSplit error: %v", err)
	}

	lots, _ := lr.FindByHolding(context.Background(), existingHolding.ID)
	if len(lots) != 1 {
		t.Fatalf("expected 1 lot, got %d", len(lots))
	}
	lot := lots[0]
	if lot.Quantity != 200 || lot.RemainingQuantity != 200 {
		t.Fatalf("lot qty=%v remaining=%v, want 200/200", lot.Quantity, lot.RemainingQuantity)
	}
	if lot.PriceCents != 50 {
		t.Fatalf("lot price = %d, want 50 (100/2 split-adjusted)", lot.PriceCents)
	}

	// Holding reflects ApplySplit (qty ×ratio, avg cost /ratio).
	h, _ := hr.FindByAccountAndSecurity(context.Background(), tenantID, accountID, securityID)
	if h.Quantity != 200 {
		t.Fatalf("holding quantity = %v, want 200", h.Quantity)
	}
	if h.AvgCostCents != 50 {
		t.Fatalf("holding avg cost = %d, want 50", h.AvgCostCents)
	}
}

// --- D-currency Task 2: aggregateRealized multi-currency折算 ---

// TestAggregateRealizedConvertsToBase verifies realized P&L and dividend income
// are折算 to the base currency (CNY) via rate history. seed: a USD sell trade
// realized=2000 USD-cents and a CNY dividend=500; rate[USD]=7.0, rate[CNY]=1.0;
// expected base = 2000×7/1 + 500×1/1 = 14500 CNY.
func TestAggregateRealizedConvertsToBase(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	secUSID, secCID := uuid.New(), uuid.New()

	secRepo := newFullSecRepo([]secSeed{
		{ID: secUSID, Symbol: "AAPL", Exchange: "NASDAQ", Type: domain.SecurityTypeStock, Currency: "USD", CurrentPriceCents: 20000},
		{ID: secCID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
	})
	rateRepo := &fakeRateRepo{rateByCode: map[string]float64{"USD": 7.0, "CNY": 1.0}}
	tr := &memTradeRepo{}
	// g1: USD sell, realized=2000 (USD-cents). 折算 → 2000×7/1 = 14000.
	tr.saved = append(tr.saved, &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: secUSID,
		TradeType: domain.TradeTypeSell, RealizedPnLCents: 2000, TradeDate: time.Now(),
	})
	// g2: CNY dividend, amount=500. 折算 → 500×1/1 = 500.
	tr.saved = append(tr.saved, &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: secCID,
		TradeType: domain.TradeTypeDividend, AmountCents: 500, TradeDate: time.Now(),
	})

	svc := NewService(secRepo, newMemHoldingRepo(), tr)
	svc.SetRateHistoryRepository(rateRepo)

	got, err := svc.aggregateRealized(context.Background(), tenantID, &accountID, "CNY")
	if err != nil {
		t.Fatalf("aggregateRealized error: %v", err)
	}
	if got != 14500 {
		t.Fatalf("aggregateRealized(CNY base) = %d, want 14500 (14000 USD折算 + 500 CNY)", got)
	}
}

// TestAggregateRealizedDefaultBaseCNY verifies baseCurrency="" falls back to CNY
// (rate[CNY]=1.0 → no conversion). A single CNY sell realized=1000 stays 1000.
func TestAggregateRealizedDefaultBaseCNY(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	secID := uuid.New()

	secRepo := newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
	})
	rateRepo := &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}}
	tr := &memTradeRepo{}
	tr.saved = append(tr.saved, &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		TradeType: domain.TradeTypeSell, RealizedPnLCents: 1000, TradeDate: time.Now(),
	})

	svc := NewService(secRepo, newMemHoldingRepo(), tr)
	svc.SetRateHistoryRepository(rateRepo)

	// baseCurrency="" → default CNY.
	got, err := svc.aggregateRealized(context.Background(), tenantID, &accountID, "")
	if err != nil {
		t.Fatalf("aggregateRealized('') error: %v", err)
	}
	if got != 1000 {
		t.Fatalf("aggregateRealized('') = %d, want 1000 (default CNY, no conversion)", got)
	}
}

// --- D-currency Task 3: GetPortfolioPerformance baseCurrency switch ---

// TestGetPortfolioPerformanceBaseCurrency verifies the portfolio performance
// foot is 折算 to the configured baseCurrency via the CNY-base cross rate
// (ConvertToBase). seed: a CNY holding (mv=10000/day, cost 10000, unrealized
// 6800) + a USD holding (mv=5000/day, cost 19500, unrealized 0); rates
// USD=7.0, CNY=1.0. Tests three base configurations:
//
//   - base=CNY:  portfolio point=450.00, realized=5500, unrealized=6800,
//     costBasis=146500, Currency="CNY".
//   - base=USD:  CNY holding cross-rate 折算 (÷7) + USD holding raw;
//     portfolio point≈64.29, realized=786, unrealized=971, costBasis=20929,
//     Currency="USD".
//   - base="":   defaults to CNY, Currency="CNY".
//
// This exercises the full base-switching path (samplePortfolioInBase,
// currentUnrealizedInBase, currentCostBasisInBase, aggregateRealized) and the
// Currency=base assertion (non-hardcoded CNY).
func TestGetPortfolioPerformanceBaseCurrency(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	cnySecID, usdSecID, cnyHoldingID, usdHoldingID := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: cnySecID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 168},
		{ID: usdSecID, Symbol: "AAPL", Exchange: "NASDAQ", Type: domain.SecurityTypeStock, Currency: "USD", CurrentPriceCents: 19500},
	})
	day1 := truncateToDate(time.Now().AddDate(0, 0, -1))
	day2 := truncateToDate(time.Now())
	snapRepo := &memSnapshotRepo{
		saved: []domain.HoldingSnapshot{
			{TenantID: tenantID, HoldingID: cnyHoldingID, SecurityID: cnySecID, AccountID: accountID,
				SnapshotDate: day1, MarketValueCents: 10000, CurrencyCode: "CNY"},
			{TenantID: tenantID, HoldingID: cnyHoldingID, SecurityID: cnySecID, AccountID: accountID,
				SnapshotDate: day2, MarketValueCents: 10000, CurrencyCode: "CNY"},
			{TenantID: tenantID, HoldingID: usdHoldingID, SecurityID: usdSecID, AccountID: accountID,
				SnapshotDate: day1, MarketValueCents: 5000, CurrencyCode: "USD"},
			{TenantID: tenantID, HoldingID: usdHoldingID, SecurityID: usdSecID, AccountID: accountID,
				SnapshotDate: day2, MarketValueCents: 5000, CurrencyCode: "USD"},
		},
	}
	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: cnyHoldingID, TenantID: tenantID, AccountID: accountID, SecurityID: cnySecID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -1),
	})
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: usdHoldingID, TenantID: tenantID, AccountID: accountID, SecurityID: usdSecID,
		Quantity: 1, AvgCostCents: 19500, CreatedAt: time.Now().AddDate(0, 0, -1),
	})
	tr := &memTradeRepo{
		saved: []*domain.HoldingTransaction{
			{TenantID: tenantID, AccountID: accountID, SecurityID: cnySecID,
				TradeType: domain.TradeTypeSell, RealizedPnLCents: 2000, TradeDate: time.Now()},
			{TenantID: tenantID, AccountID: accountID, SecurityID: usdSecID,
				TradeType: domain.TradeTypeDividend, AmountCents: 500, TradeDate: time.Now()},
		},
	}
	rateRepo := &fakeRateRepo{rateByCode: map[string]float64{"USD": 7.0, "CNY": 1.0}}

	newSvc := func() *Service {
		svc := NewService(secRepo, hr, tr)
		svc.SetSnapshotRepository(snapRepo)
		svc.SetRateHistoryRepository(rateRepo)
		return svc
	}

	// --- base = CNY (direct: CNY raw, USD ×7) ---
	perfCNY, err := newSvc().GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", false, "CNY")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance(CNY) error: %v", err)
	}
	if perfCNY.Currency != "CNY" {
		t.Fatalf("base=CNY: Currency = %s, want CNY", perfCNY.Currency)
	}
	for i, p := range perfCNY.PortfolioPoints {
		if p.Value != 450.00 {
			t.Fatalf("base=CNY: portfolio point[%d] = %.2f, want 450.00", i, p.Value)
		}
	}
	if perfCNY.RealizedCents != 5500 {
		t.Fatalf("base=CNY: realized = %d, want 5500", perfCNY.RealizedCents)
	}
	if perfCNY.UnrealizedCents != 6800 {
		t.Fatalf("base=CNY: unrealized = %d, want 6800", perfCNY.UnrealizedCents)
	}
	if perfCNY.TotalCents != 12300 {
		t.Fatalf("base=CNY: total = %d, want 12300", perfCNY.TotalCents)
	}

	// --- base = USD (cross-rate via CNY base: CNY ÷7, USD raw) ---
	// CNY holding mv 10000 → ConvertToBase(10000, 1.0, 7.0) = 1429.
	// USD holding mv 5000 → ConvertToBase(5000, 7.0, 7.0) = 5000. point = 6429/100 = 64.29.
	perfUSD, err := newSvc().GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", false, "USD")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance(USD) error: %v", err)
	}
	if perfUSD.Currency != "USD" {
		t.Fatalf("base=USD: Currency = %s, want USD", perfUSD.Currency)
	}
	for i, p := range perfUSD.PortfolioPoints {
		if p.Value != 64.29 {
			t.Fatalf("base=USD: portfolio point[%d] = %.2f, want 64.29", i, p.Value)
		}
	}
	// realized: CNY sell 2000 → ConvertToBase(2000,1.0,7.0) = 286; USD div 500 →
	// ConvertToBase(500,7.0,7.0) = 500. total = 786.
	if perfUSD.RealizedCents != 786 {
		t.Fatalf("base=USD: realized = %d, want 786 (286 CNY折算 + 500 USD raw)", perfUSD.RealizedCents)
	}
	// unrealized: CNY 6800 → ConvertToBase(6800,1.0,7.0) = 971; USD 0 → 0.
	if perfUSD.UnrealizedCents != 971 {
		t.Fatalf("base=USD: unrealized = %d, want 971", perfUSD.UnrealizedCents)
	}
	// costBasis: CNY 10000 → 1429; USD 19500 → 19500. total = 20929.
	// totalPct = (786+971)/20929 × 100 ≈ 8.39.
	if perfUSD.TotalCents != 1757 {
		t.Fatalf("base=USD: total = %d, want 1757 (786 + 971)", perfUSD.TotalCents)
	}
	if perfUSD.TotalPct < 8.0 || perfUSD.TotalPct > 9.0 {
		t.Fatalf("base=USD: totalPct = %.4f, want ~8.39", perfUSD.TotalPct)
	}

	// --- base = "" → default CNY ---
	perfDef, err := newSvc().GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", false, "")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance('') error: %v", err)
	}
	if perfDef.Currency != "CNY" {
		t.Fatalf("base='': Currency = %s, want CNY (default)", perfDef.Currency)
	}
	if perfDef.RealizedCents != perfCNY.RealizedCents {
		t.Fatalf("base='': realized = %d, want %d (same as CNY base)", perfDef.RealizedCents, perfCNY.RealizedCents)
	}
}
