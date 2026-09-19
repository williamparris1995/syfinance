package application

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/shared/domain/recurrence"
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
	// logRepo backs the Task 8 autoRecord idempotency check (audit C1 +
	// D4 concurrent-tick guard). At the start of RecordTransaction's WithTx
	// fn, logRepo.Upsert tries to insert a row keyed by (tenant_id,
	// template_id, NextDate); inserted=false means the same (template, date)
	// was already recorded → autoRecord skips recorder.Record entirely,
	// preventing duplicate transactions from a concurrent scheduler tick or a
	// crash-retry against a NextDate that hasn't advanced. Nil preserves the
	// legacy non-idempotent behavior that mock-based unit tests rely on
	// (service_test.go); production wire always injects the real repo.
	logRepo domain.TemplateRecordLogRepository
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

// SetLogRepo injects the TemplateRecordLog repo used by RecordTransaction's
// idempotency check (Task 8 / audit C1 + D4 concurrent-tick guard). At the
// start of the WithTx fn, logRepo.Upsert tries to insert a row keyed by
// (tenant_id, template_id, NextDate); a UNIQUE conflict (inserted=false)
// short-circuits recorder.Record so a duplicate scheduler tick or crash-retry
// does not double-count a template. Nil preserves the legacy non-idempotent
// behavior that mock-based unit tests rely on (service_test.go); production
// wire always injects the real repo (provideTemplateRecordLogRepo).
func (s *Service) SetLogRepo(logRepo domain.TemplateRecordLogRepository) {
	s.logRepo = logRepo
}

// CreateTemplate validates and persists a new template.
func (s *Service) CreateTemplate(ctx context.Context, req CreateTemplateRequest) (*TemplateDTO, error) {
	rule := recurrence.Rule{
		Cycle:       recurrence.Cycle(req.Cycle),
		Interval:    req.Interval,
		CycleDays:   req.CycleDays,
		BillingDay:  req.BillingDay,
		WeekdayMask: req.WeekdayMask,
		MonthlyMode: req.MonthlyMode,
		Nth:         req.Nth,
	}
	tmpl, err := domain.NewTransactionTemplate(
		req.TenantID, req.Name, req.AmountCents,
		req.Direction, req.SourceAccountID,
		rule, req.StartDate,
	)
	if err != nil {
		return nil, fmt.Errorf("create template: %w", err)
	}

	tmpl.Description = req.Description
	tmpl.DestinationAccountID = req.DestinationAccountID
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

// UpdateTemplate updates a template's mutable fields. Rule fields are
// editable: when the recurrence rule changes, NextDate is recomputed as the
// first occurrence >= max(start_date, today) under the new rule (the
// template_record_log idempotency key prevents double-recording a date that
// was already recorded under the old rule).
func (s *Service) UpdateTemplate(ctx context.Context, req UpdateTemplateRequest) (*TemplateDTO, error) {
	tmpl, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}

	if tmpl.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, tmpl.Version)
	}

	// Cycle 0 = keep the current rule (legacy callers that update
	// name/amount only); a non-zero cycle replaces the whole rule.
	newRule := tmpl.Rule()
	if req.Cycle != 0 {
		newRule = recurrence.Rule{
			Cycle:       recurrence.Cycle(req.Cycle),
			Interval:    req.Interval,
			CycleDays:   req.CycleDays,
			BillingDay:  req.BillingDay,
			WeekdayMask: req.WeekdayMask,
			MonthlyMode: req.MonthlyMode,
			Nth:         req.Nth,
		}
		if err := newRule.Validate(); err != nil {
			return nil, fmt.Errorf("update template: %w", err)
		}
	}

	tmpl.Name = req.Name
	tmpl.Description = req.Description
	tmpl.AmountCents = req.AmountCents
	ruleChanged := tmpl.Rule() != newRule
	tmpl.Cycle = domain.TemplateCycle(newRule.Cycle)
	tmpl.CycleDays = newRule.CycleDays
	tmpl.BillingDay = newRule.BillingDay
	tmpl.Interval = newRule.Interval
	tmpl.WeekdayMask = newRule.WeekdayMask
	tmpl.MonthlyMode = newRule.MonthlyMode
	tmpl.Nth = newRule.Nth
	tmpl.EndDate = req.EndDate
	tmpl.AutoRecord = req.AutoRecord

	if ruleChanged {
		after := time.Now().UTC().Truncate(24 * time.Hour)
		if tmpl.StartDate.After(after) {
			after = tmpl.StartDate
		}
		// F38: first occurrence >= after on the ANCHORED series from
		// start_date (NextAfter(start) and onwards). Chaining from today
		// re-anchors the series and permanently drifts interval>1 rules
		// (rent every 3 months from Aug 1: Nov 1 became Dec 1).
		tmpl.NextDate = recurrence.FirstOnSeriesAfter(tmpl.StartDate, newRule, after)
	}

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
// audit D4 duplicate-record prevention. Task 8 additionally guards the
// concurrent-tick / crash-retry case via a template_record_log idempotency key
// (logRepo.Upsert at the start of the WithTx fn): a duplicate attempt for the
// same (tenant, template, NextDate) hits the UNIQUE conflict and is
// downgraded to a no-op before recorder.Record is ever called.
func (s *Service) RecordTransaction(ctx context.Context, tenantID, templateID uuid.UUID) (*RecordResult, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*RecordResult, error) {
		return s.autoRecord(ctx, tenantID, templateID)
	})
}

// autoRecord is the transactional-body implementation of RecordTransaction.
// It must be called inside runInTx (directly or via the RecordTransaction
// wrapper) so the idempotency-key insert (Task 8), recorder.Record (which
// delegates to transaction.Service.Simple*) and the subsequent template
// NextDate-advance repo.Update all join the surrounding transaction.
//
// Flow (Task 7 + Task 8):
//  1. load template → reject if Paused
//  2. **Task 8 idempotency check** — logRepo.Upsert at the start of the tx fn.
//     On UNIQUE(tenant_id, template_id, record_date) conflict (inserted=false),
//     the (template, NextDate) was already recorded → return nil; the empty tx
//     commits and we leave the world unchanged. On any non-constraint error
//     surface it (rolls back the whole tx). On success (inserted=true) capture
//     the logID so SetTransactionID can back-fill after recorder.Record.
//  3. build RecordRequest from the template's direction/amount/accounts/category
//     with Date=NextDate
//  4. recorder.Record (joins outer tx via sqltx.DriverFrom)
//  5. logRepo.SetTransactionID — back-fill the new txnID on the log row created
//     at step 2 (same tx, so a later failure rolls back the back-fill too)
//  6. set LastTransactionID + AdvanceNextDate → repo.Update (joins outer tx
//     via clientFor)
//
// The TransactionRecorder port keeps template from importing the transaction
// module (mirrors the backup TenantDataPort cross-module pattern).
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

	// Task 8 idempotency check: insert a log row keyed by
	// (tenant_id, template_id, record_date=NextDate) at the start of the tx
	// fn. A UNIQUE conflict means a duplicate attempt (concurrent scheduler
	// tick OR a crash-retry against a NextDate that hasn't advanced) → skip
	// recorder.Record entirely; the empty tx commits, leaving the world
	// unchanged. Nil logRepo preserves the legacy non-idempotent path that
	// mock-based unit tests rely on (service_test.go).
	var logID uuid.UUID
	if s.logRepo != nil {
		logID = uuid.New()
		inserted, err := s.logRepo.Upsert(ctx, &domain.TemplateRecordLog{
			ID:         logID,
			TenantID:   tenantID,
			TemplateID: tmpl.ID,
			RecordDate: tmpl.NextDate,
		})
		if err != nil {
			return nil, fmt.Errorf("idempotency check: %w", err)
		}
		if !inserted {
			slog.Info("autoRecord: already recorded, skip",
				"template_id", tmpl.ID,
				"record_date", tmpl.NextDate.Format("2006-01-02"),
				"operation", "TemplateAutoRecord",
			)
			return nil, nil
		}
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

	// Back-fill the new txnID on the log row created above. Same tx, so a
	// later failure (e.g. template NextDate-advance Update) rolls back the
	// back-fill too — preventing a stale transaction_id from surviving a
	// rolled-back autoRecord. Skipped when logRepo is nil (legacy test path)
	// or when no logID was created (idempotency check returned inserted=true
	// path is the only one that reaches here).
	if s.logRepo != nil {
		if err := s.logRepo.SetTransactionID(ctx, logID, txnID); err != nil {
			return nil, fmt.Errorf("back-fill log transaction_id: %w", err)
		}
	}

	tmpl.LastTransactionID = &txnID
	tmpl.NextDate = tmpl.Rule().NextAfter(tmpl.NextDate)
	tmpl.IncrementVersion()
	tmpl.UpdatedAt = time.Now()

	if err := s.repo.Update(ctx, tmpl); err != nil {
		return nil, fmt.Errorf("update template after record: %w", err)
	}

	return &RecordResult{TransactionID: txnID, NextDate: tmpl.NextDate}, nil
}
