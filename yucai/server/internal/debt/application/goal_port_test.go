package application

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
)

// --- Task 5: GetDebtsPaid (goal.DebtProgressSource) ---

// TestGetDebtsPaid_SumsAndSkipsMissing verifies:
//   - paid amount = TotalPrincipalCents − RemainingPrincipal per debt, Σ'd;
//   - a missing debt (FindByID error) is skipped, not fatal;
//   - tenant scoping (other tenant's debt excluded by repo).
func TestGetDebtsPaid_SumsAndSkipsMissing(t *testing.T) {
	tenant := uuid.New()
	acc := uuid.New()
	repo := newPagedDebtRepo()

	// seedDebt(total, principalPaid): marks Schedule[0] paid with PrincipalCents
	// = principalPaid, so paid amount = principalPaid (RemainingPrincipal =
	// total − principalPaid).
	// d1: total 1000, paid 200.
	d1 := seedDebt(t, tenant, acc, 1000, 200)
	// d2: total 5000, paid 0.
	d2 := seedDebt(t, tenant, acc, 5000, 0)
	// d3: total 3000, paid 1000.
	d3 := seedDebt(t, tenant, acc, 3000, 1000)
	_ = repo.Save(context.Background(), d1)
	_ = repo.Save(context.Background(), d2)
	_ = repo.Save(context.Background(), d3)

	// missingID never seeded → FindByID returns error.
	missingID := uuid.New()

	svc := NewService(repo)
	got, err := svc.GetDebtsPaid(context.Background(), tenant,
		[]uuid.UUID{d1.ID, d2.ID, d3.ID, missingID})
	if err != nil {
		t.Fatalf("GetDebtsPaid error: %v", err)
	}
	// 200 + 0 + 1000 = 1200; missing skipped.
	if got != 1200 {
		t.Errorf("paid sum = %d, want 1200 (missing skipped)", got)
	}
}

// TestGetDebtsPaid_TenantScoping verifies the repo enforces tenant isolation:
// a debt belonging to another tenant is not found under this tenant's call
// (pagedDebtRepo.FindByID returns an error on tenant mismatch).
func TestGetDebtsPaid_TenantScoping(t *testing.T) {
	tenant := uuid.New()
	otherTenant := uuid.New()
	acc := uuid.New()
	repo := newPagedDebtRepo()

	d := seedDebt(t, otherTenant, acc, 999999, 0)
	_ = repo.Save(context.Background(), d)

	svc := NewService(repo)
	got, err := svc.GetDebtsPaid(context.Background(), tenant, []uuid.UUID{d.ID})
	if err != nil {
		t.Fatalf("GetDebtsPaid error: %v", err)
	}
	if got != 0 {
		t.Errorf("paid sum = %d, want 0 (other tenant's debt excluded)", got)
	}
}

// TestGetDebtsPaid_EmptyIDs verifies an empty debtIDs slice returns 0.
func TestGetDebtsPaid_EmptyIDs(t *testing.T) {
	svc := NewService(newPagedDebtRepo())
	got, err := svc.GetDebtsPaid(context.Background(), uuid.New(), nil)
	if err != nil {
		t.Fatalf("GetDebtsPaid error: %v", err)
	}
	if got != 0 {
		t.Errorf("paid sum = %d, want 0 for empty debtIDs", got)
	}
}

// TestGetDebtsPaid_FullyPaidDebt verifies a fully-paid debt (RemainingPrincipal
// = 0) contributes its full original principal as paid.
func TestGetDebtsPaid_FullyPaidDebt(t *testing.T) {
	tenant := uuid.New()
	acc := uuid.New()
	repo := newPagedDebtRepo()

	d, err := domain.NewDebtDetails(
		tenant, acc, "Lender", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
		4000, domain.BorrowedIn, "",
		"", "", nil,"", "",

	)
	if err != nil {
		t.Fatalf("new debt: %v", err)
	}
	d.GenerateSchedule()
	// Mark every schedule entry paid with its full principal so the sum of paid
	// PrincipalCents equals TotalPrincipalCents (RemainingPrincipal = 0). We
	// redistribute the total across entries proportionally so the math is exact
	// regardless of the amortization method's principal split.
	if len(d.Schedule) == 0 {
		t.Fatalf("no schedule entries")
	}
	per := int64(4000 / len(d.Schedule))
	rem := int64(4000) - per*int64(len(d.Schedule))
	for i := range d.Schedule {
		d.Schedule[i].PrincipalCents = per
		d.Schedule[i].Paid = true
		d.Schedule[i].PaidCents = d.Schedule[i].TotalCents
	}
	d.Schedule[len(d.Schedule)-1].PrincipalCents += rem
	_ = repo.Save(context.Background(), d)

	svc := NewService(repo)
	got, err := svc.GetDebtsPaid(context.Background(), tenant, []uuid.UUID{d.ID})
	if err != nil {
		t.Fatalf("GetDebtsPaid error: %v", err)
	}
	if got != 4000 {
		t.Errorf("paid sum = %d, want 4000 (fully paid → full principal)", got)
	}
}
