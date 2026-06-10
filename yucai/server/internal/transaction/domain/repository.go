package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// TransactionRepository defines the port for Transaction persistence.
type TransactionRepository interface {
	Save(ctx context.Context, tx *Transaction) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Transaction, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, filter TransactionFilter, page PageRequest) (*PaginatedResult[Transaction], error)
	Update(ctx context.Context, tx *Transaction) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}

// TransactionFilter holds optional query filters.
type TransactionFilter struct {
	AccountID *uuid.UUID
	DateFrom  *time.Time
	DateTo    *time.Time
}

// PageRequest for cursor-based pagination.
type PageRequest struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
