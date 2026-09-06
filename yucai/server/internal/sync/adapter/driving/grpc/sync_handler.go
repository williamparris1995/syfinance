package grpc

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	pb "github.com/yucai/server/internal/proto/sync/v1"
	"github.com/yucai/server/internal/sync/application"
	"github.com/yucai/server/internal/sync/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// SyncHandler implements the generated SyncServiceServer interface.
type SyncHandler struct {
	pb.UnimplementedSyncServiceServer
	service *application.Service
}

// NewSyncHandler creates a new SyncHandler.
func NewSyncHandler(service *application.Service) *SyncHandler {
	return &SyncHandler{service: service}
}

// RegisterDevice registers a new sync device. device_id (F17 ADR-1, added to
// the wire after verification): the handler does NOT read the x-client-id
// metadata (which the client already sends on every RPC), and before the
// field existed it hardcoded uuid.Nil — a fresh server-generated id per call,
// never idempotent by client identity. A non-empty well-formed device_id now
// takes the service's caller-supplied idempotent path (re-registration
// returns the existing row); empty keeps the legacy server-generated path; a
// malformed value is InvalidArgument fail-closed (parseUUIDStrict).
func (h *SyncHandler) RegisterDevice(ctx context.Context, req *pb.RegisterDeviceRequest) (*pb.RegisterDeviceResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	var deviceID uuid.UUID
	if req.DeviceId != "" {
		var perr error
		deviceID, perr = parseUUIDStrict("device_id", req.DeviceId)
		if perr != nil {
			return nil, perr
		}
	}
	device, err := h.service.RegisterDevice(ctx, tenantID, deviceID, req.DeviceName)
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.RegisterDeviceResponse{
		DeviceId:        device.ID.String(),
		LastSyncVersion: device.LastSyncVersion,
	}, nil
}

// GetSyncStatus returns the current sync status. device_id filter (F16 ADR-2):
// an EMPTY device_id keeps the tenant-aggregate view (log frontier + pending
// conflicts — backward compatible, the proto field is new); a non-empty
// device_id scopes the response to that registered device.
func (h *SyncHandler) GetSyncStatus(ctx context.Context, req *pb.GetSyncStatusRequest) (*pb.SyncStatusResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	var result *application.SyncStatusDTO
	if req.DeviceId == "" {
		result, err = h.service.GetTenantSyncStatus(ctx, tenantID)
		if err != nil {
			return nil, mapError(err)
		}
	} else {
		// Hardened parse: the reject path returns its gRPC status error
		// verbatim (mapError would re-wrap it as Internal).
		deviceID, perr := resolveDeviceID(req.DeviceId)
		if perr != nil {
			return nil, perr
		}
		result, err = h.service.GetSyncStatus(ctx, tenantID, deviceID)
		if err != nil {
			return nil, mapError(err)
		}
	}

	// The aggregate view carries no device attribution — empty on the wire,
	// not a Nil uuid string.
	deviceIDStr := ""
	if result.DeviceID != uuid.Nil {
		deviceIDStr = result.DeviceID.String()
	}
	return &pb.SyncStatusResponse{
		DeviceId:         deviceIDStr,
		LastSyncVersion:  result.LastSyncVersion,
		LastSyncAt:       timestamppb.New(result.LastSyncAt),
		PendingConflicts: result.PendingConflicts,
	}, nil
}

// PushChanges processes incoming changes from a client. Batch device
// identity: the client stamps every change with the same deviceId; the first
// change's value attributes the whole batch (F16 ADR-2 hardening — empty is
// InvalidArgument, malformed is InvalidArgument, the legacy 'bound' literal
// is tolerated as uuid.Nil; see resolveDeviceID).
func (h *SyncHandler) PushChanges(ctx context.Context, req *pb.PushChangesRequest) (*pb.PushResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	// Fail-closed device attribution BEFORE any write runs. An empty batch
	// carries no deviceId to validate and remains a trivial no-op push
	// (service early-return), preserving the existing behavior.
	var deviceID uuid.UUID
	if len(req.Changes) > 0 {
		deviceID, err = resolveDeviceID(req.Changes[0].DeviceId)
		if err != nil {
			return nil, err
		}
	}

	payloads := make([]application.SyncPayloadDTO, len(req.Changes))
	for i, c := range req.Changes {
		// Fail-closed entity id parse (F16 T2): a malformed entity_id is an
		// InvalidArgument BEFORE any write runs — the old parseUUID coerced it
		// to uuid.Nil and the batch failed later as an opaque Internal.
		entityID, perr := parseUUIDStrict("entity_id", c.EntityId)
		if perr != nil {
			return nil, perr
		}
		payloads[i] = application.SyncPayloadDTO{
			EntityType: c.EntityType,
			EntityID:   entityID,
			Operation:  protoToOperation(c.Operation),
			Payload:    c.Payload,
			Version:    c.Version,
			// Batch-level attribution: the validated deviceId from change[0].
			// Per-change DeviceId strings are NOT re-parsed — the old loop
			// silently coerced a malformed per-change value to uuid.Nil.
			DeviceID: deviceID,
		}
	}

	syncedVersion, conflicts, err := h.service.PushChanges(ctx, tenantID, deviceID, payloads)
	if err != nil {
		return nil, mapError(err)
	}

	conflictProtos := make([]*pb.ConflictDTO, len(conflicts))
	for i, c := range conflicts {
		conflictProtos[i] = conflictToProto(c)
	}

	return &pb.PushResponse{
		SyncedVersion: syncedVersion,
		Conflicts:     conflictProtos,
	}, nil
}

// PullChanges returns changes since a given version (F16 ADR-3: ordered
// sync_log replay pagination).
//
// page_size clamping: <=0 (field absent on the wire or an explicit 0) becomes
// the default 500; >1000 is capped at 1000. The response contract the client
// codes against: apply changes in the returned version order (ascending) —
// every upsert/delete replay is idempotent; on has_more=true continue pulling
// with since_version = the last change's version in this page; latest_version
// is the tenant log frontier, not the page cursor.
func (h *SyncHandler) PullChanges(ctx context.Context, req *pb.PullChangesRequest) (*pb.PullChangesResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	pageSize := clampPullPageSize(req.PageSize)

	payloads, latestVersion, hasMore, err := h.service.PullChanges(ctx, tenantID, req.SinceVersion, req.EntityTypes, pageSize)
	if err != nil {
		return nil, mapError(err)
	}

	changes := make([]*pb.SyncPayload, len(payloads))
	for i, p := range payloads {
		changes[i] = &pb.SyncPayload{
			EntityType: p.EntityType,
			EntityId:   p.EntityID.String(),
			Operation:  operationToProto(p.Operation),
			Payload:    p.Payload,
			Version:    p.Version,
			DeviceId:   p.DeviceID.String(),
		}
	}

	return &pb.PullChangesResponse{
		Changes:       changes,
		LatestVersion: latestVersion,
		HasMore:       hasMore,
	}, nil
}

// clampPullPageSize sanitizes the wire page_size: 0/absent -> default 500,
// >1000 -> 1000 (values in between pass through).
func clampPullPageSize(n int32) int {
	if n <= 0 {
		return application.DefaultPullPageSize
	}
	if n > application.MaxPullPageSize {
		return application.MaxPullPageSize
	}
	return int(n)
}

// ResolveConflict resolves a sync conflict.
func (h *SyncHandler) ResolveConflict(ctx context.Context, req *pb.ResolveConflictRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	// Fail-closed parse (F16 T2): a malformed conflict_id is InvalidArgument,
	// not a silently coerced uuid.Nil matching zero rows as an Internal.
	conflictID, perr := parseUUIDStrict("conflict_id", req.ConflictId)
	if perr != nil {
		return nil, perr
	}

	if err := h.service.ResolveConflict(ctx, tenantID, conflictID, req.Resolution); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// ListConflicts returns pending conflicts.
func (h *SyncHandler) ListConflicts(ctx context.Context, req *pb.ListConflictsRequest) (*pb.ListConflictsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	page := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}

	conflicts, nextToken, totalCount, err := h.service.ListConflicts(ctx, tenantID, page)
	if err != nil {
		return nil, mapError(err)
	}

	conflictProtos := make([]*pb.ConflictDTO, len(conflicts))
	for i, c := range conflicts {
		conflictProtos[i] = conflictToProto(c)
	}

	return &pb.ListConflictsResponse{
		Conflicts: conflictProtos,
		Page:      &commonpb.PageResponse{NextPageToken: nextToken, TotalCount: totalCount},
	}, nil
}

// --- Helpers ---

func conflictToProto(c application.ConflictDTO) *pb.ConflictDTO {
	return &pb.ConflictDTO{
		Id:            c.ID.String(),
		EntityType:    c.EntityType,
		EntityId:      c.EntityID.String(),
		ServerPayload: c.ServerPayload,
		ClientPayload: c.ClientPayload,
		Resolution:    c.Resolution,
		// F16: the conflict classification must survive the mapping (the old
		// mapper silently dropped it).
		ConflictType: c.ConflictType,
	}
}

func protoToOperation(op pb.SyncOperation) domain.SyncOperation {
	switch op {
	case pb.SyncOperation_SYNC_OPERATION_CREATE:
		return domain.SyncOperationCreate
	case pb.SyncOperation_SYNC_OPERATION_UPDATE:
		return domain.SyncOperationUpdate
	case pb.SyncOperation_SYNC_OPERATION_DELETE:
		return domain.SyncOperationDelete
	default:
		return 0
	}
}

func operationToProto(op domain.SyncOperation) pb.SyncOperation {
	switch op {
	case domain.SyncOperationCreate:
		return pb.SyncOperation_SYNC_OPERATION_CREATE
	case domain.SyncOperationUpdate:
		return pb.SyncOperation_SYNC_OPERATION_UPDATE
	case domain.SyncOperationDelete:
		return pb.SyncOperation_SYNC_OPERATION_DELETE
	default:
		return pb.SyncOperation_SYNC_OPERATION_UNSPECIFIED
	}
}

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

// legacyBoundDeviceMarker is the device_id literal the F10-F13 single-device
// client sends on every change (client binding/data/grpc_offline_sync_port.dart
// — BoundMarker stores the string 'bound', not a uuid). It is NOT a valid
// uuid; the old parseUUID coerced the parse failure to uuid.Nil silently.
// F16 ADR-2 keeps tolerating it as an EXPLICIT alias of uuid.Nil; the F17
// client no longer sends it (deviceId = the per-install clientId now), but
// the tolerance stays until pre-F17 clients age out.
const legacyBoundDeviceMarker = "bound"

// resolveDeviceID parses a wire device_id fail-closed (F16 ADR-2):
//   - ""            -> InvalidArgument "device_id required" (the tenantID
//     fallback is retired: an attribution gap must be loud, not laundered
//     into the authenticated tenant).
//   - "bound"       -> uuid.Nil, nil (legacy single-device literal; see
//     legacyBoundDeviceMarker).
//   - valid uuid    -> parsed value; an explicit uuid.Nil string is likewise
//     tolerated (transition semantics until F17).
//   - anything else -> InvalidArgument (the parse error is surfaced, no
//     longer swallowed into uuid.Nil).
func resolveDeviceID(s string) (uuid.UUID, error) {
	if s == "" {
		return uuid.Nil, status.Error(codes.InvalidArgument, "device_id required")
	}
	if s == legacyBoundDeviceMarker {
		return uuid.Nil, nil
	}
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, status.Error(codes.InvalidArgument, fmt.Sprintf("invalid device_id: %v", err))
	}
	return id, nil
}

// parseUUIDStrict parses a REQUIRED wire uuid fail-closed: a malformed (or
// empty) value is an InvalidArgument status error, never a silently coerced
// uuid.Nil (F16 T2 hardening — the old parseUUID helper swallowed the parse
// error). The handler's wire-level validations return their status errors
// directly (NOT via mapError), which is where the validation->InvalidArgument
// mapping for this module lives.
func parseUUIDStrict(field, s string) (uuid.UUID, error) {
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, status.Error(codes.InvalidArgument, fmt.Sprintf("invalid %s: %v", field, err))
	}
	return id, nil
}

// mapError maps service errors to gRPC codes with per-family fidelity (F16
// FR-6 / ADR-6; the debt-handler message-matching convention, plus the sync
// module's own sentinels):
//   - ErrVersionConflict (serialization retries exhausted) -> Aborted: the
//     batch is valid, it kept losing the version race — retryable.
//   - ErrInvalidResolution (ResolveConflict whitelist) -> InvalidArgument.
//   - "... not found" (the ent NotFound message shape flowing through the
//     repos' fmt.Errorf %w wraps — device/conflict lookups) -> NotFound.
//   - everything else -> Internal: fail-closed. Note mid-batch payload-decode
//     faults deliberately land here too — the wire shape was structurally
//     accepted, the content is garbage; the whole batch rolled back and the
//     generic fault surface is the honest classification (matching the F11
//     integration contract).
func mapError(err error) error {
	switch {
	case errors.Is(err, application.ErrVersionConflict):
		return status.Errorf(codes.Aborted, "sync version conflict: %v", err)
	case errors.Is(err, application.ErrInvalidResolution):
		return status.Errorf(codes.InvalidArgument, "%v", err)
	case strings.Contains(err.Error(), "not found"):
		return status.Errorf(codes.NotFound, "%v", err)
	default:
		return status.Errorf(codes.Internal, "sync service error: %v", err)
	}
}
