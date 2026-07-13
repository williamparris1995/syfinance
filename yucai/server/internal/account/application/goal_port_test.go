package application

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// --- Task 5: GetAccountsBalance (goal.AccountBalanceSource) ---

// errAccountRepo wraps filterAccountRepo and returns an error for the seeded
// "errorID", exercising the err != nil skip branch (filterAccountRepo only
// covers the (nil,nil) missing branch).
type errAccountRepo struct {
	inner   *filterAccountRepo
	errorID uuid.UUID
}

func (e *errAccountRepo) Save(ctx context.Context, a *domain.Account) error {
	return e.inner.Save(ctx, a)
}
func (e *errAccountRepo) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Account, error) {
	if id == e.errorID {
		return nil, fmt.Errorf("simulated repo failure")
	}
	return e.inner.FindByID(ctx, tenantID, id)
}
func (e *errAccountRepo) FindAll(ctx context.Context, tenantID uuid.UUID, f domain.AccountFilter, p domain.PageRequest) (*domain.PaginatedResult[domain.Account], error) {
	return e.inner.FindAll(ctx, tenantID, f, p)
}
func (e *errAccountRepo) FindByAccountType(ctx context.Context, tenantID uuid.UUID, t domain.AccountType) ([]domain.Account, error) {
	return e.inner.FindByAccountType(ctx, tenantID, t)
}
func (e *errAccountRepo) Update(ctx context.Context, a *domain.Account) error {
	return e.inner.Update(ctx, a)
}
func (e *errAccountRepo) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	return e.inner.SoftDelete(ctx, tenantID, id)
}
func (e *errAccountRepo) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Account, error) {
	return e.inner.FindAllForBackup(ctx, tenantID)
}
func (e *errAccountRepo) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	return e.inner.DeleteByTenant(ctx, tenantID)
}

var _ domain.AccountRepository = (*errAccountRepo)(nil)

// TestGetAccountsBalance_SumsAndSkipsMissing verifies:
//   - Σ CurrentBalanceCents across the given accountIDs;
//   - a missing account (FindByID returns nil,nil) is skipped, not fatal;
//   - a FindByID error is also skipped (best-effort);
//   - tenant scoping (other tenant's account excluded by repo).
func TestGetAccountsBalance_SumsAndSkipsMissing(t *testing.T) {
	tenant := uuid.New()
	repo := newFilterAccountRepo()

	seed := func(name string, code string, bal int64) *domain.Account {
		a, err := domain.NewAccount(tenant, name, domain.AccountTypeAsset, code)
		if err != nil {
			t.Fatalf("new account: %v", err)
		}
		a.CurrentBalanceCents = bal
		_ = repo.Save(context.Background(), a)
		return a
	}
	a1 := seed("savings", "CNY", 1000)
	a2 := seed("invest", "CNY", 2500)
	a3 := seed("usd", "USD", 800)

	// missingID never seeded → FindByID returns (nil, nil).
	missingID := uuid.New()
	// errorID triggers a repo error via the wrapper.
	errorID := uuid.New()
	wrapped := &errAccountRepo{inner: repo, errorID: errorID}

	svc := NewService(wrapped, newMockChartRepo())
	got, err := svc.GetAccountsBalance(context.Background(), tenant,
		[]uuid.UUID{a1.ID, a2.ID, a3.ID, missingID, errorID})
	if err != nil {
		t.Fatalf("GetAccountsBalance error: %v", err)
	}
	// Only a1 + a2 + a3 contribute (1000 + 2500 + 800 = 4300); missing + error skipped.
	if got != 4300 {
		t.Errorf("sum = %d, want 4300 (missing + error skipped)", got)
	}
}

// TestGetAccountsBalance_EmptyIDs verifies an empty accountIDs slice returns 0.
func TestGetAccountsBalance_EmptyIDs(t *testing.T) {
	svc := NewService(newFilterAccountRepo(), newMockChartRepo())
	got, err := svc.GetAccountsBalance(context.Background(), uuid.New(), nil)
	if err != nil {
		t.Fatalf("GetAccountsBalance error: %v", err)
	}
	if got != 0 {
		t.Errorf("sum = %d, want 0 for empty accountIDs", got)
	}
}
