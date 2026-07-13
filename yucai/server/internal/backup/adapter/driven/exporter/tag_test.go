package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	tagDomain "github.com/yucai/server/internal/tag/domain"
)

// fakeTagRepoExporter is an in-memory TagRepository port for exporter tests.
// FindAllForBackup returns a non-nil empty slice for an empty tenant so the
// exported JSON is "[]" (matching the real repo).
type fakeTagRepoExporter struct {
	data        map[uuid.UUID][]tagDomain.Tag
	findAllErr  error
	saveErr     error
	deleteErr   error
	deleteCalls int
}

func newFakeTagRepoExporter() *fakeTagRepoExporter {
	return &fakeTagRepoExporter{data: map[uuid.UUID][]tagDomain.Tag{}}
}

func (f *fakeTagRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]tagDomain.Tag, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []tagDomain.Tag{}
	}
	return out, nil
}

func (f *fakeTagRepoExporter) Save(_ context.Context, tag *tagDomain.Tag) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	cp := *tag
	f.data[cp.TenantID] = append(f.data[cp.TenantID], cp)
	return nil
}

func (f *fakeTagRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestTag builds a Tag literal with realistic fields.
func newTestTag(tenantID uuid.UUID, name string) tagDomain.Tag {
	return tagDomain.Tag{
		ID:        uuid.New(),
		TenantID:  tenantID,
		Name:      name,
		Color:     "#FF5733",
		Version:   1,
		CreatedAt: testDate,
		UpdatedAt: testDate,
	}
}

// TestTagExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestTagExporter_Name(t *testing.T) {
	e := NewTagExporter(newFakeTagRepoExporter())
	if got := e.Name(); got != "tag" {
		t.Fatalf("Name = %q, want \"tag\"", got)
	}
}

// TestTagExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same tags.
func TestTagExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeTagRepoExporter()

	t1 := newTestTag(tenantID, "Food")
	t2 := newTestTag(tenantID, "Travel")
	repo.data[tenantID] = []tagDomain.Tag{t1, t2}

	e := NewTagExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []tagDomain.Tag
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d tags, want 2", len(exported))
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

// TestTagExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record.
func TestTagExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeTagRepoExporter()
	tag := newTestTag(srcTenant, "Food")
	repo.data[srcTenant] = []tagDomain.Tag{tag}

	e := NewTagExporter(repo)
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
			t.Fatalf("imported tag TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestTagExporter_Export_EmptyTenant verifies Export on a tenant with no tags
// returns a valid empty JSON array, not null.
func TestTagExporter_Export_EmptyTenant(t *testing.T) {
	e := NewTagExporter(newFakeTagRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestTagExporter_Export_Error verifies Export propagates a FindAllForBackup
// error (error-path coverage).
func TestTagExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeTagRepoExporter()
	repo.findAllErr = injected
	e := NewTagExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestTagExporter_Import_SaveError verifies Import propagates a Save error
// (error-path coverage).
func TestTagExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeTagRepoExporter()
	tag := newTestTag(tenantID, "Food")
	repo.data[tenantID] = []tagDomain.Tag{tag}
	e := NewTagExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestTagExporter_Purge_Error verifies Purge propagates a DeleteByTenant error
// (error-path coverage).
func TestTagExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeTagRepoExporter()
	repo.deleteErr = injected
	e := NewTagExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
