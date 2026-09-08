package tests

// F16 T2 — handler-level integration tests for the pull pagination + conflict
// detection surface (spec FR-3/4/6, design ADR-3/4/6), riding the same
// newSyncPushIT harness as the F11/T1 sync suites: the REAL SyncHandler over
// real repos/writers/service on the shared in-memory SQLite database.
//
//   - PullChanges: ordered pages (version ASC), has_more via the n+1 sentinel,
//     page_size clamping (0 -> default 500), entity_types filter composition.
//   - PushChanges conflict detection end to end (dual device over the wire):
//     stale-base UPDATE skipped + recorded with conflict_type=version_conflict
//     and both payloads; GetSyncStatus aggregate and ListConflicts surface it.
//   - ResolveConflict: whitelist (InvalidArgument on bad values), NotFound on
//     unknown ids, resolved_at stamped on success.
//   - Malformed entity_id: InvalidArgument before any write runs.

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"

	syncpb "github.com/yucai/server/internal/proto/sync/v1"
)

// --- PullChanges pagination ---

// TestSyncPull_PaginationOrderedPagesHasMore: five pushed changes paged at
// two come back [v1,v2] has_more, [v3,v4] has_more, [v5] done — strictly in
// version order (the client replay contract), with latest_version = frontier
// on every page.
func TestSyncPull_PaginationOrderedPagesHasMore(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	for i := 0; i < 5; i++ {
		accID := uuid.New()
		if _, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
			syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
				marshalSyncRow(t, syncAccountRow(accID.String(), "row", 1))),
		}}); err != nil {
			t.Fatalf("seed push %d: %v", i+1, err)
		}
	}

	pages := []struct {
		since   int64
		size    int32
		versions []int64
		hasMore bool
	}{
		{0, 2, []int64{1, 2}, true},
		{2, 2, []int64{3, 4}, true},
		{4, 2, []int64{5}, false},
	}
	for i, want := range pages {
		resp, err := it.handler.PullChanges(pushCtx, &syncpb.PullChangesRequest{
			SinceVersion: want.since, PageSize: want.size,
		})
		if err != nil {
			t.Fatalf("page %d: %v", i+1, err)
		}
		if len(resp.Changes) != len(want.versions) {
			t.Fatalf("page %d: %d changes, want %d", i+1, len(resp.Changes), len(want.versions))
		}
		for j, v := range want.versions {
			if resp.Changes[j].Version != v {
				t.Fatalf("page %d change %d: version %d, want %d (ascending replay order)", i+1, j, resp.Changes[j].Version, v)
			}
		}
		if resp.HasMore != want.hasMore {
			t.Fatalf("page %d: has_more = %v, want %v", i+1, resp.HasMore, want.hasMore)
		}
		if resp.LatestVersion != 5 {
			t.Fatalf("page %d: latest_version = %d, want frontier 5", i+1, resp.LatestVersion)
		}
	}
}

// TestSyncPull_DefaultPageSizeWhenAbsent: page_size 0 (field absent on the
// wire, the F13 client sends none) applies the default 500 — everything comes
// back in one page with has_more=false. Single-device zero-regression shape.
func TestSyncPull_DefaultPageSizeWhenAbsent(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	for i := 0; i < 3; i++ {
		accID := uuid.New()
		if _, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
			syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
				marshalSyncRow(t, syncAccountRow(accID.String(), "row", 1))),
		}}); err != nil {
			t.Fatalf("seed push %d: %v", i+1, err)
		}
	}

	resp, err := it.handler.PullChanges(pushCtx, &syncpb.PullChangesRequest{})
	if err != nil {
		t.Fatalf("PullChanges (no page_size): %v", err)
	}
	if len(resp.Changes) != 3 || resp.HasMore {
		t.Fatalf("default page = %d changes has_more=%v, want 3 false (default 500)", len(resp.Changes), resp.HasMore)
	}
}

// TestSyncPull_EntityTypesFilterComposesWithPaging: an interleaved log paged
// through a one-type filter returns only that type, ascending, with has_more.
func TestSyncPull_EntityTypesFilterComposesWithPaging(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	// account v1, tag v2, account v3 — three SEPARATE pushes so the log keeps
	// the interleaved order (one batch would be reordered account-first).
	acc1, tagID, acc2 := uuid.New(), uuid.New(), uuid.New()
	for _, seed := range []*syncpb.SyncPayload{
		syncChange(tenantID, "account", acc1.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(acc1.String(), "a1", 1))),
		syncChange(tenantID, "tag", tagID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncTagRow(tagID.String(), "t", 1))),
		syncChange(tenantID, "account", acc2.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(acc2.String(), "a2", 1))),
	} {
		if _, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{seed}}); err != nil {
			t.Fatalf("seed push: %v", err)
		}
	}

	resp, err := it.handler.PullChanges(pushCtx, &syncpb.PullChangesRequest{
		EntityTypes: []string{"account"}, PageSize: 1,
	})
	if err != nil {
		t.Fatalf("filtered pull: %v", err)
	}
	if len(resp.Changes) != 1 || !resp.HasMore {
		t.Fatalf("filtered page = %d changes has_more=%v, want 1 true", len(resp.Changes), resp.HasMore)
	}
	if resp.Changes[0].EntityType != "account" || resp.Changes[0].Version != 1 {
		t.Fatalf("filtered change = %s v%d, want account v1", resp.Changes[0].EntityType, resp.Changes[0].Version)
	}

	resp, err = it.handler.PullChanges(pushCtx, &syncpb.PullChangesRequest{
		SinceVersion: 1, EntityTypes: []string{"account"}, PageSize: 1,
	})
	if err != nil {
		t.Fatalf("filtered pull page 2: %v", err)
	}
	if len(resp.Changes) != 1 || resp.Changes[0].Version != 3 || resp.HasMore {
		t.Fatalf("filtered page 2 = v%d has_more=%v, want v3 false", resp.Changes[0].Version, resp.HasMore)
	}
}

// --- PushChanges conflict detection (dual device over the wire) ---

// seedConflictOverWire drives the A/B device sequence through the handler and
// returns B's conflicting response.
func seedConflictOverWire(t *testing.T, it *syncPushIT, ctx context.Context, tenantID uuid.UUID) *syncpb.PushResponse {
	t.Helper()
	pushCtx := syncPushCtx(ctx, tenantID)
	accID := uuid.New()
	deviceA, deviceB := uuid.New(), uuid.New()

	push := func(device uuid.UUID, op syncpb.SyncOperation, name string, version int64) *syncpb.PushResponse {
		change := syncChange(tenantID, "account", accID.String(), op,
			marshalSyncRow(t, syncAccountRow(accID.String(), name, version)))
		change.DeviceId = device.String()
		resp, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{change}})
		if err != nil {
			t.Fatalf("push (%s v%d): %v", name, version, err)
		}
		return resp
	}

	push(deviceA, syncpb.SyncOperation_SYNC_OPERATION_CREATE, "A's account", 1)
	push(deviceA, syncpb.SyncOperation_SYNC_OPERATION_UPDATE, "A's edit v2", 2)
	return push(deviceB, syncpb.SyncOperation_SYNC_OPERATION_UPDATE, "B's stale edit", 1)
}

// TestSyncPush_ConflictDetection_SkipsAndSurfaces: device B's stale-base
// UPDATE is skipped and reported — the response carries a ConflictDTO with
// conflict_type=version_conflict, the server payload is A's current v2 state
// (parseable JSON with the right row version), the client payload is B's
// bytes verbatim, the row keeps A's content, the log gains no entry, and the
// batch response is still OK. GetSyncStatus (tenant aggregate) counts the
// pending conflict and ListConflicts surfaces it.
func TestSyncPush_ConflictDetection_SkipsAndSurfaces(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	resp := seedConflictOverWire(t, it, ctx, tenantID)
	if len(resp.Conflicts) != 1 {
		t.Fatalf("PushResponse.conflicts = %d, want 1", len(resp.Conflicts))
	}
	c := resp.Conflicts[0]
	if c.ConflictType != "version_conflict" {
		t.Fatalf("conflict_type = %q, want version_conflict (proto field 7)", c.ConflictType)
	}
	if c.EntityType != "account" || c.Resolution != "pending" {
		t.Fatalf("conflict DTO = %s/%s, want account/pending", c.EntityType, c.Resolution)
	}

	// Server payload: A's current row state (name + row version 5? no — row
	// version comes from the account row: A's edit set Version 2).
	var serverRow map[string]any
	if err := json.Unmarshal(c.ServerPayload, &serverRow); err != nil {
		t.Fatalf("server_payload must be JSON: %v", err)
	}
	if serverRow["Name"] != "A's edit v2" || serverRow["Version"] != float64(2) {
		t.Fatalf("server_payload = %v/%v, want A's edit v2 / 2", serverRow["Name"], serverRow["Version"])
	}
	var clientRow map[string]any
	if err := json.Unmarshal(c.ClientPayload, &clientRow); err != nil {
		t.Fatalf("client_payload must be JSON: %v", err)
	}
	if clientRow["Name"] != "B's stale edit" {
		t.Fatalf("client_payload = %v, want B's stale edit verbatim", clientRow["Name"])
	}

	// Business row untouched by the skipped change; log holds only the two
	// applied changes.
	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 2 {
		t.Fatalf("sync_log rows = %d, want 2 (skipped change appends nothing)", len(rows))
	}

	// Aggregate status sees the pending conflict.
	status, err := it.handler.GetSyncStatus(syncPushCtx(ctx, tenantID), &syncpb.GetSyncStatusRequest{})
	if err != nil {
		t.Fatalf("aggregate GetSyncStatus: %v", err)
	}
	if status.PendingConflicts != 1 {
		t.Fatalf("pending_conflicts = %d, want 1", status.PendingConflicts)
	}

	// ListConflicts surfaces it with the type.
	list, err := it.handler.ListConflicts(syncPushCtx(ctx, tenantID), &syncpb.ListConflictsRequest{})
	if err != nil {
		t.Fatalf("ListConflicts: %v", err)
	}
	if len(list.Conflicts) != 1 || list.Conflicts[0].ConflictType != "version_conflict" {
		t.Fatalf("ListConflicts = %+v, want one version_conflict", list.Conflicts)
	}
	// F18 FR-6: the recorded-at timestamp rides the DTO (non-breaking field
	// 8; the panel sorts newest-first on it).
	if list.Conflicts[0].CreatedAt == nil || list.Conflicts[0].CreatedAt.AsTime().IsZero() {
		t.Fatalf("ListConflicts created_at = %v, want a stamped timestamp", list.Conflicts[0].CreatedAt)
	}
}

// TestSyncPush_ConflictDetection_SingleDeviceWireShape_EditsApply_RepushShortCircuits
// (F13 zero-regression pin; review fix round 1 FAIL-1 restored the
// short-circuit for the real wire form): the production client wire shape
// (CREATE op, deviceId 'bound', envelope map row) applies cleanly while each
// push carries a strictly-ahead version, and re-delivering the SAME row
// content — the lost-response retry — is silently short-circuited: zero
// conflicts, zero new log entries, no log version consumed. Detection
// compares the writer's Canonicalize form (decode -> tenant stamp ->
// re-marshal) against the server's current state, so the map-versus-struct
// encoding difference of equal data no longer fabricates a conflict.
func TestSyncPush_ConflictDetection_SingleDeviceWireShape_EditsApply_RepushShortCircuits(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)
	accID := uuid.New()

	// The exact F13 wire shape: CREATE op, deviceId 'bound', envelope row.
	mk := func(name string, version int64) *syncpb.SyncPayload {
		change := syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accID.String(), name, version)))
		change.DeviceId = "bound"
		return change
	}

	// Strictly-ahead pushes (fresh ids / bumped versions) apply without
	// conflicts — the single-device steady state.
	for i, tc := range []struct {
		name    string
		version int64
	}{{"first", 1}, {"second", 2}} {
		resp, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{mk(tc.name, tc.version)}})
		if err != nil {
			t.Fatalf("push %d (%s): %v", i+1, tc.name, err)
		}
		if len(resp.Conflicts) != 0 {
			t.Fatalf("push %d (%s): conflicts = %d, want 0 (ahead push applies)", i+1, tc.name, len(resp.Conflicts))
		}
	}

	// Lost-response retry: the SAME envelope row re-delivered at the SAME
	// version short-circuits — no conflict, no log append, version unchanged.
	resp, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{mk("second", 2)}})
	if err != nil {
		t.Fatalf("re-push: %v", err)
	}
	if len(resp.Conflicts) != 0 {
		t.Fatalf("re-push conflicts = %d, want 0 (same data in client wire form short-circuits)", len(resp.Conflicts))
	}
	if resp.SyncedVersion != 2 {
		t.Fatalf("re-push synced_version = %d, want 2 (short-circuit consumes no log version)", resp.SyncedVersion)
	}
	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 2 {
		t.Fatalf("sync_log rows = %d, want 2 (short-circuit appends nothing)", len(rows))
	}
	// And nothing pending for the resolution UI.
	list, err := it.handler.ListConflicts(pushCtx, &syncpb.ListConflictsRequest{})
	if err != nil {
		t.Fatalf("ListConflicts: %v", err)
	}
	if len(list.Conflicts) != 0 {
		t.Fatalf("listed conflicts = %d, want 0", len(list.Conflicts))
	}
}

// --- ResolveConflict over the wire ---

// TestSyncResolveConflict_HandlerCodes: whitelist rejects map to
// InvalidArgument; an unknown conflict id maps NotFound; a malformed
// conflict_id is InvalidArgument from the parse; a valid resolution succeeds
// and clears the pending count.
func TestSyncResolveConflict_HandlerCodes(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	// Seed one conflict.
	resp := seedConflictOverWire(t, it, ctx, tenantID)
	conflictID := resp.Conflicts[0].Id

	// Malformed id: InvalidArgument (parseUUID no longer swallows).
	_, err := it.handler.ResolveConflict(pushCtx, &syncpb.ResolveConflictRequest{ConflictId: "not-a-uuid", Resolution: "server"})
	if err == nil {
		t.Fatal("malformed conflict_id must be rejected")
	}
	assertCode(t, err, codes.InvalidArgument)

	// Whitelist violations: InvalidArgument with the finalized value domain.
	for _, bad := range []string{"", "server_wins", "pending"} {
		_, err = it.handler.ResolveConflict(pushCtx, &syncpb.ResolveConflictRequest{ConflictId: conflictID, Resolution: bad})
		if err == nil {
			t.Fatalf("resolution %q must be rejected", bad)
		}
		assertCode(t, err, codes.InvalidArgument)
	}

	// Unknown id: NotFound (not Internal — FR-6 fidelity).
	_, err = it.handler.ResolveConflict(pushCtx, &syncpb.ResolveConflictRequest{ConflictId: uuid.New().String(), Resolution: "server"})
	if err == nil {
		t.Fatal("unknown conflict id must error")
	}
	assertCode(t, err, codes.NotFound)

	// F18 ADR-3: "merged" without merged_payload is InvalidArgument before
	// any DB round-trip (nothing persisted, conflict stays pending).
	_, err = it.handler.ResolveConflict(pushCtx, &syncpb.ResolveConflictRequest{ConflictId: conflictID, Resolution: "merged"})
	if err == nil {
		t.Fatal("merged without merged_payload must be rejected")
	}
	assertCode(t, err, codes.InvalidArgument)
	preReject, err := it.handler.ListConflicts(pushCtx, &syncpb.ListConflictsRequest{})
	if err != nil {
		t.Fatalf("ListConflicts after empty-merged reject: %v", err)
	}
	if len(preReject.Conflicts) != 1 {
		t.Fatalf("conflicts after empty-merged reject = %d, want 1 (untouched)", len(preReject.Conflicts))
	}

	// Valid resolution lands and clears the pending count.
	if _, err := it.handler.ResolveConflict(pushCtx, &syncpb.ResolveConflictRequest{ConflictId: conflictID, Resolution: "server"}); err != nil {
		t.Fatalf("valid resolve: %v", err)
	}
	status, err := it.handler.GetSyncStatus(pushCtx, &syncpb.GetSyncStatusRequest{})
	if err != nil {
		t.Fatalf("aggregate status: %v", err)
	}
	if status.PendingConflicts != 0 {
		t.Fatalf("pending_conflicts after resolve = %d, want 0", status.PendingConflicts)
	}
	list, err := it.handler.ListConflicts(pushCtx, &syncpb.ListConflictsRequest{})
	if err != nil {
		t.Fatalf("ListConflicts: %v", err)
	}
	if len(list.Conflicts) != 0 {
		t.Fatalf("listed conflicts after resolve = %d, want 0", len(list.Conflicts))
	}
}

// TestSyncPush_MalformedEntityID_Rejected: a change whose entity_id is not a
// uuid fails InvalidArgument BEFORE any write runs (the old parseUUID coerced
// it to uuid.Nil and the batch died later as an opaque Internal).
func TestSyncPush_MalformedEntityID_Rejected(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	_, err := it.handler.PushChanges(syncPushCtx(ctx, tenantID), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantID, "account", "garbage-id", syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(uuid.New().String(), "Bad id", 1))),
	}})
	if err == nil {
		t.Fatal("malformed entity_id must be rejected")
	}
	assertCode(t, err, codes.InvalidArgument)
	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 0 {
		t.Fatalf("no log rows may persist, got %d", len(rows))
	}
}
