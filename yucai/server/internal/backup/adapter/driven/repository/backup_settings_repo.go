package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
	backupent "github.com/yucai/server/internal/backup/ent"
	"github.com/yucai/server/internal/backup/ent/backupsettings"
)

// BackupSettingsRepository implements domain.BackupSettingsRepository. Mirrors
// the per-module split pattern (own interface + own impl) used by the snapshot
// repos so adding settings persistence does not perturb any BackupRepository
// implementer.
type BackupSettingsRepository struct {
	client *backupent.Client
}

// NewBackupSettingsRepository creates a new BackupSettingsRepository.
func NewBackupSettingsRepository(client *backupent.Client) *BackupSettingsRepository {
	return &BackupSettingsRepository{client: client}
}

// Save upserts the tenant's settings row: if a row already exists for the
// tenant it is updated, otherwise a new row is created. At most one row per
// tenant is expected (tenant-scoped preferences).
func (r *BackupSettingsRepository) Save(ctx context.Context, s *domain.BackupSettings) error {
	existing, err := r.GetByTenant(ctx, s.TenantID)
	if err != nil {
		return fmt.Errorf("save backup settings: lookup: %w", err)
	}
	if existing != nil {
		if _, err := r.client.BackupSettings.UpdateOneID(existing.ID).
			SetAutoBackup(s.AutoBackup).
			SetAutoBackupIntervalHours(s.AutoBackupIntervalHours).
			Save(ctx); err != nil {
			return fmt.Errorf("update backup settings: %w", err)
		}
		return nil
	}
	if _, err := r.client.BackupSettings.Create().
		SetTenantID(s.TenantID).
		SetAutoBackup(s.AutoBackup).
		SetAutoBackupIntervalHours(s.AutoBackupIntervalHours).
		Save(ctx); err != nil {
		return fmt.Errorf("create backup settings: %w", err)
	}
	return nil
}

// GetByTenant returns the tenant's settings row, or (nil, nil) when no
// settings have been configured yet (Service treats nil as defaults).
func (r *BackupSettingsRepository) GetByTenant(ctx context.Context, tenantID uuid.UUID) (*domain.BackupSettings, error) {
	row, err := r.client.BackupSettings.Query().
		Where(backupsettings.TenantID(tenantID)).
		Only(ctx)
	if err != nil {
		if backupent.IsNotFound(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("find backup settings: %w", err)
	}
	return toDomainSettings(row), nil
}

func toDomainSettings(row *backupent.BackupSettings) *domain.BackupSettings {
	return &domain.BackupSettings{
		ID:                      row.ID,
		TenantID:                row.TenantID,
		AutoBackup:              row.AutoBackup,
		AutoBackupIntervalHours: row.AutoBackupIntervalHours,
	}
}

// Compile-time check.
var _ domain.BackupSettingsRepository = (*BackupSettingsRepository)(nil)
