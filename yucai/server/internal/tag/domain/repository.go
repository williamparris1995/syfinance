package domain

import (
	"context"

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

// TagRepository defines the port for Tag persistence.
type TagRepository interface {
	Save(ctx context.Context, tag *Tag) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Tag, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, search string, page PageRequest) (*PaginatedResult[Tag], error)
	Update(ctx context.Context, tag *Tag) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
	// Tag-transaction junction
	AddTagToTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error
	RemoveTagFromTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error
	FindByTransaction(ctx context.Context, tenantID, transactionID uuid.UUID) ([]Tag, error)
}
