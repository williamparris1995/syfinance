package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// PageRequest for cursor-based pagination.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// TemplateRepository defines the port for TransactionTemplate persistence.
type TemplateRepository interface {
	Save(ctx context.Context, tmpl *TransactionTemplate) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*TransactionTemplate, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, paused *bool, page PageRequest) (*PaginatedResult[TransactionTemplate], error)
	FindDue(ctx context.Context, today time.Time) ([]TransactionTemplate, error)
	Update(ctx context.Context, tmpl *TransactionTemplate) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
	// FindAllForBackup returns every template for a tenant (no pagination, no
	// soft-delete filter — templates are hard-deleted only). Used by backup.
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]TransactionTemplate, error)
	// DeleteByTenant hard-deletes every template for a tenant. Used by backup
	// purge. Templates have no child tables.
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}
