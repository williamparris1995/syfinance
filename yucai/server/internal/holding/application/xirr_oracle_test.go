package application

import (
	"context"
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// FR-7 真实样本 e2e:1e8 cents 量级经 service 屘真实取数(collectTradeCashFlows +
// currentMarketValueInBase,非 mock 现金流)→ XIRR 收敛于闭式解。
// 2024-01-01 投入 1e8,2024-12-31(恰 365 天)终值 1.1e8 → 年化精确 10%。
func TestPortfolioXIRRLargeCashFlowsEndToEnd(t *testing.T) {
	secID := uuid.New()
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 11000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 10000, AvgCostCents: 10000}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 10000, AmountCents: 100000000, SecurityID: secID, TradeDate: dseg("2024-01-01")},
		}},
		priceHistoryRepo: &fakePriceRepoDated{entries: []domain.SecurityPriceHistory{
			{SecurityID: secID, PriceDate: dseg("2024-01-01"), PriceCents: 10000},
		}},
		rateRepo: &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	svc.SetNow(func() time.Time { return dseg("2024-12-31") })

	full, _, err := svc.portfolioXIRR(context.Background(), uuid.Nil, nil, "CNY", dseg("2024-06-01"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("full XIRR nil at 1e8 cents magnitude, want converged value (F3)")
	}
	if math.Abs(*full-0.10) > 1e-6 {
		t.Errorf("full XIRR = %.9f, want ~0.10 (1e8 → 1.1e8 over exactly 365d)", *full)
	}
}
