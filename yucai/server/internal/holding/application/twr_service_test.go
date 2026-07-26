package application

import (
	"context"
	"strconv"
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
	twr, err := svc.holdingTWR(context.Background(), uuid.Nil, holdID)
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

// TestPortfolioTWRCacheBenchmark scales TestPortfolioTWRSharedCacheReducesLookups
// to a realistic portfolio (N=10 cashFlowDays × M=5 holdings) and verifies the
// request-scoped mvCache still turns the range computeTWR into pure cache hits.
//
// Fixture:
//   - M=5 distinct securities (CNY) + 5 holdings (one per security, qty grows via buys)
//   - N=10 cashFlowDays [day0..day9]; 5 buys per day (one per security) → 50 trades
//   - rangeStart=day5 so the range window is a strict subset of the full window
//
// cachedMV unique-key math (cache key = accountID|qtyAsOf|priceAsOf; per computeTWR
// the begin lookup + 2 per effectiveDay):
//
//	full  (rangeStart=day0, effectiveDays=[day1..day9], 9): 1 + 2×9 = 19 unique keys
//	range (rangeStart=day5, effectiveDays=[day6..day9], 4): 1 + 2×4 =  9 unique keys
//	  └ range ⊂ full: every range key is one full already populated
//	     (range.begin=(day6,day5)=full.bvAfter(day5); each range bvBefore/bvAfter
//	     matches the same cashFlowDay's full bvBefore/bvAfter) → 9/9 hits
//
// Each cachedMV MISS calls marketValueAtDateAsOfWithTrades which loops the M
// holdings and calls priceAtOrBefore → FindBySecurity once per non-zero-qty
// holding, i.e. M calls per miss. currentMarketValueInBase (finalValue) uses
// Security.CurrentPriceCents, not priceAtOrBefore, so it adds 0 FindBySecurity
// calls.
//
//	without cache: (19 + 9) × M = 28 × 5 = 140 FindBySecurity calls
//	with cache:    19          × M = 19 × 5 =  95 FindBySecurity calls (45 saved, 32%)
func TestPortfolioTWRCacheBenchmark(t *testing.T) {
	const (
		nCashFlowDays = 10
		mHoldings     = 5
		rangeDayIdx   = 5 // rangeStart = day[5] → range ⊂ full
	)

	// M distinct securities + M holdings (same account, tenant-pass-through).
	accountID := uuid.New()
	secIDs := make([]uuid.UUID, mHoldings)
	for i := range secIDs {
		secIDs[i] = uuid.New()
	}
	securities := make([]secSeed, mHoldings)
	for i, id := range secIDs {
		securities[i] = secSeed{
			ID: id, Symbol: "S" + strconv.Itoa(i), Exchange: "TEST",
			Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 10000,
		}
	}
	secRepo := newFullSecRepo(securities)

	hr := newMemHoldingRepo()
	for _, id := range secIDs {
		hr.SaveOrUpdate(context.Background(), &domain.Holding{
			ID: uuid.New(), TenantID: uuid.Nil, AccountID: accountID,
			SecurityID: id, Quantity: 100, AvgCostCents: 10000,
		})
	}

	// N=10 cashFlowDays × M=5 buys/day (qty 100, amount 1_000_000 each). Every
	// security accumulates qty on every day so each holding contributes a
	// FindBySecurity call per marketValueAtDateAsOfWithTrades invocation.
	days := make([]time.Time, nCashFlowDays)
	trades := make([]domain.HoldingTransaction, 0, nCashFlowDays*mHoldings)
	for d := 0; d < nCashFlowDays; d++ {
		day := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC).AddDate(0, 0, d)
		days[d] = day
		for _, id := range secIDs {
			trades = append(trades, domain.HoldingTransaction{
				ID: uuid.New(), TenantID: uuid.Nil, AccountID: accountID,
				TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000,
				SecurityID: id, TradeDate: day,
			})
		}
	}

	prices := &countingPriceRepo{fakePriceRepo: &fakePriceRepo{priceCents: 10000}}
	svc := &Service{
		securityRepo:     secRepo,
		holdingRepo:      hr,
		tradeRepo:        &fakeTradeRepo{items: trades},
		priceHistoryRepo: prices,
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}

	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", days[rangeDayIdx])
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil || rng == nil {
		t.Fatalf("expected full and rng non-nil, got full=%v rng=%v", full, rng)
	}

	// Per-miss cost = M FindBySecurity calls (one per non-zero-qty holding).
	const (
		fullUniqueKeys = 1 + 2*(nCashFlowDays-1)            // 1 begin + 2×9 effectiveDays = 19
		rngUniqueKeys  = 1 + 2*(nCashFlowDays-1-rangeDayIdx) // 1 begin + 2×4 effectiveDays = 9
		withoutCache   = (fullUniqueKeys + rngUniqueKeys) * mHoldings // 28 × 5 = 140
		withCache      = fullUniqueKeys * mHoldings                   // 19 × 5 = 95 (range 9/9 hit)
	)
	if got := prices.calls; got != withCache {
		t.Errorf("FindBySecurity calls=%d, want %d (shared cache at scale: range's %d BV lookups all hit; "+
			"without cache would be %d — %.0f%% saved)", got, withCache, rngUniqueKeys, withoutCache,
			100.0*float64(withoutCache-withCache)/float64(withoutCache))
	}
	t.Logf("N=%d cashFlowDays × M=%d holdings: FindBySecurity calls with cache=%d, without=%d (%.0f%% saved by range⊂full cache hits)",
		nCashFlowDays, mHoldings, withCache, withoutCache, 100.0*float64(withoutCache-withCache)/float64(withoutCache))
}

// TestUniqueSortedTradeDatesExcludesPureSplitDay: a day with only a split trade
// is NOT a cash-flow day (split is market-value-neutral, non-cash-flow) → must
// not seed a TWR sub-period. The split trade stays in trades for QtyAtDate replay.
func TestUniqueSortedTradeDatesExcludesPureSplitDay(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	// buy day0, split day1 (pure split day), sell day2.
	trades := []domain.HoldingTransaction{
		{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: day0},
		{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
		{TradeType: domain.TradeTypeSell, Quantity: 50, SecurityID: secID, TradeDate: day2},
	}
	days := uniqueSortedTradeDates(trades)
	// day1 (pure split) excluded; day0 (buy) + day2 (sell) kept.
	if len(days) != 2 {
		t.Fatalf("len(days)=%d, want 2 (pure split day excluded); days=%v", len(days), days)
	}
	if !days[0].Equal(day0) || !days[1].Equal(day2) {
		t.Errorf("days=%v, want [day0, day2] (day1 pure split excluded)", days)
	}
}

// TestUniqueSortedTradeDatesKeepsSplitPlusBuyDay: split+buy same day → the buy
// makes it a cash-flow day, so the day is kept (split folded via QtyAtDate).
func TestUniqueSortedTradeDatesKeepsSplitPlusBuyDay(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	trades := []domain.HoldingTransaction{
		{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: day0},
		{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
		{TradeType: domain.TradeTypeBuy, Quantity: 50, SecurityID: secID, TradeDate: day1}, // split+buy same day
	}
	days := uniqueSortedTradeDates(trades)
	if len(days) != 2 {
		t.Fatalf("len(days)=%d, want 2 (day1 has buy → kept); days=%v", len(days), days)
	}
	if !days[1].Equal(day1) {
		t.Errorf("days=%v, want day1 kept (split+buy same day is a cash-flow day)", days)
	}
}

// splitPriceRepo serves raw (unadjusted) prices that jump across a split:
// preSplitCents strictly before splitDay, postSplitCents on/after splitDay.
// Mirrors how Sina (不复权) and Yahoo (quote.close raw, not adjclose) store
// split-jumping raw prices — the root cause of the TWR split-day BV cross-scale
// bug (one price paired with pre-/post-split quantities).
type splitPriceRepo struct {
	splitDay       time.Time
	preSplitCents  int64
	postSplitCents int64
}

func (r *splitPriceRepo) FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	// preSplit entry predates any buy day (one year before split) so priceAtOrBefore
	// returns preSplit for every date strictly before splitDay, postSplit on/after.
	return []domain.SecurityPriceHistory{
		{PriceDate: r.splitDay.AddDate(-1, 0, 0), PriceCents: r.preSplitCents},
		{PriceDate: r.splitDay, PriceCents: r.postSplitCents},
	}, nil
}

// No-op stubs to satisfy domain.PriceHistoryRepository (only FindBySecurity is
// exercised by the TWR path; mirrors fakePriceRepo's no-op pattern verbatim).
// NOTE: brief omitted these; added as required compile fix — see task-2-report.
func (r *splitPriceRepo) SaveAll(_ context.Context, _ []domain.SecurityPriceHistory) error { return nil }
func (r *splitPriceRepo) Save(_ context.Context, _ domain.SecurityPriceHistory) error      { return nil }
func (r *splitPriceRepo) Exists(_ context.Context, _ uuid.UUID) (bool, error)              { return true, nil }

// TestHoldingTWRSplitNoPhantomHPR: buy 100@¥100(day0) → split 1:2(day1) →
// sell 50@¥60(day2); raw price jumps 10000→5000 across split; current ¥60.
//
// GIPS hand-math (split day must NOT seed a sub-period):
//	cashFlowDays = [day0, day2]                       (day1 pure split excluded)
//	BV_after(day0)  = QtyAtDate(day1)×price(day0)   = 100×10000 = 1,000,000 (pre-split)
//	BV_before(day2) = QtyAtDate(day2)×price(day2)   = 200×5000  = 1,000,000 (post-split raw price; replay split 100×2)
//	subPeriod HPR   = 1,000,000 / 1,000,000 = 1.0   → in-period flat (BV equal at raw prices)
//	finalValue/lastAfterCF = (150×6000)/(150×5000) = 900,000/750,000 = 1.2 → cumulative +20% (current ¥60 > lastAfterCF basis ¥50), NO phantom split HPR.
//
// Bug (split day as cut point) pairs one price with cross-scale qty at day1:
//	BV_before(day1)=100×5000=500,000 (pre-split qty × post-split price) → phantom −50% HPR
//	→ cumulative ≈ −40% (negative). Fix → positive TWR. Assert TWR > 0 to lock the fix.
func TestHoldingTWRSplitNoPhantomHPR(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 6000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 150}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0, AccountID: accID},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1, AccountID: accID},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 300000, SecurityID: secID, TradeDate: day2, AccountID: accID},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day1, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.holdingTWR(context.Background(), uuid.Nil, holdID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("holdingTWR nil, want non-nil (split folded; 2 cash-flow days day0/day2)")
	}
	// Real gain (current ¥60 > post-split cost basis ¥50) → positive TWR.
	// Bug (split as cut point) yields negative TWR (phantom −50% HPR at split day).
	if *twr <= 0 {
		t.Errorf("holdingTWR = %v, want > 0 (split must not seed phantom HPR; +20%% real gain)", *twr)
	}
}

// TestHoldingTWRSplitLastNeutral: split is the LAST trade. cashFlowDays exclude
// the pure-split day2 → [day0, day1]. lastAfterCF comes from day1 (pre-split
// scale: 50 × ¥100); finalValue is post-split (100 × ¥50). Split market-value
// neutrality (50×10000 == 100×5000) must connect the two scales → cumulative 0%.
//
// GIPS hand-math:
//	cashFlowDays = [day0, day1]                          (day2 pure split excluded)
//	BV_after(day0) = QtyAtDate(day1)×price(day0)       = 100×10000 = 1,000,000
//	subPeriod [day0→day1]: Begin=1,000,000, End=BV_before(day1)=100×10000=1,000,000 → HPR=1.0
//	lastAfterCF = BV_after(day1) = QtyAtDate(day2)×price(day1) = 50×10000 = 500,000 (pre-split)
//	finalValue  = 100(post-split)×5000 = 500,000
//	cumulative = 1.0 × 500,000/500,000 − 1 = 0  ✓
//
// Bug (day2 as cut point): BV_before(day2)=50×5000=250,000 (pre qty × post price)
// → phantom HPR 0.5 → cumulative ≈ −50%. Assert |TWR|<0.01 to lock neutrality.
func TestHoldingTWRSplitLastNeutral(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 5000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0, AccountID: accID},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 500000, SecurityID: secID, TradeDate: day1, AccountID: accID},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day2, AccountID: accID},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day2, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.holdingTWR(context.Background(), uuid.Nil, holdID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("holdingTWR nil, want non-nil (split folded; 2 cash-flow days day0/day1)")
	}
	// Split last + market-value-neutral current (¥50) → cumulative 0%.
	// Bug (split as cut point) → strongly negative (phantom HPR). Assert ~0.
	if *twr > 0.01 || *twr < -0.01 {
		t.Errorf("holdingTWR = %v, want ~0 (split last, market-value-neutral; bug would be strongly negative)", *twr)
	}
}

// TestPortfolioTWRSplitNoPhantomHPR: same scenario at portfolio level — split
// must not seed a phantom sub-period in computeTWR either. rangeStart=day0 →
// rng == full (byte-identical, mirrors TestPortfolioTWRSimple). Both must be > 0.
func TestPortfolioTWRSplitNoPhantomHPR(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 6000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 150}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 300000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day1, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("portfolioTWR full nil, want non-nil (split folded; 2 cash-flow days)")
	}
	if *full <= 0 {
		t.Errorf("portfolioTWR full = %v, want > 0 (split must not seed phantom HPR)", *full)
	}
	if rng == nil {
		t.Fatal("portfolioTWR rng nil when rangeStart == cashFlowDays[0], want non-nil (== full)")
	}
	if diff := *rng - *full; diff > 1e-9 || diff < -1e-9 {
		t.Errorf("rng (%v) != full (%v) when rangeStart == cashFlowDays[0]", *rng, *full)
	}
}
