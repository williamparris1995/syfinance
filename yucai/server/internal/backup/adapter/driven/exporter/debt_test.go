package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	debtDomain "github.com/yucai/server/internal/debt/domain"
)

// fakeDebtRepoExporter is an in-memory DebtRepository port for exporter tests.
// Named distinctly from the debt grpc-test fakeDebtRepo to avoid collisions
// (different package regardless). FindAllForBackup returns a non-nil empty slice
// for an empty tenant so the exported JSON is "[]" (matching the real repo).
type fakeDebtRepoExporter struct {
	data        map[uuid.UUID][]debtDomain.DebtDetails
	findAllErr  error
	saveErr     error
	deleteErr   error
	lastSaved   *debtDomain.DebtDetails
	deleteCalls int
}

func newFakeDebtRepoExporter() *fakeDebtRepoExporter {
	return &fakeDebtRepoExporter{data: map[uuid.UUID][]debtDomain.DebtDetails{}}
}

func (f *fakeDebtRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]debtDomain.DebtDetails, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []debtDomain.DebtDetails{}
	}
	return out, nil
}
func (f *fakeDebtRepoExporter) Save(_ context.Context, d *debtDomain.DebtDetails) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	c := *d
	f.data[c.TenantID] = append(f.data[c.TenantID], c)
	f.lastSaved = &c
	return nil
}
func (f *fakeDebtRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestDebt builds a DebtDetails literal with two schedule entries so the
// roundtrip test has a realistic graph (header + nested schedule).
func newTestDebt(tenantID uuid.UUID, counterparty string) debtDomain.DebtDetails {
	debtID := uuid.New()
	return debtDomain.DebtDetails{
		ID:                  debtID,
		TenantID:            tenantID,
		AccountID:           uuid.New(),
		Counterparty:        counterparty,
		InterestRate:        0.05,
		AmortizationMethod:  debtDomain.AmortizationLumpSum,
		StartDate:           testDate,
		DueDate:             testDate.AddDate(0, 6, 0),
		TotalPrincipalCents: 1000000,
		DebtType:            debtDomain.BorrowedIn,
		Schedule: []debtDomain.PaymentScheduleEntry{
			{ID: uuid.New(), DebtID: debtID, PaymentDate: testDate, PrincipalCents: 500000, InterestCents: 10000, TotalCents: 510000},
			{ID: uuid.New(), DebtID: debtID, PaymentDate: testDate.AddDate(0, 6, 0), PrincipalCents: 500000, InterestCents: 5000, TotalCents: 505000},
		},
		Version: 1,
	}
}

// TestDebtExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestDebtExporter_Name(t *testing.T) {
	e := NewDebtExporter(newFakeDebtRepoExporter())
	if got := e.Name(); got != "debt" {
		t.Fatalf("Name = %q, want \"debt\"", got)
	}
}

// TestDebtExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same debts (including nested schedules).
func TestDebtExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeDebtRepoExporter()

	d1 := newTestDebt(tenantID, "Bank A")
	d2 := newTestDebt(tenantID, "Lender B")
	_ = repo.Save(context.Background(), &d1)
	_ = repo.Save(context.Background(), &d2)

	e := NewDebtExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []debtDomain.DebtDetails
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d debts, want 2", len(exported))
	}
	for _, d := range exported {
		if len(d.Schedule) != 2 {
			t.Fatalf("debt %s has %d schedule entries, want 2", d.ID, len(d.Schedule))
		}
	}

	if err := e.Purge(context.Background(), tenantID); err != nil {
		t.Fatalf("Purge: %v", err)
	}
	if got := len(repo.data[tenantID]); got != 0 {
		t.Fatalf("after Purge repo has %d, want 0", got)
	}

	if err := e.Import(context.Background(), tenantID, raw); err != nil {
		t.Fatalf("Import: %v", err)
	}
	if got := len(repo.data[tenantID]); got != len(exported) {
		t.Fatalf("after Import repo has %d, want %d", got, len(exported))
	}
	for _, d := range repo.data[tenantID] {
		if len(d.Schedule) != 2 {
			t.Fatalf("restored debt %s has %d schedule entries, want 2", d.ID, len(d.Schedule))
		}
	}
}

// TestDebtExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record.
func TestDebtExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeDebtRepoExporter()
	d := newTestDebt(srcTenant, "Bank A")
	_ = repo.Save(context.Background(), &d)

	e := NewDebtExporter(repo)
	raw, err := e.Export(context.Background(), srcTenant)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}

	dstTenant := uuid.New()
	if err := e.Import(context.Background(), dstTenant, raw); err != nil {
		t.Fatalf("Import: %v", err)
	}
	for _, got := range repo.data[dstTenant] {
		if got.TenantID != dstTenant {
			t.Fatalf("imported debt TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestDebtExporter_Export_EmptyTenant verifies Export on a tenant with no debts
// returns a valid empty JSON array, not null.
func TestDebtExporter_Export_EmptyTenant(t *testing.T) {
	e := NewDebtExporter(newFakeDebtRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestDebtExporter_Export_Error verifies Export propagates a FindAllForBackup
// error (error-path coverage).
func TestDebtExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeDebtRepoExporter()
	repo.findAllErr = injected
	e := NewDebtExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestDebtExporter_Import_SaveError verifies Import propagates a Save error
// (error-path coverage).
func TestDebtExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeDebtRepoExporter()
	d := newTestDebt(tenantID, "x")
	_ = repo.Save(context.Background(), &d)
	e := NewDebtExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestDebtExporter_Purge_Error verifies Purge propagates a DeleteByTenant error
// (error-path coverage).
func TestDebtExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeDebtRepoExporter()
	repo.deleteErr = injected
	e := NewDebtExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
