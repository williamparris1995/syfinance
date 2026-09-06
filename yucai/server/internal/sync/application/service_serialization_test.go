package application

// Tier-A tests for F16 T1 S1 (version serialization, ADR-1) and S2
// (RegisterDevice full chain, ADR-2), extending the F11 push harness:
//   - (tenant_id, version) unique index + whole-batch retry: a version
//     collision inside the batch transaction reopens the ENTIRE sqltx (fresh
//     LatestVersion + replayed writes + logs) and succeeds on the retry.
//   - Retry bound: a perpetually colliding push aborts after <=3 retries and
//     leaves the log untouched (every attempt rolled back).
//   - RegisterDevice idempotency (caller-supplied stable device id) and the
//     server-generated default.
//   - GetSyncStatus device scope vs the tenant-aggregate view (empty
//     device_id on the wire).
//
// Collision seam: a single-connection SQLite DB cannot interleave a committed
// write between LatestVersion and the appends (the tx owns THE connection), so
// the race is simulated at the port boundary — staleLatestVersionRepo makes
// LatestVersion return a stale base while committed log rows exist, which is
// exactly what the losing side of a real concurrent push observes. The unique
// index then trips the append, the same code path a real Postgres collision
// takes.

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"

	accountdomain "github.com/yucai/server/internal/account/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// staleLatestVersionRepo wraps a SyncLogRepository and returns base version 0
// for its first staleFor LatestVersion calls, then delegates. The test seam
// that deterministically reproduces the read-before-a-concurrent-commit race
// on the single-connection SQLite harness (see file comment).
type staleLatestVersionRepo struct {
	syncdomain.SyncLogRepository
	latestCalls int
	staleFor    int
}

func (r *staleLatestVersionRepo) LatestVersion(ctx context.Context, tenantID uuid.UUID) (int64, error) {
	r.latestCalls++
	if r.latestCalls <= r.staleFor {
		return 0, nil
	}
	return r.SyncLogRepository.LatestVersion(ctx, tenantID)
}

// TestPushChanges_VersionCollision_RetriesWholeBatch (FR-1 serialization):
// the log holds committed rows v1..v2; the pushed batch reads a STALE base
// (0) on its first transaction, so its first append collides with the unique
// (tenant_id, version) index. PushChanges must reopen the whole batch
// transaction — re-reading LatestVersion and replaying the business writes
// and log appends — and succeed with contiguous versions. Replay safety rests
// on per-entity idempotent upserts (F11 FR-1): re-applying an upsert keyed by
// entity id to rows the aborted attempt already (tentatively) wrote cannot
// duplicate state, and the aborted attempt's writes are rolled back anyway.
func TestPushChanges_VersionCollision_RetriesWholeBatch(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	// Seed two committed log rows (v1: account A, v2: account B).
	seed := make([]SyncPayloadDTO, 0, 2)
	var seededIDs []uuid.UUID
	for _, name := range []string{"Seed one", "Seed two"} {
		payload := accountPayload(t, h.tenantID, name, 1)
		var acc accountdomain.Account
		if err := json.Unmarshal(payload, &acc); err != nil {
			t.Fatalf("decode seed payload: %v", err)
		}
		seededIDs = append(seededIDs, acc.ID)
		seed = append(seed, SyncPayloadDTO{
			EntityType: "account", EntityID: acc.ID,
			Operation: syncdomain.SyncOperationCreate, Payload: payload,
			Version: 1, DeviceID: h.deviceID,
		})
	}
	if v, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, seed); err != nil || v != 2 {
		t.Fatalf("seed push: v=%d err=%v, want v=2 nil", v, err)
	}

	// The racing push: first transaction reads a stale base (0) — its appends
	// at v1/v2 collide with the committed rows above.
	stale := &staleLatestVersionRepo{SyncLogRepository: h.logRepo, staleFor: 1}
	racingSvc := NewService(stale, h.deviceRepo, h.conflictRepo, h.resolver, h.writers, h.db, sqliteDialect)

	racing := make([]SyncPayloadDTO, 0, 2)
	var racingIDs []uuid.UUID
	for _, name := range []string{"Racing one", "Racing two"} {
		payload := accountPayload(t, h.tenantID, name, 1)
		var acc accountdomain.Account
		if err := json.Unmarshal(payload, &acc); err != nil {
			t.Fatalf("decode racing payload: %v", err)
		}
		racingIDs = append(racingIDs, acc.ID)
		racing = append(racing, SyncPayloadDTO{
			EntityType: "account", EntityID: acc.ID,
			Operation: syncdomain.SyncOperationCreate, Payload: payload,
			Version: 1, DeviceID: h.deviceID,
		})
	}

	v, _, err := racingSvc.PushChanges(ctx, h.tenantID, h.deviceID, racing)
	if err != nil {
		t.Fatalf("colliding push must retry and succeed, got: %v", err)
	}
	if v != 4 {
		t.Fatalf("synced version after retry = %d, want 4 (2 seeded + 2 replayed)", v)
	}
	if stale.latestCalls != 2 {
		t.Fatalf("LatestVersion calls = %d, want 2 (stale attempt + retried attempt)", stale.latestCalls)
	}

	// The log holds exactly versions 1..4 — no duplicates (unique index) and
	// no gaps from the aborted attempt (whole-tx rollback).
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 4 {
		t.Fatalf("log entries = %d, want 4", len(entries))
	}
	for i, want := range []int64{1, 2, 3, 4} {
		if entries[i].Version != want {
			t.Errorf("log[%d].version = %d, want %d (contiguous, no duplicates)", i, entries[i].Version, want)
		}
	}

	// Business rows: the replay did not duplicate anything — 4 accounts total.
	for _, id := range append(append([]uuid.UUID{}, seededIDs...), racingIDs...) {
		if _, err := h.accountCl.Account.Get(ctx, id); err != nil {
			t.Errorf("account %s missing after retry: %v", id, err)
		}
	}
	if n := tenantAccountCount(t, h, ctx); n != 4 {
		t.Fatalf("account rows = %d, want 4 (seed 2 + racing 2, replay idempotent)", n)
	}
}

// tenantAccountCount counts the tenant's account rows.
func tenantAccountCount(t *testing.T, h *pushHarness, ctx context.Context) int {
	t.Helper()
	rows, err := h.accountCl.Account.Query().All(ctx)
	if err != nil {
		t.Fatalf("query accounts: %v", err)
	}
	return len(rows)
}

// TestPushChanges_VersionCollisionExhausted_Aborts (FR-1 retry bound): a
// push whose base version is perpetually stale collides on EVERY attempt;
// after the bounded retries the push fails with ErrVersionConflict (mapped to
// Aborted on the wire) and the log is untouched — each attempt's partial
// writes rolled back with its transaction.
func TestPushChanges_VersionCollisionExhausted_Aborts(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	seedPayload := accountPayload(t, h.tenantID, "Seed", 1)
	var seedAcc accountdomain.Account
	if err := json.Unmarshal(seedPayload, &seedAcc); err != nil {
		t.Fatalf("decode seed payload: %v", err)
	}
	if v, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "account", EntityID: seedAcc.ID,
		Operation: syncdomain.SyncOperationCreate, Payload: seedPayload,
		Version: 1, DeviceID: h.deviceID,
	}}); err != nil || v != 1 {
		t.Fatalf("seed push: v=%d err=%v", v, err)
	}

	// Perpetually stale base: every attempt assigns v1 and collides.
	stale := &staleLatestVersionRepo{SyncLogRepository: h.logRepo, staleFor: 100}
	racingSvc := NewService(stale, h.deviceRepo, h.conflictRepo, h.resolver, h.writers, h.db, sqliteDialect)

	payload := accountPayload(t, h.tenantID, "Doomed", 1)
	var acc accountdomain.Account
	if err := json.Unmarshal(payload, &acc); err != nil {
		t.Fatalf("decode payload: %v", err)
	}

	_, _, err := racingSvc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "account", EntityID: acc.ID,
		Operation: syncdomain.SyncOperationCreate, Payload: payload,
		Version: 1, DeviceID: h.deviceID,
	}})
	if err == nil {
		t.Fatal("perpetually colliding push must fail after bounded retries")
	}
	if !errors.Is(err, ErrVersionConflict) {
		t.Fatalf("exhausted collision must surface ErrVersionConflict (wire: Aborted), got: %v", err)
	}
	// 1 initial attempt + 3 retries, then abort.
	if stale.latestCalls != 1+versionConflictRetryLimit {
		t.Fatalf("LatestVersion calls = %d, want %d (initial + %d retries)", stale.latestCalls, 1+versionConflictRetryLimit, versionConflictRetryLimit)
	}

	// The log (and business tables) are untouched by the aborted attempts.
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 1 || entries[0].Version != 1 {
		t.Fatalf("log after exhausted retries = %+v, want exactly the seeded v1 row", entries)
	}
	if _, err := h.accountCl.Account.Get(ctx, acc.ID); err == nil {
		t.Fatal("racing account must not persist after exhausted retries")
	}
}

// TestRegisterDevice_IdempotentSameDeviceID (ADR-2): a caller-supplied stable
// device id (the F17 client identity) makes re-registration idempotent — the
// retry returns the EXISTING row (same id, its current last_sync_version)
// instead of erroring or creating a second device.
func TestRegisterDevice_IdempotentSameDeviceID(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	deviceID := uuid.New()
	first, err := h.svc.RegisterDevice(ctx, h.tenantID, deviceID, "phone")
	if err != nil {
		t.Fatalf("first register: %v", err)
	}
	if first.ID != deviceID {
		t.Fatalf("registered id = %s, want caller-supplied %s", first.ID, deviceID)
	}

	// The device pushes; its tracked version moves to 3.
	for i := 0; i < 3; i++ {
		payload := accountPayload(t, h.tenantID, "acc", 1)
		var acc accountdomain.Account
		if err := json.Unmarshal(payload, &acc); err != nil {
			t.Fatalf("decode payload: %v", err)
		}
		if _, _, err := h.svc.PushChanges(ctx, h.tenantID, deviceID, []SyncPayloadDTO{{
			EntityType: "account", EntityID: acc.ID,
			Operation: syncdomain.SyncOperationCreate, Payload: payload,
			Version: 1, DeviceID: deviceID,
		}}); err != nil {
			t.Fatalf("push %d: %v", i, err)
		}
	}

	second, err := h.svc.RegisterDevice(ctx, h.tenantID, deviceID, "phone-retry")
	if err != nil {
		t.Fatalf("idempotent re-register must succeed: %v", err)
	}
	if second.ID != deviceID {
		t.Fatalf("re-registered id = %s, want %s", second.ID, deviceID)
	}
	if second.LastSyncVersion != 3 {
		t.Fatalf("re-registered LastSyncVersion = %d, want the existing row's 3", second.LastSyncVersion)
	}
	if second.DeviceName != "phone" {
		t.Fatalf("re-registered DeviceName = %q, want the persisted %q", second.DeviceName, "phone")
	}
}

// TestRegisterDevice_ServerGeneratedIDWhenNil: uuid.Nil deviceID (the current
// RegisterDeviceRequest wire shape carries no device identity) keeps the
// server-generated fresh id per call — two calls create two devices.
func TestRegisterDevice_ServerGeneratedIDWhenNil(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	a, err := h.svc.RegisterDevice(ctx, h.tenantID, uuid.Nil, "phone-a")
	if err != nil {
		t.Fatalf("register a: %v", err)
	}
	b, err := h.svc.RegisterDevice(ctx, h.tenantID, uuid.Nil, "phone-b")
	if err != nil {
		t.Fatalf("register b: %v", err)
	}
	if a.ID == uuid.Nil || b.ID == uuid.Nil {
		t.Fatalf("server-generated ids must be non-nil, got %s / %s", a.ID, b.ID)
	}
	if a.ID == b.ID {
		t.Fatalf("two Nil-id registrations must create distinct devices, both %s", a.ID)
	}
}

// TestRegisterDevice_EmptyName_Rejected keeps the domain validation pinned at
// the service boundary.
func TestRegisterDevice_EmptyName_Rejected(t *testing.T) {
	h := newPushHarness(t)
	if _, err := h.svc.RegisterDevice(context.Background(), h.tenantID, uuid.Nil, ""); err == nil {
		t.Fatal("empty device name must be rejected")
	}
}

// TestGetSyncStatus_DeviceScopedVsTenantAggregate (ADR-2 GetSyncStatusRequest
// device_id, empty = tenant aggregate): the device-scoped view returns the
// device row's own last_sync_version; the aggregate view returns the tenant
// log frontier (latest version) regardless of which device is asking.
func TestGetSyncStatus_DeviceScopedVsTenantAggregate(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	phone, err := h.svc.RegisterDevice(ctx, h.tenantID, uuid.New(), "phone")
	if err != nil {
		t.Fatalf("register phone: %v", err)
	}
	tablet, err := h.svc.RegisterDevice(ctx, h.tenantID, uuid.New(), "tablet")
	if err != nil {
		t.Fatalf("register tablet: %v", err)
	}

	push := func(device uuid.UUID, name string) {
		t.Helper()
		payload := accountPayload(t, h.tenantID, name, 1)
		var acc accountdomain.Account
		if err := json.Unmarshal(payload, &acc); err != nil {
			t.Fatalf("decode payload: %v", err)
		}
		if _, _, err := h.svc.PushChanges(ctx, h.tenantID, device, []SyncPayloadDTO{{
			EntityType: "account", EntityID: acc.ID,
			Operation: syncdomain.SyncOperationCreate, Payload: payload,
			Version: 1, DeviceID: device,
		}}); err != nil {
			t.Fatalf("push from %s: %v", name, err)
		}
	}

	push(phone.ID, "from phone")   // v1: phone tracked at 1
	push(tablet.ID, "from tablet") // v2: tablet tracked at 2 (frontier)

	// Device-scoped: phone's own position (1), not the frontier.
	phoneStatus, err := h.svc.GetSyncStatus(ctx, h.tenantID, phone.ID)
	if err != nil {
		t.Fatalf("device-scoped status: %v", err)
	}
	if phoneStatus.DeviceID != phone.ID || phoneStatus.LastSyncVersion != 1 {
		t.Fatalf("phone status = device %s v%d, want %s v1", phoneStatus.DeviceID, phoneStatus.LastSyncVersion, phone.ID)
	}

	// Tenant aggregate: the log frontier (3) with no device attribution.
	agg, err := h.svc.GetTenantSyncStatus(ctx, h.tenantID)
	if err != nil {
		t.Fatalf("aggregate status: %v", err)
	}
	if agg.DeviceID != uuid.Nil {
		t.Fatalf("aggregate DeviceID = %s, want Nil (no device attribution)", agg.DeviceID)
	}
	if agg.LastSyncVersion != 2 {
		t.Fatalf("aggregate LastSyncVersion = %d, want log frontier 2", agg.LastSyncVersion)
	}
	if agg.PendingConflicts != 0 {
		t.Fatalf("aggregate PendingConflicts = %d, want 0 (v1 has no detection)", agg.PendingConflicts)
	}
}

// TestGetSyncStatus_UnknownDevice_NotFound: a device-scoped query for an
// unregistered id errors (fail-closed), while the aggregate view of the same
// tenant succeeds — the empty device_id on the wire stays a valid aggregate
// request, not an error.
func TestGetSyncStatus_UnknownDevice_NotFound(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	if _, err := h.svc.GetSyncStatus(ctx, h.tenantID, uuid.New()); err == nil {
		t.Fatal("device-scoped status for an unknown device must error")
	}
	if _, err := h.svc.GetTenantSyncStatus(ctx, h.tenantID); err != nil {
		t.Fatalf("aggregate status must succeed on an empty log: %v", err)
	}
}
