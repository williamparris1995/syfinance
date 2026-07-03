package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/debt/adapter/driven/repository"
	"github.com/yucai/server/internal/debt/domain"
)

// TestDebtRepo_SaveFind_ContactContractCollection verifies that the 3 new
// receivables fields (contact, contract_ref, collection_account_id) survive a
// Save → FindByID round trip, both populated and nil/empty.
func TestDebtRepo_SaveFind_ContactContractCollection(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	account := uuid.New()
	collection := uuid.New()

	// Populated path.
	populated, err := domain.NewDebtDetails(
		tenant, account, "Alice",
		0.05, domain.AmortizationEqualPrincipalInterest,
		time.Now(), time.Now().AddDate(1, 0, 0), 1_000_00,
		domain.BorrowedOut, "personal",
		"138-6677", "BO-2026-0215.pdf", &collection,
	)
	if err != nil {
		t.Fatalf("NewDebtDetails populated: %v", err)
	}

	repo := repository.NewDebtRepository(client)
	if err := repo.Save(ctx, populated); err != nil {
		t.Fatalf("Save populated: %v", err)
	}

	got, err := repo.FindByID(ctx, tenant, populated.ID)
	if err != nil {
		t.Fatalf("FindByID populated: %v", err)
	}
	if got.Contact != "138-6677" {
		t.Errorf("Contact = %q, want 138-6677", got.Contact)
	}
	if got.ContractRef != "BO-2026-0215.pdf" {
		t.Errorf("ContractRef = %q, want BO-2026-0215.pdf", got.ContractRef)
	}
	if got.CollectionAccountID == nil || *got.CollectionAccountID != collection {
		t.Errorf("CollectionAccountID = %v, want %s", got.CollectionAccountID, collection)
	}

	// Nil path: empty contact/contract_ref, nil collection_account_id.
	empty, err := domain.NewDebtDetails(
		tenant, uuid.New(), "Bob",
		0.03, domain.AmortizationLumpSum,
		time.Now(), time.Now().AddDate(2, 0, 0), 500_00,
		domain.BorrowedIn, "family",
		"", "", nil,
	)
	if err != nil {
		t.Fatalf("NewDebtDetails empty: %v", err)
	}
	if err := repo.Save(ctx, empty); err != nil {
		t.Fatalf("Save empty: %v", err)
	}
	gotEmpty, err := repo.FindByID(ctx, tenant, empty.ID)
	if err != nil {
		t.Fatalf("FindByID empty: %v", err)
	}
	if gotEmpty.Contact != "" {
		t.Errorf("Contact = %q, want empty", gotEmpty.Contact)
	}
	if gotEmpty.ContractRef != "" {
		t.Errorf("ContractRef = %q, want empty", gotEmpty.ContractRef)
	}
	if gotEmpty.CollectionAccountID != nil {
		t.Errorf("CollectionAccountID = %v, want nil", gotEmpty.CollectionAccountID)
	}
}
