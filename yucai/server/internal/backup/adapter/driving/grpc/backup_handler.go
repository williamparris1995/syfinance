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
		Provider:                protoToProvider(req.Settings.Provider),
		WebDAVURL:               req.Settings.WebdavUrl,
		WebDAVUsername:          req.Settings.WebdavUsername,
		OAuthToken:              req.Settings.OauthToken,
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
			Provider:                providerToProto(settings.Provider),
			WebdavUrl:               settings.WebDAVURL,
			WebdavUsername:          settings.WebDAVUsername,
			OauthToken:              settings.OAuthToken,
			AutoBackup:              settings.AutoBackup,
			AutoBackupIntervalHours: settings.AutoBackupIntervalHours,
		},
	}, nil
}

// TestCloudConnection tests connectivity to a cloud provider.
func (h *BackupHandler) TestCloudConnection(ctx context.Context, req *pb.TestConnectionRequest) (*pb.TestConnectionResponse, error) {
	provider := protoToProvider(req.Provider)
	success, message := h.service.TestCloudConnection(ctx, provider)
	return &pb.TestConnectionResponse{Success: success, Message: message}, nil
}

// UploadToCloud uploads a backup to a cloud provider.
func (h *BackupHandler) UploadToCloud(ctx context.Context, req *pb.UploadRequest) (*pb.BackupResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	backupID := parseUUID(req.BackupId)
	if backupID == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid backup_id")
	}
	provider := protoToProvider(req.Provider)

	result, err := h.service.UploadToCloud(ctx, tenantID, backupID, provider)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BackupResponse{Backup: dtoToProto(*result)}, nil
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
	case pb.BackupProvider_BACKUP_PROVIDER_WEBDAV:
		return domain.BackupProviderWebDAV
	case pb.BackupProvider_BACKUP_PROVIDER_DROPBOX:
		return domain.BackupProviderDropbox
	case pb.BackupProvider_BACKUP_PROVIDER_GOOGLE_DRIVE:
		return domain.BackupProviderGoogleDrive
	case pb.BackupProvider_BACKUP_PROVIDER_ONE_DRIVE:
		return domain.BackupProviderOneDrive
	default:
		return domain.BackupProvider(0)
	}
}

func providerToProto(p domain.BackupProvider) pb.BackupProvider {
	switch p {
	case domain.BackupProviderLocal:
		return pb.BackupProvider_BACKUP_PROVIDER_LOCAL
	case domain.BackupProviderWebDAV:
		return pb.BackupProvider_BACKUP_PROVIDER_WEBDAV
	case domain.BackupProviderDropbox:
		return pb.BackupProvider_BACKUP_PROVIDER_DROPBOX
	case domain.BackupProviderGoogleDrive:
		return pb.BackupProvider_BACKUP_PROVIDER_GOOGLE_DRIVE
	case domain.BackupProviderOneDrive:
		return pb.BackupProvider_BACKUP_PROVIDER_ONE_DRIVE
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
	case errors.Is(err, domain.ErrPasswordRequired),
		errors.Is(err, domain.ErrPasswordOnPlaintext),
		errors.Is(err, domain.ErrWrongPassword):
		return status.Error(codes.InvalidArgument, err.Error())
	default:
		return status.Errorf(codes.Internal, "backup service error: %v", err)
	}
}
