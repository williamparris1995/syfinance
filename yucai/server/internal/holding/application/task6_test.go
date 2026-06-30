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

// --- Task 6 test doubles ---

// secSeed is a security seed with full control over fields (multi-currency
// portfolio tests need non-CNY securities).
type secSeed struct {
	ID                uuid.UUID
	Symbol            string
	Exchange          string
	Type              domain.SecurityType
	Currency          string
	CurrentPriceCents int64
}

// fullSecRepo is an in-memory SecurityRepository used by Task 6 tests (snapshot
// + backfill + perf). Supports FindByID/FindAll/FindBySymbol/Exists-free.
type fullSecRepo struct {
	byID map[uuid.UUID]*domain.Security
}

func newFullSecRepo(seeds []secSeed) *fullSecRepo {
	r := &fullSecRepo{byID: map[uuid.UUID]*domain.Security{}}
	for _, s := range seeds {
		r.byID[s.ID] = &domain.Security{
			ID: s.ID, Symbol: s.Symbol, Name: s.Symbol,
			SecurityType: s.Type, Exchange: s.Exchange,
			CurrencyCode:      s.Currency,
			CurrentPriceCents: s.CurrentPriceCents,
		}
	}
	return r
}

func (r *fullSecRepo) Save(context.Context, *domain.Security) error { panic("not used") }
func (r *fullSecRepo) FindByID(_ context.Context, id uuid.UUID) (*domain.Security, error) {
	if s, ok := r.byID[id]; ok {
		return s, nil
	}
	return nil, errors.New("not found")
}
func (r *fullSecRepo) FindAll(_ context.Context, _ *domain.SecurityType, _ domain.PageRequest) (*domain.PaginatedResult[domain.Security], error) {
	items := make([]domain.Security, 0, len(r.byID))
	for _, s := range r.byID {
		items = append(items, *s)
	}
	return &domain.PaginatedResult[domain.Security]{Items: items, TotalCount: int32(len(items))}, nil
}
func (r *fullSecRepo) FindBySymbol(_ context.Context, symbol, exchange string) (*domain.Security, error) {
	for _, s := range r.byID {
		if s.Symbol == symbol && s.Exchange == exchange {
			return s, nil
		}
	}
	return nil, errors.New("not found")
}
func (r *fullSecRepo) Search(context.Context, string, int) ([]domain.Security, error) {
	panic("not used")
}
func (r *fullSecRepo) UpdatePrice(_ context.Context, id uuid.UUID, priceCents int64) error {
	if s, ok := r.byID[id]; ok {
		s.CurrentPriceCents = priceCents
		return nil
	}
	return errors.New("not found")
}

// memSnapshotRepo records saved snapshots + serves FindSnapshots by date range.
type memSnapshotRepo struct {
	saved []domain.HoldingSnapshot
}

func (r *memSnapshotRepo) Save(_ context.Context, s domain.HoldingSnapshot) error {
	r.saved = append(r.saved, s)
	return nil
}
func (r *memSnapshotRepo) FindSnapshots(_ context.Context, tenantID uuid.UUID, from, to time.Time, _, _ *uuid.UUID) ([]domain.HoldingSnapshot, error) {
	out := []domain.HoldingSnapshot{}
	for _, s := range r.saved {
		if tenantID != uuid.Nil && s.TenantID != tenantID {
			continue
		}
		// inclusive on both ends
		if !s.SnapshotDate.Before(from) && !s.SnapshotDate.After(to) {
			out = append(out, s)
		}
	}
	return out, nil
}

// memPriceHistoryRepo records price rows + tracks Exists by securityID.
// SaveAll/Save upsert on the (securityID, priceDate) key to mirror the real
// repo's UNIQUE constraint (rows for an existing key are updated in place,
// not appended) so application-layer tests reflect the production upsert.
type memPriceHistoryRepo struct {
	rows        []domain.SecurityPriceHistory
	existingIDs map[uuid.UUID]bool // securities pre-marked as "has history"
	saveCalls   int
}

func newMemPriceHistoryRepo(existing map[uuid.UUID]bool) *memPriceHistoryRepo {
	if existing == nil {
		existing = map[uuid.UUID]bool{}
	}
	return &memPriceHistoryRepo{existingIDs: existing}
}

func (r *memPriceHistoryRepo) FindBySecurity(_ context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	out := []domain.SecurityPriceHistory{}
	for _, p := range r.rows {
		if p.SecurityID == securityID && !p.PriceDate.Before(from) && !p.PriceDate.After(to) {
			out = append(out, p)
		}
	}
	return out, nil
}
func (r *memPriceHistoryRepo) SaveAll(_ context.Context, ph []domain.SecurityPriceHistory) error {
	r.saveCalls++
	r.upsertAll(ph)
	return nil
}
func (r *memPriceHistoryRepo) Save(_ context.Context, p domain.SecurityPriceHistory) error {
	r.upsertAll([]domain.SecurityPriceHistory{p})
	return nil
}
// upsertAll inserts new (securityID, priceDate) keys and updates price/source
// for keys already present.
func (r *memPriceHistoryRepo) upsertAll(ph []domain.SecurityPriceHistory) {
	for _, p := range ph {
		r.existingIDs[p.SecurityID] = true
		replaced := false
		for i := range r.rows {
			if r.rows[i].SecurityID == p.SecurityID && r.rows[i].PriceDate.Equal(p.PriceDate) {
				r.rows[i] = p
				replaced = true
				break
			}
		}
		if !replaced {
			r.rows = append(r.rows, p)
		}
	}
}
func (r *memPriceHistoryRepo) Exists(_ context.Context, securityID uuid.UUID) (bool, error) {
	return r.existingIDs[securityID], nil
}

// fakeHistoricalProvider serves FetchHistory from a symbol→points map.
type fakeHistoricalProvider struct {
	points   map[string][]priceprovider.HistoryPoint
	errOn    map[string]error
	noSource map[string]bool
}

func (h *fakeHistoricalProvider) FetchHistory(_ context.Context, v priceprovider.PriceView, _ int) ([]priceprovider.HistoryPoint, error) {
	if h.errOn != nil {
		if e, ok := h.errOn[v.Symbol]; ok {
			return nil, e
		}
	}
	if h.noSource[v.Symbol] {
		return nil, priceprovider.ErrNoSource
	}
	if pts, ok := h.points[v.Symbol]; ok {
		return pts, nil
	}
	return nil, priceprovider.ErrNoSource
}

// fakeRateRepo serves FindRate from a (code,date)-insensitive map keyed by code.
// For test determinism, the same rate is returned regardless of date.
type fakeRateRepo struct {
	rateByCode map[string]float64
}

func (r *fakeRateRepo) FindRate(_ context.Context, code string, _ time.Time) (float64, error) {
	if v, ok := r.rateByCode[code]; ok {
		return v, nil
	}
	return 1.0, nil
}
func (r *fakeRateRepo) FindRange(_ context.Context, code string, _, _ time.Time) (map[time.Time]float64, error) {
	v := r.rateByCode[code]
	return map[time.Time]float64{time.Now(): v}, nil
}

// --- tests ---

// TestSnapshotHoldingsWritesPerHolding verifies SnapshotHoldings writes one
// snapshot per holding, with market_value = qty×price and unrealized =
// mv − qty×avgCost.
func TestSnapshotHoldingsWritesPerHolding(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	secID := uuid.New()
	hr := newMemHoldingRepo()
	// holding: 100 shares @ avgCost 100 cents; current price 120 cents.
	// mv = 120×100 = 12000; unrealized = (120−100)×100 = 2000.
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100,
	})
	secRepo := newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 120},
	})
	snapRepo := &memSnapshotRepo{}
	svc := NewService(secRepo, hr, &memTradeRepo{})
	svc.SetSnapshotRepository(snapRepo)

	count, err := svc.SnapshotHoldings(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("SnapshotHoldings error: %v", err)
	}
	if count != 1 {
		t.Fatalf("count = %d, want 1", count)
	}
	if len(snapRepo.saved) != 1 {
		t.Fatalf("saved snapshots = %d, want 1", len(snapRepo.saved))
	}
	s := snapRepo.saved[0]
	if s.MarketValueCents != 12000 {
		t.Fatalf("market value = %d, want 12000", s.MarketValueCents)
	}
	if s.UnrealizedPnlCents != 2000 {
		t.Fatalf("unrealized = %d, want 2000", s.UnrealizedPnlCents)
	}
	if s.CurrencyCode != "CNY" {
		t.Fatalf("currency = %s, want CNY", s.CurrencyCode)
	}
	// snapshot date truncated to today midnight UTC.
	if s.SnapshotDate != truncateToDate(time.Now()) {
		t.Fatalf("snapshot date = %v, want today", s.SnapshotDate)
	}
}

// TestSnapshotHoldingsSkipsMissingSecurity verifies a holding whose security
// can't be loaded is skipped (logged), not fatal — count reflects only the
// resolvable holding.
func TestSnapshotHoldingsSkipsMissingSecurity(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	goodSecID, badSecID := uuid.New(), uuid.New()
	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: goodSecID,
		Quantity: 10, AvgCostCents: 50,
	})
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: badSecID,
		Quantity: 10, AvgCostCents: 50,
	})
	secRepo := newFullSecRepo([]secSeed{
		{ID: goodSecID, Symbol: "GOOD", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 60},
		// badSecID intentionally absent
	})
	snapRepo := &memSnapshotRepo{}
	svc := NewService(secRepo, hr, &memTradeRepo{})
	svc.SetSnapshotRepository(snapRepo)

	count, err := svc.SnapshotHoldings(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("SnapshotHoldings should not error on missing security: %v", err)
	}
	if count != 1 {
		t.Fatalf("count = %d, want 1 (missing security skipped)", count)
	}
}

// TestBackfillPriceHistoryBackfillsAllCoveredSecurities verifies the Exists
// gate was removed: every Sina-covered security is backfilled on each run, even
// one that already carries a today point written by the B SyncPrices scheduler.
// 510300 is pre-seeded with a today row (Source="sina", PriceCents=99) — backfill
// must NOT skip it; instead it fetches 510300 history and upserts the today row
// to the backfill value. Both 600519 and 510300 are counted (count=2).
func TestBackfillPriceHistoryBackfillsAllCoveredSecurities(t *testing.T) {
	maotaiID, etfID := uuid.New(), uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: maotaiID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 100},
		{ID: etfID, Symbol: "510300", Exchange: "SSE", Type: domain.SecurityTypeETF, Currency: "CNY", CurrentPriceCents: 100},
	})
	d1 := truncateToDate(time.Now().AddDate(0, 0, -2))
	d2 := truncateToDate(time.Now().AddDate(0, 0, -1))
	d3 := truncateToDate(time.Now())
	// 510300 already has a today row (as if B SyncPrices wrote it before backfill).
	phRepo := newMemPriceHistoryRepo(nil)
	phRepo.rows = []domain.SecurityPriceHistory{
		{SecurityID: etfID, PriceDate: d3, PriceCents: 99, Source: "sina"},
	}
	hist := &fakeHistoricalProvider{
		points: map[string][]priceprovider.HistoryPoint{
			"600519": {{Date: d1, PriceCents: 160}, {Date: d2, PriceCents: 165}, {Date: d3, PriceCents: 168}},
			"510300": {{Date: d1, PriceCents: 400}, {Date: d2, PriceCents: 410}, {Date: d3, PriceCents: 420}},
		},
	}
	svc := NewService(secRepo, newMemHoldingRepo(), &memTradeRepo{})
	svc.SetPriceHistoryRepository(phRepo)
	svc.SetHistoricalProvider(hist)

	count, err := svc.BackfillPriceHistory(context.Background(), "DAY")
	if err != nil {
		t.Fatalf("BackfillPriceHistory error: %v", err)
	}
	// Both securities backfilled — 510300 is NOT skipped despite its existing today row.
	if count != 2 {
		t.Fatalf("backfilled count = %d, want 2 (no Exists gate — both covered securities refreshed)", count)
	}
	// 3 rows per security × 2 securities = 6 (510300's pre-existing today row is
	// upserted in place, not appended a second time).
	if len(phRepo.rows) != 6 {
		t.Fatalf("price_history rows = %d, want 6 (600519 ×3 + 510300 ×3, today upserted)", len(phRepo.rows))
	}
	// 510300's today row was upserted to the backfill value (420), source "backfill".
	var etfToday *domain.SecurityPriceHistory
	for i := range phRepo.rows {
		if phRepo.rows[i].SecurityID == etfID && phRepo.rows[i].PriceDate.Equal(d3) {
			etfToday = &phRepo.rows[i]
			break
		}
	}
	if etfToday == nil {
		t.Fatal("510300 today row missing after backfill")
	}
	if etfToday.PriceCents != 420 {
		t.Fatalf("510300 today row price = %d, want 420 (upserted by backfill)", etfToday.PriceCents)
	}
	if etfToday.Source != "backfill" {
		t.Fatalf("510300 today row source = %q, want \"backfill\" (upserted)", etfToday.Source)
	}
	// Both securities marked existing after backfill.
	for _, id := range []uuid.UUID{maotaiID, etfID} {
		exists, _ := phRepo.Exists(context.Background(), id)
		if !exists {
			t.Fatalf("%s should be marked existing after backfill", id)
		}
	}
}

// TestBackfillPriceHistorySkipsNoSource verifies non-covered securities
// (ErrNoSource) are skipped silently, not counted as backfilled.
func TestBackfillPriceHistorySkipsNoSource(t *testing.T) {
	usID := uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: usID, Symbol: "AAPL", Exchange: "NASDAQ", Type: domain.SecurityTypeStock, Currency: "USD", CurrentPriceCents: 19500},
	})
	phRepo := newMemPriceHistoryRepo(nil)
	hist := &fakeHistoricalProvider{noSource: map[string]bool{"AAPL": true}}
	svc := NewService(secRepo, newMemHoldingRepo(), &memTradeRepo{})
	svc.SetPriceHistoryRepository(phRepo)
	svc.SetHistoricalProvider(hist)

	count, err := svc.BackfillPriceHistory(context.Background(), "DAY")
	if err != nil {
		t.Fatalf("BackfillPriceHistory error: %v", err)
	}
	if count != 0 {
		t.Fatalf("count = %d, want 0 (ErrNoSource skipped)", count)
	}
	if len(phRepo.rows) != 0 {
		t.Fatalf("rows = %d, want 0", len(phRepo.rows))
	}
}

// TestGetPortfolioPerformanceSamplesAndConverts verifies the portfolio curve
// sampling + multi-currency折算: CNY holding mv=10000/day, USD holding mv=5000/day
// with USD→CNY=7.0 → each bucket point = (10000 + 5000×7)/100 = 450.00 元.
func TestGetPortfolioPerformanceSamplesAndConverts(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	cnySecID, usdSecID, cnyHoldingID, usdHoldingID := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: cnySecID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 168},
		{ID: usdSecID, Symbol: "AAPL", Exchange: "NASDAQ", Type: domain.SecurityTypeStock, Currency: "USD", CurrentPriceCents: 19500},
	})
	// Two days of snapshots per holding (both within the 30-day DAY window).
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
	// Current holdings: CNY 100@168 (cost 100, unrealized = (168−100)×100 = 6800,
	// cost basis = 100×100 = 10000); USD 1@19500 (cost 19500, unrealized = 0).
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
				TradeType: domain.TradeTypeSell, RealizedPnLCents: 2000},
			{TenantID: tenantID, AccountID: accountID, SecurityID: usdSecID,
				TradeType: domain.TradeTypeDividend, AmountCents: 500},
		},
	}
	svc := NewService(secRepo, hr, tr)
	svc.SetSnapshotRepository(snapRepo)
	svc.SetRateHistoryRepository(&fakeRateRepo{rateByCode: map[string]float64{"USD": 7.0}})

	perf, err := svc.GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", false)
	if err != nil {
		t.Fatalf("GetPortfolioPerformance error: %v", err)
	}
	// Two portfolio points (day1, day2), each = (10000 + 5000×7)/100 = 450.00 元.
	if len(perf.PortfolioPoints) != 2 {
		t.Fatalf("portfolio points = %d, want 2", len(perf.PortfolioPoints))
	}
	for i, p := range perf.PortfolioPoints {
		if p.Value != 450.00 {
			t.Fatalf("point[%d] value = %.2f, want 450.00 (CNY 10000 + USD 5000×7)/100", i, p.Value)
		}
	}
	// Points sorted ascending by date.
	if !perf.PortfolioPoints[0].Time.Before(perf.PortfolioPoints[1].Time) {
		t.Fatal("portfolio points not sorted ascending by time")
	}
	// Realized = sell 2000 + dividend 500 = 2500.
	if perf.RealizedCents != 2500 {
		t.Fatalf("realized = %d, want 2500", perf.RealizedCents)
	}
	// Unrealized = CNY 6800 (×1.0) + USD 0 (×7) = 6800.
	if perf.UnrealizedCents != 6800 {
		t.Fatalf("unrealized = %d, want 6800", perf.UnrealizedCents)
	}
	// Total = realized + unrealized = 9300.
	if perf.TotalCents != 9300 {
		t.Fatalf("total = %d, want 9300", perf.TotalCents)
	}
	if perf.Currency != "CNY" {
		t.Fatalf("currency = %s, want CNY", perf.Currency)
	}
	// totalPct = total/costBasis×100; costBasis = CNY 10000 + USD 19500×7 = 146500.
	// totalPct = 9300/146500×100 ≈ 6.348.
	if perf.TotalPct < 6.3 || perf.TotalPct > 6.4 {
		t.Fatalf("total pct = %.4f, want ~6.35", perf.TotalPct)
	}
}

// TestGetPortfolioPerformanceWithBenchmark verifies the CSI300 benchmark path
// is exercised and returns price-history points when 000300 is seeded.
func TestGetPortfolioPerformanceWithBenchmark(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	csiID := uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: csiID, Symbol: "000300", Exchange: "SSE", Type: domain.SecurityTypeIndex, Currency: "CNY", CurrentPriceCents: 3800},
	})
	hr := newMemHoldingRepo()
	phRepo := newMemPriceHistoryRepo(nil)
	phRepo.rows = []domain.SecurityPriceHistory{
		{SecurityID: csiID, PriceDate: truncateToDate(time.Now().AddDate(0, 0, -1)), PriceCents: 3790},
		{SecurityID: csiID, PriceDate: truncateToDate(time.Now()), PriceCents: 3800},
	}
	svc := NewService(secRepo, hr, &memTradeRepo{})
	svc.SetSnapshotRepository(&memSnapshotRepo{})             // no snapshots → empty portfolio curve
	svc.SetPriceHistoryRepository(phRepo)

	perf, err := svc.GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", true)
	if err != nil {
		t.Fatalf("GetPortfolioPerformance error: %v", err)
	}
	if perf.BenchmarkName != "沪深300" {
		t.Fatalf("benchmark name = %q, want 沪深300", perf.BenchmarkName)
	}
	if len(perf.BenchmarkPoints) != 2 {
		t.Fatalf("benchmark points = %d, want 2", len(perf.BenchmarkPoints))
	}
	// Benchmark value is price_cents/100 → 37.90 / 38.00.
	if perf.BenchmarkPoints[0].Value != 37.90 {
		t.Fatalf("benchmark[0] = %.2f, want 37.90", perf.BenchmarkPoints[0].Value)
	}
	if perf.BenchmarkPoints[1].Value != 38.00 {
		t.Fatalf("benchmark[1] = %.2f, want 38.00", perf.BenchmarkPoints[1].Value)
	}
}

// TestGetHoldingPerformancePriceCurveAndRealized verifies the single-holding
// curve pulls price_history for the holding's security and realized aggregates
// that holding's trades only (a trade for a different security in the same
// account must NOT be counted — securityID scoping).
func TestGetHoldingPerformancePriceCurveAndRealized(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	secID, otherSecID, holdingID := uuid.New(), uuid.New(), uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 168},
		{ID: otherSecID, Symbol: "510300", Exchange: "SSE", Type: domain.SecurityTypeETF, Currency: "CNY", CurrentPriceCents: 425},
	})
	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100,
	})
	phRepo := newMemPriceHistoryRepo(nil)
	phRepo.rows = []domain.SecurityPriceHistory{
		{SecurityID: secID, PriceDate: truncateToDate(time.Now().AddDate(0, 0, -1)), PriceCents: 165},
		{SecurityID: secID, PriceDate: truncateToDate(time.Now()), PriceCents: 168},
	}
	tr := &memTradeRepo{
		saved: []*domain.HoldingTransaction{
			// this holding's realized
			{TenantID: tenantID, AccountID: accountID, SecurityID: secID,
				TradeType: domain.TradeTypeSell, RealizedPnLCents: 3000},
			// a DIFFERENT security in the same account — must be excluded
			{TenantID: tenantID, AccountID: accountID, SecurityID: otherSecID,
				TradeType: domain.TradeTypeSell, RealizedPnLCents: 9999},
		},
	}
	svc := NewService(secRepo, hr, tr)
	svc.SetPriceHistoryRepository(phRepo)

	perf, err := svc.GetHoldingPerformance(context.Background(), holdingID, "DAY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance error: %v", err)
	}
	if len(perf.PricePoints) != 2 {
		t.Fatalf("price points = %d, want 2", len(perf.PricePoints))
	}
	if perf.PricePoints[0].Value != 1.65 || perf.PricePoints[1].Value != 1.68 {
		t.Fatalf("price points = %.2f/%.2f, want 1.65/1.68 (cents/100)", perf.PricePoints[0].Value, perf.PricePoints[1].Value)
	}
	// realized = 3000 (one sell trade for this holding's account).
	if perf.RealizedCents != 3000 {
		t.Fatalf("realized = %d, want 3000", perf.RealizedCents)
	}
	// unrealized = (168−100)×100 = 6800.
	if perf.UnrealizedCents != 6800 {
		t.Fatalf("unrealized = %d, want 6800", perf.UnrealizedCents)
	}
	if perf.TotalCents != 9800 {
		t.Fatalf("total = %d, want 9800", perf.TotalCents)
	}
	if perf.Currency != "CNY" {
		t.Fatalf("currency = %s, want CNY", perf.Currency)
	}
}

// TestAnnualizedPctSimple verifies the simple annualization formula on a
// synthetic holding whose created_at is 365.25 days ago.
func TestAnnualizedPctSimple(t *testing.T) {
	tenantID, accountID := uuid.New(), uuid.New()
	secID, hID := uuid.New(), uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "X", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 100},
	})
	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: hID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 10, AvgCostCents: 100,
		// 365.25 days ago → years ≈ 1.0.
		CreatedAt: time.Now().AddDate(-1, 0, 0),
	})
	svc := NewService(secRepo, hr, &memTradeRepo{})

	// total = 1000, costBasis = 1000 → totalReturn = 1.0; years ≈ 1.0.
	// annualized ≈ 1.0/1.0×100 = 100%. (AddDate(-1,0,0) ≈ 365 days < 365.25, so
	// years slightly < 1 → annualized slightly > 100.)
	got := svc.annualizedPct(context.Background(), 1000, 1000, tenantID)
	if got < 99.5 || got > 101 {
		t.Fatalf("annualized = %.4f, want ~100", got)
	}
}
