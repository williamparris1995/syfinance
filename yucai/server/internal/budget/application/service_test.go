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
	return &domain.PaginatedResult[domain.Budget]{Items: []domain.Budget{*r.budget}}, nil
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
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		ID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 200000},
		},
		TotalAmountCents: 200000,
	}}
	// mock entryFunc: 返 debit 50000(¥500 支出), credit 0
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 50000, 0, nil
	}
	svc := NewService(repo, entryFunc)

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
	svc := NewService(repo, nil) // nil entryFunc
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("nil entryFunc: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}

func TestGetBudgetActualsEntryFuncErrGraceful(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month: "2026-07",
		Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 0, 0, fmt.Errorf("boom")
	}
	svc := NewService(repo, entryFunc)
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("should not propagate entryFunc err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("err fallback: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}

func TestGetBudgetByIDComputesActuals(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}}
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 30000, 10000, nil // net 20000
	}
	svc := NewService(repo, entryFunc)
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
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}}
	entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return 80000, 0, nil
	}
	svc := NewService(repo, entryFunc)
	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: uuid.New()})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(res.Budgets) != 1 {
		t.Fatalf("expected 1 budget, got %d", len(res.Budgets))
	}
	// BudgetDTO has no total fields, but item should be filled
	if res.Budgets[0].Items[0].ActualAmountCents != 80000 {
		t.Fatalf("item actual: got %d, want 80000", res.Budgets[0].Items[0].ActualAmountCents)
	}
}
