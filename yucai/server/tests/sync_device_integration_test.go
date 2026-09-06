package tests

// F16 T1 S2 — handler-level integration tests for the device identity chain
// (spec FR-2 / ADR-2), extending the F11 sync push harness:
//   - deviceId hardening on PushChanges: empty -> InvalidArgument (the
//     tenantID fallback is retired, fail-closed), malformed non-empty ->
//     InvalidArgument (parseUUID no longer swallows into uuid.Nil), while the
//     production single-device value — the 'bound' literal the F10-F13 client
//     sends — stays tolerated as uuid.Nil until F17 ships real registration.
//   - RegisterDevice idempotency surface: server-generated ids per call today
//     (the wire request carries no device identity yet).
//   - GetSyncStatus device_id filter: empty = tenant aggregate (log frontier),
//     a registered device id = the device row, malformed = InvalidArgument.
//
// Everything drives the REAL SyncHandler over the shared in-memory SQLite
// harness from sync_push_integration_test.go (newSyncPushIT), so the covered
// surface is the full production chain.

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"

	syncpb "github.com/yucai/server/internal/proto/sync/v1"
)

// deviceCtx is the auth context shape reused from syncPushCtx.
func deviceCtx(ctx context.Context, tenantID uuid.UUID) context.Context {
	return syncPushCtx(ctx, tenantID)
}

// TestSyncDevice_BoundLiteralDeviceID_Accepted (client zero-regression pin):
// the production single-device client stamps every change with the literal
// 'bound' string (BoundMarker — NOT a uuid; see client
// binding/data/grpc_offline_sync_port.dart). The hardened parse must keep
// accepting it as uuid.Nil through F17; only the sync_log device_id column
// and the (no-op) device-version bump observe Nil.
func TestSyncDevice_BoundLiteralDeviceID_Accepted(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	accID := uuid.New()
	change := syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
		marshalSyncRow(t, syncAccountRow(accID.String(), "Bound device", 1)))
	change.DeviceId = "bound" // the REAL production literal

	resp, err := it.handler.PushChanges(deviceCtx(ctx, tenantID), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{change}})
	if err != nil {
		t.Fatalf("push with the legacy 'bound' device literal must stay accepted: %v", err)
	}
	if resp.SyncedVersion != 1 {
		t.Fatalf("synced_version = %d, want 1", resp.SyncedVersion)
	}

	// The log row carries the Nil device attribution.
	rows := it.syncLogRows(t, ctx, tenantID)
	if len(rows) != 1 || rows[0].DeviceID != uuid.Nil {
		t.Fatalf("log device_id = %+v, want one row attributed to uuid.Nil", rows)
	}
}

// TestSyncDevice_EmptyDeviceID_Rejected (fallback retirement): a batch whose
// changes carry an empty device_id must fail InvalidArgument — the old
// fallback (deviceID = tenantID) is retired so a real device attribution gap
// is loud, not silently laundered into the tenant id. Nothing persists.
func TestSyncDevice_EmptyDeviceID_Rejected(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	accID := uuid.New()
	change := syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
		marshalSyncRow(t, syncAccountRow(accID.String(), "No device", 1)))
	change.DeviceId = ""

	_, err := it.handler.PushChanges(deviceCtx(ctx, tenantID), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{change}})
	if err == nil {
		t.Fatal("push with empty device_id must be rejected (fallback retired)")
	}
	assertCode(t, err, codes.InvalidArgument)

	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 0 {
		t.Fatalf("no log rows may persist, got %d", len(rows))
	}
}

// TestSyncDevice_MalformedDeviceID_Rejected: a non-empty device_id that is
// neither a uuid nor the legacy 'bound' literal must fail InvalidArgument —
// the old parseUUID swallowed the parse error into uuid.Nil silently.
func TestSyncDevice_MalformedDeviceID_Rejected(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	accID := uuid.New()
	change := syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
		marshalSyncRow(t, syncAccountRow(accID.String(), "Bad device", 1)))
	change.DeviceId = "not-a-uuid"

	_, err := it.handler.PushChanges(deviceCtx(ctx, tenantID), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{change}})
	if err == nil {
		t.Fatal("push with a malformed device_id must be rejected")
	}
	assertCode(t, err, codes.InvalidArgument)
	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 0 {
		t.Fatalf("no log rows may persist, got %d", len(rows))
	}
}

// TestSyncDevice_ExplicitUUIDDeviceID_Accepted: a well-formed device uuid
// attributes the batch (log column + device-version bump land on the
// REGISTERED device row) — the F17 shape already works end to end today.
func TestSyncDevice_ExplicitUUIDDeviceID_Accepted(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	reg, err := it.handler.RegisterDevice(deviceCtx(ctx, tenantID), &syncpb.RegisterDeviceRequest{DeviceName: "phone"})
	if err != nil {
		t.Fatalf("RegisterDevice: %v", err)
	}
	deviceID, err := uuid.Parse(reg.DeviceId)
	if err != nil {
		t.Fatalf("registered device_id is not a uuid: %v", err)
	}

	accID := uuid.New()
	change := syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
		marshalSyncRow(t, syncAccountRow(accID.String(), "Real device", 1)))
	change.DeviceId = deviceID.String()

	if _, err := it.handler.PushChanges(deviceCtx(ctx, tenantID), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{change}}); err != nil {
		t.Fatalf("push with registered device uuid: %v", err)
	}

	rows := it.syncLogRows(t, ctx, tenantID)
	if len(rows) != 1 || rows[0].DeviceID != deviceID {
		t.Fatalf("log device attribution = %+v, want %s", rows, deviceID)
	}

	// The registered device row was bumped to the batch's synced version.
	status, err := it.handler.GetSyncStatus(deviceCtx(ctx, tenantID), &syncpb.GetSyncStatusRequest{DeviceId: deviceID.String()})
	if err != nil {
		t.Fatalf("GetSyncStatus(device): %v", err)
	}
	if status.LastSyncVersion != 1 {
		t.Fatalf("device last_sync_version = %d, want 1 (bump landed on the registered row)", status.LastSyncVersion)
	}
}

// TestSyncDevice_RegisterDevice_ServerGeneratedFreshIDs: the wire request
// carries no device identity yet (device_name only), so each registration
// returns a fresh server-generated uuid starting at last_sync_version 0. The
// idempotent re-registration path (caller-supplied stable id) is exercised at
// the service layer in internal/sync/application tests; F17 adds the wire
// field.
func TestSyncDevice_RegisterDevice_ServerGeneratedFreshIDs(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()

	a, err := it.handler.RegisterDevice(deviceCtx(ctx, tenantID), &syncpb.RegisterDeviceRequest{DeviceName: "phone"})
	if err != nil {
		t.Fatalf("register a: %v", err)
	}
	b, err := it.handler.RegisterDevice(deviceCtx(ctx, tenantID), &syncpb.RegisterDeviceRequest{DeviceName: "tablet"})
	if err != nil {
		t.Fatalf("register b: %v", err)
	}
	if a.DeviceId == b.DeviceId {
		t.Fatalf("two registrations must not share a device id: %s", a.DeviceId)
	}
	if a.LastSyncVersion != 0 || b.LastSyncVersion != 0 {
		t.Fatalf("fresh devices must start at last_sync_version 0, got %d/%d", a.LastSyncVersion, b.LastSyncVersion)
	}

	// Empty device_name is still rejected (domain validation through the
	// handler).
	if _, err := it.handler.RegisterDevice(deviceCtx(ctx, tenantID), &syncpb.RegisterDeviceRequest{DeviceName: ""}); err == nil {
		t.Fatal("empty device_name must be rejected")
	}
}

// TestSyncDevice_GetSyncStatus_DeviceFilter (ADR-2): an EMPTY device_id
// returns the tenant-aggregate view (log frontier — no device row needed);
// a REGISTERED device id returns that device's row; a MALFORMED device_id is
// InvalidArgument; an UNKNOWN but well-formed id errors (device not found —
// mapped Internal by the current mapError until the FR-6 fidelity pass).
func TestSyncDevice_GetSyncStatus_DeviceFilter(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := deviceCtx(ctx, tenantID)

	// Two pushes so the frontier (2) differs from any single-device position.
	acc1, acc2 := uuid.New(), uuid.New()
	for _, acc := range []uuid.UUID{acc1, acc2} {
		if _, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
			syncChange(tenantID, "account", acc.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
				marshalSyncRow(t, syncAccountRow(acc.String(), "agg", 1))),
		}}); err != nil {
			t.Fatalf("seed push: %v", err)
		}
	}

	// Aggregate: empty device_id -> log frontier, no device attribution.
	agg, err := it.handler.GetSyncStatus(pushCtx, &syncpb.GetSyncStatusRequest{})
	if err != nil {
		t.Fatalf("aggregate GetSyncStatus (empty device_id) must stay compatible: %v", err)
	}
	if agg.LastSyncVersion != 2 {
		t.Fatalf("aggregate last_sync_version = %d, want log frontier 2", agg.LastSyncVersion)
	}
	if agg.DeviceId != "" {
		t.Fatalf("aggregate device_id = %q, want empty (no attribution)", agg.DeviceId)
	}

	// Registered device: scoped row.
	reg, err := it.handler.RegisterDevice(pushCtx, &syncpb.RegisterDeviceRequest{DeviceName: "phone"})
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	scoped, err := it.handler.GetSyncStatus(pushCtx, &syncpb.GetSyncStatusRequest{DeviceId: reg.DeviceId})
	if err != nil {
		t.Fatalf("scoped GetSyncStatus: %v", err)
	}
	if scoped.DeviceId != reg.DeviceId || scoped.LastSyncVersion != 0 {
		t.Fatalf("scoped status = (%s, %d), want (%s, 0)", scoped.DeviceId, scoped.LastSyncVersion, reg.DeviceId)
	}

	// Malformed device_id: InvalidArgument (hardened parse).
	if _, err := it.handler.GetSyncStatus(pushCtx, &syncpb.GetSyncStatusRequest{DeviceId: "garbage"}); err == nil {
		t.Fatal("malformed device_id must be InvalidArgument")
	} else {
		assertCode(t, err, codes.InvalidArgument)
	}

	// The legacy 'bound' literal parses to Nil; no device row exists for it,
	// so the scoped lookup errors (not-found — not silently aggregate).
	if _, err := it.handler.GetSyncStatus(pushCtx, &syncpb.GetSyncStatusRequest{DeviceId: "bound"}); err == nil {
		t.Fatal("'bound'-attributed status must surface the missing device row, not silently aggregate")
	}
}
