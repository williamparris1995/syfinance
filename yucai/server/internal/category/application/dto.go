package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
)

// CategoryDTO is the read model for categories.
type CategoryDTO struct {
	ID           uuid.UUID
	TenantID     uuid.UUID
	Name         string
	CategoryType domain.CategoryType
	Icon         string
	Color        string
	ParentID     *uuid.UUID
	IsSystem     bool
	SortOrder    int32
	Version      int64
	CreatedAt    time.Time
}

// CreateCategoryRequest holds parameters for creating a category.
type CreateCategoryRequest struct {
	Name         string
	CategoryType domain.CategoryType
	Icon         string
	Color        string
	ParentID     *uuid.UUID
	SortOrder    int32
}

// UpdateCategoryRequest holds parameters for updating a category.
type UpdateCategoryRequest struct {
	ID        uuid.UUID
	Name      string
	Icon      string
	Color     string
	SortOrder int32
	Version   int64
}

// ListCategoriesResult holds a paginated list of categories.
type ListCategoriesResult struct {
	Categories    []CategoryDTO
	NextPageToken string
	TotalCount    int32
}

// CategoryToDTO converts a domain Category to a DTO.
func CategoryToDTO(c *domain.Category) CategoryDTO {
	return CategoryDTO{
		ID: c.ID, TenantID: c.TenantID, Name: c.Name,
		CategoryType: c.CategoryType, Icon: c.Icon, Color: c.Color,
		ParentID: c.ParentID, IsSystem: c.IsSystem,
		SortOrder: c.SortOrder, Version: c.Version,
		CreatedAt: c.CreatedAt,
	}
}
