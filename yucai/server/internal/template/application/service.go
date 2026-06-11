package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
)

// Service orchestrates template operations.
type Service struct {
	repo domain.TemplateRepository
}

// NewService creates a new template application service.
func NewService(repo domain.TemplateRepository) *Service {
	return &Service{repo: repo}
}

// CreateTemplate validates and persists a new template.
func (s *Service) CreateTemplate(ctx context.Context, req CreateTemplateRequest) (*TemplateDTO, error) {
	tmpl, err := domain.NewTransactionTemplate(
		req.TenantID, req.Name, req.AmountCents,
		req.Direction, req.SourceAccountID,
		req.Cycle, req.BillingDay, req.StartDate,
	)
	if err != nil {
		return nil, fmt.Errorf("create template: %w", err)
	}

	tmpl.Description = req.Description
	tmpl.DestinationAccountID = req.DestinationAccountID
	tmpl.CycleDays = req.CycleDays
	tmpl.EndDate = req.EndDate
	tmpl.AutoRecord = req.AutoRecord
	tmpl.Category = req.Category

	if err := s.repo.Save(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("save template: %w", err)
	}

	dto := TemplateToDTO(tmpl)
	return &dto, nil
}

// GetTemplate retrieves a template by ID.
func (s *Service) GetTemplate(ctx context.Context, tenantID, id uuid.UUID) (*TemplateDTO, error) {
	tmpl, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}
	dto := TemplateToDTO(tmpl)
	return &dto, nil
}

// UpdateTemplate updates a template's mutable fields.
func (s *Service) UpdateTemplate(ctx context.Context, req UpdateTemplateRequest) (*TemplateDTO, error) {
	tmpl, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}

	if tmpl.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, tmpl.Version)
	}

	tmpl.Name = req.Name
	tmpl.Description = req.Description
	tmpl.AmountCents = req.AmountCents
	tmpl.Cycle = req.Cycle
	tmpl.CycleDays = req.CycleDays
	tmpl.EndDate = req.EndDate
	tmpl.AutoRecord = req.AutoRecord
	tmpl.IncrementVersion()

	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template: %w", err)
	}

	dto := TemplateToDTO(tmpl)
	return &dto, nil
}

// DeleteTemplate deletes a template.
func (s *Service) DeleteTemplate(ctx context.Context, tenantID, id uuid.UUID) error {
	return s.repo.Delete(ctx, tenantID, id)
}

// PauseTemplate pauses a template.
func (s *Service) PauseTemplate(ctx context.Context, tenantID, id uuid.UUID) (*TemplateDTO, error) {
	tmpl, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}
	tmpl.Pause()
	tmpl.IncrementVersion()
	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template: %w", err)
	}
	dto := TemplateToDTO(tmpl)
	return &dto, nil
}

// ResumeTemplate resumes a paused template.
func (s *Service) ResumeTemplate(ctx context.Context, tenantID, id uuid.UUID) (*TemplateDTO, error) {
	tmpl, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}
	tmpl.Resume()
	tmpl.IncrementVersion()
	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template: %w", err)
	}
	dto := TemplateToDTO(tmpl)
	return &dto, nil
}

// ListTemplates returns a paginated list of templates.
func (s *Service) ListTemplates(ctx context.Context, req ListTemplatesRequest) (*ListTemplatesResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.Paused, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list templates: %w", err)
	}
	dtos := make([]TemplateDTO, len(result.Items))
	for i, t := range result.Items {
		dtos[i] = TemplateToDTO(&t)
	}
	return &ListTemplatesResult{
		Templates:    dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}
