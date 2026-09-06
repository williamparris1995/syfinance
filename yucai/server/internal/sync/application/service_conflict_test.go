package application

// Tier-A tests for F16 T2 S4 (conflict detection skip semantics, ADR-4):
// PushChanges checks UPDATE-type changes against the server's current row
// (writer CurrentState); a payload whose version is not strictly ahead of the
// stored row's version is SKIPPED (no business write, no sync_log append) and
// recorded as a version_conflict row with both payloads — the rest of the
// batch still lands (multi-device semantics; the single-device client is
// pinned to zero conflicts below). Reuses the F11 push harness.

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"

	accountdomain "github.com/yucai/server/internal/account/domain"
	accpred "github.com/yucai/server/internal/account/ent/account"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	"github.com/yucai/server/internal/sync/ent/syncconflict"
)

// conflictRow is the raw persisted shape the Resolve assertions read back.
type conflictRow struct {
	ID         uuid.UUID
	Resolution string
	ResolvedAt *time.Time
}

// syncConflictRows reads the tenant's sync_conflicts straight from ent (raw
// column values, including resolved_at).
func (h *pushHarness) syncConflictRows(ctx context.Context, tenantID uuid.UUID) ([]conflictRow, error) {
	rows, err := h.syncCl.SyncConflict.Query().
		Where(syncconflict.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]conflictRow, len(rows))
	for i, r := range rows {
		out[i] = conflictRow{ID: r.ID, Resolution: r.Resolution, ResolvedAt: r.ResolvedAt}
	}
	return out, nil
}

// seedConflict pushes one stale UPDATE over a seeded row and returns the
// recorded conflict's id.
func seedConflict(t *testing.T, h *pushHarness, ctx context.Context) uuid.UUID {
	t.Helper()
	id := uuid.New()
	seed := createChangeForPayload(updatedAccountPayload(t, id, "seed", 2))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{seed}); err != nil {
		t.Fatalf("seed push: %v", err)
	}
	stale := updateChange(h.tenantID, updatedAccountPayload(t, id, "stale", 1))
	_, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{stale})
	if err != nil || len(conflicts) != 1 {
		t.Fatalf("conflicting push: conflicts=%d err=%v", len(conflicts), err)
	}
	return conflicts[0].ID
}

// updatedAccountPayload decodes a fresh account fixture, overrides id/name/
// version, and re-marshals it — the "same entity, next edit" push shape.
func updatedAccountPayload(t *testing.T, id uuid.UUID, name string, version int64) []byte {
	t.Helper()
	now := time.Now()
	return mustMarshal(t, accountdomain.Account{
		ID: id, TenantID: uuid.Nil, Name: name,
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY", Ownership: accountdomain.OwnershipPersonal,
		Status: accountdomain.AccountStatusActive, Version: version, CreatedAt: now, UpdatedAt: now,
	})
}

// updateChange builds an UPDATE-typed DTO for the given account payload.
func updateChange(tenantID uuid.UUID, payload []byte) SyncPayloadDTO {
	var probe struct {
		ID      uuid.UUID
		Version int64
	}
	if err := json.Unmarshal(payload, &probe); err != nil {
		panic(err)
	}
	return SyncPayloadDTO{
		EntityType: "account", EntityID: probe.ID,
		Operation: syncdomain.SyncOperationUpdate, Payload: payload,
		Version: probe.Version, DeviceID: uuid.Nil,
	}
}

// createChangeForPayload builds a CREATE-typed DTO reusing an existing
// payload's id (the re-push / resurrection shape).
func createChangeForPayload(payload []byte) SyncPayloadDTO {
	var probe struct {
		ID      uuid.UUID
		Version int64
	}
	if err := json.Unmarshal(payload, &probe); err != nil {
		panic(err)
	}
	return SyncPayloadDTO{
		EntityType: "account", EntityID: probe.ID,
		Operation: syncdomain.SyncOperationCreate, Payload: payload,
		Version: probe.Version, DeviceID: uuid.Nil,
	}
}

// TestPushChanges_VersionConflict_SkipsStaleUpdateAndRecordsConflict (FR-4
// core): device A pushes the account to v2; device B — still holding base v1
// — pushes an UPDATE with payload version 1. The server row exists and
// 1 <= 2, so the change is skipped: a sync_conflicts row records
// conflict_type=version_conflict with the server's CURRENT entity JSON and
// B's original payload, the business row keeps A's v2 state, the sync_log
// gains no entry for the skipped change, and the response carries the
// conflict. The batch itself succeeds (multi-device: one device's conflict
// does not fail its own clean changes).
func TestPushChanges_VersionConflict_SkipsStaleUpdateAndRecordsConflict(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	deviceA, deviceB := uuid.New(), uuid.New()

	// A creates the account (v1) then edits it to v2.
	id := uuid.New()
	create := createChangeForPayload(updatedAccountPayload(t, id, "A's account", 1))
	create.DeviceID = deviceA
	if v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, deviceA, []SyncPayloadDTO{create}); err != nil || v != 1 || len(conflicts) != 0 {
		t.Fatalf("A create: v=%d conflicts=%d err=%v", v, len(conflicts), err)
	}
	aEdit := updateChange(h.tenantID, updatedAccountPayload(t, id, "A's edit v2", 2))
	aEdit.DeviceID = deviceA
	if v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, deviceA, []SyncPayloadDTO{aEdit}); err != nil || v != 2 || len(conflicts) != 0 {
		t.Fatalf("A edit: v=%d conflicts=%d err=%v", v, len(conflicts), err)
	}

	// B pushes its stale-base UPDATE (payload version 1 over server v2).
	bPayload := updatedAccountPayload(t, id, "B's stale edit", 1)
	bChange := updateChange(h.tenantID, bPayload)
	bChange.DeviceID = deviceB
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, deviceB, []SyncPayloadDTO{bChange})
	if err != nil {
		t.Fatalf("conflicting push must succeed (skip semantics), got error: %v", err)
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2 (skipped change consumes no log version)", v)
	}
	if len(conflicts) != 1 {
		t.Fatalf("response conflicts = %d, want 1", len(conflicts))
	}
	c := conflicts[0]
	if c.EntityType != "account" || c.EntityID != id {
		t.Fatalf("conflict targets = %s/%s, want account/%s", c.EntityType, c.EntityID, id)
	}
	if c.ConflictType != "version_conflict" {
		t.Fatalf("conflict_type = %q, want version_conflict", c.ConflictType)
	}
	if string(c.ClientPayload) != string(bPayload) {
		t.Fatalf("client_payload must be B's original change payload verbatim")
	}
	var serverState accountdomain.Account
	if err := json.Unmarshal(c.ServerPayload, &serverState); err != nil {
		t.Fatalf("server_payload must be the server entity JSON: %v", err)
	}
	if serverState.ID != id || serverState.Name != "A's edit v2" || serverState.Version != 2 {
		t.Fatalf("server_payload = %s v%d %q, want A's current v2 state", serverState.ID, serverState.Version, serverState.Name)
	}

	// Business row untouched: A's v2 content survives B's skipped write.
	got, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Only(ctx)
	if err != nil {
		t.Fatalf("read account: %v", err)
	}
	if got.Name != "A's edit v2" || got.Version != 2 {
		t.Fatalf("row after conflict = %q v%d, want A's edit v2 / 2 (skip, not overwrite)", got.Name, got.Version)
	}

	// Log holds exactly the two applied changes (A's create + edit) — the
	// skipped change appended nothing.
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("log entries = %d, want 2 (skipped change is not logged)", len(entries))
	}

	// The conflict row is persisted (pending) — GetTenantSyncStatus sees it.
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil {
		t.Fatalf("FindPending: %v", err)
	}
	if pending.TotalCount != 1 || len(pending.Items) != 1 {
		t.Fatalf("pending conflicts = %d (items %d), want 1/1", pending.TotalCount, len(pending.Items))
	}
	if pending.Items[0].ConflictType != "version_conflict" || !pending.Items[0].IsPending() {
		t.Fatalf("persisted conflict = type %q resolution %q, want version_conflict/pending",
			pending.Items[0].ConflictType, pending.Items[0].Resolution.String())
	}
}

// TestPushChanges_UpdateNewerVersion_NoConflict: an UPDATE whose payload
// version is STRICTLY ahead of the stored row applies normally — detection
// only fires on "server exists and payload is not ahead".
func TestPushChanges_UpdateNewerVersion_NoConflict(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	create := createChangeForPayload(updatedAccountPayload(t, id, "base", 1))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create}); err != nil {
		t.Fatalf("create: %v", err)
	}
	update := updateChange(h.tenantID, updatedAccountPayload(t, id, "next edit", 2))
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{update})
	if err != nil {
		t.Fatalf("fresh update: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts = %d, want 0 (2 > 1 is not a conflict)", len(conflicts))
	}
	got, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Only(ctx)
	if err != nil || got.Name != "next edit" || got.Version != 2 {
		t.Fatalf("row after update = %+v err %v, want next edit v2", got, err)
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2", v)
	}
}

// TestPushChanges_CreateOperationNeverChecked: CREATE-typed changes skip
// detection entirely — even an equal/older payload version over an existing
// row applies (the single-device re-push semantics F10-F13 rely on: the
// shipped client always sends CREATE, grpc_offline_sync_port.dart).
func TestPushChanges_CreateOperationNeverChecked(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	create := createChangeForPayload(updatedAccountPayload(t, id, "v2 first", 2))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create}); err != nil {
		t.Fatalf("create v2: %v", err)
	}
	// Re-push of the SAME version as CREATE: idempotent apply, no conflict.
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create})
	if err != nil {
		t.Fatalf("create re-push: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts = %d, want 0 (CREATE is never conflict-checked)", len(conflicts))
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2 (re-push appends a log version)", v)
	}
}

// TestPushChanges_SingleDeviceFlow_ZeroConflicts (F10-F13 zero-regression
// pin): the single-device flow — CREATE then strictly-newer UPDATEs from the
// same device — never trips detection. Two independent reasons: (1) the
// shipped client stamps every upsert CREATE, which is never checked; (2) even
// a real UPDATE from the owning device carries a strictly newer payload
// version (the client increments it per local edit), so
// payload.version <= server.version cannot hold.
func TestPushChanges_SingleDeviceFlow_ZeroConflicts(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	for i := 0; i < 3; i++ {
		payload := updatedAccountPayload(t, id, "local edit", int64(i+1))
		var change SyncPayloadDTO
		if i == 0 {
			change = createChangeForPayload(payload)
		} else {
			change = updateChange(h.tenantID, payload)
		}
		v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{change})
		if err != nil {
			t.Fatalf("push %d: %v", i+1, err)
		}
		if len(conflicts) != 0 {
			t.Fatalf("push %d: conflicts = %d, want 0 (single device always pushes the newest version)", i+1, len(conflicts))
		}
		if v != int64(i+1) {
			t.Fatalf("push %d: synced_version = %d", i+1, v)
		}
	}
}

// TestPushChanges_MixedBatch_OneConflictTwoApplied: a batch mixing one stale
// UPDATE with two fresh ones lands the two (business rows + log entries) and
// records the one conflict — the batch's atomicity boundary is "what is
// applied is all-or-nothing"; a conflict is an explicit skip, not a failure.
func TestPushChanges_MixedBatch_OneConflictTwoApplied(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	staleID, fresh1, fresh2 := uuid.New(), uuid.New(), uuid.New()
	// Seed: staleID at server v3, the others absent.
	seed := createChangeForPayload(updatedAccountPayload(t, staleID, "seeded", 3))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{seed}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	batch := []SyncPayloadDTO{
		updateChange(h.tenantID, updatedAccountPayload(t, fresh1, "fresh 1", 1)),
		updateChange(h.tenantID, updatedAccountPayload(t, staleID, "stale edit", 2)), // 2 <= 3 -> conflict
		updateChange(h.tenantID, updatedAccountPayload(t, fresh2, "fresh 2", 1)),
	}
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, batch)
	if err != nil {
		t.Fatalf("mixed batch: %v", err)
	}
	if len(conflicts) != 1 || conflicts[0].EntityID != staleID {
		t.Fatalf("conflicts = %+v, want exactly the stale change", conflicts)
	}
	if v != 3 { // 1 seed + 2 applied
		t.Fatalf("synced_version = %d, want 3 (only applied changes consume versions)", v)
	}

	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 1, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("log entries after batch = %d, want 2", len(entries))
	}

	// Fresh rows landed; the stale row keeps its v3 content.
	for _, id := range []uuid.UUID{fresh1, fresh2} {
		if n, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Count(ctx); err != nil || n != 1 {
			t.Fatalf("fresh row %s must land, n=%d err=%v", id, n, err)
		}
	}
	got, err := h.accountCl.Account.Query().Where(accpred.ID(staleID)).Only(ctx)
	if err != nil || got.Name != "seeded" || got.Version != 3 {
		t.Fatalf("stale row = %+v err %v, want seeded v3 (skipped)", got, err)
	}
}

// TestPushChanges_DeleteNeverChecked: DELETE changes apply regardless of the
// server row's version — a tombstone is the client's final word
// (detection/update semantics are for upserts only; spec FR-4).
func TestPushChanges_DeleteNeverChecked(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	create := createChangeForPayload(updatedAccountPayload(t, id, "doomed", 9))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	del := SyncPayloadDTO{
		EntityType: "account", EntityID: id,
		Operation: syncdomain.SyncOperationDelete, Payload: nil,
		Version: 0, DeviceID: h.deviceID, // tombstones carry no version
	}
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{del})
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts = %d, want 0 (DELETE is never conflict-checked)", len(conflicts))
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2", v)
	}
	if n, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("row must be hard-deleted, n=%d err=%v", n, err)
	}
}

// TestListConflicts_FillsConflictType: the listing path surfaces the recorded
// conflict_type and both payloads for the (future) resolution UI.
func TestListConflicts_FillsConflictType(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	seed := createChangeForPayload(updatedAccountPayload(t, id, "seed", 4))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{seed}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	stale := updateChange(h.tenantID, updatedAccountPayload(t, id, "stale", 2))
	if _, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{stale}); err != nil || len(conflicts) != 1 {
		t.Fatalf("conflicting push: conflicts=%d err=%v", len(conflicts), err)
	}

	dtos, nextToken, total, err := h.svc.ListConflicts(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil {
		t.Fatalf("ListConflicts: %v", err)
	}
	if total != 1 || len(dtos) != 1 || nextToken != "" {
		t.Fatalf("ListConflicts = (%d items %d token %q), want (1, 1, \"\")", total, len(dtos), nextToken)
	}
	if dtos[0].ConflictType != "version_conflict" || dtos[0].Resolution != "pending" {
		t.Fatalf("listed conflict = type %q resolution %q, want version_conflict/pending", dtos[0].ConflictType, dtos[0].Resolution)
	}
	if len(dtos[0].ServerPayload) == 0 || len(dtos[0].ClientPayload) == 0 {
		t.Fatal("listed conflict must carry both payloads")
	}
}

// TestResolveConflict_InvalidResolution_Rejected: the resolution value domain
// is FINALIZED as {server, client, merged} (the strings domain
// ParseConflictResolution persists; "pending" is not a resolvable state).
// Anything else fails validation without touching the row.
func TestResolveConflict_InvalidResolution_Rejected(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	conflictID := seedConflict(t, h, ctx)

	for _, bad := range []string{"", "pending", "server_wins", "SERVER", "nonsense"} {
		if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, bad); err == nil {
			t.Fatalf("resolution %q must be rejected", bad)
		}
	}

	// Row untouched: still pending.
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 1 {
		t.Fatalf("pending after rejects = %d err %v, want 1 (rejects change nothing)", pending.TotalCount, err)
	}
}

// TestResolveConflict_ValidResolvesAndStampsResolvedAt: every whitelisted
// value resolves the conflict, writes resolved_at, and drops it from the
// pending listing.
func TestResolveConflict_ValidResolvesAndStampsResolvedAt(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	for _, resolution := range []string{"server", "client", "merged"} {
		conflictID := seedConflict(t, h, ctx)
		if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, resolution); err != nil {
			t.Fatalf("ResolveConflict(%q): %v", resolution, err)
		}
		// Persisted row: resolution + resolved_at stamped, no longer pending.
		rows, err := h.syncConflictRows(ctx, h.tenantID)
		if err != nil {
			t.Fatalf("read conflicts: %v", err)
		}
		var found *conflictRow
		for i := range rows {
			if rows[i].ID == conflictID {
				found = &rows[i]
			}
		}
		if found == nil {
			t.Fatalf("conflict %s must persist", conflictID)
		}
		if found.Resolution != resolution {
			t.Fatalf("stored resolution = %q, want %q", found.Resolution, resolution)
		}
		if found.ResolvedAt == nil {
			t.Fatalf("ResolveConflict(%q) must stamp resolved_at (stored defect: never written)", resolution)
		}
	}

	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 0 {
		t.Fatalf("pending after resolutions = %d err %v, want 0", pending.TotalCount, err)
	}
}

// TestResolveConflict_UnknownOrCrossTenantID_NotFound: resolving a conflict
// id the tenant does not own errors (tenant predicate — the old repo updated
// by bare id, letting one tenant resolve another's conflict).
func TestResolveConflict_UnknownOrCrossTenantID_NotFound(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	otherTenant := uuid.New()

	// Seed one real conflict under h.tenantID.
	id := uuid.New()
	seed := createChangeForPayload(updatedAccountPayload(t, id, "seed", 2))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{seed}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	stale := updateChange(h.tenantID, updatedAccountPayload(t, id, "stale", 1))
	_, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{stale})
	if err != nil || len(conflicts) != 1 {
		t.Fatalf("conflicting push: conflicts=%d err=%v", len(conflicts), err)
	}

	// The SAME id under another tenant must not resolve it (tenant predicate).
	if err := h.svc.ResolveConflict(ctx, otherTenant, conflicts[0].ID, "server"); err == nil {
		t.Fatal("cross-tenant resolve must fail (tenant predicate)")
	}
	// And the real tenant's row is still pending.
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 1 {
		t.Fatalf("pending after cross-tenant attempt = %d err %v, want 1 (untouched)", pending.TotalCount, err)
	}

	// An entirely unknown id errors too.
	if err := h.svc.ResolveConflict(ctx, h.tenantID, uuid.New(), "server"); err == nil {
		t.Fatal("unknown conflict id must error")
	}
}
