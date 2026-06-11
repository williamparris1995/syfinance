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

// DebtRepository defines the port for DebtDetails persistence.
type DebtRepository interface {
	Save(ctx context.Context, debt *DebtDetails) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*DebtDetails, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, page PageRequest) (*PaginatedResult[DebtDetails], error)
	Update(ctx context.Context, debt *DebtDetails) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
	FindUpcomingPayments(ctx context.Context, tenantID uuid.UUID, daysAhead int) ([]PaymentScheduleEntry, error)
}
