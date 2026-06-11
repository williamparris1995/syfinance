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
}
