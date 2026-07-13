package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
)

// fakeBudgetRepoExporter is an in-memory BudgetRepository port for exporter
// tests. FindAllForBackup returns a non-nil empty slice for an empty tenant so
// the exported JSON is "[]" (matching the real repo).
type fakeBudgetRepoExporter struct {
	data        map[uuid.UUID][]domain.Budget
	findAllErr  error
	saveErr     error
	deleteErr   error
	lastSaved   *domain.Budget
	deleteCalls int
}

func newFakeBudgetRepoExporter() *fakeBudgetRepoExporter {
	return &fakeBudgetRepoExporter{data: map[uuid.UUID][]domain.Budget{}}
}

func (f *fakeBudgetRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]domain.Budget, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []domain.Budget{}
	}
	return out, nil
}
func (f *fakeBudgetRepoExporter) Save(_ context.Context, b *domain.Budget) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	c := *b
	f.data[c.TenantID] = append(f.data[c.TenantID], c)
	f.lastSaved = &c
	return nil
}
func (f *fakeBudgetRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestBudget builds a Budget literal with two items so the roundtrip test
// has a realistic graph (header + nested items).
func newTestBudget(tenantID uuid.UUID, name string) domain.Budget {
	budgetID := uuid.New()
	return domain.Budget{
		ID:               budgetID,
		TenantID:         tenantID,
		Name:             name,
		Month:            "2026-03",
		TotalAmountCents: 200000,
		CurrencyCode:     "CNY",
		IsActive:         true,
		Items: []domain.BudgetItem{
			{ID: uuid.New(), BudgetID: budgetID, AccountID: uuid.New(), PlannedAmountCents: 120000, ActualAmountCents: 50000, Notes: "food"},
			{ID: uuid.New(), BudgetID: budgetID, AccountID: uuid.New(), PlannedAmountCents: 80000, ActualAmountCents: 30000, Notes: "transport"},
		},
		Version:   1,
		CreatedAt: testDate,
		UpdatedAt: testDate,
	}
}

// TestBudgetExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestBudgetExporter_Name(t *testing.T) {
	e := NewBudgetExporter(newFakeBudgetRepoExporter())
	if got := e.Name(); got != "budget" {
		t.Fatalf("Name = %q, want \"budget\"", got)
	}
}

// TestBudgetExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same budgets (including nested items).
func TestBudgetExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeBudgetRepoExporter()

	b1 := newTestBudget(tenantID, "March")
	b2 := newTestBudget(tenantID, "April")
	b2.Month = "2026-04"
	_ = repo.Save(context.Background(), &b1)
	_ = repo.Save(context.Background(), &b2)

	e := NewBudgetExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []domain.Budget
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d budgets, want 2", len(exported))
	}
	for _, b := range exported {
		if len(b.Items) != 2 {
			t.Fatalf("budget %s has %d items, want 2", b.ID, len(b.Items))
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
	for _, b := range repo.data[tenantID] {
		if len(b.Items) != 2 {
			t.Fatalf("restored budget %s has %d items, want 2", b.ID, len(b.Items))
		}
	}
}

// TestBudgetExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record.
func TestBudgetExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeBudgetRepoExporter()
	b := newTestBudget(srcTenant, "March")
	_ = repo.Save(context.Background(), &b)

	e := NewBudgetExporter(repo)
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
			t.Fatalf("imported budget TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestBudgetExporter_Export_EmptyTenant verifies Export on a tenant with no
// budgets returns a valid empty JSON array, not null.
func TestBudgetExporter_Export_EmptyTenant(t *testing.T) {
	e := NewBudgetExporter(newFakeBudgetRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestBudgetExporter_Export_Error verifies Export propagates a FindAllForBackup
// error (error-path coverage).
func TestBudgetExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeBudgetRepoExporter()
	repo.findAllErr = injected
	e := NewBudgetExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestBudgetExporter_Import_SaveError verifies Import propagates a Save error
// (error-path coverage).
func TestBudgetExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeBudgetRepoExporter()
	b := newTestBudget(tenantID, "x")
	_ = repo.Save(context.Background(), &b)
	e := NewBudgetExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestBudgetExporter_Purge_Error verifies Purge propagates a DeleteByTenant
// error (error-path coverage).
func TestBudgetExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeBudgetRepoExporter()
	repo.deleteErr = injected
	e := NewBudgetExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
