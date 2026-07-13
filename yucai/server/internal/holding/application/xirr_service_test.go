package application

import (
	"context"
	"errors"
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// fakeSecurityRepoByID returns one fixed security for any FindByID call
// (XIRR test only reads the single seeded security). Empty when sec.ID is zero.
type fakeSecurityRepoByID struct{ sec domain.Security }

func (r *fakeSecurityRepoByID) Save(_ context.Context, _ *domain.Security) error { return nil }
func (r *fakeSecurityRepoByID) FindByID(_ context.Context, _ uuid.UUID) (*domain.Security, error) {
	if r.sec.ID == uuid.Nil {
		return nil, errors.New("security not found")
	}
	return &r.sec, nil
}
func (r *fakeSecurityRepoByID) FindAll(_ context.Context, _ *domain.SecurityType, _ domain.PageRequest) (*domain.PaginatedResult[domain.Security], error) {
	if r.sec.ID == uuid.Nil {
		return &domain.PaginatedResult[domain.Security]{}, nil
	}
	return &domain.PaginatedResult[domain.Security]{Items: []domain.Security{r.sec}}, nil
}
func (r *fakeSecurityRepoByID) FindBySymbol(_ context.Context, _, _ string) (*domain.Security, error) {
	if r.sec.ID == uuid.Nil {
		return nil, errors.New("security not found")
	}
	return &r.sec, nil
}
func (r *fakeSecurityRepoByID) Search(_ context.Context, _ string, _ int) ([]domain.Security, error) {
	return nil, nil
}
func (r *fakeSecurityRepoByID) UpdatePrice(_ context.Context, _ uuid.UUID, _ int64) error { return nil }

// fakeHoldingRepoSingle returns one fixed holding (XIRR test only reads the
// single seeded holding). Always returns r.h — the portfolio test intentionally
// builds a holding with no ID (only SecurityID/Quantity/AvgCostCents matter).
type fakeHoldingRepoSingle struct{ h domain.Holding }

func (r *fakeHoldingRepoSingle) SaveOrUpdate(_ context.Context, _ *domain.Holding) error {
	return nil
}
func (r *fakeHoldingRepoSingle) FindByAccountAndSecurity(_ context.Context, _, _, _ uuid.UUID) (*domain.Holding, error) {
	return &r.h, nil
}
func (r *fakeHoldingRepoSingle) FindByID(_ context.Context, _ uuid.UUID) (*domain.Holding, error) {
	return &r.h, nil
}
func (r *fakeHoldingRepoSingle) FindAll(_ context.Context, _ uuid.UUID, _ *uuid.UUID, _ domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	return &domain.PaginatedResult[domain.Holding]{Items: []domain.Holding{r.h}}, nil
}

// fakeTradeRepo serves in-memory trades (tenant/account/security-insensitive
// for test simplicity — XIRR only reads Items).
type fakeTradeRepo struct{ items []domain.HoldingTransaction }

func (r *fakeTradeRepo) Save(_ context.Context, _ *domain.HoldingTransaction) error {
	return nil
}
func (r *fakeTradeRepo) FindAll(_ context.Context, _ uuid.UUID, _, _ *uuid.UUID, _ domain.PageRequest) (*domain.PaginatedResult[domain.HoldingTransaction], error) {
	return &domain.PaginatedResult[domain.HoldingTransaction]{Items: r.items}, nil
}

// fakePriceRepo returns one fixed price for any (security,date ≤ query).
// Both FindBySecurity and FindAtOrBefore honor priceCents so priceAtOrBefore
// (which routes through FindBySecurity) sees a valid history entry.
type fakePriceRepo struct{ priceCents int64 }

func (r *fakePriceRepo) FindBySecurity(_ context.Context, securityID uuid.UUID, _, _ time.Time) ([]domain.SecurityPriceHistory, error) {
	if r.priceCents == 0 {
		return nil, nil
	}
	return []domain.SecurityPriceHistory{{
		SecurityID: securityID,
		PriceDate:  time.Unix(0, 0),
		PriceCents: r.priceCents,
	}}, nil
}
func (r *fakePriceRepo) FindAtOrBefore(_ context.Context, _ uuid.UUID, _ time.Time) (int64, bool) {
	return r.priceCents, true
}
func (r *fakePriceRepo) SaveAll(_ context.Context, _ []domain.SecurityPriceHistory) error { return nil }
func (r *fakePriceRepo) Save(_ context.Context, _ domain.SecurityPriceHistory) error      { return nil }
func (r *fakePriceRepo) Exists(_ context.Context, _ uuid.UUID) (bool, error)              { return true, nil }

func mustDate2(s string) time.Time {
	t, _ := time.Parse("2006-01-02", s)
	return t
}

// 全期 XIRR:两笔 buy(原币 CNY,rate=1)+ 当前终值 → 与 domain XIRR 一致。
func TestPortfolioXIRRFullPeriodCNY(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 12000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 100, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, FeeCents: 0, SecurityID: secID, TradeDate: mustDate2("2020-01-01")},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 12000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, _, err := svc.portfolioXIRR(context.Background(), uuid.Nil, nil, "CNY", mustDate2("2020-06-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full XIRR nil, want non-nil")
	}
	// 投入 10000(100×100元)→ 终值 12000(100×120元)≈ 1 年后;终值市值 12000,
	// 与 -10000 + 12000(同日近似)→ rate 接近 +20%(取决于 today 距 2020-01-01)。
	if *full <= 0 {
		t.Errorf("full XIRR = %v, want positive", *full)
	}
}

// 单标的 XIRR:buy + 终值(原币,不折算)。
func TestHoldingXIRROriginalCurrency(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, FeeCents: 0, SecurityID: secID, TradeDate: mustDate2("2020-01-01"), AccountID: accID},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 15000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, err := svc.holdingXIRR(context.Background(), holdID, "CNY")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil || math.IsNaN(*full) {
		t.Fatalf("holding XIRR nil/NaN: %v", full)
	}
}

// GetPortfolioPerformance wires portfolioXIRR.full → AnnualizedPct and
// portfolioXIRR.range → RangeAnnualizedPct. This test (Task 4 Step 1) verifies
// the full XIRR is filled (non-nil) when a buy trade + current price exist.
// snapshotRepo is seeded empty so the snapshot nil-guard passes but the curve
// stays empty; XIRR runs through tradeRepo + holdingRepo + priceHistoryRepo.
func TestGetPortfolioPerformanceFillsXIRR(t *testing.T) {
	secID := uuid.New()
	tenant := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 12000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{TenantID: tenant, SecurityID: secID, Quantity: 100, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: mustDate2("2020-01-01")},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
		snapshotRepo:     &memSnapshotRepo{},
	}
	out, err := svc.GetPortfolioPerformance(context.Background(), tenant, nil, "MONTH", false, "CNY")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.AnnualizedPct == nil {
		t.Error("AnnualizedPct nil, want non-nil (full XIRR)")
	}
}

// 无 trade → nil(降级,不造假)。
func TestPortfolioXIRRNoTrades(t *testing.T) {
	svc := &Service{
		securityRepo:     &fakeSecurityRepoByID{},
		holdingRepo:      &fakeHoldingRepoSingle{},
		tradeRepo:        &fakeTradeRepo{items: nil},
		priceHistoryRepo: &fakePriceRepo{priceCents: 0},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioXIRR(context.Background(), uuid.Nil, nil, "CNY", mustDate2("2020-06-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full != nil || rng != nil {
		t.Errorf("expected nil/nil for no trades, got full=%v rng=%v", full, rng)
	}
}
