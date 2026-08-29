package application

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// F5:金额规则单点 helper——四舍五入,不截断。
func TestTradeAmountCentsRoundsNotTruncates(t *testing.T) {
	// 999 × 0.5 = 499.5:截断 499(F5 病灶),四舍五入 500。
	if got := TradeAmountCents(999, 0.5); got != 500 {
		t.Errorf("TradeAmountCents(999, 0.5) = %d, want 500 (round, not truncate)", got)
	}
	if got := TradeAmountCents(10000, 3.335); got != 33350 {
		t.Errorf("TradeAmountCents(10000, 3.335) = %d, want 33350", got)
	}
	if got := TradeAmountCents(1234, 0.0004); got != 0 {
		t.Errorf("TradeAmountCents(1234, 0.0004) = %d, want 0 (rounds below half)", got)
	}
}

// spyHoldingRepo 统计 SaveOrUpdate 调用次数(证明 split 守卫先于任何持久化)。
type spyHoldingRepo struct {
	fakeHoldingRepoSingle
	saves int
}

func (r *spyHoldingRepo) SaveOrUpdate(_ context.Context, _ *domain.Holding) error {
	r.saves++
	return nil
}

// F12:ratio≤0 → InvalidArgument 语义拒绝,fail-closed(零持久化)。
func TestRecordSplitRejectsNonPositiveRatioBeforePersisting(t *testing.T) {
	secID := uuid.New()
	accID := uuid.New()
	for _, ratio := range []float64{0, -1, -0.5} {
		repo := &spyHoldingRepo{fakeHoldingRepoSingle: fakeHoldingRepoSingle{
			h: domain.Holding{AccountID: accID, SecurityID: secID, Quantity: 100},
		}}
		svc := &Service{
			securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY"}},
			holdingRepo:  repo,
			tradeRepo:    &fakeTradeRepo{},
			rateRepo:     &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
		}
		_, err := svc.RecordSplit(context.Background(), RecordSplitRequest{
			TenantID:   uuid.Nil,
			AccountID:  accID,
			SecurityID: secID,
			Ratio:      ratio,
			SplitDate:  time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC),
		})
		if err == nil {
			t.Fatalf("ratio %v: want error, got nil", ratio)
		}
		if want := "invalid"; !containsStr(err.Error(), want) {
			t.Errorf("ratio %v: error %q should carry invalid-argument semantics (contains %q)", ratio, err.Error(), want)
		}
		if repo.saves != 0 {
			t.Errorf("ratio %v: holding persisted %d times, want 0 (guard must precede persistence)", ratio, repo.saves)
		}
	}
}

func containsStr(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
