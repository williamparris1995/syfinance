package domain

import (
	"context"

	"github.com/google/uuid"
)

// CategoryRepository is the port interface for category persistence.
type CategoryRepository interface {
	Save(ctx context.Context, category *Category) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Category, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, categoryType *CategoryType, search string, page PageRequest) (*PaginatedResult[Category], error)
	Update(ctx context.Context, category *Category) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}
