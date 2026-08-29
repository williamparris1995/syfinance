package application

import (
	"context"
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// fakePriceRepoDated 按日期返回 ≤ 查询日的最新价格(分段 TWR 需要时变价格)。
type fakePriceRepoDated struct {
	entries []domain.SecurityPriceHistory // 按 PriceDate 升序喂入
}

func (r *fakePriceRepoDated) FindBySecurity(_ context.Context, _ uuid.UUID, _, to time.Time) ([]domain.SecurityPriceHistory, error) {
	var out []domain.SecurityPriceHistory
	for _, e := range r.entries {
		if !e.PriceDate.After(to) {
			out = append(out, e)
		}
	}
	return out, nil
}
func (r *fakePriceRepoDated) FindAtOrBefore(_ context.Context, _ uuid.UUID, at time.Time) (int64, bool) {
	latest := int64(-1)
	found := false
	var best time.Time
	for _, e := range r.entries {
		if !e.PriceDate.After(at) && (!found || e.PriceDate.After(best)) {
			latest, found, best = e.PriceCents, true, e.PriceDate
		}
	}
	return latest, found
}
func (r *fakePriceRepoDated) SaveAll(_ context.Context, _ []domain.SecurityPriceHistory) error { return nil }
func (r *fakePriceRepoDated) Save(_ context.Context, _ domain.SecurityPriceHistory) error      { return nil }
func (r *fakePriceRepoDated) Exists(_ context.Context, _ uuid.UUID) (bool, error)              { return true, nil }

func dseg(s string) time.Time {
	t, _ := time.Parse("2006-01-02", s)
	return t
}

// F6 主用例:中途完全清仓 → 重建。GIPS 分段链乘。
//
//	d0(01-01)买 100@10000;d10(01-11)清仓 100(价 11000);d40(02-10)重建 买 50@20000;
//	now=03-11,现价 22000。
//	段1:{1,000,000→1,100,000} HPR 1.1,终止尾因子 1,10 天;
//	段2:空 subs,尾 1,100,000/1,000,000=1.1,30 天;
//	链乘 1.21 → cum 0.21,totalDays 40 → 年化 1.21^(365/40)−1。
func TestPortfolioTWRLiquidationRebuildSegments(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 22000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 50, AvgCostCents: 20000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-01-01")},
			{TradeType: domain.TradeTypeSell, Quantity: 100, AmountCents: 1100000, SecurityID: secID, TradeDate: dseg("2020-01-11")},
			{TradeType: domain.TradeTypeBuy, Quantity: 50, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-02-10")},
		}},
		priceHistoryRepo: &fakePriceRepoDated{entries: []domain.SecurityPriceHistory{
			{SecurityID: secID, PriceDate: dseg("2020-01-01"), PriceCents: 10000},
			{SecurityID: secID, PriceDate: dseg("2020-01-11"), PriceCents: 11000},
			{SecurityID: secID, PriceDate: dseg("2020-02-10"), PriceCents: 20000},
		}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	svc.SetNow(func() time.Time { return dseg("2020-03-11") })

	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", dseg("2020-01-21"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full TWR nil after liquidation+rebuild, want segmented chain value (F6)")
	}
	wantFull := math.Pow(1.21, 365.0/40.0) - 1
	if math.Abs(*full-wantFull) > 1e-9 {
		t.Errorf("full TWR = %.9f, want %.9f (segmented chain 1.1×1.1, 40d)", *full, wantFull)
	}
	// range 起点落在空仓 gap(01-21)→ 链应从重建日重启:cum 0.10,30 天。
	if rng == nil {
		t.Fatal("range TWR nil when rangeStart inside liquidation gap, want rebuild-restarted chain")
	}
	wantRng := math.Pow(1.10, 365.0/30.0) - 1
	if math.Abs(*rng-wantRng) > 1e-9 {
		t.Errorf("range TWR = %.9f, want %.9f (rebuild-restarted 1.1, 30d)", *rng, wantRng)
	}
}

// 终态完全清仓:链终止于清仓日(GIPS discontinued),不乘 0 → 不返 -100%。
//
//	d0 买 100@10000;d20(01-21)清仓(价 12000);now=02-20。
//	段:{1,000,000→1,200,000} HPR 1.2,终止,20 天 → 1.2^(365/20)−1。
func TestPortfolioTWRTerminateAtFinalLiquidation(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 12000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 0, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-01-01")},
			{TradeType: domain.TradeTypeSell, Quantity: 100, AmountCents: 1200000, SecurityID: secID, TradeDate: dseg("2020-01-21")},
		}},
		priceHistoryRepo: &fakePriceRepoDated{entries: []domain.SecurityPriceHistory{
			{SecurityID: secID, PriceDate: dseg("2020-01-01"), PriceCents: 10000},
			{SecurityID: secID, PriceDate: dseg("2020-01-21"), PriceCents: 12000},
		}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	svc.SetNow(func() time.Time { return dseg("2020-02-20") })

	full, _, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", dseg("2020-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full TWR nil after final liquidation, want terminated-track value (not -100%)")
	}
	want := math.Pow(1.2, 365.0/20.0) - 1
	if math.Abs(*full-want) > 1e-9 {
		t.Errorf("full TWR = %.9f, want %.9f (terminated track 1.2, 20d)", *full, want)
	}
}

// 坏价边界:qty>0 但 MV=0(价格拍到 0)→ sentinel 降级 nil,
// 不美化成终止、不返误导性 -100%(旧实现 product×0 → cum −1)。
func TestPortfolioTWRZeroMVWithOpenQuantityDegrades(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 150, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-01-01")},
			{TradeType: domain.TradeTypeBuy, Quantity: 50, AmountCents: 500000, SecurityID: secID, TradeDate: dseg("2020-01-11")},
		}},
		priceHistoryRepo: &fakePriceRepoDated{entries: []domain.SecurityPriceHistory{
			{SecurityID: secID, PriceDate: dseg("2020-01-01"), PriceCents: 10000},
			{SecurityID: secID, PriceDate: dseg("2020-01-11"), PriceCents: 0}, // 坏价
		}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	svc.SetNow(func() time.Time { return dseg("2020-01-21") })

	full, _, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", dseg("2020-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full != nil {
		t.Fatalf("full TWR = %v with open quantity at zero MV, want nil (data-issue sentinel)", *full)
	}
}

// 当日全额换手(buy+sell 同日净 0)后隔日重建:零时长 track 被丢弃,
// 链从重建日起,恒价 → TWR ≈ 0。
func TestPortfolioTWRSameDayRotationThenRebuild(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 10000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 10, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-01-01")},
			{TradeType: domain.TradeTypeSell, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: dseg("2020-01-01")},
			{TradeType: domain.TradeTypeBuy, Quantity: 10, AmountCents: 100000, SecurityID: secID, TradeDate: dseg("2020-01-06")},
		}},
		priceHistoryRepo: &fakePriceRepoDated{entries: []domain.SecurityPriceHistory{
			{SecurityID: secID, PriceDate: dseg("2020-01-01"), PriceCents: 10000},
		}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	svc.SetNow(func() time.Time { return dseg("2020-01-16") })

	full, _, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", dseg("2020-01-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full TWR nil after same-day rotation + rebuild, want ~0 (zero-duration track dropped)")
	}
	if math.Abs(*full) > 1e-9 {
		t.Errorf("full TWR = %v, want ~0 (constant price, rebuild-only track)", *full)
	}
}
