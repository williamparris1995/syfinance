package application

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// FR-2:主指标语义常量填充——XIRR 主指标 + CAGR 口径标注(audit 06 决策 1)。
func TestGetPortfolioPerformanceFillsPrimaryMetricSemantics(t *testing.T) {
	tenantID, accountID, secID, holdingID := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	day := truncateToDate(time.Now())
	snapRepo := &memSnapshotRepo{saved: []domain.HoldingSnapshot{
		{TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
			SnapshotDate: day, MarketValueCents: 10000, CurrencyCode: "CNY"},
	}}
	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -1),
	})
	svc := NewService(newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 168},
	}), hr, &memTradeRepo{})
	svc.SetSnapshotRepository(snapRepo)
	svc.SetRateHistoryRepository(&fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}})

	for _, bench := range []bool{false, true} {
		perf, err := svc.GetPortfolioPerformance(context.Background(), tenantID, &accountID, "DAY", bench, "CNY")
		if err != nil {
			t.Fatalf("GetPortfolioPerformance(bench=%v) error: %v", bench, err)
		}
		if perf.PrimaryReturnMetric != ReturnMetricXIRR {
			t.Errorf("PrimaryReturnMetric = %v (bench=%v), want ReturnMetricXIRR", perf.PrimaryReturnMetric, bench)
		}
		if perf.CagrScope != CagrScopeCurrentHoldingsCostToMV {
			t.Errorf("CagrScope = %v (bench=%v), want CagrScopeCurrentHoldingsCostToMV", perf.CagrScope, bench)
		}
	}
}

// 本地枚举与 pb 枚举值序对齐守卫(review 建议):handler 直转依赖此契约,
// 漂移必须在此失败而非 wire 上静默错值。
func TestLocalEnumValuesMatchProto(t *testing.T) {
	if int(ReturnMetricXIRR) != 1 || int(CagrScopeCurrentHoldingsCostToMV) != 1 {
		t.Fatalf("local enum drift: XIRR=%d CagrScope=%d, want 1/1", int(ReturnMetricXIRR), int(CagrScopeCurrentHoldingsCostToMV))
	}
}
