package application

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
	"github.com/yucai/server/internal/sqltx"
)

// Service orchestrates backup operations.
type Service struct {
	repo           domain.BackupRepository
	settingsRepo   domain.BackupSettingsRepository
	cloudProviders map[domain.BackupProvider]CloudProvider
	ports          []domain.TenantDataPort
	db             *sql.DB // shared pool; CreateBackup opens the snapshot tx on it (D5)
	dialect        string  // ent dialect string ("postgres" prod / "sqlite3" tests) for sqltx placeholder style

	freeze *RestoreFreeze
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
// settingsRepo persists per-tenant cloud/auto-backup preferences.
//
// db + dialect back CreateBackup's snapshot transaction (D5): the Export loop
// runs inside one REPEATABLE READ + ReadOnly tx opened on db, and dialect is the
// ent dialect string forwarded to sqltx so builders emit the right placeholders.
func NewService(repo domain.BackupRepository, settingsRepo domain.BackupSettingsRepository, cloudProviders map[domain.BackupProvider]CloudProvider, ports []domain.TenantDataPort, db *sql.DB, dialect string, freeze *RestoreFreeze) *Service {
	return &Service{repo: repo, settingsRepo: settingsRepo, cloudProviders: cloudProviders, ports: ports, db: db, dialect: dialect, freeze: freeze}
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

	// 1. Aggregate each module's Export → envelope. The whole Export loop runs
	// inside ONE REPEATABLE READ + ReadOnly transaction so every module shares
	// the same DB snapshot — a concurrent writer can no longer tear the backup
	// (account=T1, transaction=T2). The tx propagates to each repo's
	// FindAllForBackup via context (sqltx.DriverFrom); Export's signature is
	// unchanged. File IO (marshal/compress/encrypt/upload/save below) runs
	// OUTSIDE the tx — the tx only guards DB read consistency. Any Export error
	// returns from fn → WithTx rolls back (no partial snapshot); FR-3 atomicity.
	envelope := domain.BackupEnvelope{
		Version:   1,
		TenantID:  tenantID,
		CreatedAt: time.Now(),
		Modules:   map[string]json.RawMessage{},
	}
	if err := sqltx.WithTx(ctx, s.db, s.dialect, &sql.TxOptions{
		Isolation: sql.LevelRepeatableRead,
		ReadOnly:  true,
	}, func(ctxT context.Context) error {
		for _, p := range s.ports {
			raw, err := p.Export(ctxT, tenantID)
			if err != nil {
				return fmt.Errorf("export %s: %w", p.Name(), err)
			}
			envelope.Modules[p.Name()] = raw
		}
		return nil
	}); err != nil {
		return nil, err
	}
	data, err := json.Marshal(envelope)
	if err != nil {
		return nil, fmt.Errorf("marshal envelope: %w", err)
	}

	// gzip 压缩(encrypt 内层,checksum 仍对最外层密文)。
	if data, err = domain.Compress(data); err != nil {
		return nil, fmt.Errorf("compress backup: %w", err)
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
	if encrypted && !auto {
		// D13/D19b-alternative: audit-trail warning — an encrypted backup's
		// password is the ONLY recovery path (no DEK, no recovery code).
		slog.Info("encrypted backup created",
			"tenant_id", tenantID.String(),
			"backup_id", backup.ID.String(),
			"operation", "EncryptedBackupCreated",
			"warning", "password loss is unrecoverable")
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
// Before purging, auto-creates a pre-restore safety backup (encrypted with
// the SAME password the user just supplied when restoring an encrypted
// backup — D13 layering; plaintext restores keep a plaintext safety, the
// user's own existing choice (spec FR-1-B),
// Auto=true → client shows「自动」badge); on success it is removed, on
// failure/crash it remains so the user can recover the pre-restore state.
// Pragmatic substitute for cross-module DB atomicity (each module has its own
// ent client/driver; shared *sql.Tx would need architecture-wide refactor).
func (s *Service) RestoreBackup(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
	// D12 freeze for the WHOLE restore (download + tx + import) — user
	// writes and scheduler ticks for this tenant see "restore in progress".
	release := s.freeze.Acquire(tenantID)
	defer release()

	// 1. Safety net: auto-create a pre-restore backup BEFORE touching any data.
//    (Defense split: the tx below guarantees ATOMICITY against failures;
//    this safety backup guards HUMAN errors — restoring the wrong file or
//    garbage data — which a rollback cannot prevent.)
	preRestore, err := s.CreateBackup(ctx, tenantID, password != "", password, true)
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

// UploadExternal imports an externally-produced BackupEnvelope (R6 offline
// first: one-way guest -> server migration on account binding). It reuses
// the hardened purge+import path with a pre-upload safety backup, mirroring
// RestoreBackup's shape. The envelope's TenantID is OVERRIDDEN by the
// authenticated tenant (anti cross-tenant injection); password is reserved
// for the encrypted-archive future (empty = plaintext envelope).
func (s *Service) UploadExternal(ctx context.Context, tenantID uuid.UUID, data []byte, password string) error {
	// D12 freeze (same whole-operation window as RestoreBackup).
	release := s.freeze.Acquire(tenantID)
	defer release()

	// 1. Safety net: even though binding targets an empty account, keep the
	// pre-import backup as defense in depth (same contract as restore).
	preUpload, err := s.CreateBackup(ctx, tenantID, false, "", true)
	if err != nil {
		return fmt.Errorf("pre-upload safety backup: %w", err)
	}

	importErr := s.uploadImport(ctx, tenantID, data)

	if importErr == nil {
		if delErr := s.DeleteBackup(ctx, tenantID, preUpload.ID); delErr != nil {
			slog.Error("pre-upload safety cleanup failed", "backup_id", preUpload.ID, "err", delErr)
		}
	}
	return importErr
}

// uploadImport parses the envelope and runs the purge+import loops (the
// shared tail of restoreNoSafety, minus the backup-storage download path).
func (s *Service) uploadImport(ctx context.Context, tenantID uuid.UUID, data []byte) error {
	var envelope domain.BackupEnvelope
	if err := json.Unmarshal(data, &envelope); err != nil {
		return fmt.Errorf("unmarshal envelope: %w", err)
	}
	if envelope.Version != 1 {
		return domain.ErrBackupFormatOutdated
	}
	// Authenticated tenant always wins — a client-crafted tenant_id never
	// reaches the import layer.
	envelope.TenantID = tenantID

	return s.purgeAndImport(ctx, tenantID, envelope)
}

// purgeAndImport runs the purge + import loops inside ONE cross-module
// transaction (D6 atomicity): any module failure rolls the whole restore
// back — purge can no longer become a fait accompli. Read Committed is
// sufficient: atomicity comes from rollback, not snapshot isolation (the
// concurrent-write freeze is D12, feature C). Shared by restoreNoSafety and
// uploadImport (R6 feature G rides the same guarantee).
func (s *Service) purgeAndImport(ctx context.Context, tenantID uuid.UUID, envelope domain.BackupEnvelope) error {
	return sqltx.WithTx(ctx, s.db, s.dialect, &sql.TxOptions{
		Isolation: sql.LevelReadCommitted,
	}, func(ctxT context.Context) error {
		for _, p := range s.orderedPortsForPurge() {
			if err := p.Purge(ctxT, tenantID); err != nil {
				return fmt.Errorf("purge %s: %w", p.Name(), err)
			}
		}
		for _, p := range s.orderedPortsForImport() {
			raw, ok := envelope.Modules[p.Name()]
			if !ok {
				continue
			}
			if err := p.Import(ctxT, tenantID, raw); err != nil {
				return fmt.Errorf("import %s: %w", p.Name(), err)
			}
		}
		return nil
	})
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

	// 校验密文完整性(防传输/存储损坏 + 静默篡改)。checksum 创建时对加密后
	// 数据算,此处对下载的密文算 sha256 比对;空 checksum = 数据不完整。
	got := sha256.Sum256(data)
	if backup.Checksum == "" || fmt.Sprintf("%x", got) != backup.Checksum {
		return domain.ErrChecksumMismatch
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

	// gunzip(encrypt 内层,decrypt 后;旧格式 → ErrBackupFormatOutdated)。
	if data, err = domain.Decompress(data); err != nil {
		return err
	}

	// Deserialize envelope.
	var envelope domain.BackupEnvelope
	if err := json.Unmarshal(data, &envelope); err != nil {
		return fmt.Errorf("unmarshal envelope: %w", err)
	}

	// Purge + import inside one cross-module tx (D6): dependents-first
	// purge, account-first import, atomic on failure. The download/decrypt/
	// decompress/unmarshal above stays outside the tx (no DB surface).
	return s.purgeAndImport(ctx, tenantID, envelope)
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

// CloudSettings represents per-tenant auto-backup configuration. Despite the
// legacy "Cloud" name (kept to minimize churn), only auto-backup fields remain
// after cloud-backup removal (2026-07-25).
type CloudSettings struct {
	TenantID                uuid.UUID
	AutoBackup              bool
	AutoBackupIntervalHours int32
}

// SaveCloudSettings persists the auto-backup portion of the cloud settings for
// a tenant (upsert by tenant). Provider/credential fields are still deferred —
// only AutoBackup + AutoBackupIntervalHours are stored today.
func (s *Service) SaveCloudSettings(ctx context.Context, settings CloudSettings) error {
	return s.settingsRepo.Save(ctx, &domain.BackupSettings{
		TenantID:                settings.TenantID,
		AutoBackup:              settings.AutoBackup,
		AutoBackupIntervalHours: settings.AutoBackupIntervalHours,
	})
}

// GetCloudSettings retrieves cloud settings for a tenant. When no row exists
// yet (tenant never configured), returns a zero-valued CloudSettings seeded
// with the tenant ID — callers see defaults (AutoBackup=false, 24h interval).
func (s *Service) GetCloudSettings(ctx context.Context, tenantID uuid.UUID) (*CloudSettings, error) {
	stored, err := s.settingsRepo.GetByTenant(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("load cloud settings: %w", err)
	}
	if stored == nil {
		return &CloudSettings{TenantID: tenantID}, nil
	}
	return &CloudSettings{
		TenantID:                tenantID,
		AutoBackup:              stored.AutoBackup,
		AutoBackupIntervalHours: stored.AutoBackupIntervalHours,
	}, nil
}

// AutoBackupSettings reads a tenant's auto-backup config for the scheduler
// (scheduler.AutoBackupSource port). It wraps BackupSettingsRepository.
// GetByTenant and applies scheduler-safe defaults: an unconfigured tenant
// (no settings row) reports auto=false with a 1h interval, and any configured
// interval below 1h is clamped up to 1h so the scheduler never hot-loops
// (Task 3 concern 3). *Service thus satisfies scheduler.AutoBackupSource
// structurally alongside scheduler.BackupCreator (CreateBackup).
func (s *Service) AutoBackupSettings(ctx context.Context, tenantID uuid.UUID) (bool, int32, error) {
	settings, err := s.settingsRepo.GetByTenant(ctx, tenantID)
	if err != nil {
		return false, 0, err
	}
	if settings == nil {
		// Unconfigured → auto off, 1h default (scheduler treats this as "skip").
		return false, 1, nil
	}
	interval := settings.AutoBackupIntervalHours
	if interval < 1 {
		// Enforce min 1h: a misconfigured sub-hour interval must not spin the
		// scheduler faster than the 1h prod tick cadence.
		interval = 1
	}
	return settings.AutoBackup, interval, nil
}
