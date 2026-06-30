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

// TestSnapshotRepoFindSnapshots_TenantAndDateRange verifies tenant scoping,
// inclusive date range, and ascending date ordering.
func TestSnapshotRepoFindSnapshots_TenantAndDateRange(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	otherTenant := uuid.New()
	holding := uuid.New()
	security := uuid.New()
	account := uuid.New()

	seedSnapshot(t, client, tenant, holding, security, account, day("2025-01-01"), 10000)
	seedSnapshot(t, client, tenant, holding, security, account, day("2025-01-03"), 10500)
	seedSnapshot(t, client, tenant, holding, security, account, day("2025-01-05"), 11000)
	// Out of range (after to).
	seedSnapshot(t, client, tenant, holding, security, account, day("2025-01-10"), 99999)
	// Different tenant — must be excluded.
	seedSnapshot(t, client, otherTenant, holding, security, account, day("2025-01-03"), 88888)

	repo := repository.NewSnapshotRepository(client)
	got, err := repo.FindSnapshots(ctx, tenant, day("2025-01-01"), day("2025-01-05"), nil, nil)
	if err != nil {
		t.Fatalf("FindSnapshots: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 rows in tenant+range, got %d", len(got))
	}
	// Ascending by date.
	if !got[0].SnapshotDate.Equal(day("2025-01-01")) {
		t.Errorf("first date = %s, want 2025-01-01", got[0].SnapshotDate.Format("2006-01-02"))
	}
	if !got[2].SnapshotDate.Equal(day("2025-01-05")) {
		t.Errorf("last date = %s, want 2025-01-05 (range inclusive)", got[2].SnapshotDate.Format("2006-01-02"))
	}
	for _, s := range got {
		if s.TenantID != tenant {
			t.Errorf("tenant leakage: row tenant %s != %s", s.TenantID, tenant)
		}
	}
}

// TestSnapshotRepoFindSnapshots_AccountAndSecurityFilter confirms the optional
// account/security filters narrow the result set.
func TestSnapshotRepoFindSnapshots_AccountAndSecurityFilter(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	accountA := uuid.New()
	accountB := uuid.New()
	securityA := uuid.New()
	securityB := uuid.New()
	// UNIQUE(tenant_id, holding_id, snapshot_date) — to keep two same-day rows
	// for the same tenant, each must belong to a different holding.
	holdingA := uuid.New()
	holdingB := uuid.New()

	// Two snapshots same day, different account/security/holding.
	seedSnapshot(t, client, tenant, holdingA, securityA, accountA, day("2025-02-01"), 10000)
	seedSnapshot(t, client, tenant, holdingB, securityB, accountB, day("2025-02-01"), 20000)

	repo := repository.NewSnapshotRepository(client)

	// Filter by accountA → only the first row.
	got, err := repo.FindSnapshots(ctx, tenant, day("2025-02-01"), day("2025-02-01"), &accountA, nil)
	if err != nil {
		t.Fatalf("FindSnapshots by account: %v", err)
	}
	if len(got) != 1 || got[0].AccountID != accountA {
		t.Fatalf("account filter: expected 1 row for accountA, got %+v", got)
	}

	// Filter by securityB → only the second row.
	got, err = repo.FindSnapshots(ctx, tenant, day("2025-02-01"), day("2025-02-01"), nil, &securityB)
	if err != nil {
		t.Fatalf("FindSnapshots by security: %v", err)
	}
	if len(got) != 1 || got[0].SecurityID != securityB {
		t.Fatalf("security filter: expected 1 row for securityB, got %+v", got)
	}
}

// TestSnapshotRepoSave_RoundTrip verifies Save persists and the row is
// queryable with all fields intact.
func TestSnapshotRepoSave_RoundTrip(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	holding := uuid.New()
	security := uuid.New()
	account := uuid.New()

	repo := repository.NewSnapshotRepository(client)
	s := domain.HoldingSnapshot{
		ID: uuid.New(), TenantID: tenant, HoldingID: holding, SecurityID: security, AccountID: account,
		SnapshotDate: day("2025-04-01"), MarketValueCents: 12345, UnrealizedPnlCents: 678,
		CurrencyCode: "CNY",
	}
	if err := repo.Save(ctx, s); err != nil {
		t.Fatalf("Save: %v", err)
	}

	got, err := repo.FindSnapshots(ctx, tenant, day("2025-04-01"), day("2025-04-01"), nil, nil)
	if err != nil {
		t.Fatalf("FindSnapshots: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 row, got %d", len(got))
	}
	if got[0].MarketValueCents != 12345 || got[0].UnrealizedPnlCents != 678 {
		t.Errorf("round-trip mismatch: %+v", got[0])
	}
	if got[0].ID != s.ID {
		t.Errorf("ID mismatch: got %s want %s", got[0].ID, s.ID)
	}
}

func seedSnapshot(t *testing.T, client *holdingent.Client, tenantID, holdingID, securityID, accountID uuid.UUID, snapshotDate time.Time, marketValueCents int64) {
	t.Helper()
	ctx := context.Background()
	if _, err := client.HoldingSnapshot.Create().
		SetTenantID(tenantID).SetHoldingID(holdingID).SetSecurityID(securityID).SetAccountID(accountID).
		SetSnapshotDate(snapshotDate).SetMarketValueCents(marketValueCents).
		SetUnrealizedPnlCents(0).SetCurrencyCode("CNY").
		Save(ctx); err != nil {
		t.Fatalf("seed snapshot: %v", err)
	}
}
