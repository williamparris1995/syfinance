package application

// Tier-A tests for the conflict surface: F16 T2 S4 (conflict skip semantics)
// updated to the F18 T1 unified detection matrix (spec FR-1 / ADR-1):
// PushChanges checks EVERY upsert (CREATE and UPDATE alike) against the
// server's current row via the writer CurrentState — the F16 UPDATE-only
// check never fired because the shipped client stamps every upsert CREATE
// (the blocking finding). The unified rules for an entity the server holds:
//   - payload canonically-equal to the server's state (Canonicalize form —
//     same data in any wire encoding) -> SILENT skip (no conflict row, no
//     sync_log append, no log version consumed — the F18 idempotent re-push
//     short-circuit, which also lands the F16 same-payload backlog);
//   - different payload, probe.Version <= server version -> conflict (skip +
//     sync_conflicts row with both payloads + response carries it);
//   - different payload, probe.Version > server version -> normal apply.
// An entity absent server-side always applies; DELETE is never checked. The
// rest of the batch always lands (multi-device: one device's conflict must
// not fail its own clean changes). Reuses the F11 push harness.

import (
	"bytes"
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
// recorded conflict's id plus the conflicting entity's id (the resolution
// tests build merged payloads against that entity).
func seedConflict(t *testing.T, h *pushHarness, ctx context.Context) (uuid.UUID, uuid.UUID) {
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
	return conflicts[0].ID, id
}

// updatedAccountPayload decodes a fresh account fixture, overrides id/name/
// version, and re-marshals it — the "same entity, next edit" push shape.
// TenantID stays uuid.Nil: the writer stamps the real tenant, so a payload
// built here never canonicalizes equal to the stored state (its zero TenantID
// becomes the real tenant on the server side) — exactly what the
// divergent/conflicting scenarios below want.
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

// tenantStampedAccountPayload is updatedAccountPayload with the REAL tenant
// baked into the bytes: push -> store -> CurrentState re-marshal then
// round-trips byte-identically (the writer stamps the same tenant), which is
// what the F18 same-payload short-circuit compares against.
func tenantStampedAccountPayload(t *testing.T, tenantID, id uuid.UUID, name string, version int64) []byte {
	t.Helper()
	now := time.Now()
	return mustMarshal(t, accountdomain.Account{
		ID: id, TenantID: tenantID, Name: name,
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

// TestPushChanges_CreateOverExisting_DifferentPayload_RecordsConflict (FR-1
// core, the blocking-fix pin): a CREATE-typed change whose entity id already
// exists server-side with a DIFFERENT payload and a version that is not ahead
// is a conflict — the F16 UPDATE-only check never fired because the shipped
// client stamps every upsert CREATE, silently LWW-overwriting the server row
// (multi-device: device B re-creating an id it does not know was updated).
func TestPushChanges_CreateOverExisting_DifferentPayload_RecordsConflict(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	deviceA, deviceB := uuid.New(), uuid.New()

	// A creates the account and edits it to v2.
	id := uuid.New()
	aCreate := createChangeForPayload(updatedAccountPayload(t, id, "A's account", 1))
	aCreate.DeviceID = deviceA
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, deviceA, []SyncPayloadDTO{aCreate}); err != nil {
		t.Fatalf("A create: %v", err)
	}
	aEdit := updateChange(h.tenantID, updatedAccountPayload(t, id, "A's edit v2", 2))
	aEdit.DeviceID = deviceA
	if v, _, err := h.svc.PushChanges(ctx, h.tenantID, deviceA, []SyncPayloadDTO{aEdit}); err != nil || v != 2 {
		t.Fatalf("A edit: v=%d err=%v", v, err)
	}

	// B pushes a CREATE for the same id from its stale base (payload v1 over
	// server v2): different payload, 1 <= 2 -> conflict, not a silent overwrite.
	bPayload := updatedAccountPayload(t, id, "B's divergent create", 1)
	bCreate := createChangeForPayload(bPayload)
	bCreate.DeviceID = deviceB
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, deviceB, []SyncPayloadDTO{bCreate})
	if err != nil {
		t.Fatalf("conflicting CREATE push must succeed (skip semantics), got error: %v", err)
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2 (conflicting change consumes no log version)", v)
	}
	if len(conflicts) != 1 {
		t.Fatalf("response conflicts = %d, want 1 (CREATE over existing IS checked)", len(conflicts))
	}
	if conflicts[0].ConflictType != "version_conflict" || conflicts[0].EntityID != id {
		t.Fatalf("conflict = %s/%s, want version_conflict/%s", conflicts[0].ConflictType, conflicts[0].EntityID, id)
	}

	// Business row untouched: A's v2 content survives B's skipped CREATE.
	got, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Only(ctx)
	if err != nil || got.Name != "A's edit v2" || got.Version != 2 {
		t.Fatalf("row after conflicting create = %q v%d err %v, want A's edit v2 / 2", got.Name, got.Version, err)
	}

	// The log holds exactly the two applied changes.
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("log entries = %d, want 2 (conflicting change is not logged)", len(entries))
	}
}

// TestPushChanges_CreateAheadVersion_Applies: a CREATE-typed change over an
// existing row whose payload version is STRICTLY ahead applies normally —
// detection unification must not turn a legitimate ahead push (any op) into a
// conflict.
func TestPushChanges_CreateAheadVersion_Applies(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	create := createChangeForPayload(updatedAccountPayload(t, id, "base", 1))
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create}); err != nil {
		t.Fatalf("seed create: %v", err)
	}
	// CREATE (not UPDATE) carrying v2 over the v1 row: applies.
	ahead := createChangeForPayload(updatedAccountPayload(t, id, "ahead edit", 2))
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{ahead})
	if err != nil {
		t.Fatalf("ahead create: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts = %d, want 0 (2 > 1 is not a conflict)", len(conflicts))
	}
	got, err := h.accountCl.Account.Query().Where(accpred.ID(id)).Only(ctx)
	if err != nil || got.Name != "ahead edit" || got.Version != 2 {
		t.Fatalf("row after ahead create = %+v err %v, want ahead edit v2", got, err)
	}
	if v != 2 {
		t.Fatalf("synced_version = %d, want 2", v)
	}
}

// TestPushChanges_IdenticalPayload_ShortCircuits (FR-1 idempotent re-push
// tightening): re-pushing a payload equal to the server's current state — the
// lost-response retry, for either op — is a SILENT skip: no conflict row, no
// sync_log append, no log version consumed, response carries zero conflicts.
// This is the Go-form twin of TestPushChanges_ClientWireFormPayload below;
// tenantStampedAccountPayload bakes the real tenant into the bytes so the
// push -> store -> CurrentState re-marshal round-trips byte-identically (the
// writer stamps the same tenant).
func TestPushChanges_IdenticalPayload_ShortCircuits(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	for _, op := range []struct {
		name string
		mk   func(payload []byte) SyncPayloadDTO
	}{
		{"create", createChangeForPayload},
		{"update", func(p []byte) SyncPayloadDTO { return updateChange(h.tenantID, p) }},
	} {
		t.Run(op.name, func(t *testing.T) {
			id := uuid.New()
			payload := tenantStampedAccountPayload(t, h.tenantID, id, "settled", 4)
			// The subtests share the harness (same tenant + log), so the
			// frontier is read, not assumed: first push advances it by exactly
			// one, the identical re-push leaves it untouched.
			base, err := h.logRepo.LatestVersion(ctx, h.tenantID)
			if err != nil {
				t.Fatalf("read frontier: %v", err)
			}
			first := op.mk(payload)
			if v, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{first}); err != nil || v != base+1 {
				t.Fatalf("first push: v=%d err=%v", v, err)
			}

			repush := op.mk(payload)
			v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{repush})
			if err != nil {
				t.Fatalf("identical re-push: %v", err)
			}
			if len(conflicts) != 0 {
				t.Fatalf("conflicts = %d, want 0 (equal re-push is not a conflict)", len(conflicts))
			}
			if v != base+1 {
				t.Fatalf("synced_version = %d, want %d (identical re-push consumes no log version)", v, base+1)
			}
			entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500)
			if err != nil {
				t.Fatalf("FindSince: %v", err)
			}
			if int64(len(entries)) != base+1 {
				t.Fatalf("log entries = %d, want %d (identical re-push appends nothing)", len(entries), base+1)
			}
			pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
			if err != nil || pending.TotalCount != 0 {
				t.Fatalf("pending conflicts = %d err %v, want 0 (no conflict row recorded)", pending.TotalCount, err)
			}
		})
	}
}

// TestPushChanges_SingleDeviceFlow_ZeroConflicts (F10-F13 zero-regression
// pin): the single-device flow — CREATE then strictly-newer updates from the
// same device — never trips detection: every push carries a strictly newer
// payload version than the server row (the client increments it per local
// edit), which the unified existence check waves through (F18 ADR-1).
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
	conflictID, _ := seedConflict(t, h, ctx)

	for _, bad := range []string{"", "pending", "server_wins", "SERVER", "nonsense"} {
		if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, bad, nil); err == nil {
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
// pending listing. F18 ADR-3 semantics: "server" only marks; "client" persists
// the conflict row's client_payload; "merged" persists the caller-supplied
// payload (both + log, asserted in detail below).
func TestResolveConflict_ValidResolvesAndStampsResolvedAt(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	for _, resolution := range []string{"server", "client", "merged"} {
		conflictID, entityID := seedConflict(t, h, ctx)
		var payload []byte
		if resolution == "merged" {
			payload = updatedAccountPayload(t, entityID, "merged outcome", 3)
		}
		if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, resolution, payload); err != nil {
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
		t.Fatalf("seed push: %v", err)
	}
	stale := updateChange(h.tenantID, updatedAccountPayload(t, id, "stale", 1))
	_, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{stale})
	if err != nil || len(conflicts) != 1 {
		t.Fatalf("conflicting push: conflicts=%d err=%v", len(conflicts), err)
	}

	// The SAME id under another tenant must not resolve it (tenant predicate).
	if err := h.svc.ResolveConflict(ctx, otherTenant, conflicts[0].ID, "server", nil); err == nil {
		t.Fatal("cross-tenant resolve must fail (tenant predicate)")
	}
	// And the real tenant's row is still pending.
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 1 {
		t.Fatalf("pending after cross-tenant attempt = %d err %v, want 1 (untouched)", pending.TotalCount, err)
	}

	// An entirely unknown id errors too.
	if err := h.svc.ResolveConflict(ctx, h.tenantID, uuid.New(), "server", nil); err == nil {
		t.Fatal("unknown conflict id must error")
	}
}

// TestPushChanges_ClientWireFormPayload_ShortCircuits (review fix round 1,
// FAIL-1): the REAL client wire form — a JSON object built from a Dart map
// (key order differs from the Go struct order, no TenantID key, int enums,
// RFC3339 timestamps) — carrying the SAME data as the stored row must
// short-circuit the detection. Raw byte comparison never matches this shape
// (map marshal vs Go re-marshal), which made the idempotent re-push branch
// dead and recorded one conflict per re-pushed entity; the comparison now
// runs on the writer's Canonicalize form. The negative control (a Dart-form
// payload with DIFFERENT data still conflicts) is
// TestPushChanges_CreateOverExisting_DifferentPayload_RecordsConflict above.
func TestPushChanges_ClientWireFormPayload_ShortCircuits(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	id := uuid.New()
	ts := time.Date(2026, 9, 8, 8, 0, 0, 123456789, time.UTC)
	// Server-form seed: the Go struct marshal with the real tenant baked in.
	seed := mustMarshal(t, accountdomain.Account{
		ID: id, TenantID: h.tenantID, Name: "Dart-shaped",
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY", Ownership: accountdomain.OwnershipPersonal,
		Status: accountdomain.AccountStatusActive, Version: 2, CreatedAt: ts, UpdatedAt: ts,
	})
	first := createChangeForPayload(seed)
	if v, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{first}); err != nil || v != 1 {
		t.Fatalf("seed push: v=%d err=%v", v, err)
	}

	// The Dart envelope re-push: same data, different encoding — keys in map
	// (not struct) order, no TenantID key, timestamps re-encoded RFC3339,
	// absent keys standing in for the seed's zero values.
	row := map[string]any{
		"Name":         "Dart-shaped",
		"Version":      2,
		"ID":           id.String(),
		"AccountType":  1, // asset
		"Category":     1, // savings
		"Ownership":    1, // personal
		"Status":       1, // active
		"CurrencyCode": "CNY",
		"CreatedAt":    "2026-09-08T08:00:00.123456789Z",
		"UpdatedAt":    "2026-09-08T08:00:00.123456789Z",
	}
	repush := createChangeForPayload(mustMarshal(t, row))
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{repush})
	if err != nil {
		t.Fatalf("Dart-form re-push: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts = %d, want 0 (same data in client wire form must short-circuit, not conflict)", len(conflicts))
	}
	if v != 1 {
		t.Fatalf("synced_version = %d, want 1 (short-circuit consumes no log version)", v)
	}
	if entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500); err != nil || len(entries) != 1 {
		t.Fatalf("log entries = %d err=%v, want 1 (short-circuit appends nothing)", len(entries), err)
	}
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 0 {
		t.Fatalf("pending conflicts = %d err %v, want 0 (no conflict row recorded)", pending.TotalCount, err)
	}
}

// --- F18 T1: ResolveConflict persistence semantics (spec FR-3 / ADR-3) ---

// TestResolveConflict_ClientWins_UpsertsAndLogsPullably: resolving "client"
// persists the conflict row's client_payload into the business table (inside
// one transaction) and appends a sync_log entry at the NEXT log version, so
// device B converges by pulling: PullChanges(since = pre-resolution frontier)
// returns exactly that entry (entity/version/payload/operation=update). The
// merged_payload argument is IGNORED on this branch — the conflict row's
// client_payload is the client's own state by definition.
func TestResolveConflict_ClientWins_UpsertsAndLogsPullably(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	conflictID, entityID := seedConflict(t, h, ctx)
	// seedConflict leaves: server row "seed" v2 (log v1), conflict holding
	// client_payload "stale" v1.
	frontier, err := h.logRepo.LatestVersion(ctx, h.tenantID)
	if err != nil {
		t.Fatalf("read frontier: %v", err)
	}

	// A junk merged_payload must not influence the client branch.
	if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, "client", []byte(`{"junk":true}`)); err != nil {
		t.Fatalf("ResolveConflict(client): %v", err)
	}

	// Business row now holds the client's payload content.
	got, err := h.accountCl.Account.Query().Where(accpred.ID(entityID)).Only(ctx)
	if err != nil || got.Name != "stale" || got.Version != 1 {
		t.Fatalf("row after client-wins = %q v%d err %v, want stale / 1", got.Name, got.Version, err)
	}

	// The log entry is pullable past the pre-resolution frontier.
	changes, _, _, err := h.svc.PullChanges(ctx, h.tenantID, frontier, nil, 10)
	if err != nil {
		t.Fatalf("PullChanges after resolve: %v", err)
	}
	if len(changes) != 1 {
		t.Fatalf("pullable changes = %d, want exactly the resolution entry", len(changes))
	}
	resolved := changes[0]
	if resolved.EntityType != "account" || resolved.EntityID != entityID || resolved.Operation != syncdomain.SyncOperationUpdate {
		t.Fatalf("resolution change = %s/%s/%s, want account/%s/update", resolved.EntityType, resolved.EntityID, resolved.Operation, entityID)
	}
	if resolved.Version != frontier+1 {
		t.Fatalf("resolution log version = %d, want %d (next sequence — probe.Version would collide with existing rows and strand the entry behind the cursor)", resolved.Version, frontier+1)
	}
	var probe struct {
		ID      uuid.UUID
		Version int64
		Name    string
	}
	if err := json.Unmarshal(resolved.Payload, &probe); err != nil {
		t.Fatalf("resolution payload must be JSON: %v", err)
	}
	if probe.ID != entityID || probe.Version != 1 || probe.Name != "stale" {
		t.Fatalf("resolution payload probe = %s v%d %q, want %s v1 %q (the client's own bytes)", probe.ID, probe.Version, probe.Name, entityID, "stale")
	}

	// Conflict row resolved.
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 0 {
		t.Fatalf("pending after client-wins = %d err %v, want 0", pending.TotalCount, err)
	}
}

// TestResolveConflict_MergedPayload_UpsertsAndLogs: resolving "merged"
// persists the caller-supplied merged_payload (the field-level merge result
// the v2 editor will send) the same way — upsert + one pullable log entry at
// the next sequence version, operation=update.
func TestResolveConflict_MergedPayload_UpsertsAndLogs(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	conflictID, entityID := seedConflict(t, h, ctx)
	frontier, err := h.logRepo.LatestVersion(ctx, h.tenantID)
	if err != nil {
		t.Fatalf("read frontier: %v", err)
	}

	merged := updatedAccountPayload(t, entityID, "merged outcome", 7)
	if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, "merged", merged); err != nil {
		t.Fatalf("ResolveConflict(merged): %v", err)
	}

	got, err := h.accountCl.Account.Query().Where(accpred.ID(entityID)).Only(ctx)
	if err != nil || got.Name != "merged outcome" || got.Version != 7 {
		t.Fatalf("row after merged = %q v%d err %v, want merged outcome / 7", got.Name, got.Version, err)
	}

	changes, _, _, err := h.svc.PullChanges(ctx, h.tenantID, frontier, nil, 10)
	if err != nil {
		t.Fatalf("PullChanges after merged resolve: %v", err)
	}
	if len(changes) != 1 || changes[0].EntityID != entityID || changes[0].Operation != syncdomain.SyncOperationUpdate {
		t.Fatalf("merged resolution change = %+v, want one update for the entity", changes)
	}
	if !bytes.Equal(changes[0].Payload, merged) {
		t.Fatalf("merged resolution payload must be the merged bytes verbatim")
	}
	if changes[0].Version != frontier+1 {
		t.Fatalf("merged resolution log version = %d, want %d", changes[0].Version, frontier+1)
	}

	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 0 {
		t.Fatalf("pending after merged = %d err %v, want 0", pending.TotalCount, err)
	}
}

// TestResolveConflict_ServerWins_ZeroAction: resolving "server" only marks
// the conflict row — the server row is already authoritative, so there is no
// business write and no sync_log append (devices that already pulled the
// server state need no new entry; the losing device converges on its next
// pull of the EXISTING entries or via the F18-T2 client confirmation mark).
func TestResolveConflict_ServerWins_ZeroAction(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	conflictID, entityID := seedConflict(t, h, ctx)
	frontier, err := h.logRepo.LatestVersion(ctx, h.tenantID)
	if err != nil {
		t.Fatalf("read frontier: %v", err)
	}

	if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, "server", nil); err != nil {
		t.Fatalf("ResolveConflict(server): %v", err)
	}

	got, err := h.accountCl.Account.Query().Where(accpred.ID(entityID)).Only(ctx)
	if err != nil || got.Name != "seed" || got.Version != 2 {
		t.Fatalf("row after server-wins = %q v%d err %v, want seed / 2 (untouched)", got.Name, got.Version, err)
	}
	if v, err := h.logRepo.LatestVersion(ctx, h.tenantID); err != nil || v != frontier {
		t.Fatalf("frontier after server-wins = %d err %v, want %d (no log append)", v, err, frontier)
	}
	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 0 {
		t.Fatalf("pending after server-wins = %d err %v, want 0 (marked resolved)", pending.TotalCount, err)
	}
}

// TestResolveConflict_MergedEmptyPayload_Rejected: "merged" without payload
// bytes is a client error (InvalidArgument on the wire) — there is nothing to
// persist. Nothing changes: the row stays pending, the log is untouched.
func TestResolveConflict_MergedEmptyPayload_Rejected(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	conflictID, _ := seedConflict(t, h, ctx)
	frontier, err := h.logRepo.LatestVersion(ctx, h.tenantID)
	if err != nil {
		t.Fatalf("read frontier: %v", err)
	}

	for _, empty := range [][]byte{nil, {}} {
		if err := h.svc.ResolveConflict(ctx, h.tenantID, conflictID, "merged", empty); err == nil {
			t.Fatal("merged with empty payload must be rejected")
		}
	}

	pending, err := h.conflictRepo.FindPending(ctx, h.tenantID, syncdomain.PageRequest{PageSize: 10})
	if err != nil || pending.TotalCount != 1 {
		t.Fatalf("pending after empty-merged rejects = %d err %v, want 1 (untouched)", pending.TotalCount, err)
	}
	if v, err := h.logRepo.LatestVersion(ctx, h.tenantID); err != nil || v != frontier {
		t.Fatalf("frontier after empty-merged rejects = %d err %v, want %d", v, err, frontier)
	}
}
