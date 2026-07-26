package application

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/template/domain"
)

// Service orchestrates template operations.
type Service struct {
	repo     domain.TemplateRepository
	recorder domain.TransactionRecorder
	// db is the shared *sql.DB backing every ent client (Task 1's provideDB).
	// RecordTransaction wraps its recorder.Record + repo.Update sequence in a
	// single sqltx.WithTx over db so a partial failure (e.g. a template Update
	// error after the recorder has already created the transaction) rolls back
	// the whole operation (audit D4 — duplicate-record prevention). Nil is
	// accepted for backward compatibility with mock-based unit tests that do
	// not exercise transactionality; when nil, the wrapping is skipped and the
	// methods run legacy (auto-commit) semantics. Mirrors Task 5/6's
	// holding/debt Service.SetDB.
	db *sql.DB
}

// NewService creates a new template application service. recorder is the
// TransactionRecorder port (implemented by transaction/application's adapter,
// wire-injected); it may be nil only during bootstrap before the adapter is
// wired (Task 5 fills the real adapter). RecordTransaction panics if recorder
// is nil — CRUD methods are unaffected.
func NewService(repo domain.TemplateRepository, recorder domain.TransactionRecorder) *Service {
	return &Service{repo: repo, recorder: recorder}
}

// SetDB injects the shared *sql.DB backing the template ent client.
// RecordTransaction wraps its recorder.Record + repo.Update writes in a single
// sqltx.WithTx over db so a partial failure rolls back the whole operation
// (Task 7 / audit D4). Nil preserves the legacy non-transactional behavior that
// mock-based unit tests rely on; production wire always injects the shared db
// (Task 1's provideDB). Mirrors Task 5/6's holding/debt Service.SetDB.
func (s *Service) SetDB(db *sql.DB) { s.db = db }

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

// FindDueForAutoRecord returns templates due for automatic recording across all
// tenants: not paused, NextDate <= today, AND AutoRecord enabled. Wraps the
// cross-tenant repo.FindDue (which already filters paused + NextDate) and adds
// the AutoRecord policy filter in-memory (autoRecord is a scheduler-policy
// concern, not a domain-repo concern — FindDue stays usable for a future manual
// "record all due" button that should include non-auto templates). Used by the
// TemplateScheduler; safe to call multiple times per day (RecordTransaction
// advances NextDate past today, so the second call finds nothing due).
func (s *Service) FindDueForAutoRecord(ctx context.Context, today time.Time) ([]domain.TransactionTemplate, error) {
	templates, err := s.repo.FindDue(ctx, today)
	if err != nil {
		return nil, fmt.Errorf("find due templates: %w", err)
	}
	filtered := make([]domain.TransactionTemplate, 0, len(templates))
	for i := range templates {
		if templates[i].AutoRecord {
			filtered = append(filtered, templates[i])
		}
	}
	return filtered, nil
}

// RecordResult is the outcome of recording a transaction from a template.
type RecordResult struct {
	TransactionID uuid.UUID
	NextDate      time.Time
}

// runInTx wraps fn in a single sqltx.WithTx over the shared *sql.DB so the
// recorder's transaction write (delegated through transaction.Service.Simple*
// → SimpleExpense/Income/Transfer, which themselves wrap runInTx that JOINS
// this outer tx via sqltx.DriverFrom) and the template's NextDate-advance
// repo.Update join one atomic DB transaction. A failure at either step rolls
// back the whole operation (audit D4 — duplicate-record prevention: if the
// recorder succeeds but NextDate advance fails, the next scheduler tick would
// otherwise re-record the same transaction).
//
// When s.db is nil the wrapper is skipped and fn runs directly against the
// repos' default (auto-commit) clients. This preserves the legacy
// non-transactional behavior that mock-based unit tests rely on (they inject
// mock repos without a *sql.DB); production wire always injects the shared db
// from Task 1's provideDB, so the rollback guarantee holds in deployment.
//
// Join-existing-tx semantics: when ctx already carries a tx driver (an outer
// WithTx from a caller orchestrating multiple services), sqltx.WithTx runs fn
// against that outer driver without opening a new transaction — the outermost
// caller owns commit/rollback. Mirrors Task 4-6's runInTx in
// transaction/holding/debt application.
func (s *Service) runInTx(ctx context.Context, fn func(ctx context.Context) (*RecordResult, error)) (*RecordResult, error) {
	if s.db == nil {
		return fn(ctx)
	}
	var res *RecordResult
	err := sqltx.WithTx(ctx, s.db, "postgres", nil, func(ctxT context.Context) error {
		r, e := fn(ctxT)
		res = r
		return e
	})
	return res, err
}

// RecordTransaction instantiates a template as a double-entry transaction via
// the TransactionRecorder port, then advances the template's NextDate and
// records the new transaction's ID on LastTransactionID. Both writes run inside
// a single sqltx.WithTx so a partial failure (recorder succeeds but the
// template Update fails, or vice versa) rolls back the whole operation —
// audit D4 duplicate-record prevention. Task 8 will additionally guard the
// concurrent-tick case via a template_record_log idempotency key (NOT in scope
// here).
func (s *Service) RecordTransaction(ctx context.Context, tenantID, templateID uuid.UUID) (*RecordResult, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*RecordResult, error) {
		return s.autoRecord(ctx, tenantID, templateID)
	})
}

// autoRecord is the transactional-body implementation of RecordTransaction.
// It must be called inside runInTx (directly or via the RecordTransaction
// wrapper) so the recorder.Record call (which delegates to
// transaction.Service.Simple*) and the subsequent template NextDate-advance
// repo.Update both join the surrounding transaction.
//
// Flow: load template → reject if Paused → build RecordRequest from the
// template's direction/amount/accounts/category with Date=NextDate →
// recorder.Record (joins outer tx via sqltx.DriverFrom) → set
// LastTransactionID + AdvanceNextDate → repo.Update (joins outer tx via
// clientFor). The port keeps template from importing the transaction module
// (mirrors the backup TenantDataPort cross-module pattern).
func (s *Service) autoRecord(ctx context.Context, tenantID, templateID uuid.UUID) (*RecordResult, error) {
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
	tmpl.IncrementVersion()
	tmpl.UpdatedAt = time.Now()

	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template after record: %w", err)
	}

	return &RecordResult{TransactionID: txnID, NextDate: tmpl.NextDate}, nil
}
