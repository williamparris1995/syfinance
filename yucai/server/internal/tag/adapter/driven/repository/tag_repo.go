package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/tag/domain"
	tagent "github.com/yucai/server/internal/tag/ent"
	"github.com/yucai/server/internal/tag/ent/tag"
	"github.com/yucai/server/internal/tag/ent/transactiontag"
)

// TagRepository implements domain.TagRepository using entGo.
type TagRepository struct {
	client *tagent.Client
}

// NewTagRepository creates a new TagRepository.
func NewTagRepository(client *tagent.Client) *TagRepository {
	return &TagRepository{client: client}
}

// Save persists a new tag.
func (r *TagRepository) Save(ctx context.Context, t *domain.Tag) error {
	_, err := r.client.Tag.Create().
		SetID(t.ID).
		SetTenantID(t.TenantID).
		SetName(t.Name).
		SetColor(t.Color).
		SetVersion(t.Version).
		SetCreatedAt(t.CreatedAt).
		SetUpdatedAt(t.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save tag: %w", err)
	}
	return nil
}

// FindByID retrieves a tag by ID (excluding soft-deleted).
func (r *TagRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Tag, error) {
	t, err := r.client.Tag.Query().
		Where(
			tag.ID(id),
			tag.TenantID(tenantID),
			tag.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find tag: %w", err)
	}
	return toDomainTag(t), nil
}

// FindAll returns paginated tags with optional name search.
func (r *TagRepository) FindAll(ctx context.Context, tenantID uuid.UUID, search string, page domain.PageRequest) (*domain.PaginatedResult[domain.Tag], error) {
	query := r.client.Tag.Query().
		Where(
			tag.TenantID(tenantID),
			tag.DeletedAtIsNil(),
		)

	if search != "" {
		query.Where(tag.NameContains(search))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count tags: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(tag.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query tags: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	tags := make([]domain.Tag, len(results))
	for i, t := range results {
		tags[i] = *toDomainTag(t)
	}

	return &domain.PaginatedResult[domain.Tag]{
		Items:         tags,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a tag.
func (r *TagRepository) Update(ctx context.Context, t *domain.Tag) error {
	_, err := r.client.Tag.UpdateOneID(t.ID).
		Where(tag.Version(t.Version - 1)).
		SetName(t.Name).
		SetColor(t.Color).
		SetVersion(t.Version).
		SetUpdatedAt(t.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update tag: %w", err)
	}
	return nil
}

// SoftDelete soft-deletes a tag.
func (r *TagRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Tag.UpdateOneID(id).
		Where(tag.TenantID(tenantID)).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete tag: %w", err)
	}
	return nil
}

// AddTagToTransaction creates a tag-transaction association.
func (r *TagRepository) AddTagToTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	_, err := r.client.TransactionTag.Create().
		SetTagID(tagID).
		SetTransactionID(transactionID).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("add tag to transaction: %w", err)
	}
	return nil
}

// RemoveTagFromTransaction removes a tag-transaction association.
func (r *TagRepository) RemoveTagFromTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	_, err := r.client.TransactionTag.Delete().
		Where(
			transactiontag.TagID(tagID),
			transactiontag.TransactionID(transactionID),
		).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("remove tag from transaction: %w", err)
	}
	return nil
}

// FindByTransaction returns all tags for a transaction.
func (r *TagRepository) FindByTransaction(ctx context.Context, tenantID, transactionID uuid.UUID) ([]domain.Tag, error) {
	// Find junction entries
	junctions, err := r.client.TransactionTag.Query().
		Where(
			transactiontag.TransactionID(transactionID),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find transaction tags: %w", err)
	}

	tags := make([]domain.Tag, 0, len(junctions))
	for _, j := range junctions {
		t, err := r.client.Tag.Query().
			Where(
				tag.ID(j.TagID),
				tag.TenantID(tenantID),
				tag.DeletedAtIsNil(),
			).
			Only(ctx)
		if err != nil {
			continue // skip deleted or not found tags
		}
		tags = append(tags, *toDomainTag(t))
	}
	return tags, nil
}

func toDomainTag(t *tagent.Tag) *domain.Tag {
	return &domain.Tag{
		ID:        t.ID,
		TenantID:  t.TenantID,
		Name:      t.Name,
		Color:     t.Color,
		Version:   t.Version,
		DeletedAt: t.DeletedAt,
		CreatedAt: t.CreatedAt,
		UpdatedAt: t.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.TagRepository = (*TagRepository)(nil)

var _ = time.Time{}
