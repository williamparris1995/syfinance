package repository_test

import (
	"time"
	"context"
	"testing"

	"github.com/google/uuid"

	debtent "github.com/yucai/server/internal/debt/ent"
	"github.com/yucai/server/internal/debt/adapter/driven/repository"
	"github.com/yucai/server/internal/debt/domain"
)

func newSnap(tenant, debt uuid.UUID, date string, remaining int64) *domain.DebtProgressSnapshot {
	return &domain.DebtProgressSnapshot{
		ID:                  uuid.New(),
		TenantID:            tenant,
		DebtID:              debt,
		SnapshotDate:        dayDebt(date),
		TotalPrincipalCents: 1_000_00,
		RemainingCents:      remaining,
		PaidTotalCents:      1_000_00 - remaining,
	}
}

// TestDebtSnapshotRepo_SaveSnapshot_UpsertOnSameDay verifies that saving a
// second snapshot for the same (tenant, debt, date) updates the existing row
// instead of failing the unique constraint.

// seedDebtParent creates the DebtDetails parent row so snapshots satisfy the
// new FK edge (D8 same-module FK + Cascade — R5 feature E).
func seedDebtParent(t *testing.T, client *debtent.Client, tenant, debt uuid.UUID) {
	t.Helper()
	if err := client.DebtDetails.Create().
		SetID(debt).
		SetTenantID(tenant).
		SetAccountID(uuid.New()).
		SetCounterparty("test").
		SetInterestRate(3).
		SetAmortizationMethod("equal_principal_interest").
		SetStartDate(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)).
		SetDueDate(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)).
		SetTotalPrincipalCents(1_000_00).
		SetDebtType("borrowed_in").
		SetVersion(1).
		Exec(context.Background()); err != nil {
		t.Fatalf("seedDebtParent: %v", err)
	}
}

func TestDebtSnapshotRepo_SaveSnapshot_UpsertOnSameDay(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	debt := uuid.New()
	repo := repository.NewDebtSnapshotRepository(client)
	seedDebtParent(t, client, tenant, debt)

	if err := repo.SaveSnapshot(ctx, newSnap(tenant, debt, "2025-01-01", 900_00)); err != nil {
		t.Fatalf("first SaveSnapshot: %v", err)
	}
	// Same day, different remaining — must upsert, not error.
	if err := repo.SaveSnapshot(ctx, newSnap(tenant, debt, "2025-01-01", 800_00)); err != nil {
		t.Fatalf("second SaveSnapshot (upsert): %v", err)
	}

	latest, err := repo.FindLatestByDebt(ctx, tenant, debt, dayDebt("2025-01-31"))
	if err != nil {
		t.Fatalf("FindLatestByDebt: %v", err)
	}
	if latest == nil {
		t.Fatal("expected a snapshot, got nil")
	}
	if latest.RemainingCents != 800_00 {
		t.Errorf("RemainingCents = %d, want 80000 (upserted value)", latest.RemainingCents)
	}
}

// TestDebtSnapshotRepo_FindLatestByDebt verifies the <= asOf + DESC ordering.
func TestDebtSnapshotRepo_FindLatestByDebt(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	debt := uuid.New()
	repo := repository.NewDebtSnapshotRepository(client)
	seedDebtParent(t, client, tenant, debt)

	mustSave(t, repo, ctx, newSnap(tenant, debt, "2025-01-01", 950_00))
	mustSave(t, repo, ctx, newSnap(tenant, debt, "2025-01-05", 900_00))
	mustSave(t, repo, ctx, newSnap(tenant, debt, "2025-01-10", 850_00))

	// asOf between Jan 5 and Jan 10 → latest is Jan 5.
	got, err := repo.FindLatestByDebt(ctx, tenant, debt, dayDebt("2025-01-07"))
	if err != nil {
		t.Fatalf("FindLatestByDebt: %v", err)
	}
	if got == nil || !got.SnapshotDate.Equal(dayDebt("2025-01-05")) {
		t.Fatalf("got = %+v, want 2025-01-05", got)
	}

	// asOf before any snapshot → nil, nil.
	none, err := repo.FindLatestByDebt(ctx, tenant, debt, dayDebt("2024-12-31"))
	if err != nil || none != nil {
		t.Errorf("got = %v/%v, want nil/nil before first snapshot", none, err)
	}
}

// TestDebtSnapshotRepo_FindSnapshotRange verifies tenant scoping, IN filter,
// inclusive BETWEEN, and ascending order.
func TestDebtSnapshotRepo_FindSnapshotRange(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	otherTenant := uuid.New()
	debt1 := uuid.New()
	debt2 := uuid.New()
	repo := repository.NewDebtSnapshotRepository(client)
	seedDebtParent(t, client, tenant, debt1)
	seedDebtParent(t, client, tenant, debt2)

	mustSave(t, repo, ctx, newSnap(tenant, debt1, "2025-01-01", 950_00))
	mustSave(t, repo, ctx, newSnap(tenant, debt1, "2025-01-03", 900_00))
	mustSave(t, repo, ctx, newSnap(tenant, debt1, "2025-01-10", 850_00)) // outside range
	mustSave(t, repo, ctx, newSnap(tenant, debt2, "2025-01-02", 500_00))
	// Wrong tenant, same debt1 — must be excluded.
	mustSave(t, repo, ctx, newSnap(otherTenant, debt1, "2025-01-02", 99999))

	got, err := repo.FindSnapshotRange(ctx, tenant, []uuid.UUID{debt1, debt2}, dayDebt("2025-01-01"), dayDebt("2025-01-05"))
	if err != nil {
		t.Fatalf("FindSnapshotRange: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 rows, got %d", len(got))
	}
	// Ascending by date.
	if !got[0].SnapshotDate.Equal(dayDebt("2025-01-01")) {
		t.Errorf("first date = %s, want 2025-01-01", got[0].SnapshotDate)
	}
	for _, s := range got {
		if s.TenantID != tenant {
			t.Errorf("tenant leak: row tenant = %s", s.TenantID)
		}
	}

	// Empty debtIDs → nil, nil.
	empty, err := repo.FindSnapshotRange(ctx, tenant, nil, dayDebt("2025-01-01"), dayDebt("2025-01-05"))
	if err != nil || empty != nil {
		t.Errorf("empty debtIDs: got %v/%v, want nil/nil", empty, err)
	}
}

func mustSave(t *testing.T, repo domain.DebtSnapshotRepository, ctx context.Context, snap *domain.DebtProgressSnapshot) {
	t.Helper()
	if err := repo.SaveSnapshot(ctx, snap); err != nil {
		t.Fatalf("SaveSnapshot: %v", err)
	}
}
