package application

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
)

// Service orchestrates backup operations.
type Service struct {
	repo           domain.BackupRepository
	cloudProviders map[domain.BackupProvider]CloudProvider
	ports          []domain.TenantDataPort
}

// CloudProvider is the port interface for cloud backup providers.
type CloudProvider interface {
	Upload(ctx context.Context, filename string, data []byte) error
	Download(ctx context.Context, filename string) ([]byte, error)
	Delete(ctx context.Context, filename string) error
	TestConnection(ctx context.Context) error
}

// NewService creates a new backup application service. ports is the ordered list
// of tenant data ports (exporters) aggregated into each backup; nil/empty means
// CreateBackup produces an envelope with no modules (wired in Task 10).
func NewService(repo domain.BackupRepository, cloudProviders map[domain.BackupProvider]CloudProvider, ports []domain.TenantDataPort) *Service {
	return &Service{repo: repo, cloudProviders: cloudProviders, ports: ports}
}

// CreateBackup serializes tenant data → optionally encrypts → Upload →
// Finalize (sha256/size) → Save.
func (s *Service) CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*BackupDTO, error) {
	if encrypted && password == "" {
		return nil, domain.ErrPasswordRequired
	}
	if !encrypted && password != "" {
		return nil, domain.ErrPasswordOnPlaintext
	}

	// 1. Aggregate each module's Export → envelope.
	envelope := domain.BackupEnvelope{
		Version:   1,
		TenantID:  tenantID,
		CreatedAt: time.Now(),
		Modules:   map[string]json.RawMessage{},
	}
	for _, p := range s.ports {
		raw, err := p.Export(ctx, tenantID)
		if err != nil {
			return nil, fmt.Errorf("export %s: %w", p.Name(), err)
		}
		envelope.Modules[p.Name()] = raw
	}
	data, err := json.Marshal(envelope)
	if err != nil {
		return nil, fmt.Errorf("marshal envelope: %w", err)
	}

	// 2. Optional encryption.
	if encrypted {
		data, err = domain.Encrypt(data, password)
		if err != nil {
			return nil, fmt.Errorf("encrypt backup: %w", err)
		}
	}

	// 3. Backup record + Upload + Finalize (checksum/size inline).
	backup, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, encrypted, auto)
	if err != nil {
		return nil, fmt.Errorf("create backup: %w", err)
	}
	provider, ok := s.cloudProviders[domain.BackupProviderLocal]
	if !ok {
		return nil, fmt.Errorf("local provider not configured")
	}
	if err := provider.Upload(ctx, backup.Filename, data); err != nil {
		return nil, fmt.Errorf("upload backup: %w", err)
	}
	hash := sha256.Sum256(data)
	backup.Checksum = fmt.Sprintf("%x", hash)
	backup.SizeBytes = int64(len(data))

	if err := s.repo.Save(ctx, backup); err != nil {
		return nil, fmt.Errorf("save backup: %w", err)
	}

	dto := BackupToDTO(backup)
	return &dto, nil
}

// RestoreBackup downloads → decrypts → per-module Purge + Import.
// Before purging, auto-creates a pre-restore safety backup (unencrypted,
// Auto=true → client shows「自动」badge); on success it is removed, on
// failure/crash it remains so the user can recover the pre-restore state.
// Pragmatic substitute for cross-module DB atomicity (each module has its own
// ent client/driver; shared *sql.Tx would need architecture-wide refactor).
func (s *Service) RestoreBackup(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
	// 1. Safety net: auto-create a pre-restore backup BEFORE touching any data.
	preRestore, err := s.CreateBackup(ctx, tenantID, false, "", true)
	if err != nil {
		return fmt.Errorf("pre-restore safety backup: %w", err)
	}

	// 2. Restore (download/decrypt/purge/import — the original logic).
	restoreErr := s.restoreNoSafety(ctx, tenantID, backupID, password)

	// 3. On success, remove the safety net (best-effort). On failure, leave it.
	if restoreErr == nil {
		if delErr := s.DeleteBackup(ctx, tenantID, preRestore.ID); delErr != nil {
			slog.Error("pre-restore safety cleanup failed", "backup_id", preRestore.ID, "err", delErr)
		}
	}
	return restoreErr
}

// restoreNoSafety holds the pre-safety-net restore logic (download/decrypt/
// purge/import). Extracted from RestoreBackup so the safety net can wrap it.
func (s *Service) restoreNoSafety(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
	backup, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return fmt.Errorf("find backup: %w", err)
	}
	provider, ok := s.cloudProviders[domain.BackupProviderLocal]
	if !ok {
		return fmt.Errorf("local provider not configured")
	}
	data, err := provider.Download(ctx, backup.Filename)
	if err != nil {
		return fmt.Errorf("download backup: %w", err)
	}

	// Decrypt if encrypted.
	if backup.Encrypted {
		if password == "" {
			return domain.ErrPasswordRequired
		}
		data, err = domain.Decrypt(data, password)
		if err != nil {
			return err // ErrWrongPassword
		}
	} else if domain.IsEncrypted(data) {
		return domain.ErrWrongPassword // plaintext backup but file carries magic — anomalous
	}

	// Deserialize envelope.
	var envelope domain.BackupEnvelope
	if err := json.Unmarshal(data, &envelope); err != nil {
		return fmt.Errorf("unmarshal envelope: %w", err)
	}

	// Purge (dependents first, account last).
	for _, p := range s.orderedPortsForPurge() {
		if err := p.Purge(ctx, tenantID); err != nil {
			return fmt.Errorf("purge %s: %w", p.Name(), err)
		}
	}
	// Import (account first, then dependents).
	for _, p := range s.orderedPortsForImport() {
		raw, ok := envelope.Modules[p.Name()]
		if !ok {
			continue // older backup may lack this module
		}
		if err := p.Import(ctx, tenantID, raw); err != nil {
			return fmt.Errorf("import %s: %w", p.Name(), err)
		}
	}
	return nil
}

// orderedPortsForPurge returns ports in dependency order (account last).
func (s *Service) orderedPortsForPurge() []domain.TenantDataPort {
	var rest []domain.TenantDataPort
	var account domain.TenantDataPort
	for _, p := range s.ports {
		if p.Name() == "account" {
			account = p
		} else {
			rest = append(rest, p)
		}
	}
	if account != nil {
		rest = append(rest, account)
	}
	return rest
}

// orderedPortsForImport returns ports in dependency order (account first).
func (s *Service) orderedPortsForImport() []domain.TenantDataPort {
	var account domain.TenantDataPort
	var rest []domain.TenantDataPort
	for _, p := range s.ports {
		if p.Name() == "account" {
			account = p
		} else {
			rest = append(rest, p)
		}
	}
	if account != nil {
		return append([]domain.TenantDataPort{account}, rest...)
	}
	return rest
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

// DeleteBackup removes the backup file + metadata.
func (s *Service) DeleteBackup(ctx context.Context, tenantID, backupID uuid.UUID) error {
	backup, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return fmt.Errorf("find backup: %w", err)
	}
	provider, ok := s.cloudProviders[domain.BackupProviderLocal]
	if !ok {
		return fmt.Errorf("local provider not configured")
	}
	if err := provider.Delete(ctx, backup.Filename); err != nil {
		return fmt.Errorf("delete backup file: %w", err)
	}
	if err := s.repo.Delete(ctx, tenantID, backupID); err != nil {
		return fmt.Errorf("delete backup record: %w", err)
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
