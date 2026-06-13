package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
	categoryent "github.com/yucai/server/internal/category/ent"
	"github.com/yucai/server/internal/category/ent/category"
)

// CategoryRepository implements domain.CategoryRepository.
type CategoryRepository struct {
	client *categoryent.Client
}

// NewCategoryRepository creates a new CategoryRepository.
func NewCategoryRepository(client *categoryent.Client) *CategoryRepository {
	return &CategoryRepository{client: client}
}

// Save creates a new category record.
func (r *CategoryRepository) Save(ctx context.Context, c *domain.Category) error {
	create := r.client.Category.Create().
		SetID(c.ID).SetTenantID(c.TenantID).
		SetName(c.Name).SetCategoryType(c.CategoryType.String()).
		SetIcon(c.Icon).SetColor(c.Color).
		SetIsSystem(c.IsSystem).SetSortOrder(c.SortOrder).
		SetVersion(c.Version).
		SetCreatedAt(c.CreatedAt).SetUpdatedAt(c.UpdatedAt)

	if c.ParentID != nil {
		create.SetParentID(*c.ParentID)
	}

	_, err := create.Save(ctx)
	if err != nil {
		return fmt.Errorf("create category: %w", err)
	}
	return nil
}

// FindByID retrieves a non-deleted category by ID within a tenant.
func (r *CategoryRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Category, error) {
	c, err := r.client.Category.Query().
		Where(category.TenantID(tenantID), category.ID(id), category.DeletedAtIsNil()).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find category by id: %w", err)
	}
	return toDomain(c), nil
}

// FindAll returns paginated categories with optional type filter and name search.
func (r *CategoryRepository) FindAll(ctx context.Context, tenantID uuid.UUID, categoryType *domain.CategoryType, search string, page domain.PageRequest) (*domain.PaginatedResult[domain.Category], error) {
	query := r.client.Category.Query().
		Where(category.TenantID(tenantID), category.DeletedAtIsNil())

	if categoryType != nil {
		query.Where(category.CategoryType(categoryType.String()))
	}
	if search != "" {
		query.Where(category.NameContains(search))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count categories: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(category.IDGTE(cursorID))
	}

	query.Order(categoryent.Asc(category.FieldSortOrder))

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.Category, len(results))
	for i, c := range results {
		items[i] = *toDomain(c)
	}

	return &domain.PaginatedResult[domain.Category]{
		Items:         items,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update saves changes to an existing category.
func (r *CategoryRepository) Update(ctx context.Context, c *domain.Category) error {
	_, err := r.client.Category.UpdateOneID(c.ID).
		SetName(c.Name).SetIcon(c.Icon).SetColor(c.Color).
		SetSortOrder(c.SortOrder).SetVersion(c.Version).SetUpdatedAt(c.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update category: %w", err)
	}
	return nil
}

// SoftDelete sets deleted_at on a category.
func (r *CategoryRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Category.UpdateOneID(id).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete category: %w", err)
	}
	return nil
}

func toDomain(c *categoryent.Category) *domain.Category {
	return &domain.Category{
		ID: c.ID, TenantID: c.TenantID, Name: c.Name,
		CategoryType: domain.ParseCategoryType(c.CategoryType),
		Icon: c.Icon, Color: c.Color, ParentID: c.ParentID,
		IsSystem: c.IsSystem, SortOrder: c.SortOrder,
		Version: c.Version, DeletedAt: c.DeletedAt,
		CreatedAt: c.CreatedAt, UpdatedAt: c.UpdatedAt,
	}
}
