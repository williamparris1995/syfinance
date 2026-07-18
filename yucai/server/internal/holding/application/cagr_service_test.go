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

// fakePriceRepoWithDate returns one fixed price row at a controlled PriceDate.
// CAGR test needs a date that produces a finite, sane days count, unlike the
// XIRR/TWR fakePriceRepo which hardcodes time.Unix(0,0) = epoch (1970 → ~56y
// → CAGR near 0 even for 1.5× growth, hard to assert). priceDate is the date
// used both for FindBySecurity (full CAGR first price) and FindAtOrBefore
// (range CAGR start price) responses.
type fakePriceRepoWithDate struct {
	priceCents int64
	priceDate  time.Time
}

func (r *fakePriceRepoWithDate) FindBySecurity(_ context.Context, securityID uuid.UUID, _, _ time.Time) ([]domain.SecurityPriceHistory, error) {
	if r.priceCents == 0 {
		return nil, nil
	}
	return []domain.SecurityPriceHistory{{
		SecurityID: securityID,
		PriceDate:  r.priceDate,
		PriceCents: r.priceCents,
	}}, nil
}
func (r *fakePriceRepoWithDate) FindAtOrBefore(_ context.Context, _ uuid.UUID, _ time.Time) (int64, bool) {
	return r.priceCents, true
}
func (r *fakePriceRepoWithDate) SaveAll(_ context.Context, _ []domain.SecurityPriceHistory) error {
	return nil
}
func (r *fakePriceRepoWithDate) Save(_ context.Context, _ domain.SecurityPriceHistory) error {
	return nil
}
func (r *fakePriceRepoWithDate) Exists(_ context.Context, _ uuid.UUID) (bool, error) {
	return true, nil
}

// fakeHoldingRepoEmpty returns no holdings — for portfolio CAGR nil-degrade
// (no history / cost basis = 0) coverage.
type fakeHoldingRepoEmpty struct{}

func (r *fakeHoldingRepoEmpty) SaveOrUpdate(_ context.Context, _ *domain.Holding) error {
	return nil
}
func (r *fakeHoldingRepoEmpty) FindByAccountAndSecurity(_ context.Context, _, _, _ uuid.UUID) (*domain.Holding, error) {
	return nil, errors.New("not found")
}
func (r *fakeHoldingRepoEmpty) FindByID(_ context.Context, _ uuid.UUID) (*domain.Holding, error) {
	return nil, errors.New("not found")
}
func (r *fakeHoldingRepoEmpty) FindAll(_ context.Context, _ uuid.UUID, _ *uuid.UUID, _ domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	return &domain.PaginatedResult[domain.Holding]{}, nil
}
func (r *fakeHoldingRepoEmpty) FindAllForBackup(_ context.Context, _ uuid.UUID) ([]domain.Holding, []domain.HoldingTransaction, error) {
	return nil, nil, nil
}
func (r *fakeHoldingRepoEmpty) DeleteByTenant(_ context.Context, _ uuid.UUID) error { return nil }

// --- portfolioCAGR (full: costBasis → currentMV; nil degrade) ---

// 全期 portfolio CAGR:costBasis 1,000,000 → currentMV 1,500,000(2020→now,>5y)
// → CAGR = 1.5^(365/days)-1 > 0(非 nil)。
func TestPortfolioCAGRFullPeriod(t *testing.T) {
	secID := uuid.New()
	tenant := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}},
		holdingRepo: &fakeHoldingRepoSingle{h: domain.Holding{
			TenantID: tenant, SecurityID: secID, Quantity: 100, AvgCostCents: 10000,
			CreatedAt: mustDate2("2020-01-01"),
		}},
		tradeRepo:        &fakeTradeRepo{},
		priceHistoryRepo: &fakePriceRepoWithDate{priceCents: 10000, priceDate: mustDate2("2020-01-01")},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, _, err := svc.portfolioCAGR(context.Background(), tenant, nil, "CNY", mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full CAGR nil, want non-nil (costBasis>0, earliest=2020-01-01, days>=1)")
	}
	if math.IsNaN(*full) || math.IsInf(*full, 0) {
		t.Fatalf("full CAGR not finite: %v", *full)
	}
	if *full <= 0 {
		t.Errorf("full CAGR = %v, want positive (1.5x growth over 5y)", *full)
	}
}

// 无 holding → costBasis=0 + earliest=zero → full CAGR nil(降级,不造假)。
func TestPortfolioCAGRNoHoldingsDegraded(t *testing.T) {
	tenant := uuid.New()
	svc := &Service{
		securityRepo:     &fakeSecurityRepoByID{},
		holdingRepo:      &fakeHoldingRepoEmpty{},
		tradeRepo:        &fakeTradeRepo{},
		priceHistoryRepo: &fakePriceRepoWithDate{},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioCAGR(context.Background(), tenant, nil, "CNY", mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full != nil || rng != nil {
		t.Errorf("expected nil/nil for no holdings, got full=%v rng=%v", full, rng)
	}
}

// --- holdingCAGR (full: firstPrice → current; nil degrade) ---

// 全期 holding CAGR:first price 10000(2020-01-01)→ current 15000 → ratio 1.5
// over ~6y → CAGR > 0(非 nil)。
func TestHoldingCAGRFullPeriod(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	h := domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100, AvgCostCents: 10000}
	sec := domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}
	svc := &Service{
		securityRepo:     &fakeSecurityRepoByID{sec: sec},
		holdingRepo:      &fakeHoldingRepoSingle{h: h},
		tradeRepo:        &fakeTradeRepo{},
		priceHistoryRepo: &fakePriceRepoWithDate{priceCents: 10000, priceDate: mustDate2("2020-01-01")},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, _, err := svc.holdingCAGR(context.Background(), h, sec, mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full CAGR nil, want non-nil (first price 2020-01-01, current 15000)")
	}
	if math.IsNaN(*full) || math.IsInf(*full, 0) {
		t.Fatalf("full CAGR not finite: %v", *full)
	}
	if *full <= 0 {
		t.Errorf("full CAGR = %v, want positive (1.5x price growth over ~6y)", *full)
	}
}

// 无 price_history → first price missing → full CAGR nil(降级,不造假)。
func TestHoldingCAGRNoHistoryDegraded(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	h := domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100, AvgCostCents: 10000}
	sec := domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}
	svc := &Service{
		securityRepo:     &fakeSecurityRepoByID{sec: sec},
		holdingRepo:      &fakeHoldingRepoSingle{h: h},
		tradeRepo:        &fakeTradeRepo{},
		priceHistoryRepo: &fakePriceRepoWithDate{priceCents: 0}, // empty history
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.holdingCAGR(context.Background(), h, sec, mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full != nil || rng != nil {
		t.Errorf("expected nil/nil for no price history, got full=%v rng=%v", full, rng)
	}
}
