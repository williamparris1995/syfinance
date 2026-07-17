package application

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
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
	svc := NewService(repo, nil, entryMonthFunc)

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
		Month: "2026-07",
		Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	svc := NewService(repo, nil, nil) // nil entryMonthFunc
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
		Month: "2026-07",
		Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return nil, fmt.Errorf("boom")
	}
	svc := NewService(repo, nil, entryMonthFunc)
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
	svc := NewService(repo, nil, entryMonthFunc)
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
	svc := NewService(repo, nil, entryMonthFunc)
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
	svc := NewService(repo, nil, entryMonthFunc)

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
	svc := NewService(repo, nil, entryMonthFunc)

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
