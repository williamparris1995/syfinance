package grpc

// Tier-A unit tests for the F16 T2 handler surface pieces that are pure
// functions: the pull page-size clamp, the ConflictDTO mapping (conflict_type
// fidelity), and the mapError gRPC code taxonomy (FR-6 / ADR-6). The
// end-to-end behaviors ride the tests/ integration harness.

import (
	"errors"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/yucai/server/internal/sync/application"
)

// TestClampPullPageSize: 0/absent -> default 500, negative -> 500, >1000 ->
// 1000, in-range values pass through.
func TestClampPullPageSize(t *testing.T) {
	cases := []struct {
		in   int32
		want int
	}{
		{0, 500},
		{-1, 500},
		{-1000, 500},
		{1, 1},
		{500, 500},
		{999, 999},
		{1000, 1000},
		{1001, 1000},
		{5000, 1000},
	}
	for _, c := range cases {
		if got := clampPullPageSize(c.in); got != c.want {
			t.Errorf("clampPullPageSize(%d) = %d, want %d", c.in, got, c.want)
		}
	}
}

// TestConflictToProto_CarriesConflictType: the F16 field must survive the
// DTO->proto mapping (the old mapper silently dropped it).
func TestConflictToProto_CarriesConflictType(t *testing.T) {
	in := application.ConflictDTO{
		ID:            uuid.New(),
		EntityType:    "account",
		EntityID:      uuid.New(),
		ConflictType:  "version_conflict",
		ServerPayload: []byte(`{"a":1}`),
		ClientPayload: []byte(`{"b":2}`),
		Resolution:    "pending",
	}
	out := conflictToProto(in)
	if out.ConflictType != "version_conflict" {
		t.Fatalf("conflict_type = %q, want version_conflict (mapping must not drop it)", out.ConflictType)
	}
	if out.EntityType != "account" || out.Resolution != "pending" {
		t.Fatalf("mapping = %+v", out)
	}
	if string(out.ServerPayload) != `{"a":1}` || string(out.ClientPayload) != `{"b":2}` {
		t.Fatal("payloads must map verbatim")
	}
}

// TestMapError_CodeFidelity (FR-6/ADR-6): the gRPC code taxonomy keeps the
// distinct failure families distinguishable on the wire —
// ErrVersionConflict -> Aborted, ErrInvalidResolution -> InvalidArgument,
// ent NotFound (wrapped) -> NotFound, everything else -> Internal.
func TestMapError_CodeFidelity(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want codes.Code
	}{
		{
			"version conflict retries exhausted",
			fmt.Errorf("push: %w", application.ErrVersionConflict),
			codes.Aborted,
		},
		{
			"invalid resolution",
			fmt.Errorf("resolve conflict: %w", application.ErrInvalidResolution),
			codes.InvalidArgument,
		},
		{
			"device not found (ent NotFound message through the wrap chain)",
			errors.New("find device: ent: sync_device not found"),
			codes.NotFound,
		},
		{
			"conflict not found (repo surfaced shape)",
			errors.New("resolve conflict: ent: sync_conflict not found"),
			codes.NotFound,
		},
		{
			"unknown service fault",
			errors.New("boom"),
			codes.Internal,
		},
		{
			"batch decode fault stays fail-closed Internal",
			fmt.Errorf("decode account %s payload id: invalid character 'o' in literal null", uuid.New()),
			codes.Internal,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := status.Code(mapError(c.err))
			if got != c.want {
				t.Fatalf("mapError(%v) = %v, want %v", c.err, got, c.want)
			}
		})
	}
}
