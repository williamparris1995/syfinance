package application

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	currencydomain "github.com/yucai/server/internal/currency/domain"
)

// --- fake source ports (map[code]int64) ---

type fakeAccountSource struct {
	balances map[string]int64
	err      error
}

func (f *fakeAccountSource) SumBalancesByCurrency(_ context.Context, _ uuid.UUID) (map[string]int64, error) {
	return f.balances, f.err
}

type fakeHoldingSource struct {
	mv  map[string]int64
	err error
}

func (f *fakeHoldingSource) SumMarketValueByCurrency(_ context.Context, _ uuid.UUID) (map[string]int64, error) {
	return f.mv, f.err
}

type fakeDebtSource struct {
	remaining map[string]int64
	err       error
}

func (f *fakeDebtSource) SumRemainingByCurrency(_ context.Context, _ uuid.UUID) (map[string]int64, error) {
	return f.remaining, f.err
}

// fakeRateRepo serves FindRate from a (code,date)-insensitive map keyed by code.
// CNY defaults to 1.0 (base); USD=7.0 (1 USD = 7 CNY). Missing code → 1.0.
type fakeRateRepo struct {
	rateByCode map[string]float64
}

func (r *fakeRateRepo) FindRate(_ context.Context, code string, _ time.Time) (float64, error) {
	if v, ok := r.rateByCode[code]; ok {
		return v, nil
	}
	return 1.0, nil
}

func (r *fakeRateRepo) FindRange(_ context.Context, _ string, _, _ time.Time) ([]currencydomain.RateHistory, error) {
	return nil, nil
}

func (r *fakeRateRepo) Save(_ context.Context, _ currencydomain.RateHistory) error { return nil }

// --- tests ---

// TestGetNetWorthMultiCurrencyBaseCNY: account CNY 10000 + holding USD 1000 mv +
// debt CNY 5000, base CNY → assets = 10000 + 1000×7 = 17000; liab = 5000;
// net = 12000.
func TestGetNetWorthMultiCurrencyBaseCNY(t *testing.T) {
	acc := &fakeAccountSource{balances: map[string]int64{"CNY": 10000}}
	hld := &fakeHoldingSource{mv: map[string]int64{"USD": 1000}}
	dbt := &fakeDebtSource{remaining: map[string]int64{"CNY": 5000}}
	rate := &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0, "USD": 7.0}}

	svc := NewService(acc, hld, dbt, rate, nil)
	res, err := svc.GetNetWorth(context.Background(), uuid.New(), "CNY")
	if err != nil {
		t.Fatalf("GetNetWorth: unexpected error: %v", err)
	}
	if res.TotalAssetsCents != 17000 {
		t.Errorf("assets: got %d, want 17000", res.TotalAssetsCents)
	}
	if res.TotalLiabilitiesCents != 5000 {
		t.Errorf("liabilities: got %d, want 5000", res.TotalLiabilitiesCents)
	}
	if res.NetWorthCents != 12000 {
		t.Errorf("net worth: got %d, want 12000", res.NetWorthCents)
	}
	if res.Currency != "CNY" {
		t.Errorf("currency: got %q, want CNY", res.Currency)
	}
}

// TestGetNetWorthBaseUSD: same sources, base USD → assets = 10000/7 + 1000 =
// 2429; liab = 5000/7 = 714; net = 1715.
func TestGetNetWorthBaseUSD(t *testing.T) {
	acc := &fakeAccountSource{balances: map[string]int64{"CNY": 10000}}
	hld := &fakeHoldingSource{mv: map[string]int64{"USD": 1000}}
	dbt := &fakeDebtSource{remaining: map[string]int64{"CNY": 5000}}
	rate := &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0, "USD": 7.0}}

	svc := NewService(acc, hld, dbt, rate, nil)
	res, err := svc.GetNetWorth(context.Background(), uuid.New(), "USD")
	if err != nil {
		t.Fatalf("GetNetWorth: unexpected error: %v", err)
	}
	// Each line is converted with math.Round individually then summed:
	//   account CNY: round(10000 × 1 / 7) = round(1428.57) = 1429
	//   holding USD: round(1000 × 7 / 7)  = 1000
	//   → assets = 2429
	if res.TotalAssetsCents != 2429 {
		t.Errorf("assets: got %d, want 2429", res.TotalAssetsCents)
	}
	//   debt CNY:    round(5000 × 1 / 7)  = round(714.28) = 714
	if res.TotalLiabilitiesCents != 714 {
		t.Errorf("liabilities: got %d, want 714", res.TotalLiabilitiesCents)
	}
	if res.NetWorthCents != 2429-714 {
		t.Errorf("net worth: got %d, want %d", res.NetWorthCents, 2429-714)
	}
	if res.Currency != "USD" {
		t.Errorf("currency: got %q, want USD", res.Currency)
	}
}

// TestGetNetWorthBaseDefaultsToCNY: empty baseCurrency → CNY.
func TestGetNetWorthBaseDefaultsToCNY(t *testing.T) {
	acc := &fakeAccountSource{balances: map[string]int64{"CNY": 1000}}
	hld := &fakeHoldingSource{mv: map[string]int64{}}
	dbt := &fakeDebtSource{remaining: map[string]int64{}}
	rate := &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}}

	svc := NewService(acc, hld, dbt, rate, nil)
	res, err := svc.GetNetWorth(context.Background(), uuid.New(), "")
	if err != nil {
		t.Fatalf("GetNetWorth: unexpected error: %v", err)
	}
	if res.Currency != "CNY" {
		t.Errorf("empty base → currency: got %q, want CNY", res.Currency)
	}
	if res.TotalAssetsCents != 1000 {
		t.Errorf("assets: got %d, want 1000", res.TotalAssetsCents)
	}
}

// TestGetNetWorthBestEffortSkipFailedPort: account port errors → skipped,
// holding + debt still contribute.
func TestGetNetWorthBestEffortSkipFailedPort(t *testing.T) {
	acc := &fakeAccountSource{err: context.DeadlineExceeded} // simulates failure
	hld := &fakeHoldingSource{mv: map[string]int64{"USD": 1000}}
	dbt := &fakeDebtSource{remaining: map[string]int64{"CNY": 5000}}
	rate := &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0, "USD": 7.0}}

	svc := NewService(acc, hld, dbt, rate, nil)
	res, err := svc.GetNetWorth(context.Background(), uuid.New(), "CNY")
	if err != nil {
		t.Fatalf("GetNetWorth: best-effort must not return error: %v", err)
	}
	// account skipped → assets from holding only: 1000 × 7 = 7000
	if res.TotalAssetsCents != 7000 {
		t.Errorf("assets (account skipped): got %d, want 7000", res.TotalAssetsCents)
	}
	// debt intact: 5000
	if res.TotalLiabilitiesCents != 5000 {
		t.Errorf("liabilities: got %d, want 5000", res.TotalLiabilitiesCents)
	}
	if res.NetWorthCents != 7000-5000 {
		t.Errorf("net worth: got %d, want %d", res.NetWorthCents, 7000-5000)
	}
}

// TestGetNetWorthNilRateRepoNoConversion: nil rateRepo → all amounts raw
// (rate defaults to 1.0 → ConvertToBase returns amount unchanged).
func TestGetNetWorthNilRateRepoNoConversion(t *testing.T) {
	acc := &fakeAccountSource{balances: map[string]int64{"CNY": 10000}}
	hld := &fakeHoldingSource{mv: map[string]int64{"USD": 1000}} // not converted
	dbt := &fakeDebtSource{remaining: map[string]int64{}}

	svc := NewService(acc, hld, dbt, nil, nil)
	res, err := svc.GetNetWorth(context.Background(), uuid.New(), "CNY")
	if err != nil {
		t.Fatalf("GetNetWorth: unexpected error: %v", err)
	}
	// No conversion: assets = 10000 + 1000 = 11000 (raw, mixed currencies)
	if res.TotalAssetsCents != 11000 {
		t.Errorf("assets (no conversion): got %d, want 11000", res.TotalAssetsCents)
	}
}
