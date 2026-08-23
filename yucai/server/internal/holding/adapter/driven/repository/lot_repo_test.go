package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// TestLotRepoFindByHolding_OrdersByAcquiredDateAsc verifies the FIFO contract:
// lots come back ordered by acquired_date ascending regardless of insert order.

// seedHoldingParent creates the Holding parent row so lots satisfy the new FK
// edge (D8 same-module FK + Cascade — R5 feature E).
func seedHoldingParent(t *testing.T, client *holdingent.Client, tenantID, holdingID, accountID, securityID uuid.UUID) {
	t.Helper()
	if err := client.Holding.Create().
		SetID(holdingID).
		SetTenantID(tenantID).
		SetAccountID(accountID).
		SetSecurityID(securityID).
		SetQuantity(1).
		SetAvgCostCents(1).
		SetVersion(1).
		Exec(context.Background()); err != nil {
		t.Fatalf("seedHoldingParent: %v", err)
	}
}

func TestLotRepoFindByHolding_OrdersByAcquiredDateAsc(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	holding := uuid.New()
	security := uuid.New()
	seedHoldingParent(t, client, tenant, holding, uuid.New(), security)

	// Insert out of order: newer lot first, older lot second. The repo must
	// return them oldest-first (FIFO consume order).
	if _, err := client.HoldingLot.Create().
		SetTenantID(tenant).SetHoldingID(holding).SetSecurityID(security).
		SetAcquiredDate(day("2025-01-05")).SetAcquiredTradeID(uuid.New()).
		SetPriceCents(11000).SetQuantity(40).SetRemainingQuantity(40).
		Save(ctx); err != nil {
		t.Fatalf("seed newer lot: %v", err)
	}
	if _, err := client.HoldingLot.Create().
		SetTenantID(tenant).SetHoldingID(holding).SetSecurityID(security).
		SetAcquiredDate(day("2025-01-02")).SetAcquiredTradeID(uuid.New()).
		SetPriceCents(10000).SetQuantity(60).SetRemainingQuantity(60).
		Save(ctx); err != nil {
		t.Fatalf("seed older lot: %v", err)
	}

	repo := repository.NewLotRepository(client)
	got, err := repo.FindByHolding(ctx, holding)
	if err != nil {
		t.Fatalf("FindByHolding: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 lots, got %d", len(got))
	}
	if !got[0].AcquiredDate.Before(got[1].AcquiredDate) {
		t.Fatalf("lots not ASC by acquired_date: [%s, %s]",
			got[0].AcquiredDate.Format("2006-01-02"),
			got[1].AcquiredDate.Format("2006-01-02"))
	}
	// Tiebreaker sanity: the older one carries the cheaper price.
	if got[0].PriceCents != 10000 {
		t.Errorf("oldest lot price = %d, want 10000", got[0].PriceCents)
	}
}

// TestLotRepoFindByHolding_IsolatesByHolding confirms lots of a different
// holding are not returned (no cross-holding leakage in FIFO consume).
func TestLotRepoFindByHolding_IsolatesByHolding(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	holdingA := uuid.New()
	holdingB := uuid.New()
	security := uuid.New()

	seedLot(t, client, tenant, holdingA, security, day("2025-01-02"), 10000, 100)
	seedLot(t, client, tenant, holdingB, security, day("2025-01-02"), 20000, 50)

	repo := repository.NewLotRepository(client)
	got, err := repo.FindByHolding(ctx, holdingA)
	if err != nil {
		t.Fatalf("FindByHolding: %v", err)
	}
	if len(got) != 1 || got[0].HoldingID != holdingA {
		t.Fatalf("expected 1 lot for holdingA, got %+v", got)
	}
}

// TestLotRepoSaveAll_CreateAndUpdate covers both SaveAll branches: a zero-ID
// lot is created, an existing-ID lot has quantity + remaining_quantity updated
// (sell consume / split scenario).
func TestLotRepoSaveAll_CreateAndUpdate(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	holding := uuid.New()
	security := uuid.New()

	// Seed an existing lot we will later "sell" (reduce remaining).
	existing := seedLot(t, client, tenant, holding, security, day("2025-01-02"), 10000, 100)

	// Batch: update the existing lot (sell 40 of 100 → remaining 60) AND
	// create a new lot via zero ID.
	repo := repository.NewLotRepository(client)
	newLot := domain.HoldingLot{
		TenantID: tenant, HoldingID: holding, SecurityID: security,
		AcquiredDate:    day("2025-02-01"),
		AcquiredTradeID: uuid.New(),
		PriceCents:      12000, Quantity: 30, RemainingQuantity: 30,
	}
	updated := domain.HoldingLot{
		ID: existing.ID, TenantID: tenant, HoldingID: holding, SecurityID: security,
		AcquiredDate: existing.AcquiredDate, AcquiredTradeID: existing.AcquiredTradeID,
		PriceCents: 10000, Quantity: 100, RemainingQuantity: 60,
	}
	if err := repo.SaveAll(ctx, []domain.HoldingLot{newLot, updated}); err != nil {
		t.Fatalf("SaveAll: %v", err)
	}

	got, err := repo.FindByHolding(ctx, holding)
	if err != nil {
		t.Fatalf("FindByHolding after SaveAll: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 lots after SaveAll, got %d", len(got))
	}
	// Find the updated one and verify remaining dropped to 60.
	var updatedRow *domain.HoldingLot
	for i := range got {
		if got[i].ID == existing.ID {
			updatedRow = &got[i]
		}
	}
	if updatedRow == nil {
		t.Fatalf("updated lot %s not found after SaveAll", existing.ID)
	}
	if updatedRow.RemainingQuantity != 60 {
		t.Errorf("updated lot remaining = %v, want 60", updatedRow.RemainingQuantity)
	}
}

// seedLot inserts a fully-populated lot and returns a domain.HoldingLot
// (carrying the generated ID) so callers can later reference it for updates.
func seedLot(t *testing.T, client *holdingent.Client, tenantID, holdingID, securityID uuid.UUID, acquiredDate time.Time, priceCents int64, qty float64) domain.HoldingLot {
	t.Helper()
	ctx := context.Background()
	seedHoldingParent(t, client, tenantID, holdingID, uuid.New(), securityID)
	row, err := client.HoldingLot.Create().
		SetTenantID(tenantID).SetHoldingID(holdingID).SetSecurityID(securityID).
		SetAcquiredDate(acquiredDate).SetAcquiredTradeID(uuid.New()).
		SetPriceCents(priceCents).SetQuantity(qty).SetRemainingQuantity(qty).
		Save(ctx)
	if err != nil {
		t.Fatalf("seed lot: %v", err)
	}
	return domain.HoldingLot{
		ID: row.ID, TenantID: tenantID, HoldingID: holdingID, SecurityID: securityID,
		AcquiredDate: row.AcquiredDate, AcquiredTradeID: row.AcquiredTradeID,
		PriceCents: row.PriceCents, Quantity: row.Quantity, RemainingQuantity: row.RemainingQuantity,
	}
}
