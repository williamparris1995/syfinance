package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sync/domain"
)

// SyncPayloadDTO represents a single change to sync.
type SyncPayloadDTO struct {
	EntityType string
	EntityID   uuid.UUID
	Operation  domain.SyncOperation
	Payload    []byte
	Version    int64
	DeviceID   uuid.UUID
}

// ConflictDTO represents a sync conflict.
type ConflictDTO struct {
	ID            uuid.UUID
	EntityType    string
	EntityID      uuid.UUID
	ConflictType  string
	ServerPayload []byte
	ClientPayload []byte
	Resolution    string
	// CreatedAt is when the conflict was recorded (F18 FR-6): the resolution
	// panel sorts newest-first and shows recency.
	CreatedAt time.Time
}

// SyncStatusDTO represents the current sync state for a device.
type SyncStatusDTO struct {
	DeviceID         uuid.UUID
	LastSyncVersion  int64
	LastSyncAt       time.Time
	PendingConflicts int32
}

// PayloadToDTO converts a domain SyncLogEntry to a DTO.
func PayloadToDTO(entry *domain.SyncLogEntry) SyncPayloadDTO {
	return SyncPayloadDTO{
		EntityType: entry.EntityType,
		EntityID:   entry.EntityID,
		Operation:  entry.Operation,
		Payload:    entry.Payload,
		Version:    entry.Version,
		DeviceID:   entry.DeviceID,
	}
}

// ConflictToDTO converts a domain SyncConflict to a DTO.
func ConflictToDTO(c *domain.SyncConflict) ConflictDTO {
	return ConflictDTO{
		ID:            c.ID,
		EntityType:    c.EntityType,
		EntityID:      c.EntityID,
		ConflictType:  c.ConflictType,
		ServerPayload: c.ServerPayload,
		ClientPayload: c.ClientPayload,
		Resolution:    c.Resolution.String(),
		CreatedAt:     c.CreatedAt,
	}
}
