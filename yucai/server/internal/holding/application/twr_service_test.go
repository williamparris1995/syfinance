package application

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// marketValueAtDateAsOf: qtyAsOf vs priceAsof 分离。
// 建 1 holding(qty 100)+ 2 price_history 点(day0=10000, day1=11000)。
// qtyAsOf=day0(前)→ qty 0;qtyAsOf=day1(含 buy)→ qty 100。
func TestMarketValueAtDateAsOfQtyPriceSeparation(t *testing.T) {
	secID := uuid.New()
	buyDay := time.Date(2020, 1, 10, 0, 0, 0, 0, time.UTC)
	// price at buyDay = 10000 cents;qty before buyDay = 0, after = 100
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY"}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 100}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: buyDay},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// qtyAsOf = day before buy → qty 0 → MV 0
	mv0, ok := svc.marketValueAtDateAsOf(context.Background(), uuid.Nil, nil, buyDay.AddDate(0, 0, -1), buyDay, 1.0, "CNY")
	if !ok || mv0 != 0 {
		t.Errorf("qty before buy: MV = %d ok=%v, want 0/true", mv0, ok)
	}
	// qtyAsOf = day after buy → qty 100 × price 10000 = 1000000
	mv1, ok := svc.marketValueAtDateAsOf(context.Background(), uuid.Nil, nil, buyDay.AddDate(0, 0, 1), buyDay, 1.0, "CNY")
	if !ok || mv1 != 1000000 {
		t.Errorf("qty after buy × price@buyDay: MV = %d ok=%v, want 1000000/true", mv1, ok)
	}
}

// portfolioTWR:1 holding(buy 100@100元 day0,price 恒 10000)→ 全期 TWR。
// 单子区间(BV_after day0=1000000, no later CF)→ 子区间空? 需 ≥2 cashFlowDays。
// 本测:2 buy(buy day0 + buy day1)→ 1 子区间。Task 2 起返 (full, rng);
// rangeStart=cashFlowDays[0] → rng 用同一起点 → 与 full 等价(byte-identical Task 1)。
func TestPortfolioTWRSimple(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 200}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day1},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// rangeStart = day0 = cashFlowDays[0] → rng 走与 full 相同的 computeTWR 调用。
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("portfolioTWR full nil, want non-nil (price constant → TWR ~0)")
	}
	// price 恒定(10000),无市场变化 → TWR ≈ 0(只有现金流,无收益)
	if *full > 0.01 || *full < -0.01 {
		t.Errorf("full TWR = %v, want ~0 (constant price)", *full)
	}
	// rangeStart == cashFlowDays[0] → rng 必须等价 full(同一 computeTWR 入参)。
	if rng == nil {
		t.Fatal("portfolioTWR rng nil when rangeStart == cashFlowDays[0], want non-nil (== full)")
	}
	if diff := *rng - *full; diff > 1e-9 || diff < -1e-9 {
		t.Errorf("rng (%v) != full (%v) when rangeStart == cashFlowDays[0]", *rng, *full)
	}
}

// holdingTWR:单 holding(原币,不折算)
func TestHoldingTWROriginalCurrency(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 11000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0, AccountID: accID},
			// day1 无 trade → 不切子区间;用 2 buy 切
			{TradeType: domain.TradeTypeBuy, Quantity: 0, AmountCents: 0, SecurityID: secID, TradeDate: day1, AccountID: accID},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.holdingTWR(context.Background(), holdID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("holdingTWR nil, want non-nil")
	}
}

// 无 trade → nil(full + rng 双降级,不造假)。
func TestPortfolioTWRNoTrades(t *testing.T) {
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{}, holdingRepo: &fakeHoldingRepoSingle{},
		tradeRepo: &fakeTradeRepo{items: nil}, priceHistoryRepo: &fakePriceRepo{priceCents: 0},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", mustDate2("2020-06-01"))
	if err != nil || full != nil || rng != nil {
		t.Errorf("no trades: full=%v rng=%v err=%v, want nil/nil/nil", full, rng, err)
	}
}

// TestPortfolioTWRRange:3 buy(day0/day1/day2)+ price 恒 10000 → full + rng 都解出。
// rangeStart=day1 落在 [day0, day2] 内,day2 是 effectiveDay(严格 after day1)→ rng 非空。
// price 恒定 → 无市场变化 → full ≈ 0 且 rng ≈ 0(子区间 HPR=1.0,finalValue/lastAfter=1.0)。
// 手算区间 TWR(cashFlowDays=[day0,day1,day2],rangeStart=day1):
//
//	effectiveDays=[day2]; begin=qty@day2 × price@day1=300×10000=3,000,000
//	  (qty@day2 含 day0+day1+day2 三笔 buy,但 computeTWR begin 用 qtyAsOf=rangeStart+1d=day2)
//	sub1: Begin=3,000,000(初始 prevAfter), End=BV_before(day2)=qty@day2 × price@day2=300×10000=3,000,000 → HPR=1.0
//	lastAfter=BV_after(day2)=qty@day3 × price@day2=300×10000=3,000,000
//	finalValue=300×10000=3,000,000 → finalValue/lastAfter=1.0
//	cumulative=1.0×1.0−1=0 → annualized=0(无论 totalDays)。故 rng=0 ✓
func TestPortfolioTWRRange(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 300}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full nil, want non-nil (≥2 cashFlowDays, price history present)")
	}
	if rng == nil {
		t.Fatal("rng nil for rangeStart=day1 (1 effectiveDay [day2]), want non-nil")
	}
	// price 恒定 → full 与 rng 都 ≈ 0。
	if *full > 0.01 || *full < -0.01 {
		t.Errorf("full TWR = %v, want ~0 (constant price)", *full)
	}
	if *rng > 0.01 || *rng < -0.01 {
		t.Errorf("range TWR = %v, want ~0 (constant price)", *rng)
	}
}

// TestPortfolioTWRRangeDegradeLate:rangeStart = 最后 cashFlowDay(day2)→ 无 effectiveDay
// (没有任何 cashFlowDay 严格 after day2)→ computeTWR 返 ErrInsufficientPeriods → rng nil。
// full 仍解出(rangeStart=cashFlowDays[0]=day0,不依赖 rangeStart 参数)。
func TestPortfolioTWRRangeDegradeLate(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 300}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// rangeStart = day2(末笔)→ effectiveDays 空 → rng 降级;full 仍走 cashFlowDays[0]。
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day2)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full nil, want non-nil (full-period independent of rangeStart)")
	}
	if rng != nil {
		t.Errorf("rng = %v, want nil (rangeStart=last cashFlowDay → 0 effectiveDays)", *rng)
	}
}

// TestPortfolioTWRRangeDegradeEarly:rangeStart < 首笔 trade → 区间初空仓
// (qty@(rangeStart+1d)=0 → begin MV=0 → 首子区间 BeginValueAfterCF=0 → ErrZeroValue)→ rng nil。
// full 仍解出(rangeStart=cashFlowDays[0],day0 buy 后有持仓)。
func TestPortfolioTWRRangeDegradeEarly(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	// rangeStart 早于 day0 两天 → rangeStart+1d = day0 前一天 → qty=0(空仓)。
	rangeStart := day0.AddDate(0, 0, -2)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 300}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: &fakePriceRepo{priceCents: 10000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", rangeStart)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full nil, want non-nil (full-period independent of rangeStart)")
	}
	if rng != nil {
		t.Errorf("rng = %v, want nil (rangeStart < first trade → empty opening position → ErrZeroValue)", *rng)
	}
}

// countingPriceRepo wraps fakePriceRepo and counts FindBySecurity calls.
// marketValueAtDateAsOfWithTrades → priceAtOrBefore → FindBySecurity per holding,
// so for the 1-holding test setup each market-value evaluation = 1 FindBySecurity
// call. Used to prove the request-scoped mvCache turns repeat lookups into hits.
type countingPriceRepo struct {
	*fakePriceRepo
	calls int
}

func (r *countingPriceRepo) FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	r.calls++
	return r.fakePriceRepo.FindBySecurity(ctx, securityID, from, to)
}

// TestCachedMVMemoizes: cache miss computes + stores; cache hit returns the
// stored (val, ok) without re-calling the repo. Different key → new miss.
func TestCachedMVMemoizes(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	prices := &countingPriceRepo{fakePriceRepo: &fakePriceRepo{priceCents: 10000}}
	svc := &Service{
		securityRepo:     &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY"}},
		holdingRepo:      &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 100}},
		tradeRepo:        &fakeTradeRepo{items: []domain.HoldingTransaction{{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: day0}}},
		priceHistoryRepo: prices,
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	trades, _ := svc.allTradesForTenant(context.Background(), uuid.Nil, nil)
	cache := mvCache{}

	// Miss: computes (qty@day1=100 × price@day0=10000 = 1,000,000) and stores.
	v1, ok1 := svc.cachedMV(context.Background(), cache, trades, uuid.Nil, nil, day1, day0, 1.0, "CNY")
	if !ok1 || v1 != 1000000 {
		t.Fatalf("first call (miss): v=%d ok=%v, want 1000000/true", v1, ok1)
	}
	if prices.calls != 1 {
		t.Fatalf("after miss: FindBySecurity calls=%d, want 1", prices.calls)
	}
	if len(cache) != 1 {
		t.Errorf("cache size=%d after one miss, want 1", len(cache))
	}

	// Hit: same key → returns cached (val, ok), no new repo call.
	v2, ok2 := svc.cachedMV(context.Background(), cache, trades, uuid.Nil, nil, day1, day0, 1.0, "CNY")
	if v2 != v1 || ok2 != ok1 {
		t.Errorf("hit: v=%d ok=%v, want cached (%d, %v)", v2, ok2, v1, ok1)
	}
	if prices.calls != 1 {
		t.Errorf("after hit: FindBySecurity calls=%d, want still 1 (hit must not recompute)", prices.calls)
	}
	if len(cache) != 1 {
		t.Errorf("cache size=%d after hit, want still 1 (hit must not grow cache)", len(cache))
	}

	// Different priceAsOf → new key → miss.
	v3, ok3 := svc.cachedMV(context.Background(), cache, trades, uuid.Nil, nil, day1, day1, 1.0, "CNY")
	if !ok3 || v3 != 1000000 {
		t.Errorf("second key (miss): v=%d ok=%v, want 1000000/true", v3, ok3)
	}
	if prices.calls != 2 {
		t.Errorf("after second key: FindBySecurity calls=%d, want 2", prices.calls)
	}
	if len(cache) != 2 {
		t.Errorf("cache size=%d after second miss, want 2", len(cache))
	}
}

// TestPortfolioTWRSharedCacheReducesLookups: with rangeStart=day1 (range ⊂ full,
// same setup as TestPortfolioTWRRange), the range computeTWR's 3 BV lookups are
// all keys the full computeTWR already populated. So the shared cache saves
// exactly 3 FindBySecurity calls (8 → 5). Proves the cache is both shared and
// transparent (the regression tests above already prove results are byte-identical).
func TestPortfolioTWRSharedCacheReducesLookups(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	prices := &countingPriceRepo{fakePriceRepo: &fakePriceRepo{priceCents: 10000}}
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 300}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: prices,
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	// rangeStart = day1 → range computeTWR is a strict subset of full (rangeStart=day0).
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil || rng == nil {
		t.Fatalf("expected full and rng non-nil, got full=%v rng=%v", full, rng)
	}
	// Full computeTWR issues 5 unique BV lookups; range would add 3 more without
	// sharing (begin + day2 bvBefore/bvAfter). Shared cache → range's 3 are hits.
	const (
		withoutCache = 8 // 5 (full) + 3 (range, no sharing)
		withCache    = 5 // 5 unique keys; 3 range lookups hit
	)
	if prices.calls != withCache {
		t.Errorf("FindBySecurity calls=%d, want %d (shared cache: range's 3 BV lookups hit; without cache would be %d)",
			prices.calls, withCache, withoutCache)
	}
}
