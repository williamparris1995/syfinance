package domain

import (
	"context"

	"github.com/google/uuid"
)

// BackupSettings holds per-tenant auto-backup preferences (the cloud settings
// persisted to the backup_settings table). Only the auto-backup fields are
// stored today; provider/credential fields remain defer (see auto-backup
// scheduler spec — local-first, cloud fields deferred).
type BackupSettings struct {
	ID                      uuid.UUID
	TenantID                uuid.UUID
	AutoBackup              bool
	AutoBackupIntervalHours int32
}

// BackupSettingsRepository is the port for persisting per-tenant backup
// settings. Save upserts by tenant (one row per tenant); GetByTenant returns
// the tenant's row or (nil, nil) when no settings have been configured yet.
type BackupSettingsRepository interface {
	Save(ctx context.Context, s *BackupSettings) error
	GetByTenant(ctx context.Context, tenantID uuid.UUID) (*BackupSettings, error)
}
