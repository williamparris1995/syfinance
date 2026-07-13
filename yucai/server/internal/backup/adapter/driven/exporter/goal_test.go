package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	goalDomain "github.com/yucai/server/internal/goal/domain"
)

// fakeGoalRepoExporter is an in-memory GoalRepository port for exporter tests.
// FindAllForBackup returns a non-nil empty slice for an empty tenant so the
// exported JSON is "[]" (matching the real repo).
type fakeGoalRepoExporter struct {
	data        map[uuid.UUID][]goalDomain.Goal
	findAllErr  error
	saveErr     error
	deleteErr   error
	lastSaved   *goalDomain.Goal
	deleteCalls int
}

func newFakeGoalRepoExporter() *fakeGoalRepoExporter {
	return &fakeGoalRepoExporter{data: map[uuid.UUID][]goalDomain.Goal{}}
}

func (f *fakeGoalRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]goalDomain.Goal, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []goalDomain.Goal{}
	}
	return out, nil
}
func (f *fakeGoalRepoExporter) Save(_ context.Context, g *goalDomain.Goal) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	c := *g
	f.data[c.TenantID] = append(f.data[c.TenantID], c)
	f.lastSaved = &c
	return nil
}
func (f *fakeGoalRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestGoal builds a Goal literal with nested account + debt links so the
// roundtrip test has a realistic graph (header + nested links).
func newTestGoal(tenantID uuid.UUID, name string) goalDomain.Goal {
	return goalDomain.Goal{
		ID:                 uuid.New(),
		TenantID:           tenantID,
		Name:               name,
		GoalType:           goalDomain.GoalTypeSavings,
		TargetAmountCents:  1000000,
		CurrentAmountCents: 250000,
		CurrencyCode:       "CNY",
		LinkedAccountIDs:   []uuid.UUID{uuid.New(), uuid.New()},
		LinkedDebtIDs:      []uuid.UUID{uuid.New()},
		Notes:              "emergency fund",
		IsCompleted:        false,
		Version:            1,
		CreatedAt:          testDate,
		UpdatedAt:          testDate,
	}
}

// TestGoalExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestGoalExporter_Name(t *testing.T) {
	e := NewGoalExporter(newFakeGoalRepoExporter())
	if got := e.Name(); got != "goal" {
		t.Fatalf("Name = %q, want \"goal\"", got)
	}
}

// TestGoalExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same goals (including nested account + debt links).
func TestGoalExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeGoalRepoExporter()

	g1 := newTestGoal(tenantID, "Emergency Fund")
	g2 := newTestGoal(tenantID, "New Car")
	_ = repo.Save(context.Background(), &g1)
	_ = repo.Save(context.Background(), &g2)

	e := NewGoalExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []goalDomain.Goal
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d goals, want 2", len(exported))
	}
	for _, g := range exported {
		if len(g.LinkedAccountIDs) != 2 {
			t.Fatalf("goal %s has %d account links, want 2", g.ID, len(g.LinkedAccountIDs))
		}
		if len(g.LinkedDebtIDs) != 1 {
			t.Fatalf("goal %s has %d debt links, want 1", g.ID, len(g.LinkedDebtIDs))
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
	for _, g := range repo.data[tenantID] {
		if len(g.LinkedAccountIDs) != 2 {
			t.Fatalf("restored goal %s has %d account links, want 2", g.ID, len(g.LinkedAccountIDs))
		}
		if len(g.LinkedDebtIDs) != 1 {
			t.Fatalf("restored goal %s has %d debt links, want 1", g.ID, len(g.LinkedDebtIDs))
		}
	}
}

// TestGoalExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record.
func TestGoalExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeGoalRepoExporter()
	g := newTestGoal(srcTenant, "Emergency Fund")
	_ = repo.Save(context.Background(), &g)

	e := NewGoalExporter(repo)
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
			t.Fatalf("imported goal TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestGoalExporter_Export_EmptyTenant verifies Export on a tenant with no goals
// returns a valid empty JSON array, not null.
func TestGoalExporter_Export_EmptyTenant(t *testing.T) {
	e := NewGoalExporter(newFakeGoalRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestGoalExporter_Export_Error verifies Export propagates a FindAllForBackup
// error (error-path coverage).
func TestGoalExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeGoalRepoExporter()
	repo.findAllErr = injected
	e := NewGoalExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestGoalExporter_Import_SaveError verifies Import propagates a Save error
// (error-path coverage).
func TestGoalExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeGoalRepoExporter()
	g := newTestGoal(tenantID, "x")
	_ = repo.Save(context.Background(), &g)
	e := NewGoalExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestGoalExporter_Purge_Error verifies Purge propagates a DeleteByTenant error
// (error-path coverage).
func TestGoalExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeGoalRepoExporter()
	repo.deleteErr = injected
	e := NewGoalExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
