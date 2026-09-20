package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
	backupent "github.com/yucai/server/internal/backup/ent"
	"github.com/yucai/server/internal/backup/ent/backup"
)

// BackupRepository implements domain.BackupRepository.
type BackupRepository struct {
	client *backupent.Client
}

// NewBackupRepository creates a new BackupRepository.
func NewBackupRepository(client *backupent.Client) *BackupRepository {
	return &BackupRepository{client: client}
}

// Save creates a new backup record.
func (r *BackupRepository) Save(ctx context.Context, b *domain.Backup) error {
	_, err := r.client.Backup.Create().
		SetID(b.ID).SetTenantID(b.TenantID).
		SetProvider(b.Provider.String()).
		SetFilename(b.Filename).
		SetSizeBytes(b.SizeBytes).
		SetChecksum(b.Checksum).
		SetEncrypted(b.Encrypted).
		SetAuto(b.Auto).
		SetVersion(b.Version).
		SetCreatedAt(b.CreatedAt).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("create backup: %w", err)
	}
	return nil
}

// FindByID retrieves a backup by ID within a tenant.
func (r *BackupRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Backup, error) {
	b, err := r.client.Backup.Query().
		Where(backup.TenantID(tenantID), backup.ID(id)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find backup by id: %w", err)
	}
	return toDomain(b), nil
}

// FindAll returns paginated backups for a tenant, optionally filtered by provider.
func (r *BackupRepository) FindAll(ctx context.Context, tenantID uuid.UUID, provider *domain.BackupProvider, page domain.PageRequest) (*domain.PaginatedResult[domain.Backup], error) {
	query := r.client.Backup.Query().Where(backup.TenantID(tenantID))

	if provider != nil {
		query.Where(backup.Provider(provider.String()))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count backups: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(backup.IDGTE(cursorID))
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query backups: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.Backup, len(results))
	for i, b := range results {
		items[i] = *toDomain(b)
	}

	return &domain.PaginatedResult[domain.Backup]{
		Items:         items,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// FindByAuto returns all backups for a tenant carrying the given auto flag,
// ordered by created_at ascending (oldest first) — the deterministic
// enumeration the auto-backup retention policy trims from (F40).
func (r *BackupRepository) FindByAuto(ctx context.Context, tenantID uuid.UUID, auto bool) ([]domain.Backup, error) {
	rows, err := r.client.Backup.Query().
		Where(backup.TenantID(tenantID), backup.Auto(auto)).
		Order(backup.ByCreatedAt()).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find backups by auto: %w", err)
	}
	items := make([]domain.Backup, len(rows))
	for i, b := range rows {
		items[i] = *toDomain(b)
	}
	return items, nil
}

// Update updates an existing backup record.
func (r *BackupRepository) Update(ctx context.Context, b *domain.Backup) error {
	_, err := r.client.Backup.UpdateOneID(b.ID).
		SetSizeBytes(b.SizeBytes).
		SetChecksum(b.Checksum).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update backup: %w", err)
	}
	return nil
}

// Delete removes a backup record.
func (r *BackupRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	err := r.client.Backup.DeleteOneID(id).Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete backup: %w", err)
	}
	return nil
}

func toDomain(b *backupent.Backup) *domain.Backup {
	return &domain.Backup{
		ID:         b.ID,
		TenantID:   b.TenantID,
		Provider:   domain.ParseBackupProvider(b.Provider),
		Filename:   b.Filename,
		SizeBytes:  b.SizeBytes,
		Checksum:   b.Checksum,
		Encrypted:  b.Encrypted,
		Auto:       b.Auto,
		Version:    b.Version,
		CreatedAt:  b.CreatedAt,
		UpdatedAt:  b.UpdatedAt,
	}
}
