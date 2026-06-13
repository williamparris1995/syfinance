package grpc

import (
	"context"

	pb "github.com/yucai/server/internal/proto/sync/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
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

// RegisterDevice registers a new sync device.
func (h *SyncHandler) RegisterDevice(ctx context.Context, req *pb.RegisterDeviceRequest) (*pb.RegisterDeviceResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	device, err := h.service.RegisterDevice(ctx, tenantID, req.DeviceName)
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.RegisterDeviceResponse{
		DeviceId:        device.ID.String(),
		LastSyncVersion: device.LastSyncVersion,
	}, nil
}

// GetSyncStatus returns the current sync status for a device.
func (h *SyncHandler) GetSyncStatus(ctx context.Context, req *pb.GetSyncStatusRequest) (*pb.SyncStatusResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	// Use tenantID as deviceID placeholder — in production, extract device_id from auth context
	deviceID := tenantID

	result, err := h.service.GetSyncStatus(ctx, tenantID, deviceID)
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.SyncStatusResponse{
		DeviceId:         result.DeviceID.String(),
		LastSyncVersion:  result.LastSyncVersion,
		LastSyncAt:       timestamppb.New(result.LastSyncAt),
		PendingConflicts: result.PendingConflicts,
	}, nil
}

// PushChanges processes incoming changes from a client.
func (h *SyncHandler) PushChanges(ctx context.Context, req *pb.PushChangesRequest) (*pb.PushResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	// Extract device ID from first change or use tenantID
	var deviceID uuid.UUID
	if len(req.Changes) > 0 && req.Changes[0].DeviceId != "" {
		deviceID = parseUUID(req.Changes[0].DeviceId)
	} else {
		deviceID = tenantID
	}

	payloads := make([]application.SyncPayloadDTO, len(req.Changes))
	for i, c := range req.Changes {
		payloads[i] = application.SyncPayloadDTO{
			EntityType: c.EntityType,
			EntityID:   parseUUID(c.EntityId),
			Operation:  protoToOperation(c.Operation),
			Payload:    c.Payload,
			Version:    c.Version,
			DeviceID:   parseUUID(c.DeviceId),
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

func parseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

func mapError(err error) error {
	return status.Errorf(codes.Internal, "sync service error: %v", err)
}
