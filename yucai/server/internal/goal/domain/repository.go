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

// GoalRepository defines the port for Goal persistence.
type GoalRepository interface {
	Save(ctx context.Context, goal *Goal) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Goal, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, goalType *GoalType, page PageRequest) (*PaginatedResult[Goal], error)
	Update(ctx context.Context, goal *Goal) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}

// AccountMarketValueSource reports the market value of an account's holdings
// (Σ qty × current price). Implemented by holding/application.Service
// (structural type — goal does not import holding).
type AccountMarketValueSource interface {
	GetAccountMarketValue(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error)
}
