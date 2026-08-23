package grpc

import (
	"context"
	"errors"

	pb "github.com/yucai/server/internal/proto/backup/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/backup/application"
	"github.com/yucai/server/internal/backup/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// BackupHandler implements the generated BackupServiceServer interface.
type BackupHandler struct {
	pb.UnimplementedBackupServiceServer
	service *application.Service
}

// NewBackupHandler creates a new BackupHandler.
func NewBackupHandler(service *application.Service) *BackupHandler {
	return &BackupHandler{service: service}
}

// CreateBackup creates a new backup.
func (h *BackupHandler) CreateBackup(ctx context.Context, req *pb.CreateBackupRequest) (*pb.BackupResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	password := ""
	if req.Password != nil {
		password = *req.Password
	}
	result, err := h.service.CreateBackup(ctx, tenantID, req.Encrypted, password, false)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BackupResponse{Backup: dtoToProto(*result)}, nil
}

// UploadBackup imports an external envelope (R6 guest -> server migration).
func (h *BackupHandler) UploadBackup(ctx context.Context, req *pb.UploadBackupRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	if len(req.Data) == 0 {
		return nil, status.Error(codes.InvalidArgument, "empty upload data")
	}
	if err := h.service.UploadExternal(ctx, tenantID, req.Data, req.Password); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// RestoreBackup restores from a backup.
func (h *BackupHandler) RestoreBackup(ctx context.Context, req *pb.RestoreBackupRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	backupID := parseUUID(req.BackupId)
	if backupID == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid backup_id")
	}

	if err := h.service.RestoreBackup(ctx, tenantID, backupID, req.Password); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// ListBackups returns paginated backups.
func (h *BackupHandler) ListBackups(ctx context.Context, req *pb.ListBackupsRequest) (*pb.ListBackupsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	var provider *domain.BackupProvider
	if req.Provider != pb.BackupProvider_BACKUP_PROVIDER_UNSPECIFIED {
		p := protoToProvider(req.Provider)
		provider = &p
	}

	page := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListBackups(ctx, tenantID, provider, page)
	if err != nil {
		return nil, mapError(err)
	}

	backups := make([]*pb.BackupDTO, len(result.Backups))
	for i, b := range result.Backups {
		backups[i] = dtoToProto(b)
	}

	return &pb.ListBackupsResponse{
		Backups: backups,
		Page:    &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// DeleteBackup removes a backup.
func (h *BackupHandler) DeleteBackup(ctx context.Context, req *pb.DeleteBackupRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	backupID := parseUUID(req.Id)
	if backupID == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteBackup(ctx, tenantID, backupID); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// SaveCloudSettings stores cloud backup settings.
func (h *BackupHandler) SaveCloudSettings(ctx context.Context, req *pb.SaveCloudSettingsRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	if req.Settings == nil {
		return nil, status.Error(codes.InvalidArgument, "settings required")
	}

	settings := application.CloudSettings{
		TenantID:                tenantID,
		AutoBackup:              req.Settings.AutoBackup,
		AutoBackupIntervalHours: req.Settings.AutoBackupIntervalHours,
	}

	if err := h.service.SaveCloudSettings(ctx, settings); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// GetCloudSettings retrieves cloud backup settings.
func (h *BackupHandler) GetCloudSettings(ctx context.Context, _ *emptypb.Empty) (*pb.CloudSettingsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	settings, err := h.service.GetCloudSettings(ctx, tenantID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CloudSettingsResponse{
		Settings: &pb.CloudSettingsDTO{
			AutoBackup:              settings.AutoBackup,
			AutoBackupIntervalHours: settings.AutoBackupIntervalHours,
		},
	}, nil
}

// --- Helpers ---

func dtoToProto(b application.BackupDTO) *pb.BackupDTO {
	return &pb.BackupDTO{
		Id:        b.ID.String(),
		Provider:  providerToProto(b.Provider),
		Filename:  b.Filename,
		SizeBytes: b.SizeBytes,
		Checksum:  b.Checksum,
		Encrypted: b.Encrypted,
		Auto:      b.Auto,
		CreatedAt: timestamppb.New(b.CreatedAt),
	}
}

func protoToProvider(p pb.BackupProvider) domain.BackupProvider {
	switch p {
	case pb.BackupProvider_BACKUP_PROVIDER_LOCAL:
		return domain.BackupProviderLocal
	default:
		return domain.BackupProvider(0)
	}
}

func providerToProto(p domain.BackupProvider) pb.BackupProvider {
	switch p {
	case domain.BackupProviderLocal:
		return pb.BackupProvider_BACKUP_PROVIDER_LOCAL
	default:
		return pb.BackupProvider_BACKUP_PROVIDER_UNSPECIFIED
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
	switch {
	case errors.Is(err, domain.ErrChecksumMismatch),
		errors.Is(err, domain.ErrBackupFormatOutdated):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, domain.ErrPasswordRequired),
		errors.Is(err, domain.ErrPasswordOnPlaintext),
		errors.Is(err, domain.ErrWrongPassword):
		return status.Error(codes.InvalidArgument, err.Error())
	default:
		return status.Errorf(codes.Internal, "backup service error: %v", err)
	}
}
