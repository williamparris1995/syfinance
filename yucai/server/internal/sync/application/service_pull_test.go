package application

// Tier-A tests for F16 T2 S3 (PullChanges pagination, ADR-3): the service
// trims the repo's limit+1 fetch to the page size, computes has_more from the
// sentinel row, and keeps latest_version = the tenant log frontier (NOT the
// page cursor — a client resuming after has_more uses the last change's
// version as its next since_version). Reuses the F11 push harness.

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"

	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// decodeID extracts the payload's top-level ID (every module entity
// serializes its id there — the push path's own probe contract).
func decodeID(t *testing.T, payload []byte) uuid.UUID {
	t.Helper()
	var probe struct {
		ID uuid.UUID
	}
	if err := json.Unmarshal(payload, &probe); err != nil {
		t.Fatalf("decode payload id: %v", err)
	}
	return probe.ID
}

// seedAccount pushes one account CREATE so the tenant log grows by one
// version per call, in order.
func seedAccount(t *testing.T, h *pushHarness, ctx context.Context) {
	t.Helper()
	payload := accountPayload(t, h.tenantID, "row", 1)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "account", EntityID: decodeID(t, payload),
		Operation:  syncdomain.SyncOperationCreate, Payload: payload,
		Version: 1, DeviceID: h.deviceID,
	}}); err != nil {
		t.Fatalf("seed push: %v", err)
	}
}

// TestPullChanges_PaginationTrimsAndComputesHasMore (ADR-3): a 5-entry log
// paged at 2 returns pages [1,2] (has_more), [3,4] (has_more), [5] (no
// has_more); latest_version stays the frontier (5) on every page.
func TestPullChanges_PaginationTrimsAndComputesHasMore(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		seedAccount(t, h, ctx)
	}

	pages := []struct {
		versions []int64
		hasMore  bool
	}{
		{[]int64{1, 2}, true},
		{[]int64{3, 4}, true},
		{[]int64{5}, false},
	}

	since := int64(0)
	for i, want := range pages {
		payloads, latest, hasMore, err := h.svc.PullChanges(ctx, h.tenantID, since, nil, 2)
		if err != nil {
			t.Fatalf("page %d: %v", i+1, err)
		}
		if len(payloads) != len(want.versions) {
			t.Fatalf("page %d: %d changes, want %d", i+1, len(payloads), len(want.versions))
		}
		for j, v := range want.versions {
			if payloads[j].Version != v {
				t.Fatalf("page %d change %d: version %d, want %d (ascending)", i+1, j, payloads[j].Version, v)
			}
		}
		if hasMore != want.hasMore {
			t.Fatalf("page %d: has_more = %v, want %v", i+1, hasMore, want.hasMore)
		}
		if latest != 5 {
			t.Fatalf("page %d: latest_version = %d, want frontier 5", i+1, latest)
		}
		// The resume cursor is the last change's version (not latest_version,
		// which may point past the page while has_more is set).
		since = payloads[len(payloads)-1].Version
	}
}

// TestPullChanges_ExactFitNoHasMore: a page size equal to the remaining rows
// returns everything with has_more=false (the sentinel row does not exist).
func TestPullChanges_ExactFitNoHasMore(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	for i := 0; i < 3; i++ {
		seedAccount(t, h, ctx)
	}

	payloads, latest, hasMore, err := h.svc.PullChanges(ctx, h.tenantID, 0, nil, 3)
	if err != nil {
		t.Fatalf("PullChanges: %v", err)
	}
	if len(payloads) != 3 || hasMore {
		t.Fatalf("exact fit: %d changes has_more=%v, want 3 false", len(payloads), hasMore)
	}
	if latest != 3 {
		t.Fatalf("latest_version = %d, want 3", latest)
	}
}

// TestPullChanges_EmptyLog_ZeroChanges: an empty log returns an empty page,
// has_more=false, latest_version=0 — the client's steady-state poll shape.
func TestPullChanges_EmptyLog_ZeroChanges(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	payloads, latest, hasMore, err := h.svc.PullChanges(ctx, h.tenantID, 0, nil, 500)
	if err != nil {
		t.Fatalf("PullChanges empty: %v", err)
	}
	if len(payloads) != 0 || hasMore || latest != 0 {
		t.Fatalf("empty pull = (%d changes, has_more=%v, latest=%d), want (0, false, 0)", len(payloads), hasMore, latest)
	}
}

// TestPullChanges_EntityTypeFilter: the entity_types filter composes with
// pagination — only the requested types come back, in version order.
func TestPullChanges_EntityTypeFilter(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	// One account (v1), one tag (v2), one account (v3).
	accPayload := accountPayload(t, h.tenantID, "a", 1)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "account", EntityID: decodeID(t, accPayload),
		Operation:  syncdomain.SyncOperationCreate, Payload: accPayload,
		Version: 1, DeviceID: h.deviceID,
	}}); err != nil {
		t.Fatalf("seed account: %v", err)
	}
	tagP := tagPayload(t, h.tenantID, "t", 1)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "tag", EntityID: decodeID(t, tagP),
		Operation:  syncdomain.SyncOperationCreate, Payload: tagP,
		Version: 1, DeviceID: h.deviceID,
	}}); err != nil {
		t.Fatalf("seed tag: %v", err)
	}
	accPayload2 := accountPayload(t, h.tenantID, "a2", 1)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{{
		EntityType: "account", EntityID: decodeID(t, accPayload2),
		Operation:  syncdomain.SyncOperationCreate, Payload: accPayload2,
		Version: 1, DeviceID: h.deviceID,
	}}); err != nil {
		t.Fatalf("seed account 2: %v", err)
	}

	payloads, _, hasMore, err := h.svc.PullChanges(ctx, h.tenantID, 0, []string{"account"}, 1)
	if err != nil {
		t.Fatalf("PullChanges filtered: %v", err)
	}
	if len(payloads) != 1 || !hasMore {
		t.Fatalf("filtered page = %d changes has_more=%v, want 1 true", len(payloads), hasMore)
	}
	if payloads[0].EntityType != "account" || payloads[0].Version != 1 {
		t.Fatalf("filtered change = %s v%d, want account v1", payloads[0].EntityType, payloads[0].Version)
	}

	// Page two of the filtered stream: account v3.
	payloads, _, _, err = h.svc.PullChanges(ctx, h.tenantID, 1, []string{"account"}, 1)
	if err != nil {
		t.Fatalf("PullChanges filtered page 2: %v", err)
	}
	if len(payloads) != 1 || payloads[0].Version != 3 {
		t.Fatalf("filtered page 2 = %+v, want account v3", payloads)
	}
}

// TestPullChanges_DefaultPageSizeForNonPositiveInput: a non-positive page size
// (direct service callers; the handler sanitizes the wire value) falls back to
// the documented default of 500 rather than degrading to a 1-row page.
func TestPullChanges_DefaultPageSizeForNonPositiveInput(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()
	for i := 0; i < 3; i++ {
		seedAccount(t, h, ctx)
	}

	payloads, _, hasMore, err := h.svc.PullChanges(ctx, h.tenantID, 0, nil, 0)
	if err != nil {
		t.Fatalf("PullChanges with page size 0: %v", err)
	}
	if len(payloads) != 3 || hasMore {
		t.Fatalf("page size 0 = %d changes has_more=%v, want 3 false (default 500)", len(payloads), hasMore)
	}
}
