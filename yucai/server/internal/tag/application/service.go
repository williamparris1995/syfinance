package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/tag/domain"
)

// Service orchestrates tag operations.
type Service struct {
	repo domain.TagRepository
}

// NewService creates a new tag application service.
func NewService(repo domain.TagRepository) *Service {
	return &Service{repo: repo}
}

// CreateTag validates and persists a new tag.
func (s *Service) CreateTag(ctx context.Context, req CreateTagRequest) (*TagDTO, error) {
	tag, err := domain.NewTag(req.TenantID, req.Name, req.Color)
	if err != nil {
		return nil, fmt.Errorf("create tag: %w", err)
	}

	if err := s.repo.Save(ctx, tag); err != nil {
		return nil, fmt.Errorf("save tag: %w", err)
	}

	dto := TagToDTO(tag)
	return &dto, nil
}

// UpdateTag updates a tag's name and color.
func (s *Service) UpdateTag(ctx context.Context, req UpdateTagRequest) (*TagDTO, error) {
	tag, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("tag not found: %w", err)
	}

	if tag.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, tag.Version)
	}

	if err := tag.UpdateName(req.Name); err != nil {
		return nil, err
	}
	if err := tag.UpdateColor(req.Color); err != nil {
		return nil, err
	}
	tag.IncrementVersion()

	if err := s.repo.Update(ctx, tag); err != nil {
		return nil, fmt.Errorf("update tag: %w", err)
	}

	dto := TagToDTO(tag)
	return &dto, nil
}

// DeleteTag soft-deletes a tag.
func (s *Service) DeleteTag(ctx context.Context, tenantID, id uuid.UUID) error {
	return s.repo.SoftDelete(ctx, tenantID, id)
}

// ListTags returns a paginated list of tags.
func (s *Service) ListTags(ctx context.Context, req ListTagsRequest) (*ListTagsResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.Search, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list tags: %w", err)
	}
	dtos := make([]TagDTO, len(result.Items))
	for i, t := range result.Items {
		dtos[i] = TagToDTO(&t)
	}
	return &ListTagsResult{
		Tags:          dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// AddTagToTransaction associates a tag with a transaction.
func (s *Service) AddTagToTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	return s.repo.AddTagToTransaction(ctx, tagID, transactionID)
}

// RemoveTagFromTransaction removes a tag from a transaction.
func (s *Service) RemoveTagFromTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	return s.repo.RemoveTagFromTransaction(ctx, tagID, transactionID)
}

// GetTransactionTags returns all tags for a transaction.
func (s *Service) GetTransactionTags(ctx context.Context, tenantID, transactionID uuid.UUID) (*ListTagsResult, error) {
	tags, err := s.repo.FindByTransaction(ctx, tenantID, transactionID)
	if err != nil {
		return nil, fmt.Errorf("get transaction tags: %w", err)
	}
	dtos := make([]TagDTO, len(tags))
	for i, t := range tags {
		dtos[i] = TagToDTO(&t)
	}
	return &ListTagsResult{Tags: dtos, TotalCount: int32(len(dtos))}, nil
}
