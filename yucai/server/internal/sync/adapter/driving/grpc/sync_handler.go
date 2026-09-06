package grpc

import (
	"context"
	"errors"
	"fmt"

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

// RegisterDevice registers a new sync device. The request carries no device
// identity yet (device_name only), so the handler passes uuid.Nil and the
// service server-generates a fresh id; the idempotent caller-supplied-id path
// (F17 stable device identity) is exercised at the service layer.
func (h *SyncHandler) RegisterDevice(ctx context.Context, req *pb.RegisterDeviceRequest) (*pb.RegisterDeviceResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	device, err := h.service.RegisterDevice(ctx, tenantID, uuid.Nil, req.DeviceName)
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
		payloads[i] = application.SyncPayloadDTO{
			EntityType: c.EntityType,
			EntityID:   parseUUID(c.EntityId),
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

// PullChanges returns changes since a given version.
func (h *SyncHandler) PullChanges(ctx context.Context, req *pb.PullChangesRequest) (*pb.PullChangesResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	payloads, latestVersion, err := h.service.PullChanges(ctx, tenantID, req.SinceVersion, req.EntityTypes)
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
		HasMore:       false,
	}, nil
}

// ResolveConflict resolves a sync conflict.
func (h *SyncHandler) ResolveConflict(ctx context.Context, req *pb.ResolveConflictRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	conflictID := parseUUID(req.ConflictId)
	if conflictID == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid conflict_id")
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
// F16 ADR-2 keeps tolerating it as an EXPLICIT alias of uuid.Nil so the
// shipped client keeps syncing; F17 (real RegisterDevice wiring) retires it
// together with the Nil tolerance.
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

func parseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

// mapError maps service errors to gRPC codes. Currently Internal-by-default;
// the single special case below is the F16 serialization abort signal (ADR-1:
// a push that kept losing the version race is Aborted — a retryable outcome,
// not an internal fault). Full per-error fidelity (NotFound / validation /
// conflict families) is the F16 T2 mapError pass (FR-6/ADR-6).
func mapError(err error) error {
	if errors.Is(err, application.ErrVersionConflict) {
		return status.Errorf(codes.Aborted, "sync version conflict: %v", err)
	}
	return status.Errorf(codes.Internal, "sync service error: %v", err)
}
