package domain

import (
	"context"

	"github.com/google/uuid"
)

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// CurrencyRepository is the port interface for currency persistence.
type CurrencyRepository interface {
	Save(ctx context.Context, currency *Currency) error
	FindByID(ctx context.Context, id uuid.UUID) (*Currency, error)
	FindByCode(ctx context.Context, code string) (*Currency, error)
	FindAll(ctx context.Context, activeOnly bool, page PageRequest) (*PaginatedResult[Currency], error)
	Update(ctx context.Context, currency *Currency) error
}
