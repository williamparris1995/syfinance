package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/backup/adapter/driven/repository"
	"github.com/yucai/server/internal/backup/domain"
)

// TestBackupRepositoryFindByAuto verifies the query contract the retention
// policy (F40) relies on: FindByAuto returns ONLY the rows carrying the
// requested auto flag for the tenant, ordered by created_at ASCENDING
// (oldest first). Rows are seeded out of insertion order so the assertion
// cannot pass on storage order alone.
func TestBackupRepositoryFindByAuto(t *testing.T) {
	client := setupBackupTestDB(t)
	ctx := context.Background()
	repo := repository.NewBackupRepository(client)
	tenantID := uuid.New()
	otherTenant := uuid.New()
	base := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)

	type seed struct {
		auto      bool
		offsetMin time.Duration
		tenant    uuid.UUID
	}
	// Deliberately non-monotonic insertion order (newest first, manual in
	// between, plus a foreign-tenant row) — the query must impose the order.
	seeds := []seed{
		{true, 20 * time.Minute, tenantID},
		{false, 21 * time.Minute, tenantID},
		{true, 5 * time.Minute, tenantID},
		{true, 0, otherTenant}, // foreign tenant — never returned
		{true, 0, tenantID},
		{false, 10 * time.Minute, tenantID},
		{true, 12 * time.Minute, tenantID},
	}
	var oldest, newestAuto *domain.Backup
	for i, s := range seeds {
		b, err := domain.NewBackup(s.tenant, domain.BackupProviderLocal, false, s.auto)
		if err != nil {
			t.Fatalf("NewBackup seed %d: %v", i, err)
		}
		b.CreatedAt = base.Add(s.offsetMin)
		b.UpdatedAt = b.CreatedAt
		if err := repo.Save(ctx, b); err != nil {
			t.Fatalf("Save seed %d: %v", i, err)
		}
		if s.tenant != tenantID {
			continue
		}
		if s.auto {
			if oldest == nil || b.CreatedAt.Before(oldest.CreatedAt) {
				oldest = b
			}
			if newestAuto == nil || b.CreatedAt.After(newestAuto.CreatedAt) {
				newestAuto = b
			}
		}
	}

	autos, err := repo.FindByAuto(ctx, tenantID, true)
	if err != nil {
		t.Fatalf("FindByAuto(auto): %v", err)
	}
	if len(autos) != 4 {
		t.Fatalf("auto rows = %d, want 4 (tenant-scoped)", len(autos))
	}
	for i := 1; i < len(autos); i++ {
		if autos[i].CreatedAt.Before(autos[i-1].CreatedAt) {
			t.Fatalf("FindByAuto not ascending by created_at: %v after %v", autos[i].CreatedAt, autos[i-1].CreatedAt)
		}
		if !autos[i].Auto {
			t.Fatalf("FindByAuto(auto) returned a manual row: %s", autos[i].ID)
		}
	}
	if autos[0].ID != oldest.ID {
		t.Errorf("first row = %s, want oldest auto backup %s", autos[0].ID, oldest.ID)
	}
	if autos[len(autos)-1].ID != newestAuto.ID {
		t.Errorf("last row = %s, want newest auto backup %s", autos[len(autos)-1].ID, newestAuto.ID)
	}

	manuals, err := repo.FindByAuto(ctx, tenantID, false)
	if err != nil {
		t.Fatalf("FindByAuto(manual): %v", err)
	}
	if len(manuals) != 2 {
		t.Fatalf("manual rows = %d, want 2 (tenant-scoped)", len(manuals))
	}
	for _, b := range manuals {
		if b.Auto {
			t.Errorf("FindByAuto(manual) returned an auto row: %s", b.ID)
		}
	}
}
