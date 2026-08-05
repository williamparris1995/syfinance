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
	// Service callers construct snapshots without an ID (uuid.Nil); the repo
	// must NOT SetID — ent's Default(uuid.New) generates it. Leaving ID empty
	// here mirrors the production code path and guards against pkey collisions
	// when multiple snapshots are saved in a batch.
	s := domain.HoldingSnapshot{
		TenantID: tenant, HoldingID: holding, SecurityID: security, AccountID: account,
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
	// ent Default(uuid.New) generates the id — it must not be uuid.Nil (the
	// value the service passed in), proving the repo did not echo the caller's
	// empty ID back as a pkey.
	if got[0].ID == uuid.Nil {
		t.Errorf("ID not generated: got uuid.Nil, want ent-generated non-zero id")
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

// TestSnapshotRepoSave_DuplicateDailyTickIsFirstWins (D18): the daily snapshot
// scheduler can re-tick or retry the same (tenant, holding, date) within a day.
// Previously Save did a plain insert and hard-errored on the
// UNIQUE(tenant_id, holding_id, snapshot_date) violation, aborting that day's
// snapshot. D18 makes Save first-wins: a duplicate tick is ignored (the original
// time-point snapshot is kept), matching OnConflictDoNothing intent. The ent
// codegen has no first-class OnConflict helper (sql/upsert feature not enabled),
// so this mirrors the create-then-tolerate-constraint pattern used by
// debt_snapshot_repo — but first-wins rather than overwrite, per D18.
func TestSnapshotRepoSave_DuplicateDailyTickIsFirstWins(t *testing.T) {
	client := setupHoldingTestDB(t)
	repo := repository.NewSnapshotRepository(client)
	ctx := context.Background()
	tenant := uuid.New()
	holding := uuid.New()
	security := uuid.New()
	account := uuid.New()
	date := day("2026-08-01")

	first := domain.HoldingSnapshot{
		TenantID:         tenant,
		HoldingID:        holding,
		SecurityID:       security,
		AccountID:        account,
		SnapshotDate:     date,
		MarketValueCents: 10000,
		CurrencyCode:     "CNY",
	}
	if err := repo.Save(ctx, first); err != nil {
		t.Fatalf("first Save: %v", err)
	}

	// Duplicate daily tick — same (tenant, holding, date), different value to
	// prove first-wins (not overwrite). D18: must return nil and keep the original.
	dup := first
	dup.MarketValueCents = 99999
	if err := repo.Save(ctx, dup); err != nil {
		t.Errorf("duplicate-tick Save: %v, want nil (D18 first-wins)", err)
	}

	// first-wins (not overwrite): the stored row is still the original 10000.
	got, err := repo.FindSnapshots(ctx, tenant, date, date, nil, nil)
	if err != nil {
		t.Fatalf("FindSnapshots: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("rows = %d, want 1 (single daily row, duplicate ignored)", len(got))
	}
	if got[0].MarketValueCents != 10000 {
		t.Errorf("MarketValueCents = %d, want 10000 (first-wins: duplicate tick must not overwrite the original time-point snapshot)", got[0].MarketValueCents)
	}
}
