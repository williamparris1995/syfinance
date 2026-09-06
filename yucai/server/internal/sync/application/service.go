package application

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/sync/domain"
)

// ErrVersionConflict reports that a PushChanges batch lost the per-tenant
// version-serialization race on every attempt (each retry re-collided on the
// (tenant_id, version) unique index). The handler maps it to gRPC Aborted:
// the batch itself is valid, it just kept losing the race — the client may
// retry later (spec FR-1 / ADR-1).
var ErrVersionConflict = errors.New("sync push aborted: version conflict retries exhausted")

// ErrInvalidResolution reports a ResolveConflict strategy outside the FINAL
// value domain {server, client, merged} (F16 ADR-4). Those three strings are
// exactly what domain.ParseConflictResolution persists ("pending" is the
// pre-resolution state, not a resolvable strategy); the handler maps this to
// gRPC InvalidArgument.
var ErrInvalidResolution = errors.New("invalid resolution: must be one of server, client, merged")

// validResolutions is the ResolveConflict whitelist — the value domain is
// FINAL (ADR-4): server, client, merged.
var validResolutions = map[string]bool{
	"server": true, "client": true, "merged": true,
}

// conflictTypeVersionConflict is the one conflict class F16 detects (ADR-4):
// an UPDATE whose payload version is not strictly ahead of the server's
// stored row. Finer-grained classes (delete/update races etc.) are F18.
const conflictTypeVersionConflict = "version_conflict"

// versionConflictRetryLimit bounds how many times PushChanges reopens the
// whole batch transaction after a (tenant_id, version) unique-index collision
// (initial attempt + up to this many retries; ADR-1: bounded so a pathological
// contender cannot starve the push).
const versionConflictRetryLimit = 3

// Pull paging contract (F16 ADR-3): page_size semantics are shared by the
// handler (which clamps the wire value) and the service (which defaults for
// direct callers). Default 500 / max 1000.
const (
	// DefaultPullPageSize is the page size applied when the request omits one.
	DefaultPullPageSize = 500
	// MaxPullPageSize caps an oversized request so one pull cannot pin the
	// connection streaming the whole log.
	MaxPullPageSize = 1000
)

// isSyncLogVersionConflict reports whether err is a unique-constraint
// violation on the (tenant_id, version) index of sync_logs — the serialization
// race ADR-1 retries on. Detection is string-based for dual-DB compatibility
// (ent's own sqlgraph.IsUniqueConstraintError matches the same substrings):
//   - SQLite (modernc): "constraint failed: UNIQUE constraint failed:
//     sync_logs.tenant_id, sync_logs.version (2067)" — codes 1555/2067 are
//     SQLITE_CONSTRAINT_PRIMARYKEY/UNIQUE, surfaced only inside the message.
//   - PostgreSQL (pgx): "duplicate key value violates unique constraint
//     \"synclog_tenant_id_version\" (SQLSTATE 23505)" — pgcode 23505.
//
// The match is pinned to THIS index specifically (not any unique violation):
// a business-table unique failure (e.g. the cross-tenant same-id upsert
// fail-closed path) is a deterministic batch error and must surface
// immediately, not burn retries.
func isSyncLogVersionConflict(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, `unique constraint "synclog_tenant_id_version"`) ||
		strings.Contains(msg, "UNIQUE constraint failed: sync_logs.tenant_id, sync_logs.version")
}

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

// RegisterDevice registers a sync device (F16 ADR-2). deviceID is the stable
// device identity: a non-Nil id (the F17 client registration) makes
// re-registration idempotent — the repo returns the existing row (with its
// current last_sync_version) instead of tripping the PK; uuid.Nil keeps the
// server-generated fresh id, matching the current RegisterDeviceRequest wire
// shape (device_name only, no device identity yet).
func (s *Service) RegisterDevice(ctx context.Context, tenantID, deviceID uuid.UUID, deviceName string) (*domain.SyncDevice, error) {
	device, err := domain.NewSyncDevice(tenantID, deviceName)
	if err != nil {
		return nil, fmt.Errorf("create device: %w", err)
	}
	if deviceID != uuid.Nil {
		device.ID = deviceID
	}
	if err := s.deviceRepo.Register(ctx, device); err != nil {
		return nil, fmt.Errorf("register device: %w", err)
	}
	return device, nil
}

// GetSyncStatus returns the current sync state for a device (device-scoped:
// the device row's own last_sync_version).
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

// GetTenantSyncStatus returns the tenant-aggregate sync view — the GetSyncStatus
// request shape with an empty device_id (F16 ADR-2: backward compatible, the
// field is new on the wire; empty = no device filter). last_sync_version is
// the tenant log frontier (LatestVersion), NOT any single device's position;
// DeviceID stays Nil (no device attribution — the handler emits an empty
// device_id for it).
func (s *Service) GetTenantSyncStatus(ctx context.Context, tenantID uuid.UUID) (*SyncStatusDTO, error) {
	latest, err := s.logRepo.LatestVersion(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("latest version: %w", err)
	}

	pendingConflicts, err := s.conflictRepo.FindPending(ctx, tenantID, domain.PageRequest{PageSize: 1})
	if err != nil {
		return nil, fmt.Errorf("count conflicts: %w", err)
	}

	return &SyncStatusDTO{
		DeviceID:         uuid.Nil,
		LastSyncVersion:  latest,
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
//   - Serialization (F16 ADR-1): two concurrent batches can both read the same
//     LatestVersion; the (tenant_id, version) unique index turns the loser's
//     first append into a constraint failure. The WHOLE sqltx is then reopened
//     (fresh LatestVersion, full replay of writes + logs) up to
//     versionConflictRetryLimit times; still colliding -> ErrVersionConflict
//     (wire: Aborted). Replay is safe: business writes are idempotent upserts
//     keyed by entity id (F11 FR-1) and every aborted attempt rolled back, so
//     the retry re-applies the batch to pre-attempt state. Reopening the
//     transaction — not retrying a single append — is required because under
//     Postgres READ COMMITTED the losing transaction is aborted by the
//     constraint failure and cannot continue; and the stale base version
//     poisoned every version it derived.
//   - Conflict detection skip semantics (F16 ADR-4, multi-device): each
//     UPDATE-typed change is compared against the server's current row via
//     the writer's CurrentState. When the row exists and the payload's own
//     version is not strictly ahead (payload.version <= server.version) the
//     change is SKIPPED — no business write, no sync_log append (it consumes
//     no log version) — and a sync_conflicts row records both states plus the
//     response's conflicts slice. The rest of the batch lands normally: one
//     device's conflict must not fail its own clean changes. Atomicity
//     boundary: "what is applied is all-or-nothing" — a conflict is an
//     explicit skip, not a failure, so the committed subset is exactly the
//     non-conflicting changes. CREATE and DELETE are never checked (spec
//     FR-4: a new entity cannot conflict; a tombstone is the client's final
//     word).
//   - Single-device zero-regression (F10-F13): the shipped client stamps
//     every upsert CREATE (client binding/data/grpc_offline_sync_port.dart),
//     which is never checked; and even a genuine UPDATE from the owning
//     device carries a strictly newer payload version (the client increments
//     it per local edit), so payload.version <= server.version cannot hold.
//     Detection therefore only fires for a stale-base push from ANOTHER
//     device (or an equal-version UPDATE re-delivery — flagged per ADR-4's
//     "<=" deliberately; identical-payload short-circuiting is F18 space).
//   - Device row: with the v1 deviceId fallback (= tenantID, RegisterDevice
//     not yet wired client-side) the device row often does not exist; a
//     not-found on the version bump is tolerated (logged) rather than failing
//     the batch. RegisterDevice integration is ticket 16.
func (s *Service) PushChanges(ctx context.Context, tenantID, deviceID uuid.UUID, payloads []SyncPayloadDTO) (int64, []ConflictDTO, error) {
	if len(payloads) == 0 {
		// Conflicts stay empty by definition: nothing was pushed.
		return 0, nil, nil
	}

	ordered, err := s.orderBatch(payloads)
	if err != nil {
		return 0, nil, err
	}

	var lastVersion int64
	var conflicts []ConflictDTO
	for attempt := 0; ; attempt++ {
		// Fresh per attempt: a retried (rolled-back) attempt must not leave
		// phantom conflict DTOs behind if the replay classifies differently.
		batchConflicts := make([]ConflictDTO, 0)
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
					// The probe also lifts the payload's own "Version" — the
					// entity version the conflict check compares against the
					// stored row.
					var probe struct {
						ID      uuid.UUID
						Version int64
					}
					if err := json.Unmarshal(p.Payload, &probe); err != nil {
						return fmt.Errorf("decode %s %s payload id: %w", p.EntityType, p.EntityID, err)
					}
					if probe.ID != p.EntityID {
						return fmt.Errorf("entity id mismatch: change id %s but payload id %s (%s)", p.EntityID, probe.ID, p.EntityType)
					}

					// Conflict detection (UPDATE only, ADR-4): a stale-base
					// update is skipped and recorded instead of applied.
					if p.Operation == domain.SyncOperationUpdate {
						serverVersion, serverPayload, exists, cerr := writer.CurrentState(ctxT, tenantID, p.EntityID.String())
						if cerr != nil {
							return fmt.Errorf("read current state %s %s: %w", p.EntityType, p.EntityID, cerr)
						}
						if exists && probe.Version <= serverVersion {
							conflict := domain.NewSyncConflict(
								tenantID, p.EntityType, p.EntityID,
								conflictTypeVersionConflict,
								serverPayload, p.Payload,
							)
							if serr := s.conflictRepo.Save(ctxT, conflict); serr != nil {
								return fmt.Errorf("save conflict %s %s: %w", p.EntityType, p.EntityID, serr)
							}
							batchConflicts = append(batchConflicts, ConflictToDTO(conflict))
							slog.Warn("sync push change skipped: version conflict",
								"operation", "sync_push",
								"tenant_id", tenantID.String(),
								"entity_type", p.EntityType,
								"entity_id", p.EntityID.String(),
								"client_version", probe.Version,
								"server_version", serverVersion)
							continue
						}
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
		if txErr == nil {
			conflicts = batchConflicts
			break
		}
		if !isSyncLogVersionConflict(txErr) {
			slog.Error("sync push failed",
				"operation", "sync_push",
				"tenant_id", tenantID.String(),
				"count", len(payloads),
				"error", txErr.Error())
			return 0, nil, txErr
		}
		if attempt >= versionConflictRetryLimit {
			slog.Error("sync push aborted: version conflict retries exhausted",
				"operation", "sync_push",
				"tenant_id", tenantID.String(),
				"count", len(payloads),
				"retries", versionConflictRetryLimit,
				"error", txErr.Error())
			return 0, nil, fmt.Errorf("%w: %v", ErrVersionConflict, txErr)
		}
		slog.Warn("sync push version collision, reopening batch transaction",
			"operation", "sync_push",
			"tenant_id", tenantID.String(),
			"count", len(payloads),
			"attempt", attempt+1)
	}

	slog.Info("sync push committed",
		"operation", "sync_push",
		"tenant_id", tenantID.String(),
		"count", len(payloads),
		"conflicts", len(conflicts),
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

// PullChanges returns one ordered page of changes since a given version for a
// tenant (F16 ADR-3: sync_log replay pagination).
//
// Response contract:
//   - Changes are ordered by sync_log version ASCENDING. The client MUST apply
//     them in that order; every replay is idempotent (upserts key by entity
//     id, deletes are tombstone no-ops on re-delivery), so a crashed pull can
//     simply re-pull the same since_version.
//   - has_more reports whether older-than-frontier entries remain: the repo
//     fetches pageSize+1 rows and the sentinel row is trimmed here. On
//     has_more the client continues with since_version = the version of the
//     LAST change in this page (not latest_version, which is the frontier and
//     may skip entries still in flight on later pages).
//   - latest_version keeps its pre-F16 meaning: the tenant log frontier.
//   - Tombstone rows (empty payload, DELETE op) are returned verbatim — GC /
//     retention is deliberately out of scope (YAGNI, spec scope table).
//
// pageSize <= 0 (a direct service caller; the handler sanitizes the wire
// value) falls back to DefaultPullPageSize.
func (s *Service) PullChanges(ctx context.Context, tenantID uuid.UUID, sinceVersion int64, entityTypes []string, pageSize int) ([]SyncPayloadDTO, int64, bool, error) {
	if pageSize <= 0 {
		pageSize = DefaultPullPageSize
	}

	entries, err := s.logRepo.FindSince(ctx, tenantID, sinceVersion, entityTypes, pageSize)
	if err != nil {
		return nil, 0, false, fmt.Errorf("find since: %w", err)
	}

	// The +1 sentinel row only proves more entries exist past this page.
	hasMore := len(entries) > pageSize
	if hasMore {
		entries = entries[:pageSize]
	}

	payloads := make([]SyncPayloadDTO, len(entries))
	for i, entry := range entries {
		payloads[i] = PayloadToDTO(&entry)
	}

	latestVersion, err := s.logRepo.LatestVersion(ctx, tenantID)
	if err != nil {
		return nil, 0, false, fmt.Errorf("latest version: %w", err)
	}

	return payloads, latestVersion, hasMore, nil
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

// ResolveConflict resolves a conflict with the given strategy (F16 ADR-4).
// The resolution value domain is FINAL: {server, client, merged} — validated
// here BEFORE the repo round-trip so a bad strategy is a client error
// (InvalidArgument on the wire), not a DB write.
func (s *Service) ResolveConflict(ctx context.Context, tenantID, conflictID uuid.UUID, resolution string) error {
	if !validResolutions[resolution] {
		return fmt.Errorf("%w: got %q", ErrInvalidResolution, resolution)
	}
	if err := s.conflictRepo.Resolve(ctx, tenantID, conflictID, resolution); err != nil {
		return fmt.Errorf("resolve conflict: %w", err)
	}
	return nil
}
