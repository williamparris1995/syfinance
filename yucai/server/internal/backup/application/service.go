package application

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
)

// Service orchestrates backup operations.
type Service struct {
	repo           domain.BackupRepository
	cloudProviders map[domain.BackupProvider]CloudProvider
}

// CloudProvider is the port interface for cloud backup providers.
type CloudProvider interface {
	Upload(ctx context.Context, filename string, data []byte) error
	TestConnection(ctx context.Context) error
}

// NewService creates a new backup application service.
func NewService(repo domain.BackupRepository, cloudProviders map[domain.BackupProvider]CloudProvider) *Service {
	return &Service{repo: repo, cloudProviders: cloudProviders}
}

// CreateBackup creates a new backup record.
func (s *Service) CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool) (*BackupDTO, error) {
	backup, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, encrypted)
	if err != nil {
		return nil, fmt.Errorf("create backup: %w", err)
	}
	// Compute placeholder checksum and size for the new record
	// Real data serialization happens when the backup is actually written
	backup.Checksum = ""
	backup.SizeBytes = 0

	if err := s.repo.Save(ctx, backup); err != nil {
		return nil, fmt.Errorf("save backup: %w", err)
	}

	dto := BackupToDTO(backup)
	return &dto, nil
}

// FinalizeBackup computes checksum and size from serialized data.
func (s *Service) FinalizeBackup(ctx context.Context, tenantID, backupID uuid.UUID, data []byte) (*BackupDTO, error) {
	backup, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return nil, fmt.Errorf("find backup: %w", err)
	}

	// Compute SHA-256 checksum
	hash := sha256.Sum256(data)
	backup.Checksum = fmt.Sprintf("%x", hash)
	backup.SizeBytes = int64(len(data))

	if err := s.repo.Update(ctx, backup); err != nil {
		return nil, fmt.Errorf("update backup: %w", err)
	}

	dto := BackupToDTO(backup)
	return &dto, nil
}

// RestoreBackup restores data from a backup record.
func (s *Service) RestoreBackup(ctx context.Context, tenantID, backupID uuid.UUID, password string) error {
	_, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return fmt.Errorf("find backup: %w", err)
	}
	// TODO: Implement actual restore logic — deserialize backup data,
	// optionally decrypt with password, and apply to database.
	return nil
}

// ListBackups returns paginated backups for a tenant.
func (s *Service) ListBackups(ctx context.Context, tenantID uuid.UUID, provider *domain.BackupProvider, page domain.PageRequest) (*ListBackupsResult, error) {
	result, err := s.repo.FindAll(ctx, tenantID, provider, page)
	if err != nil {
		return nil, fmt.Errorf("list backups: %w", err)
	}

	dtos := make([]BackupDTO, len(result.Items))
	for i, b := range result.Items {
		dtos[i] = BackupToDTO(&b)
	}

	return &ListBackupsResult{
		Backups:       dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// DeleteBackup removes a backup record.
func (s *Service) DeleteBackup(ctx context.Context, tenantID, backupID uuid.UUID) error {
	if err := s.repo.Delete(ctx, tenantID, backupID); err != nil {
		return fmt.Errorf("delete backup: %w", err)
	}
	return nil
}

// UploadToCloud uploads a backup to the specified cloud provider.
func (s *Service) UploadToCloud(ctx context.Context, tenantID, backupID uuid.UUID, provider domain.BackupProvider) (*BackupDTO, error) {
	backup, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return nil, fmt.Errorf("find backup: %w", err)
	}

	cloudProvider, ok := s.cloudProviders[provider]
	if !ok {
		return nil, fmt.Errorf("cloud provider %s not configured", provider)
	}

	// TODO: Serialize backup data to bytes for upload
	data := []byte{}

	if err := cloudProvider.Upload(ctx, backup.Filename, data); err != nil {
		return nil, fmt.Errorf("upload to cloud: %w", err)
	}

	dto := BackupToDTO(backup)
	return &dto, nil
}

// TestCloudConnection tests connectivity to a cloud provider.
func (s *Service) TestCloudConnection(ctx context.Context, provider domain.BackupProvider) (bool, string) {
	cloudProvider, ok := s.cloudProviders[provider]
	if !ok {
		return false, fmt.Sprintf("provider %s not configured", provider)
	}

	if err := cloudProvider.TestConnection(ctx); err != nil {
		return false, err.Error()
	}
	return true, "connection successful"
}

// CloudSettings represents cloud backup configuration for a tenant.
type CloudSettings struct {
	TenantID                uuid.UUID
	Provider                domain.BackupProvider
	WebDAVURL               string
	WebDAVUsername          string
	OAuthToken              string
	AutoBackup              bool
	AutoBackupIntervalHours int32
}

// SaveCloudSettings stores cloud settings for a tenant.
func (s *Service) SaveCloudSettings(ctx context.Context, settings CloudSettings) error {
	// TODO: Persist to a backup_settings table when schema is added
	return nil
}

// GetCloudSettings retrieves cloud settings for a tenant.
func (s *Service) GetCloudSettings(ctx context.Context, tenantID uuid.UUID) (*CloudSettings, error) {
	// TODO: Read from backup_settings table when schema is added
	return &CloudSettings{TenantID: tenantID}, nil
}

// SerializeBackupData is a helper that serializes tenant data to JSON bytes.
func SerializeBackupData(data map[string]interface{}) ([]byte, error) {
	return json.Marshal(data)
}

// DeserializeBackupData restores data from JSON bytes.
func DeserializeBackupData(raw []byte) (map[string]interface{}, error) {
	var data map[string]interface{}
	if err := json.Unmarshal(raw, &data); err != nil {
		return nil, fmt.Errorf("deserialize backup: %w", err)
	}
	return data, nil
}

// FormatBackupFilename generates a timestamped filename.
func FormatBackupFilename(t time.Time, encrypted bool) string {
	suffix := ".json"
	if encrypted {
		suffix = ".enc"
	}
	return fmt.Sprintf("backup_%s%s", t.Format("20060102_150405"), suffix)
}
