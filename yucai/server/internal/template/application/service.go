package application

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
)

// Service orchestrates template operations.
type Service struct {
	repo     domain.TemplateRepository
	recorder domain.TransactionRecorder
}

// NewService creates a new template application service. recorder is the
// TransactionRecorder port (implemented by transaction/application's adapter,
// wire-injected); it may be nil only during bootstrap before the adapter is
// wired (Task 5 fills the real adapter). RecordTransaction panics if recorder
// is nil — CRUD methods are unaffected.
func NewService(repo domain.TemplateRepository, recorder domain.TransactionRecorder) *Service {
	return &Service{repo: repo, recorder: recorder}
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

// RecordResult is the outcome of recording a transaction from a template.
type RecordResult struct {
	TransactionID uuid.UUID
	NextDate      time.Time
}

// RecordTransaction instantiates a template as a double-entry transaction via
// the TransactionRecorder port, then advances the template's NextDate and
// records the new transaction's ID on LastTransactionID.
//
// Flow: load template → reject if Paused → build RecordRequest from the
// template's direction/amount/accounts/category with Date=NextDate →
// recorder.Record → set LastTransactionID + AdvanceNextDate → repo.Update.
// The port keeps template from importing the transaction module (mirrors the
// backup TenantDataPort cross-module pattern).
func (s *Service) RecordTransaction(ctx context.Context, tenantID, templateID uuid.UUID) (*RecordResult, error) {
	if s.recorder == nil {
		return nil, fmt.Errorf("record transaction: recorder not configured")
	}

	tmpl, err := s.repo.FindByID(ctx, tenantID, templateID)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}

	if tmpl.Paused {
		return nil, domain.ErrTemplatePaused
	}

	req := domain.RecordRequest{
		Direction:          tmpl.Direction,
		AmountCents:        tmpl.AmountCents,
		SourceAccountID:    tmpl.SourceAccountID,
		DestinationAccount: tmpl.DestinationAccountID,
		Category:           tmpl.Category,
		Date:               tmpl.NextDate,
	}

	txnID, err := s.recorder.Record(ctx, tenantID, req)
	if err != nil {
		return nil, fmt.Errorf("record transaction: %w", err)
	}

	tmpl.LastTransactionID = &txnID
	tmpl.NextDate = domain.AdvanceNextDate(tmpl.NextDate, tmpl.Cycle, tmpl.CycleDays)
	tmpl.UpdatedAt = time.Now()

	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template after record: %w", err)
	}

	return &RecordResult{TransactionID: txnID, NextDate: tmpl.NextDate}, nil
}
