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
	full, _, err := svc.holdingCAGR(context.Background(), h, sec,
		[]domain.HoldingTransaction{{TradeType: domain.TradeTypeBuy, SecurityID: secID, TradeDate: mustDate2("2020-01-01")}},
		mustDate2("2024-01-01"))
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
	full, rng, err := svc.holdingCAGR(context.Background(), h, sec, nil, mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full != nil || rng != nil {
		t.Errorf("expected nil/nil for no price history, got full=%v rng=%v", full, rng)
	}
}

// --- range CAGR (rangeStart within fixture coverage → rng != nil) ---
//
// TestPortfolioCAGRFullPeriod / TestHoldingCAGRFullPeriod 丢弃 rng (`_, `) →
// range code path 无 executable assertion(Task 1 review Important)。下面 3 个
// 测补齐:2 positive(rangeStart 落在 price coverage 内)+ 1 degrade(早于 coverage)。

// TestPortfolioCAGRRange:rangeStart=2024-01-01 落在 fixture price(2020-01-01)
// 覆盖内 → marketValueAtDate 解出 startMV → rng != nil + 与公式
// (finalMV/startMV)^(365/days)-1 一致。Mirror TestPortfolioCAGRFullPeriod fixture,
// 加一笔 buy trade(full 走 costBasis 不需要 trade,但 range 走 QtyAtDate 需要)。
func TestPortfolioCAGRRange(t *testing.T) {
	secID := uuid.New()
	tenant := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}},
		holdingRepo: &fakeHoldingRepoSingle{h: domain.Holding{
			TenantID: tenant, SecurityID: secID, Quantity: 100, AvgCostCents: 10000,
			CreatedAt: mustDate2("2020-01-01"),
		}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: mustDate2("2020-01-01")},
		}},
		priceHistoryRepo: &fakePriceRepoWithDate{priceCents: 10000, priceDate: mustDate2("2020-01-01")},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	rangeStart := mustDate2("2024-01-01")
	_, rng, err := svc.portfolioCAGR(context.Background(), tenant, nil, "CNY", rangeStart)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if rng == nil {
		t.Fatal("range CAGR nil, want non-nil (rangeStart 2024-01-01 within price coverage 2020-01-01)")
	}
	if math.IsNaN(*rng) || math.IsInf(*rng, 0) {
		t.Fatalf("range CAGR not finite: %v", *rng)
	}
	// finalMV = 100 qty × 15000 cur = 1,500,000; startMV = QtyAtDate(rangeStart)=100
	// × priceAtOrBefore(rangeStart)=10000 → 1,000,000 → ratio 1.5 → 1.5^(365/days)-1.
	days := int(time.Since(rangeStart).Hours() / 24)
	want := math.Pow(1.5, 365.0/float64(days)) - 1
	if math.Abs(*rng-want) > 1e-9 {
		t.Errorf("range CAGR = %.10v, want %.10v (1.5^(365/%d)-1)", *rng, want, days)
	}
}

// TestHoldingCAGRRange:rangeStart=2024-01-01 落在 fakePriceRepoWithDate 覆盖内
// (priceDate 2020-01-01 ≤ rangeStart)→ priceAtOrBefore 解出 → rng != nil + 与公式
// (cur/startPrice)^(365/days)-1 一致。Mirror TestHoldingCAGRFullPeriod fixture。
func TestHoldingCAGRRange(t *testing.T) {
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
	rangeStart := mustDate2("2024-01-01")
	_, rng, err := svc.holdingCAGR(context.Background(), h, sec, nil, rangeStart)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if rng == nil {
		t.Fatal("range CAGR nil, want non-nil (rangeStart 2024-01-01 within price coverage 2020-01-01)")
	}
	if math.IsNaN(*rng) || math.IsInf(*rng, 0) {
		t.Fatalf("range CAGR not finite: %v", *rng)
	}
	// cur (15000) / startPrice (10000) → 1.5 → 1.5^(365/days)-1.
	days := int(time.Since(rangeStart).Hours() / 24)
	want := math.Pow(1.5, 365.0/float64(days)) - 1
	if math.Abs(*rng-want) > 1e-9 {
		t.Errorf("range CAGR = %.10v, want %.10v (1.5^(365/%d)-1)", *rng, want, days)
	}
}

// --- range CAGR degrade (rangeStart OUTSIDE fixture coverage → rng == nil) ---

// fakePriceRepoDateAware respects [from, to] on FindBySecurity (unlike
// fakePriceRepoWithDate which ignores dates)。range-degrade 测需要 rangeStart
// 落在 price 行覆盖之外 → priceAtOrBefore FindBySecurity(epoch, rangeStart) 返回空
// → ok=false → rng nil(照 TWR TestPortfolioTWRRangeDegradeEarly 范式)。
type fakePriceRepoDateAware struct {
	rows []domain.SecurityPriceHistory
}

func (r *fakePriceRepoDateAware) FindBySecurity(_ context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	var out []domain.SecurityPriceHistory
	for _, p := range r.rows {
		if p.SecurityID != securityID {
			continue
		}
		if p.PriceDate.Before(from) || p.PriceDate.After(to) {
			continue
		}
		out = append(out, p)
	}
	return out, nil
}
func (r *fakePriceRepoDateAware) SaveAll(_ context.Context, _ []domain.SecurityPriceHistory) error {
	return nil
}
func (r *fakePriceRepoDateAware) Save(_ context.Context, _ domain.SecurityPriceHistory) error { return nil }
func (r *fakePriceRepoDateAware) Exists(_ context.Context, _ uuid.UUID) (bool, error) {
	return true, nil
}

// TestPortfolioCAGRRangeDegradeEarly:rangeStart (2019-06-01) 在 buy trade
// (2019-01-01,qty=100 > 0 at rangeStart)之后,但早于唯一 price 行(2020-01-01)
// → priceAtOrBefore(rangeStart) 走 FindBySecurity(epoch, 2019-06-01) 返回空
// (date-aware 过滤)→ ok=false → marketValueAtDate 降级 → rng nil。
// Full 不依赖 rangeStart(走 costBasis → currentMV),仍解出 → 证独立降级。
// 加 trade 是为隔离 price-missing 路径(否则 QtyAtDate=0 → startMV=0 也能 rng nil,
// 但那是 empty-position 降级,不是本测要验的 history-missing 降级)。
func TestPortfolioCAGRRangeDegradeEarly(t *testing.T) {
	secID := uuid.New()
	tenant := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}},
		holdingRepo: &fakeHoldingRepoSingle{h: domain.Holding{
			TenantID: tenant, SecurityID: secID, Quantity: 100, AvgCostCents: 10000,
			CreatedAt: mustDate2("2019-01-01"),
		}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: mustDate2("2019-01-01")},
		}},
		priceHistoryRepo: &fakePriceRepoDateAware{rows: []domain.SecurityPriceHistory{{
			SecurityID: secID, PriceDate: mustDate2("2020-01-01"), PriceCents: 10000,
		}}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// rangeStart 在 trade(2019-01-01)后但早于首条 price(2020-01-01)
	// → QtyAtDate(rangeStart)=100 > 0,但 priceAtOrBefore(rangeStart) → ok=false。
	rangeStart := mustDate2("2019-06-01")
	full, rng, err := svc.portfolioCAGR(context.Background(), tenant, nil, "CNY", rangeStart)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full CAGR nil, want non-nil (full uses costBasis→currentMV, independent of rangeStart)")
	}
	if rng != nil {
		t.Errorf("rng = %v, want nil (rangeStart 2019-06-01 after trade but before first price 2020-01-01 → priceAtOrBefore ok=false)", *rng)
	}
}

// --- holdingCAGR P1-5: full-period uses BUY date, not price-history inception ---
//
// holdingCAGR full-period 的 days 必须从用户首买日算起,而非证券 price_history
// 起始日。回填场景(price_history 早于 buy)下,用 inception 会把天数撑大 →
// 同一 (cur/first) 比值算出偏低 CAGR,失真用户真实回报。spec §6.2 原写 "first
// price_history point" 是设计疏漏(P1-5 纠正):改用 earliestBuyDate +
// priceAtOrBefore(forward-fill 取买入日市价)。
//
// TestHoldingCAGR_UsesBuyDateNotInception: price_history 起始 2018(早于买入 2020)。
// 正确(buy date 2020→2024 = 1461 天):CAGR = 1.5^(365/1461)-1 ≈ 11.0%/y。
// 旧行为(inception 2018→2024 = 2192 天):≈ 7.4%/y。两者明显不同 → 锁 buy date。
//
// 与 ReverseOrder(已废)的区别:本测不验 sort-safety(priceAtOrBefore 内部扫描
// 另测),只验 firstDate 选 buy 日 vs price inception 的区分度。SetNow 注入固定
// 评估日(2024-01-01)→ days 确定性可断言(优于 time.Since 真实 now)。
func TestHoldingCAGR_UsesBuyDateNotInception(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	h := domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100, AvgCostCents: 10000}
	sec := domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 15000}
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: sec},
		holdingRepo:  &fakeHoldingRepoSingle{h: h},
		tradeRepo:    &fakeTradeRepo{},
		// price_history 起始 2018(早于买入 2020)— date-aware fake 让 priceAtOrBefore
		// 能取到 2018 行(forward-fill 到 buy 日)。
		priceHistoryRepo: &fakePriceRepoDateAware{rows: []domain.SecurityPriceHistory{{
			SecurityID: secID, PriceDate: mustDate2("2018-01-01"), PriceCents: 10000,
		}}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// 注入固定 now(2024-01-01)— Service.SetNow 存在,优于 spec fallback time.Since。
	now := mustDate2("2024-01-01")
	svc.SetNow(func() time.Time { return now })

	buyDate := mustDate2("2020-01-01")
	full, _, err := svc.holdingCAGR(context.Background(), h, sec,
		[]domain.HoldingTransaction{{TradeType: domain.TradeTypeBuy, SecurityID: secID, TradeDate: buyDate}},
		mustDate2("2024-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full CAGR nil, want non-nil (buy 2020-01-01, price history 2018-01-01 forward-fills)")
	}
	// 关键断言:days 必须从 buy 日(2020)算,不是 price inception(2018)。
	// now 已注入 2024-01-01 → days 可确定性计算。
	daysFromBuy := int(now.Sub(buyDate).Hours() / 24)
	daysFromInception := int(now.Sub(mustDate2("2018-01-01")).Hours() / 24)
	wantFromBuy := math.Pow(1.5, 365.0/float64(daysFromBuy)) - 1
	wantFromInception := math.Pow(1.5, 365.0/float64(daysFromInception)) - 1
	if math.Abs(*full-wantFromBuy) > 1e-9 {
		t.Errorf("full CAGR = %.10v, want %.10v (days from BUY 2020-01-01, NOT price inception 2018-01-01 = %.10v)",
			*full, wantFromBuy, wantFromInception)
	}
}
