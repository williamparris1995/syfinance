package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/sync/domain"
	syncent "github.com/yucai/server/internal/sync/ent"
	"github.com/yucai/server/internal/sync/ent/syncconflict"
	"github.com/yucai/server/internal/sync/ent/syncdevice"
	"github.com/yucai/server/internal/sync/ent/synclog"
)

// SyncLogRepository implements domain.SyncLogRepository.
type SyncLogRepository struct {
	client *syncent.Client
}

// NewSyncLogRepository creates a new SyncLogRepository.
func NewSyncLogRepository(client *syncent.Client) *SyncLogRepository {
	return &SyncLogRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx — PushChanges wraps the whole batch in
// one) it returns a tx-bound client whose writes join the outer transaction;
// otherwise it returns the default r.client.
func (r *SyncLogRepository) clientFor(ctx context.Context) *syncent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return syncent.NewClient(syncent.Driver(d))
	}
	return r.client
}

// Append adds a new entry to the sync log.
func (r *SyncLogRepository) Append(ctx context.Context, entry *domain.SyncLogEntry) error {
	_, err := r.clientFor(ctx).SyncLog.Create().
		SetID(entry.ID).SetTenantID(entry.TenantID).
		SetEntityType(entry.EntityType).SetEntityID(entry.EntityID).
		SetOperation(entry.Operation.String()).SetPayload(entry.Payload).
		SetVersion(entry.Version).SetDeviceID(entry.DeviceID).
		SetCreatedAt(entry.CreatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("append sync log: %w", err)
	}
	return nil
}

// FindSince returns sync log entries after the given version.
func (r *SyncLogRepository) FindSince(ctx context.Context, tenantID uuid.UUID, sinceVersion int64, entityTypes []string) ([]domain.SyncLogEntry, error) {
	query := r.clientFor(ctx).SyncLog.Query().
		Where(synclog.TenantID(tenantID), synclog.VersionGT(sinceVersion))

	if len(entityTypes) > 0 {
		query.Where(synclog.EntityTypeIn(entityTypes...))
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find since: %w", err)
	}

	entries := make([]domain.SyncLogEntry, len(results))
	for i, e := range results {
		entries[i] = domain.SyncLogEntry{
			ID: e.ID, TenantID: e.TenantID,
			EntityType: e.EntityType, EntityID: e.EntityID,
			Operation: domain.ParseSyncOperation(e.Operation),
			Payload: e.Payload, Version: e.Version,
			DeviceID: e.DeviceID, CreatedAt: e.CreatedAt,
		}
	}
	return entries, nil
}

// LatestVersion returns the highest version number for a tenant. Called from
// inside the PushChanges transaction (tx-aware via clientFor) so the batch's
// base version is read under the same lock scope as the appends.
func (r *SyncLogRepository) LatestVersion(ctx context.Context, tenantID uuid.UUID) (int64, error) {
	last, err := r.clientFor(ctx).SyncLog.Query().
		Where(synclog.TenantID(tenantID)).
		Order(syncent.Desc(synclog.FieldVersion)).
		First(ctx)
	if err != nil {
		// No entries yet
		return 0, nil
	}
	return last.Version, nil
}

// SyncDeviceRepository implements domain.SyncDeviceRepository.
type SyncDeviceRepository struct {
	client *syncent.Client
}

// NewSyncDeviceRepository creates a new SyncDeviceRepository.
func NewSyncDeviceRepository(client *syncent.Client) *SyncDeviceRepository {
	return &SyncDeviceRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx (joins the PushChanges
// sqltx transaction when one is open; otherwise the default client).
func (r *SyncDeviceRepository) clientFor(ctx context.Context) *syncent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return syncent.NewClient(syncent.Driver(d))
	}
	return r.client
}

// Register creates a new sync device.
func (r *SyncDeviceRepository) Register(ctx context.Context, device *domain.SyncDevice) error {
	_, err := r.client.SyncDevice.Create().
		SetID(device.ID).SetTenantID(device.TenantID).
		SetDeviceName(device.DeviceName).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("register device: %w", err)
	}
	return nil
}

// FindByID retrieves a device by ID within a tenant.
func (r *SyncDeviceRepository) FindByID(ctx context.Context, tenantID, deviceID uuid.UUID) (*domain.SyncDevice, error) {
	d, err := r.client.SyncDevice.Query().
		Where(syncdevice.TenantID(tenantID), syncdevice.ID(deviceID)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find device: %w", err)
	}
	return &domain.SyncDevice{
		ID: d.ID, TenantID: d.TenantID, DeviceName: d.DeviceName,
		LastSyncVersion: d.LastSyncVersion, LastSyncAt: d.LastSyncAt,
		CreatedAt: d.CreatedAt, UpdatedAt: d.UpdatedAt,
	}, nil
}

// UpdateSyncVersion updates the device's last sync version. Tx-aware via
// clientFor so it commits or rolls back with the PushChanges batch. Scoped by
// tenant AND device: a device id from another tenant matches zero rows and is
// a silent no-op (cross-tenant hygiene for the v1 deviceId fallback).
func (r *SyncDeviceRepository) UpdateSyncVersion(ctx context.Context, tenantID, deviceID uuid.UUID, version int64) error {
	_, err := r.clientFor(ctx).SyncDevice.Update().
		Where(syncdevice.ID(deviceID), syncdevice.TenantID(tenantID)).
		SetLastSyncVersion(version).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update device version: %w", err)
	}
	return nil
}

// SyncConflictRepository implements domain.SyncConflictRepository.
type SyncConflictRepository struct {
	client *syncent.Client
}

// NewSyncConflictRepository creates a new SyncConflictRepository.
func NewSyncConflictRepository(client *syncent.Client) *SyncConflictRepository {
	return &SyncConflictRepository{client: client}
}

// Save creates a new conflict record.
func (r *SyncConflictRepository) Save(ctx context.Context, conflict *domain.SyncConflict) error {
	_, err := r.client.SyncConflict.Create().
		SetID(conflict.ID).SetTenantID(conflict.TenantID).
		SetEntityType(conflict.EntityType).SetEntityID(conflict.EntityID).
		SetConflictType(conflict.ConflictType).
		SetServerPayload(conflict.ServerPayload).SetClientPayload(conflict.ClientPayload).
		SetResolution(conflict.Resolution.String()).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save conflict: %w", err)
	}
	return nil
}

// FindPending returns unresolved conflicts for a tenant.
func (r *SyncConflictRepository) FindPending(ctx context.Context, tenantID uuid.UUID, page domain.PageRequest) (*domain.PaginatedResult[domain.SyncConflict], error) {
	query := r.client.SyncConflict.Query().
		Where(syncconflict.TenantID(tenantID), syncconflict.Resolution("pending"))

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count conflicts: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(syncconflict.IDGTE(cursorID))
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query conflicts: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.SyncConflict, len(results))
	for i, c := range results {
		items[i] = domain.SyncConflict{
			ID: c.ID, TenantID: c.TenantID,
			EntityType: c.EntityType, EntityID: c.EntityID,
			ConflictType: c.ConflictType,
			ServerPayload: c.ServerPayload, ClientPayload: c.ClientPayload,
			Resolution: domain.ParseConflictResolution(c.Resolution),
			ResolvedAt: c.ResolvedAt, CreatedAt: c.CreatedAt, UpdatedAt: c.UpdatedAt,
		}
	}

	return &domain.PaginatedResult[domain.SyncConflict]{
		Items: items, NextPageToken: nextToken, TotalCount: int32(total),
	}, nil
}

// Resolve marks a conflict as resolved.
func (r *SyncConflictRepository) Resolve(ctx context.Context, tenantID, conflictID uuid.UUID, resolution string) error {
	_, err := r.client.SyncConflict.UpdateOneID(conflictID).
		SetResolution(resolution).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("resolve conflict: %w", err)
	}
	return nil
}
