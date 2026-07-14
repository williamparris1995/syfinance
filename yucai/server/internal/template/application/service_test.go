package application

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
)

// fakeRecorder is a test double for domain.TransactionRecorder. It captures the
// RecordRequest and returns the configured retID (or err).
type fakeRecorder struct {
	called bool
	gotReq domain.RecordRequest
	retID  uuid.UUID
	err    error
}

func (f *fakeRecorder) Record(ctx context.Context, tenantID uuid.UUID, req domain.RecordRequest) (uuid.UUID, error) {
	f.called = true
	f.gotReq = req
	if f.err != nil {
		return uuid.Nil, f.err
	}
	return f.retID, nil
}

// fakeRepo is a minimal TemplateRepository stand-in for service-level tests.
// Only FindByID/Update are exercised by RecordTransaction; the rest return
// zero values so the interface is satisfied.
type fakeRepo struct {
	tmpl         *domain.TransactionTemplate
	findErr      error
	updateErr    error
	updateCalled bool
	updated      *domain.TransactionTemplate
}

func (r *fakeRepo) Save(ctx context.Context, tmpl *domain.TransactionTemplate) error { return nil }
func (r *fakeRepo) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.TransactionTemplate, error) {
	if r.findErr != nil {
		return nil, r.findErr
	}
	return r.tmpl, nil
}
func (r *fakeRepo) FindAll(ctx context.Context, tenantID uuid.UUID, paused *bool, page domain.PageRequest) (*domain.PaginatedResult[domain.TransactionTemplate], error) {
	return &domain.PaginatedResult[domain.TransactionTemplate]{}, nil
}
func (r *fakeRepo) FindDue(ctx context.Context, today time.Time) ([]domain.TransactionTemplate, error) {
	return nil, nil
}
func (r *fakeRepo) Update(ctx context.Context, tmpl *domain.TransactionTemplate) error {
	if r.updateErr != nil {
		return r.updateErr
	}
	r.updateCalled = true
	r.updated = tmpl
	return nil
}
func (r *fakeRepo) Delete(ctx context.Context, tenantID, id uuid.UUID) error { return nil }
func (r *fakeRepo) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.TransactionTemplate, error) {
	return nil, nil
}
func (r *fakeRepo) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error { return nil }

// newTestTemplate builds a persisted-looking template with a known NextDate.
// startDate Jan 1 + CycleMonthly/billingDay 1 → NextDate Feb 1.
func newTestTemplate(t *testing.T, direction domain.TemplateDirection, paused bool) *domain.TransactionTemplate {
	t.Helper()
	tmpl, err := domain.NewTransactionTemplate(
		uuid.New(), "Rent", 500000, direction, uuid.New(),
		domain.CycleMonthly, 1, time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("build template: %v", err)
	}
	if paused {
		tmpl.Pause()
	}
	return tmpl
}

func TestRecordTransaction_Expense_Success(t *testing.T) {
	tmpl := newTestTemplate(t, domain.DirectionExpense, false)
	categoryID := uuid.New()
	tmpl.Category = categoryID.String()

	retID := uuid.New()
	rec := &fakeRecorder{retID: retID}
	repo := &fakeRepo{tmpl: tmpl}
	svc := NewService(repo, rec)

	ctx := context.Background()
	res, err := svc.RecordTransaction(ctx, tmpl.TenantID, tmpl.ID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// recorder was called with the template's fields and Date=NextDate (Feb 1).
	if !rec.called {
		t.Fatal("recorder.Record not called")
	}
	if rec.gotReq.Direction != domain.DirectionExpense {
		t.Errorf("direction: want expense, got %v", rec.gotReq.Direction)
	}
	if rec.gotReq.AmountCents != 500000 {
		t.Errorf("amount: want 500000, got %d", rec.gotReq.AmountCents)
	}
	if rec.gotReq.SourceAccountID != tmpl.SourceAccountID {
		t.Error("source account mismatch")
	}
	if rec.gotReq.DestinationAccount != nil {
		t.Errorf("expense should have nil destination, got %v", rec.gotReq.DestinationAccount)
	}
	if rec.gotReq.Category != categoryID.String() {
		t.Errorf("category: want %s, got %s", categoryID, rec.gotReq.Category)
	}
	wantDate := time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)
	if !rec.gotReq.Date.Equal(wantDate) {
		t.Errorf("record date: want %v, got %v", wantDate, rec.gotReq.Date)
	}

	// result carries the new txn id and the advanced next date.
	if res.TransactionID != retID {
		t.Errorf("txn id: want %s, got %s", retID, res.TransactionID)
	}
	wantNext := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	if !res.NextDate.Equal(wantNext) {
		t.Errorf("next date: want %v, got %v", wantNext, res.NextDate)
	}

	// template was persisted with LastTransactionID + advanced NextDate.
	if !repo.updateCalled {
		t.Fatal("repo.Update not called")
	}
	if repo.updated.LastTransactionID == nil || *repo.updated.LastTransactionID != retID {
		t.Errorf("last txn id not set to %s", retID)
	}
	if !repo.updated.NextDate.Equal(wantNext) {
		t.Errorf("persisted next date: want %v, got %v", wantNext, repo.updated.NextDate)
	}
}

func TestRecordTransaction_Transfer_DestinationPassed(t *testing.T) {
	tmpl := newTestTemplate(t, domain.DirectionTransfer, false)
	destID := uuid.New()
	tmpl.DestinationAccountID = &destID

	rec := &fakeRecorder{retID: uuid.New()}
	repo := &fakeRepo{tmpl: tmpl}
	svc := NewService(repo, rec)

	res, err := svc.RecordTransaction(context.Background(), tmpl.TenantID, tmpl.ID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if rec.gotReq.DestinationAccount == nil || *rec.gotReq.DestinationAccount != destID {
		t.Errorf("destination: want %s, got %v", destID, rec.gotReq.DestinationAccount)
	}
	if res.TransactionID == uuid.Nil {
		t.Error("expected non-nil transaction id")
	}
}

func TestRecordTransaction_Paused_Rejected(t *testing.T) {
	tmpl := newTestTemplate(t, domain.DirectionExpense, true)
	tmpl.Category = uuid.New().String()
	originalNext := tmpl.NextDate

	rec := &fakeRecorder{retID: uuid.New()}
	repo := &fakeRepo{tmpl: tmpl}
	svc := NewService(repo, rec)

	res, err := svc.RecordTransaction(context.Background(), tmpl.TenantID, tmpl.ID)
	if !errors.Is(err, domain.ErrTemplatePaused) {
		t.Fatalf("want ErrTemplatePaused, got %v", err)
	}
	if res != nil {
		t.Errorf("want nil result on paused, got %+v", res)
	}
	if rec.called {
		t.Error("recorder must not be called for a paused template")
	}
	if repo.updateCalled {
		t.Error("repo.Update must not be called for a paused template")
	}
	if !tmpl.NextDate.Equal(originalNext) {
		t.Errorf("paused template NextDate must be unchanged: want %v, got %v", originalNext, tmpl.NextDate)
	}
}

func TestRecordTransaction_NilRecorder_Errors(t *testing.T) {
	tmpl := newTestTemplate(t, domain.DirectionExpense, false)
	repo := &fakeRepo{tmpl: tmpl}
	svc := NewService(repo, nil) // nil recorder — bootstrap state

	res, err := svc.RecordTransaction(context.Background(), tmpl.TenantID, tmpl.ID)
	if err == nil {
		t.Fatal("want error for nil recorder, got nil")
	}
	if res != nil {
		t.Errorf("want nil result, got %+v", res)
	}
}
