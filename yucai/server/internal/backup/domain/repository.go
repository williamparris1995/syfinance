package domain

import (
	"context"

	"github.com/google/uuid"
)

type PageRequest = struct {
	PageSize  int32
	PageToken string
}

type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

type BackupRepository interface {
	Save(ctx context.Context, backup *Backup) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Backup, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, provider *BackupProvider, page PageRequest) (*PaginatedResult[Backup], error)
	// FindByAuto returns ALL backups of a tenant carrying the given auto flag,
	// ordered by CreatedAt ascending (oldest first). The retention policy needs
	// this deterministic oldest-first enumeration — the paginated FindAll is
	// ID-cursor based and carries no time ordering, so it cannot express
	// "oldest beyond the keep window".
	FindByAuto(ctx context.Context, tenantID uuid.UUID, auto bool) ([]Backup, error)
	Update(ctx context.Context, backup *Backup) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
