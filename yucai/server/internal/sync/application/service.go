package application

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/sync/domain"
)

// deleteOrder is the canonical DELETE application order for a sync batch:
// dependents first, account last — the same module sequence backup's
// orderedPortsForPurge produces over the wire port declaration order
// [account, transaction, debt, budget, goal, holding, template, tag]. A
// client batch listing "delete account" before "delete transaction" is
// reordered so referencing rows are removed before their referents (FR-2).
var deleteOrder = []string{
	"transaction", "debt", "budget", "goal", "holding", "template", "tag", "account",
}

// upsertOrder is the canonical CREATE/UPDATE application order: account first,
// then the rest — mirroring backup's orderedPortsForImport. A transaction
// pushed before the account it references still lands (FR-1).
var upsertOrder = []string{
	"account", "transaction", "debt", "budget", "goal", "holding", "template", "tag",
}

// Service orchestrates sync operations.
type Service struct {
	logRepo      domain.SyncLogRepository
	deviceRepo   domain.SyncDeviceRepository
	conflictRepo domain.SyncConflictRepository
	resolver     *ConflictResolver
	// writers dispatches each change to its module writer, keyed by entity_type
	// (the client SyncModule name — must match the writer Name() verbatim).
	writers map[string]domain.SyncEntityWriter
	// db + dialect back the batch transaction (sqltx.WithTx): every business
	// write and sync_log append of one PushChanges call joins ONE transaction.
	db      *sql.DB
	dialect string
}

// NewService creates a new sync application service. writers may be nil/empty
// (PushChanges then fails closed on any typed change — the forward-compat
// gate); db drives the batch transaction and must be the same pool every
// module ent client wraps.
func NewService(
	logRepo domain.SyncLogRepository,
	deviceRepo domain.SyncDeviceRepository,
	conflictRepo domain.SyncConflictRepository,
	resolver *ConflictResolver,
	writers map[string]domain.SyncEntityWriter,
	db *sql.DB,
	dialect string,
) *Service {
	return &Service{
		logRepo:      logRepo,
		deviceRepo:   deviceRepo,
		conflictRepo: conflictRepo,
		resolver:     resolver,
		writers:      writers,
		db:           db,
		dialect:      dialect,
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

// PushChanges processes one client batch ATOMICALLY (F11 FR-1/2/3, ADR-3/4):
// the module dispatch (DELETEs then upserts, each in dependency order), the
// sync_log appends (versions LatestVersion+1..N read and assigned inside the
// same transaction), and the device-version bump all run inside ONE
// sqltx.WithTx — any failure rolls the entire batch back, so no partial
// business state or torn log survives.
//
// Design notes:
//   - Ordering: DELETEs are applied before upserts (a batch that deletes A and
//     re-creates B never trips over A's old references), DELETEs in the
//     dependents-first purge order, upserts in the account-first import order.
//     Within one entity type the client's batch order is preserved (stable
//     sort). This fixes the dependency direction declaratively instead of
//     trusting client ordering.
//   - Versioning: sync_log versions are assigned LatestVersion+1..N once per
//     batch (the old loop re-queried LatestVersion per change outside any
//     transaction). A re-push appends new versions — accepted per FR-3: a
//     single-device client only re-pushes a batch whose response it never
//     received, and business-side idempotency is guaranteed by the per-entity
//     upsert keying.
//   - Conflicts are deliberately always empty in v1 single-device sync
//     (detection/resolution is ticket 16).
//   - Device row: with the v1 deviceId fallback (= tenantID, RegisterDevice
//     not yet wired client-side) the device row often does not exist; a
//     not-found on the version bump is tolerated (logged) rather than failing
//     the batch. RegisterDevice integration is ticket 16.
func (s *Service) PushChanges(ctx context.Context, tenantID, deviceID uuid.UUID, payloads []SyncPayloadDTO) (int64, []ConflictDTO, error) {
	// Conflicts stay empty by design in v1 (ticket 16).
	var conflicts []ConflictDTO

	if len(payloads) == 0 {
		return 0, conflicts, nil
	}

	ordered, err := s.orderBatch(payloads)
	if err != nil {
		return 0, nil, err
	}

	var lastVersion int64
	txErr := sqltx.WithTx(ctx, s.db, s.dialect, &sql.TxOptions{
		Isolation: sql.LevelReadCommitted,
	}, func(ctxT context.Context) error {
		base, err := s.logRepo.LatestVersion(ctxT, tenantID)
		if err != nil {
			return fmt.Errorf("read latest version: %w", err)
		}
		lastVersion = base

		for _, p := range ordered {
			writer, ok := s.writers[p.EntityType]
			if !ok {
				// Fail closed: an unknown entity_type rejects the whole batch
				// (forward-compat gate — e.g. holding_ledger until its writer
				// registers).
				return fmt.Errorf("unknown entity type %q", p.EntityType)
			}
			var applyErr error
			if p.Operation == domain.SyncOperationDelete {
				applyErr = writer.Delete(ctxT, tenantID, p.EntityID.String())
			} else {
				// CREATE and UPDATE are the same server-side op: an upsert
				// keyed by entity id (idempotent on re-push). First fail
				// closed on a change whose EntityID disagrees with the id
				// inside its payload — otherwise the log would record one id
				// while the writer persisted another (silent substitution).
				// Every module entity serializes its id as the top-level "ID"
				// uuid field (default Go JSON naming, backup envelope shape).
				var probe struct {
					ID uuid.UUID
				}
				if err := json.Unmarshal(p.Payload, &probe); err != nil {
					return fmt.Errorf("decode %s %s payload id: %w", p.EntityType, p.EntityID, err)
				}
				if probe.ID != p.EntityID {
					return fmt.Errorf("entity id mismatch: change id %s but payload id %s (%s)", p.EntityID, probe.ID, p.EntityType)
				}
				applyErr = writer.Upsert(ctxT, tenantID, p.Payload)
			}
			if applyErr != nil {
				return fmt.Errorf("apply %s %s %s: %w", p.EntityType, p.EntityID, p.Operation, applyErr)
			}

			lastVersion++
			// sync_logs.payload is NOT NULL; tombstones (DELETE ops) may carry
			// a nil proto bytes field — normalize to an empty non-nil slice.
			payload := p.Payload
			if payload == nil {
				payload = []byte{}
			}
			entry := &domain.SyncLogEntry{
				ID:         uuid.New(),
				TenantID:   tenantID,
				EntityType: p.EntityType,
				EntityID:   p.EntityID,
				Operation:  p.Operation,
				Payload:    payload,
				Version:    lastVersion,
				DeviceID:   deviceID,
				CreatedAt:  time.Now(),
			}
			if err := s.logRepo.Append(ctxT, entry); err != nil {
				return fmt.Errorf("append sync log: %w", err)
			}
		}

		// Device version bump: tolerated as a no-op when the device row is
		// absent (v1 fallback deviceId semantics — see method doc).
		if err := s.deviceRepo.UpdateSyncVersion(ctxT, tenantID, deviceID, lastVersion); err != nil {
			slog.Warn("sync push: device row absent, version not tracked",
				"operation", "sync_push",
				"tenant_id", tenantID.String(),
				"device_id", deviceID.String(),
				"error", err.Error())
		}
		return nil
	})
	if txErr != nil {
		slog.Error("sync push failed",
			"operation", "sync_push",
			"tenant_id", tenantID.String(),
			"count", len(payloads),
			"error", txErr.Error())
		return 0, nil, txErr
	}

	slog.Info("sync push committed",
		"operation", "sync_push",
		"tenant_id", tenantID.String(),
		"count", len(payloads),
		"synced_version", lastVersion)
	return lastVersion, conflicts, nil
}

// orderBatch partitions the batch into DELETEs and upserts (CREATE/UPDATE),
// sorts each group by its canonical module order (stable — same-type changes
// keep client order), and concatenates deletes-first. Unknown entity types
// error here, BEFORE any write runs.
func (s *Service) orderBatch(payloads []SyncPayloadDTO) ([]SyncPayloadDTO, error) {
	deletes := make([]SyncPayloadDTO, 0, len(payloads))
	upserts := make([]SyncPayloadDTO, 0, len(payloads))
	for _, p := range payloads {
		if _, ok := s.writers[p.EntityType]; !ok {
			return nil, fmt.Errorf("unknown entity type %q", p.EntityType)
		}
		if p.Operation == domain.SyncOperationDelete {
			deletes = append(deletes, p)
		} else {
			upserts = append(upserts, p)
		}
	}

	sortByOrder := func(group []SyncPayloadDTO, order []string) {
		rank := make(map[string]int, len(order))
		for i, name := range order {
			rank[name] = i
		}
		sort.SliceStable(group, func(i, j int) bool {
			return rank[group[i].EntityType] < rank[group[j].EntityType]
		})
	}
	sortByOrder(deletes, deleteOrder)
	sortByOrder(upserts, upsertOrder)

	ordered := make([]SyncPayloadDTO, 0, len(payloads))
	ordered = append(ordered, deletes...)
	ordered = append(ordered, upserts...)
	return ordered, nil
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
