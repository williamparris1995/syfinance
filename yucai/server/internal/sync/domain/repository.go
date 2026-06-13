package domain

import (
	"context"

	"github.com/google/uuid"
)

// SyncLogRepository manages append-only sync log entries.
type SyncLogRepository interface {
	Append(ctx context.Context, entry *SyncLogEntry) error
	FindSince(ctx context.Context, tenantID uuid.UUID, sinceVersion int64, entityTypes []string) ([]SyncLogEntry, error)
	LatestVersion(ctx context.Context, tenantID uuid.UUID) (int64, error)
}

// SyncDeviceRepository manages registered devices.
type SyncDeviceRepository interface {
	Register(ctx context.Context, device *SyncDevice) error
	FindByID(ctx context.Context, tenantID, deviceID uuid.UUID) (*SyncDevice, error)
	UpdateSyncVersion(ctx context.Context, tenantID, deviceID uuid.UUID, version int64) error
}

// SyncConflictRepository manages conflict records.
type SyncConflictRepository interface {
	Save(ctx context.Context, conflict *SyncConflict) error
	FindPending(ctx context.Context, tenantID uuid.UUID, page PageRequest) (*PaginatedResult[SyncConflict], error)
	Resolve(ctx context.Context, tenantID, conflictID uuid.UUID, resolution string) error
}
