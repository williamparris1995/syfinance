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
	Update(ctx context.Context, backup *Backup) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
