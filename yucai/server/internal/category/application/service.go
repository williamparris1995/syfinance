package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
)

// Service orchestrates category operations.
type Service struct {
	repo domain.CategoryRepository
}

// NewService creates a new category application service.
func NewService(repo domain.CategoryRepository) *Service {
	return &Service{repo: repo}
}

// CreateCategory creates a new user-defined category.
func (s *Service) CreateCategory(ctx context.Context, tenantID uuid.UUID, req CreateCategoryRequest) (*CategoryDTO, error) {
	category, err := domain.NewCategory(tenantID, req.Name, req.CategoryType, req.Icon, req.Color, req.ParentID, req.SortOrder)
	if err != nil {
		return nil, fmt.Errorf("create category: %w", err)
	}
	if err := s.repo.Save(ctx, category); err != nil {
		return nil, fmt.Errorf("save category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// UpdateCategory updates an existing category.
func (s *Service) UpdateCategory(ctx context.Context, tenantID uuid.UUID, req UpdateCategoryRequest) (*CategoryDTO, error) {
	category, err := s.repo.FindByID(ctx, tenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("find category: %w", err)
	}
	if category.Version != req.Version {
		return nil, fmt.Errorf("version mismatch: expected %d, got %d", category.Version, req.Version)
	}
	if req.Name != "" {
		if err := category.UpdateName(req.Name); err != nil {
			return nil, fmt.Errorf("update name: %w", err)
		}
	}
	if req.Icon != "" {
		category.UpdateIcon(req.Icon)
	}
	if req.Color != "" {
		category.UpdateColor(req.Color)
	}
	category.UpdateSortOrder(req.SortOrder)

	if err := s.repo.Update(ctx, category); err != nil {
		return nil, fmt.Errorf("update category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// DeleteCategory soft-deletes a category. System categories are rejected.
func (s *Service) DeleteCategory(ctx context.Context, tenantID, id uuid.UUID) error {
	category, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return fmt.Errorf("find category: %w", err)
	}
	if err := category.SoftDelete(); err != nil {
		return fmt.Errorf("soft delete: %w", err)
	}
	if err := s.repo.SoftDelete(ctx, tenantID, id); err != nil {
		return fmt.Errorf("repo soft delete: %w", err)
	}
	return nil
}

// GetCategory retrieves a single category by ID.
func (s *Service) GetCategory(ctx context.Context, tenantID, id uuid.UUID) (*CategoryDTO, error) {
	category, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("find category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// ListCategories returns paginated categories with optional type filter and search.
func (s *Service) ListCategories(ctx context.Context, tenantID uuid.UUID, categoryType *domain.CategoryType, search string, page domain.PageRequest) (*ListCategoriesResult, error) {
	result, err := s.repo.FindAll(ctx, tenantID, categoryType, search, page)
	if err != nil {
		return nil, fmt.Errorf("list categories: %w", err)
	}
	dtos := make([]CategoryDTO, len(result.Items))
	for i, c := range result.Items {
		dtos[i] = CategoryToDTO(&c)
	}
	return &ListCategoriesResult{
		Categories:    dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}
