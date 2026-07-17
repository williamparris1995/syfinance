package application

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
	currencydomain "github.com/yucai/server/internal/currency/domain"
)

// fakeBudgetRepo is an in-memory BudgetRepository for testing.
type fakeBudgetRepo struct {
	budget *domain.Budget
	all    []domain.Budget // FindAll returns this when non-nil (multi-budget batch tests)
	err    error
}

func (r *fakeBudgetRepo) Save(ctx context.Context, budget *domain.Budget) error {
	return r.err
}

func (r *fakeBudgetRepo) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Budget, error) {
	if r.err != nil {
		return nil, r.err
	}
	return r.budget, nil
}

func (r *fakeBudgetRepo) FindByMonth(ctx context.Context, tenantID uuid.UUID, month string) (*domain.Budget, error) {
	if r.err != nil {
		return nil, r.err
	}
	return r.budget, nil
}

func (r *fakeBudgetRepo) FindAll(ctx context.Context, tenantID uuid.UUID, activeOnly bool, page domain.PageRequest) (*domain.PaginatedResult[domain.Budget], error) {
	if r.err != nil {
		return nil, r.err
	}
	items := r.all
	if items == nil && r.budget != nil {
		items = []domain.Budget{*r.budget}
	}
	return &domain.PaginatedResult[domain.Budget]{Items: items}, nil
}

func (r *fakeBudgetRepo) Update(ctx context.Context, budget *domain.Budget) error {
	return r.err
}

func (r *fakeBudgetRepo) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	return r.err
}

func (r *fakeBudgetRepo) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Budget, error) {
	if r.err != nil {
		return nil, r.err
	}
	return []domain.Budget{}, nil
}

func (r *fakeBudgetRepo) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	return r.err
}

func TestGetBudgetComputesActualsReadTime(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 200000},
		},
		TotalAmountCents: 200000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	// batch port: returns the item account's debit/credit (¥500 spend).
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 50000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)

	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 50000 {
		t.Fatalf("item actual: got %d, want 50000", dto.Budget.Items[0].ActualAmountCents)
	}
	if dto.TotalActualCents != 50000 {
		t.Fatalf("total actual: got %d, want 50000", dto.TotalActualCents)
	}
	// usage_pct = 50000/200000*100 = 25
	if dto.UsagePct != 25.0 {
		t.Fatalf("usage_pct: got %f, want 25", dto.UsagePct)
	}
}

func TestGetBudgetActualsNilEntryFuncFallback(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month:            "2026-07",
		Items:            []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	svc := NewService(repo, nil, nil, nil, nil) // nil entryMonthFunc
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("nil entryMonthFunc: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}

func TestGetBudgetActualsEntryFuncErrGraceful(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month:            "2026-07",
		Items:            []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return nil, fmt.Errorf("boom")
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("should not propagate entryMonthFunc err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("err fallback: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}

func TestGetBudgetByIDComputesActuals(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 30000, CreditCents: 10000}}, nil // net 20000
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)
	dto, err := svc.GetBudget(context.Background(), uuid.New(), uuid.New())
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 20000 {
		t.Fatalf("item actual: got %d, want 20000 (debit-credit)", dto.Budget.Items[0].ActualAmountCents)
	}
	if dto.TotalActualCents != 20000 {
		t.Fatalf("total actual: got %d, want 20000", dto.TotalActualCents)
	}
}

func TestListBudgetsComputesActuals(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 80000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)
	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: uuid.New()})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(res.Budgets) != 1 {
		t.Fatalf("expected 1 budget, got %d", len(res.Budgets))
	}
	if res.Budgets[0].Items[0].ActualAmountCents != 80000 {
		t.Fatalf("item actual: got %d, want 80000", res.Budgets[0].Items[0].ActualAmountCents)
	}
}

// TestListBudgets_BatchOneQueryPerDistinctMonth verifies
// computeActualsReadTimeBatch issues exactly one entryMonthFunc call per
// distinct Month across all budgets (not one per budget, not one per item).
// Two July budgets share one query; a June budget triggers exactly one more.
func TestListBudgets_BatchOneQueryPerDistinctMonth(t *testing.T) {
	tenantID := uuid.New()
	calls := 0
	callsByMonth := map[string]int{}
	entryMonthFunc := func(ctx context.Context, tid uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		calls++
		callsByMonth[from.Format("2006-01")]++
		return map[uuid.UUID]EntryTotals{}, nil
	}
	repo := &fakeBudgetRepo{all: []domain.Budget{
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-06", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
	}}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)

	_, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: tenantID})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	// 2 distinct months (2026-06, 2026-07) → exactly 2 calls, NOT 3 (per budget).
	if calls != 2 {
		t.Errorf("entryMonthFunc calls: got %d, want 2 (one per distinct month)", calls)
	}
	if callsByMonth["2026-07"] != 1 || callsByMonth["2026-06"] != 1 {
		t.Errorf("per-month calls: got %+v, want 2026-07=1, 2026-06=1", callsByMonth)
	}
}

// TestListBudgets_BatchFillsActualsFromMap verifies the batch result fills each
// item's ActualAmountCents from the month query's per-account totals
// (debit−credit), and items with no matching account stay 0.
func TestListBudgets_BatchFillsActualsFromMap(t *testing.T) {
	foodAcc := uuid.New()
	transportAcc := uuid.New()
	noDataAcc := uuid.New()
	tenantID := uuid.New()
	entryMonthFunc := func(ctx context.Context, tid uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		if from.Format("2006-01") != "2026-07" {
			return map[uuid.UUID]EntryTotals{}, nil
		}
		return map[uuid.UUID]EntryTotals{
			foodAcc:      {DebitCents: 50000, CreditCents: 5000}, // net 45000
			transportAcc: {DebitCents: 20000, CreditCents: 0},    // net 20000
		}, nil
	}
	repo := &fakeBudgetRepo{all: []domain.Budget{
		{TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: foodAcc},
			{ID: uuid.New(), AccountID: transportAcc},
			{ID: uuid.New(), AccountID: noDataAcc}, // no entry → stays 0
		}},
	}}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)

	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: tenantID})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := res.Budgets[0].Items[0].ActualAmountCents; got != 45000 {
		t.Errorf("food actual: got %d, want 45000 (debit-credit)", got)
	}
	if got := res.Budgets[0].Items[1].ActualAmountCents; got != 20000 {
		t.Errorf("transport actual: got %d, want 20000", got)
	}
	if got := res.Budgets[0].Items[2].ActualAmountCents; got != 0 {
		t.Errorf("no-data item actual: got %d, want 0", got)
	}
}

// TestListBudgets_BatchErrZeroesAllItemsOfFailedMonth verifies the M2 invariant
// restored after M3's single-loop restructure: when entryMonthFunc fails for a
// month, ALL budgets with that month (including the first) get every item's
// ActualAmountCents zeroed (not just the 2nd+ budgets).
func TestListBudgets_BatchErrZeroesAllItemsOfFailedMonth(t *testing.T) {
	tenantID := uuid.New()
	entryMonthFunc := func(ctx context.Context, tid uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return nil, fmt.Errorf("boom")
	}
	repo := &fakeBudgetRepo{all: []domain.Budget{
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07",
			Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New(), ActualAmountCents: 99999}}}, // first budget, non-zero stored
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07",
			Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New(), ActualAmountCents: 88888}}}, // second budget
	}}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil)

	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: tenantID})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	for i, b := range res.Budgets {
		for j, it := range b.Items {
			if it.ActualAmountCents != 0 {
				t.Errorf("budget[%d].items[%d].actual: got %d, want 0 (failed month must zero ALL budgets incl first)", i, j, it.ActualAmountCents)
			}
		}
	}
}

// --- M3 multi-currency conversion tests (fake rateRepo/accountCur ports) ---

// fakeAccountCur implements domain.AccountCurrencySource from a static map.
type fakeAccountCur struct {
	codes map[uuid.UUID]string
	err   error
}

func (f *fakeAccountCur) CurrencyCodes(_ context.Context, _ uuid.UUID) (map[uuid.UUID]string, error) {
	return f.codes, f.err
}

// fakeRateRepo implements currencydomain.RateHistoryRepository from a static
// code->rate map (照 networth fakeRateRepo). Missing code -> 1.0.
type fakeRateRepo struct {
	rates map[string]float64
}

func (r *fakeRateRepo) FindRate(_ context.Context, code string, _ time.Time) (float64, error) {
	if v, ok := r.rates[code]; ok {
		return v, nil
	}
	return 1.0, nil
}

func (r *fakeRateRepo) FindRange(_ context.Context, _ string, _, _ time.Time) ([]currencydomain.RateHistory, error) {
	return nil, nil
}

func (r *fakeRateRepo) Save(_ context.Context, _ currencydomain.RateHistory) error { return nil }

// TestComputeActuals_MultiCurrencyConverts verifies M3: a budget in CNY with
// an item on a USD account has its actuals (USD cents) converted to CNY via
// ConvertToBase (usdCents × rateUSD / rateCNY).
func TestComputeActuals_MultiCurrencyConverts(t *testing.T) {
	usdAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: usdAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	// entryMonthFunc returns 10000 USD cents (debit) on the USD account.
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{usdAcc: {DebitCents: 10000, CreditCents: 0}}, nil
	}
	accountCur := &fakeAccountCur{codes: map[uuid.UUID]string{usdAcc: "USD"}}
	rateRepo := &fakeRateRepo{rates: map[string]float64{"CNY": 1.0, "USD": 7.0}} // 1 USD = 7 CNY
	svc := NewService(repo, nil, entryMonthFunc, rateRepo, accountCur)

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	// 10000 USD × 7 / 1 = 70000 CNY
	if got := dto.Budget.Items[0].ActualAmountCents; got != 70000 {
		t.Errorf("multi-currency actual: got %d, want 70000 (10000 USD × 7)", got)
	}
}

// TestComputeActuals_SameCurrencyNoConvert verifies the optimization: when the
// item's account currency == budget currency, no conversion happens (raw cents).
func TestComputeActuals_SameCurrencyNoConvert(t *testing.T) {
	cnyAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: cnyAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{cnyAcc: {DebitCents: 50000, CreditCents: 0}}, nil
	}
	accountCur := &fakeAccountCur{codes: map[uuid.UUID]string{cnyAcc: "CNY"}}
	rateRepo := &fakeRateRepo{rates: map[string]float64{"CNY": 1.0}}
	svc := NewService(repo, nil, entryMonthFunc, rateRepo, accountCur)

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := dto.Budget.Items[0].ActualAmountCents; got != 50000 {
		t.Errorf("same-currency actual: got %d, want 50000 (raw, no conversion)", got)
	}
}

// TestComputeActuals_NilPortsRawBehavior verifies nil rateRepo/accountCur
// preserves M2 behavior (no conversion, raw account-currency cents).
func TestComputeActuals_NilPortsRawBehavior(t *testing.T) {
	usdAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: usdAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{usdAcc: {DebitCents: 10000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil) // nil ports

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := dto.Budget.Items[0].ActualAmountCents; got != 10000 {
		t.Errorf("nil-port actual: got %d, want 10000 (M2 raw, no conversion)", got)
	}
}
