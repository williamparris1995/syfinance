package repository_test

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/backup/adapter/driven/repository"
	"github.com/yucai/server/internal/backup/domain"
)

// TestBackupSettingsRepo_GetByTenant_UnconfiguredReturnsNil verifies that a
// tenant with no persisted row returns (nil, nil) — the Service treats this as
// "defaults" (AutoBackup=false, 24h schema default not even materialized).
func TestBackupSettingsRepo_GetByTenant_UnconfiguredReturnsNil(t *testing.T) {
	client := setupBackupTestDB(t)
	ctx := context.Background()
	repo := repository.NewBackupSettingsRepository(client)

	got, err := repo.GetByTenant(ctx, uuid.New())
	if err != nil {
		t.Fatalf("GetByTenant: %v", err)
	}
	if got != nil {
		t.Fatalf("got = %+v, want nil for unconfigured tenant", got)
	}
}

// TestBackupSettingsRepo_Save_GetByTenant_Roundtrip verifies the create path:
// Save on a fresh tenant stores the row and GetByTenant returns the same
// auto-backup fields (tenant scoping is respected — another tenant stays nil).
func TestBackupSettingsRepo_Save_GetByTenant_Roundtrip(t *testing.T) {
	client := setupBackupTestDB(t)
	ctx := context.Background()
	repo := repository.NewBackupSettingsRepository(client)
	tenant := uuid.New()
	other := uuid.New()

	if err := repo.Save(ctx, &domain.BackupSettings{
		TenantID:                tenant,
		AutoBackup:              true,
		AutoBackupIntervalHours: 12,
	}); err != nil {
		t.Fatalf("Save (create): %v", err)
	}

	got, err := repo.GetByTenant(ctx, tenant)
	if err != nil {
		t.Fatalf("GetByTenant: %v", err)
	}
	if got == nil {
		t.Fatal("expected settings, got nil")
	}
	if got.TenantID != tenant {
		t.Errorf("TenantID = %v, want %v", got.TenantID, tenant)
	}
	if !got.AutoBackup {
		t.Errorf("AutoBackup = false, want true")
	}
	if got.AutoBackupIntervalHours != 12 {
		t.Errorf("AutoBackupIntervalHours = %d, want 12", got.AutoBackupIntervalHours)
	}
	if got.ID == (uuid.UUID{}) {
		t.Errorf("ID = zero UUID, want a generated value")
	}

	// Tenant isolation: another tenant must still see nil.
	if otherGot, err := repo.GetByTenant(ctx, other); err != nil || otherGot != nil {
		t.Errorf("other tenant: got = %v/%v, want nil/nil", otherGot, err)
	}
}

// TestBackupSettingsRepo_Save_UpsertsExistingRow verifies that a second Save
// for the same tenant updates the existing row in place (no duplicate, no
// unique-violation) — at most one settings row per tenant.
func TestBackupSettingsRepo_Save_UpsertsExistingRow(t *testing.T) {
	client := setupBackupTestDB(t)
	ctx := context.Background()
	repo := repository.NewBackupSettingsRepository(client)
	tenant := uuid.New()

	// First save — create.
	if err := repo.Save(ctx, &domain.BackupSettings{
		TenantID:                tenant,
		AutoBackup:              false,
		AutoBackupIntervalHours: 24,
	}); err != nil {
		t.Fatalf("Save (create): %v", err)
	}
	created, err := repo.GetByTenant(ctx, tenant)
	if err != nil || created == nil {
		t.Fatalf("GetByTenant after create: %v / %v", created, err)
	}
	createdID := created.ID

	// Second save — upsert (row already exists for this tenant).
	if err := repo.Save(ctx, &domain.BackupSettings{
		TenantID:                tenant,
		AutoBackup:              true,
		AutoBackupIntervalHours: 6,
	}); err != nil {
		t.Fatalf("Save (upsert): %v", err)
	}

	updated, err := repo.GetByTenant(ctx, tenant)
	if err != nil {
		t.Fatalf("GetByTenant after upsert: %v", err)
	}
	if updated == nil {
		t.Fatal("expected settings after upsert, got nil")
	}
	// Same row (updated in place), not a new insert.
	if updated.ID != createdID {
		t.Errorf("ID changed after upsert: got %v, want %v (same row)", updated.ID, createdID)
	}
	if !updated.AutoBackup {
		t.Errorf("AutoBackup = false, want true (upserted value)")
	}
	if updated.AutoBackupIntervalHours != 6 {
		t.Errorf("AutoBackupIntervalHours = %d, want 6 (upserted value)", updated.AutoBackupIntervalHours)
	}

	// At most one row for this tenant.
	count, err := client.BackupSettings.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Errorf("rows for tenant = %d, want 1 (upsert must not duplicate)", count)
	}
}
