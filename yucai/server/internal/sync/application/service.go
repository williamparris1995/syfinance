package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sync/domain"
)

// Service orchestrates sync operations.
type Service struct {
	logRepo      domain.SyncLogRepository
	deviceRepo   domain.SyncDeviceRepository
	conflictRepo domain.SyncConflictRepository
	resolver     *ConflictResolver
}

// NewService creates a new sync application service.
func NewService(
	logRepo domain.SyncLogRepository,
	deviceRepo domain.SyncDeviceRepository,
	conflictRepo domain.SyncConflictRepository,
	resolver *ConflictResolver,
) *Service {
	return &Service{
		logRepo:      logRepo,
		deviceRepo:   deviceRepo,
		conflictRepo: conflictRepo,
		resolver:     resolver,
	}
}

// RegisterDevice registers a new sync device for a tenant.
func (s *Service) RegisterDevice(ctx context.Context, tenantID uuid.UUID, deviceName string) (*domain.SyncDevice, error) {
	device, err := domain.NewSyncDevice(tenantID, deviceName)
	if err != nil {
		return nil, fmt.Errorf("create device: %w", err)
	}
	if err := s.deviceRepo.Register(ctx, device); err != nil {
		return nil, fmt.Errorf("register device: %w", err)
	}
	return device, nil
}

// GetSyncStatus returns the current sync state for a device.
func (s *Service) GetSyncStatus(ctx context.Context, tenantID, deviceID uuid.UUID) (*SyncStatusDTO, error) {
	device, err := s.deviceRepo.FindByID(ctx, tenantID, deviceID)
	if err != nil {
		return nil, fmt.Errorf("find device: %w", err)
	}

	pendingConflicts, err := s.conflictRepo.FindPending(ctx, tenantID, domain.PageRequest{PageSize: 1})
	if err != nil {
		return nil, fmt.Errorf("count conflicts: %w", err)
	}

	return &SyncStatusDTO{
		DeviceID:         device.ID,
		LastSyncVersion:  device.LastSyncVersion,
		LastSyncAt:       device.LastSyncAt,
		PendingConflicts: pendingConflicts.TotalCount,
	}, nil
}

// PushChanges processes incoming changes from a client device.
func (s *Service) PushChanges(ctx context.Context, tenantID, deviceID uuid.UUID, payloads []SyncPayloadDTO) (int64, []ConflictDTO, error) {
	var conflicts []ConflictDTO
	var lastVersion int64

	for _, p := range payloads {
		// Get current latest version for conflict detection
		latestVersion, _ := s.logRepo.LatestVersion(ctx, tenantID)

		// Create sync log entry
		entry := &domain.SyncLogEntry{
			ID:         uuid.New(),
			TenantID:   tenantID,
			EntityType: p.EntityType,
			EntityID:   p.EntityID,
			Operation:  p.Operation,
			Payload:    p.Payload,
			Version:    latestVersion + 1,
			DeviceID:   deviceID,
		}

		if err := s.logRepo.Append(ctx, entry); err != nil {
			return 0, nil, fmt.Errorf("append sync log: %w", err)
		}
		lastVersion = entry.Version
	}

	// Update device sync version
	if lastVersion > 0 {
		if err := s.deviceRepo.UpdateSyncVersion(ctx, tenantID, deviceID, lastVersion); err != nil {
			return 0, nil, fmt.Errorf("update device version: %w", err)
		}
	}

	return lastVersion, conflicts, nil
}

// PullChanges returns changes since a given version for a tenant.
func (s *Service) PullChanges(ctx context.Context, tenantID uuid.UUID, sinceVersion int64, entityTypes []string) ([]SyncPayloadDTO, int64, error) {
	entries, err := s.logRepo.FindSince(ctx, tenantID, sinceVersion, entityTypes)
	if err != nil {
		return nil, 0, fmt.Errorf("find since: %w", err)
	}

	payloads := make([]SyncPayloadDTO, len(entries))
	for i, entry := range entries {
		payloads[i] = PayloadToDTO(&entry)
	}

	latestVersion, err := s.logRepo.LatestVersion(ctx, tenantID)
	if err != nil {
		return nil, 0, fmt.Errorf("latest version: %w", err)
	}

	return payloads, latestVersion, nil
}

// ListConflicts returns pending conflicts for a tenant.
func (s *Service) ListConflicts(ctx context.Context, tenantID uuid.UUID, page domain.PageRequest) ([]ConflictDTO, string, int32, error) {
	result, err := s.conflictRepo.FindPending(ctx, tenantID, page)
	if err != nil {
		return nil, "", 0, fmt.Errorf("find pending conflicts: %w", err)
	}

	dtos := make([]ConflictDTO, len(result.Items))
	for i, c := range result.Items {
		dtos[i] = ConflictToDTO(&c)
	}

	return dtos, result.NextPageToken, result.TotalCount, nil
}

// ResolveConflict resolves a conflict with the given strategy.
func (s *Service) ResolveConflict(ctx context.Context, tenantID, conflictID uuid.UUID, resolution string) error {
	if err := s.conflictRepo.Resolve(ctx, tenantID, conflictID, resolution); err != nil {
		return fmt.Errorf("resolve conflict: %w", err)
	}
	return nil
}
