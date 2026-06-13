package application

import (
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sync/domain"
)

// ConflictResolver determines the resolution strategy for sync conflicts.
type ConflictResolver struct{}

// NewConflictResolver creates a new ConflictResolver.
func NewConflictResolver() *ConflictResolver {
	return &ConflictResolver{}
}

// Resolve determines the automatic resolution for a conflict.
// Returns the resolution strategy and the winning payload.
func (r *ConflictResolver) Resolve(conflictType string, serverPayload, clientPayload []byte) (domain.ConflictResolution, []byte, error) {
	switch conflictType {
	case "update_update":
		// Server wins: higher version authority
		return domain.ConflictResolutionServerWins, serverPayload, nil
	case "delete_update":
		// Delete wins: tombstone takes precedence
		return domain.ConflictResolutionServerWins, nil, nil
	case "update_delete":
		// Delete wins
		return domain.ConflictResolutionServerWins, nil, nil
	case "create_create":
		// Server wins: server assigns final ID
		return domain.ConflictResolutionServerWins, serverPayload, nil
	default:
		return domain.ConflictResolutionPending, nil, fmt.Errorf("unknown conflict type: %s", conflictType)
	}
}

// DetectConflict checks if two operations on the same entity conflict.
func (r *ConflictResolver) DetectConflict(entityType string, entityID uuid.UUID, clientOp domain.SyncOperation, serverVersion, clientVersion int64) *domain.SyncConflict {
	if serverVersion > 0 && clientVersion < serverVersion {
		conflictType := fmt.Sprintf("%s_%s", clientOp.String(), "update")
		return domain.NewSyncConflict(uuid.Nil, entityType, entityID, conflictType, nil, nil)
	}
	return nil
}
