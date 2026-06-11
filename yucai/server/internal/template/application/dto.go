package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
)

// CreateTemplateRequest holds input for creating a template.
type CreateTemplateRequest struct {
	TenantID            uuid.UUID
	Name                string
	Description         string
	AmountCents         int64
	Direction           domain.TemplateDirection
	SourceAccountID      uuid.UUID
	DestinationAccountID *uuid.UUID
	Cycle               domain.TemplateCycle
	CycleDays           int32
	BillingDay          int32
	StartDate           time.Time
	EndDate             *time.Time
	AutoRecord          bool
	Category            string
}

// UpdateTemplateRequest holds input for updating a template.
type UpdateTemplateRequest struct {
	TenantID    uuid.UUID
	ID          uuid.UUID
	Name        string
	Description string
	AmountCents int64
	Cycle       domain.TemplateCycle
	CycleDays   int32
	EndDate     *time.Time
	AutoRecord  bool
	Version     int64
}

// ListTemplatesRequest holds input for listing templates.
type ListTemplatesRequest struct {
	TenantID uuid.UUID
	Paused   *bool
	Page     domain.PageRequest
}

// TemplateDTO is the data transfer object.
type TemplateDTO struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	Name                string
	Description         string
	AmountCents         int64
	Direction           domain.TemplateDirection
	SourceAccountID      uuid.UUID
	DestinationAccountID *uuid.UUID
	Cycle               domain.TemplateCycle
	CycleDays           int32
	BillingDay          int32
	NextDate            time.Time
	StartDate           time.Time
	EndDate             *time.Time
	AutoRecord          bool
	Paused              bool
	LastTransactionID   *uuid.UUID
	Category            string
	Version             int64
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// ListTemplatesResult wraps paginated template DTOs.
type ListTemplatesResult struct {
	Templates    []TemplateDTO
	NextPageToken string
	TotalCount    int32
}

// TemplateToDTO converts domain TransactionTemplate to DTO.
func TemplateToDTO(t *domain.TransactionTemplate) TemplateDTO {
	return TemplateDTO{
		ID:                  t.ID,
		TenantID:            t.TenantID,
		Name:                t.Name,
		Description:         t.Description,
		AmountCents:         t.AmountCents,
		Direction:           t.Direction,
		SourceAccountID:      t.SourceAccountID,
		DestinationAccountID: t.DestinationAccountID,
		Cycle:               t.Cycle,
		CycleDays:           t.CycleDays,
		BillingDay:          t.BillingDay,
		NextDate:            t.NextDate,
		StartDate:           t.StartDate,
		EndDate:             t.EndDate,
		AutoRecord:          t.AutoRecord,
		Paused:              t.Paused,
		LastTransactionID:   t.LastTransactionID,
		Category:            t.Category,
		Version:             t.Version,
		CreatedAt:           t.CreatedAt,
		UpdatedAt:           t.UpdatedAt,
	}
}
