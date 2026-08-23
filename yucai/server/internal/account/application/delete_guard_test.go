package application

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// stubRefSource is a canned AccountReferenceSource for guard tests.
type stubRefSource struct {
	name  string
	count int64
	err   error
}

func (s stubRefSource) AccountReferenceSourceName() string { return s.name }
func (s stubRefSource) CountAccountReferences(_ context.Context, _, _ uuid.UUID) (int64, error) {
	return s.count, s.err
}

func seedDeletableAccount(t *testing.T, repo *mockAccountRepo, tenant uuid.UUID) *domain.Account {
	t.Helper()
	a := mustNewAccount(t, tenant, "guard probe", domain.AccountTypeAsset)
	if err := repo.Save(context.Background(), a); err != nil {
		t.Fatalf("seed account: %v", err)
	}
	return a
}

// Referenced accounts are refused with a caller-presentable reason naming the
// referencing module.
func TestDeleteAccount_RejectsReferencedAccount(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenant := uuid.New()
	acct := seedDeletableAccount(t, repo, tenant)
	svc.SetAccountReferenceSources([]domain.AccountReferenceSource{
		stubRefSource{name: "transaction", count: 0},
		stubRefSource{name: "budget", count: 3},
	})

	err := svc.DeleteAccount(context.Background(), tenant, acct.ID)
	if err == nil {
		t.Fatal("expected rejection for referenced account")
	}
	if !strings.Contains(err.Error(), "referenced by 3 budget record(s)") {
		t.Errorf("unexpected error: %v", err)
	}
}

// A counting failure must fail closed (refuse deletion), never fall through.
func TestDeleteAccount_FailsClosedOnCountError(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenant := uuid.New()
	acct := seedDeletableAccount(t, repo, tenant)
	svc.SetAccountReferenceSources([]domain.AccountReferenceSource{
		stubRefSource{name: "transaction", err: errors.New("db down")},
	})

	if err := svc.DeleteAccount(context.Background(), tenant, acct.ID); err == nil {
		t.Fatal("expected fail-closed rejection on count error")
	}
}

// Missing wiring (no sources injected) must refuse deletion — a silently
// unwired guard would recreate the orphan behavior this feature removes.
func TestDeleteAccount_FailsClosedWithoutSources(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenant := uuid.New()
	acct := seedDeletableAccount(t, repo, tenant)

	err := svc.DeleteAccount(context.Background(), tenant, acct.ID)
	if err == nil || !strings.Contains(err.Error(), "reference sources not configured") {
		t.Fatalf("expected not-configured rejection, got: %v", err)
	}
}

// Unreferenced account deletes normally once sources are wired.
func TestDeleteAccount_AllowsUnreferenced(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenant := uuid.New()
	acct := seedDeletableAccount(t, repo, tenant)
	svc.SetAccountReferenceSources([]domain.AccountReferenceSource{
		stubRefSource{name: "transaction", count: 0},
	})

	if err := svc.DeleteAccount(context.Background(), tenant, acct.ID); err != nil {
		t.Fatalf("delete unreferenced account: %v", err)
	}
}

// Categories share the same guard (entries reference them like any account).
func TestDeleteCategory_RejectsReferencedCategory(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenant := uuid.New()
	cat := mustNewAccount(t, tenant, "咖啡", domain.AccountTypeExpense)
	if err := repo.Save(context.Background(), cat); err != nil {
		t.Fatalf("seed category: %v", err)
	}
	svc.SetAccountReferenceSources([]domain.AccountReferenceSource{
		stubRefSource{name: "transaction", count: 2},
	})

	err := svc.DeleteCategory(context.Background(), tenant, cat.ID)
	if err == nil || !strings.Contains(err.Error(), "referenced by 2 transaction record(s)") {
		t.Fatalf("expected referenced-category rejection, got: %v", err)
	}
}
