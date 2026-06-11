package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/tag/domain"
)

// CreateTagRequest holds input for creating a tag.
type CreateTagRequest struct {
	TenantID uuid.UUID
	Name     string
	Color    string
}

// UpdateTagRequest holds input for updating a tag.
type UpdateTagRequest struct {
	TenantID uuid.UUID
	ID       uuid.UUID
	Name     string
	Color    string
	Version  int64
}

// ListTagsRequest holds input for listing tags.
type ListTagsRequest struct {
	TenantID uuid.UUID
	Search   string
	Page     domain.PageRequest
}

// TagDTO is the data transfer object.
type TagDTO struct {
	ID        uuid.UUID
	TenantID  uuid.UUID
	Name      string
	Color     string
	Version   int64
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ListTagsResult wraps paginated tag DTOs.
type ListTagsResult struct {
	Tags         []TagDTO
	NextPageToken string
	TotalCount    int32
}

// TagToDTO converts domain Tag to DTO.
func TagToDTO(t *domain.Tag) TagDTO {
	return TagDTO{
		ID:        t.ID,
		TenantID:  t.TenantID,
		Name:      t.Name,
		Color:     t.Color,
		Version:   t.Version,
		CreatedAt: t.CreatedAt,
		UpdatedAt: t.UpdatedAt,
	}
}
