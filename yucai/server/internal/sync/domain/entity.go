package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

// SyncLogEntry represents a single append-only change record.
type SyncLogEntry struct {
	ID         uuid.UUID
	TenantID   uuid.UUID
	EntityType string
	EntityID   uuid.UUID
	Operation  SyncOperation
	Payload    []byte
	Version    int64
	DeviceID   uuid.UUID
	CreatedAt  time.Time
}

// SyncDevice represents a registered client device.
type SyncDevice struct {
	ID              uuid.UUID
	TenantID        uuid.UUID
	DeviceName      string
	LastSyncVersion int64
	LastSyncAt      time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// NewSyncDevice creates a new SyncDevice.
func NewSyncDevice(tenantID uuid.UUID, deviceName string) (*SyncDevice, error) {
	if deviceName == "" {
		return nil, fmt.Errorf("device name must not be empty")
	}
	now := time.Now()
	return &SyncDevice{
		ID:         uuid.New(),
		TenantID:   tenantID,
		DeviceName: deviceName,
		CreatedAt:  now,
		UpdatedAt:  now,
	}, nil
}

// UpdateSyncVersion sets the last sync version and timestamp.
func (d *SyncDevice) UpdateSyncVersion(version int64) {
	d.LastSyncVersion = version
	d.LastSyncAt = time.Now()
	d.UpdatedAt = time.Now()
}

// SyncConflict represents a conflict between server and client state.
type SyncConflict struct {
	ID             uuid.UUID
	TenantID       uuid.UUID
	EntityType     string
	EntityID       uuid.UUID
	ConflictType   string
	ServerPayload  []byte
	ClientPayload  []byte
	Resolution     ConflictResolution
	ResolvedAt     *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// NewSyncConflict creates a new unresolved conflict.
func NewSyncConflict(tenantID uuid.UUID, entityType string, entityID uuid.UUID, conflictType string, serverPayload, clientPayload []byte) *SyncConflict {
	now := time.Now()
	return &SyncConflict{
		ID:            uuid.New(),
		TenantID:      tenantID,
		EntityType:    entityType,
		EntityID:      entityID,
		ConflictType:  conflictType,
		ServerPayload: serverPayload,
		ClientPayload: clientPayload,
		Resolution:    ConflictResolutionPending,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
}

// Resolve marks the conflict as resolved with the given strategy.
func (c *SyncConflict) Resolve(resolution ConflictResolution) {
	now := time.Now()
	c.Resolution = resolution
	c.ResolvedAt = &now
	c.UpdatedAt = now
}

// IsPending returns true if the conflict has not been resolved.
func (c *SyncConflict) IsPending() bool {
	return c.Resolution == ConflictResolutionPending
}
