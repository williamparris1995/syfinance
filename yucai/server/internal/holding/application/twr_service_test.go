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
