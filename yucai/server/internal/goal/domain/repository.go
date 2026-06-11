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
	FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, page PageRequest) (*PaginatedResult[Goal], error)
	Update(ctx context.Context, goal *Goal) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
