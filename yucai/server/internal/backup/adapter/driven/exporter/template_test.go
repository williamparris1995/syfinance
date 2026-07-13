package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	templateDomain "github.com/yucai/server/internal/template/domain"
)

// fakeTemplateRepoExporter is an in-memory TemplateRepository port for exporter
// tests. FindAllForBackup returns a non-nil empty slice for an empty tenant so
// the exported JSON is "[]" (matching the real repo).
type fakeTemplateRepoExporter struct {
	data        map[uuid.UUID][]templateDomain.TransactionTemplate
	findAllErr  error
	saveErr     error
	deleteErr   error
	deleteCalls int
}

func newFakeTemplateRepoExporter() *fakeTemplateRepoExporter {
	return &fakeTemplateRepoExporter{data: map[uuid.UUID][]templateDomain.TransactionTemplate{}}
}

func (f *fakeTemplateRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]templateDomain.TransactionTemplate, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []templateDomain.TransactionTemplate{}
	}
	return out, nil
}

func (f *fakeTemplateRepoExporter) Save(_ context.Context, t *templateDomain.TransactionTemplate) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	cp := *t
	f.data[cp.TenantID] = append(f.data[cp.TenantID], cp)
	return nil
}

func (f *fakeTemplateRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestTemplate builds a TransactionTemplate literal with realistic fields.
func newTestTemplate(tenantID uuid.UUID, name string) templateDomain.TransactionTemplate {
	return templateDomain.TransactionTemplate{
		ID:              uuid.New(),
		TenantID:        tenantID,
		Name:            name,
		Description:     "monthly rent",
		AmountCents:     200000,
		Direction:       templateDomain.DirectionExpense,
		SourceAccountID: uuid.New(),
		Cycle:           templateDomain.CycleMonthly,
		CycleDays:       0,
		BillingDay:      15,
		NextDate:        testDate,
		StartDate:       testDate,
		AutoRecord:      true,
		Paused:          false,
		Category:        "rent",
		Version:         1,
		CreatedAt:       testDate,
		UpdatedAt:       testDate,
	}
}

// TestTemplateExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestTemplateExporter_Name(t *testing.T) {
	e := NewTemplateExporter(newFakeTemplateRepoExporter())
	if got := e.Name(); got != "template" {
		t.Fatalf("Name = %q, want \"template\"", got)
	}
}

// TestTemplateExporter_Roundtrip verifies Export -> Purge -> Import restores
// the same templates.
func TestTemplateExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeTemplateRepoExporter()

	t1 := newTestTemplate(tenantID, "Rent")
	t2 := newTestTemplate(tenantID, "Salary")
	repo.data[tenantID] = []templateDomain.TransactionTemplate{t1, t2}

	e := NewTemplateExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []templateDomain.TransactionTemplate
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d templates, want 2", len(exported))
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
}

// TestTemplateExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record.
func TestTemplateExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeTemplateRepoExporter()
	tmpl := newTestTemplate(srcTenant, "Rent")
	repo.data[srcTenant] = []templateDomain.TransactionTemplate{tmpl}

	e := NewTemplateExporter(repo)
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
			t.Fatalf("imported template TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestTemplateExporter_Export_EmptyTenant verifies Export on a tenant with no
// templates returns a valid empty JSON array, not null.
func TestTemplateExporter_Export_EmptyTenant(t *testing.T) {
	e := NewTemplateExporter(newFakeTemplateRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestTemplateExporter_Export_Error verifies Export propagates a
// FindAllForBackup error (error-path coverage).
func TestTemplateExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeTemplateRepoExporter()
	repo.findAllErr = injected
	e := NewTemplateExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestTemplateExporter_Import_SaveError verifies Import propagates a Save error
// (error-path coverage).
func TestTemplateExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeTemplateRepoExporter()
	tmpl := newTestTemplate(tenantID, "Rent")
	repo.data[tenantID] = []templateDomain.TransactionTemplate{tmpl}
	e := NewTemplateExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestTemplateExporter_Purge_Error verifies Purge propagates a DeleteByTenant
// error (error-path coverage).
func TestTemplateExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeTemplateRepoExporter()
	repo.deleteErr = injected
	e := NewTemplateExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
