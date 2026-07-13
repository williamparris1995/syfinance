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
	// FindAllForBackup returns every non-soft-deleted tag for a tenant. Used by
	// backup. Soft-deleted tags are excluded (mirror account/transaction
	// semantics); the purge path hard-deletes all rows including soft-deleted.
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]Tag, error)
	// DeleteByTenant hard-deletes every tag for a tenant (including soft-deleted
	// rows) and also removes the tenant's transaction_tag junction rows pointing
	// at those tags (the junction has no tenant_id column, only tag_id, so the
	// tag IDs are collected first to scope the junction cleanup).
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}
