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
// 本测:2 buy(buy day0 + buy day1)→ 1 子区间。
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
	twr, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("portfolioTWR nil, want non-nil (price constant → TWR ~0)")
	}
	// price 恒定(10000),无市场变化 → TWR ≈ 0(只有现金流,无收益)
	if *twr > 0.01 || *twr < -0.01 {
		t.Errorf("TWR = %v, want ~0 (constant price)", *twr)
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

// 无 trade → nil
func TestPortfolioTWRNoTrades(t *testing.T) {
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{}, holdingRepo: &fakeHoldingRepoSingle{},
		tradeRepo: &fakeTradeRepo{items: nil}, priceHistoryRepo: &fakePriceRepo{priceCents: 0},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY")
	if err != nil || twr != nil {
		t.Errorf("no trades: twr=%v err=%v, want nil/nil", twr, err)
	}
}
