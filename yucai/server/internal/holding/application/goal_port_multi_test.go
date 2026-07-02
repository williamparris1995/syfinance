package application

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// --- Task 5: GetAccountsMarketValue best-effort unification (goal port) ---

// TestGetAccountsMarketValue_SumsAcrossAccounts verifies Σ market value across
// multiple accounts delegates to GetAccountMarketValue per account and sums.
// Account A: 10 × 1680 = 16800; Account B: 5 × 1000 = 5000 → Σ = 21800.
func TestGetAccountsMarketValue_SumsAcrossAccounts(t *testing.T) {
	tenantID := uuid.New()
	accountA, accountB := uuid.New(), uuid.New()

	secRepo := newFullSecRepo([]secSeed{
		{ID: uuid.New(), Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
		{ID: uuid.New(), Symbol: "BOND", Exchange: "SSE", Type: domain.SecurityTypeBond, Currency: "CNY", CurrentPriceCents: 1000},
	})
	// Recover the auto-generated IDs.
	var secA1, secB uuid.UUID
	for id, s := range secRepo.byID {
		if s.Symbol == "600519" {
			secA1 = id
		}
		if s.Symbol == "BOND" {
			secB = id
		}
	}

	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountA, SecurityID: secA1,
		Quantity: 10, AvgCostCents: 1600,
	})
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountB, SecurityID: secB,
		Quantity: 5, AvgCostCents: 900,
	})

	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.GetAccountsMarketValue(context.Background(), tenantID, []uuid.UUID{accountA, accountB})
	if err != nil {
		t.Fatalf("GetAccountsMarketValue error: %v", err)
	}
	if got != 21800 {
		t.Errorf("Σ mv = %d, want 21800 (A 16800 + B 5000)", got)
	}
}

// TestGetAccountsMarketValue_SkipsAccountMissingSecurity verifies the per-holding
// skip-missing-security behavior propagates through the multi-account port: an
// account whose only holding references a missing security contributes 0 (not an
// error), and the other account still contributes.
func TestGetAccountsMarketValue_SkipsAccountMissingSecurity(t *testing.T) {
	tenantID := uuid.New()
	accountA, accountB := uuid.New(), uuid.New()

	goodSec := uuid.New()
	badSec := uuid.New() // never seeded in secRepo
	secRepo := newFullSecRepo([]secSeed{
		{ID: goodSec, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
	})

	hr := newMemHoldingRepo()
	// Account A: resolvable holding → 10 × 1680 = 16800.
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountA, SecurityID: goodSec,
		Quantity: 10, AvgCostCents: 1600,
	})
	// Account B: holding references a missing security → contributes 0 (skip).
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountB, SecurityID: badSec,
		Quantity: 99, AvgCostCents: 100,
	})

	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.GetAccountsMarketValue(context.Background(), tenantID, []uuid.UUID{accountA, accountB})
	if err != nil {
		t.Fatalf("GetAccountsMarketValue error: %v", err)
	}
	if got != 16800 {
		t.Errorf("Σ mv = %d, want 16800 (B's missing security skipped, not fatal)", got)
	}
}

// TestGetAccountsMarketValue_EmptyIDs verifies an empty accountIDs slice returns 0.
func TestGetAccountsMarketValue_EmptyIDs(t *testing.T) {
	svc := NewService(newFullSecRepo(nil), newMemHoldingRepo(), &memTradeRepo{})
	got, err := svc.GetAccountsMarketValue(context.Background(), uuid.New(), nil)
	if err != nil {
		t.Fatalf("GetAccountsMarketValue error: %v", err)
	}
	if got != 0 {
		t.Errorf("Σ mv = %d, want 0 for empty accountIDs", got)
	}
}

// TestGetAccountsMarketValue_TenantScoping verifies a different tenant sees 0
// (memHoldingRepo.FindAll filters by tenantID).
func TestGetAccountsMarketValue_TenantScoping(t *testing.T) {
	tenantID := uuid.New()
	otherTenant := uuid.New()
	accountA := uuid.New()

	secRepo := newFullSecRepo([]secSeed{
		{ID: uuid.New(), Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
	})
	var secA1 uuid.UUID
	for id, s := range secRepo.byID {
		if s.Symbol == "600519" {
			secA1 = id
		}
	}

	hr := newMemHoldingRepo()
	hr.SaveOrUpdate(context.Background(), &domain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountA, SecurityID: secA1,
		Quantity: 10, AvgCostCents: 1600,
	})

	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.GetAccountsMarketValue(context.Background(), otherTenant, []uuid.UUID{accountA})
	if err != nil {
		t.Fatalf("GetAccountsMarketValue error: %v", err)
	}
	if got != 0 {
		t.Errorf("Σ mv = %d, want 0 (other tenant's holdings excluded)", got)
	}
}
