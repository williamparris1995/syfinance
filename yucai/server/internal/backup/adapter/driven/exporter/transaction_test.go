package exporter

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/domain"
)

// testDate is a fixed timestamp shared by exporter tests in this package.
var testDate = time.Date(2026, 3, 15, 0, 0, 0, 0, time.UTC)

// fakeTransactionRepo is an in-memory TransactionRepository port for exporter
// tests. FindAllForBackup returns a non-nil empty slice for an empty tenant so
// the exported JSON is "[]" (matching the real repo), not null.
type fakeTransactionRepo struct {
	data        map[uuid.UUID][]domain.Transaction
	findAllErr  error // injected error for FindAllForBackup
	saveErr     error // injected error for Save
	deleteErr   error // injected error for DeleteByTenant
	lastSaved   *domain.Transaction
	deleteCalls int
}

func newFakeTransactionRepo() *fakeTransactionRepo {
	return &fakeTransactionRepo{data: map[uuid.UUID][]domain.Transaction{}}
}

func (f *fakeTransactionRepo) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]domain.Transaction, error) {
	if f.findAllErr != nil {
		return nil, f.findAllErr
	}
	out := f.data[tenantID]
	if out == nil {
		out = []domain.Transaction{}
	}
	return out, nil
}
func (f *fakeTransactionRepo) Save(_ context.Context, tx *domain.Transaction) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	c := *tx
	f.data[c.TenantID] = append(f.data[c.TenantID], c)
	f.lastSaved = &c
	return nil
}
func (f *fakeTransactionRepo) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.data, tenantID)
	return nil
}

// newTestTransaction builds a Transaction literal with two balanced entries so
// the roundtrip test has a realistic graph (header + nested entries).
func newTestTransaction(tenantID uuid.UUID, desc string) domain.Transaction {
	txnID := uuid.New()
	acc1, acc2 := uuid.New(), uuid.New()
	return domain.Transaction{
		ID:              txnID,
		TenantID:        tenantID,
		TransactionDate: testDate,
		Description:     desc,
		Entries: []domain.TransactionEntry{
			{ID: uuid.New(), TransactionID: txnID, AccountID: acc1, DebitCents: 100, CreditCents: 0, Note: "dr"},
			{ID: uuid.New(), TransactionID: txnID, AccountID: acc2, DebitCents: 0, CreditCents: 100, Note: "cr"},
		},
		Version: 1,
	}
}

// TestTransactionExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestTransactionExporter_Name(t *testing.T) {
	e := NewTransactionExporter(newFakeTransactionRepo())
	if got := e.Name(); got != "transaction" {
		t.Fatalf("Name = %q, want \"transaction\"", got)
	}
}

// TestTransactionExporter_Roundtrip verifies Export -> Purge -> Import restores
// the same transactions (including nested entries): Export serializes tenant
// data, Purge empties the repo, then Import re-creates the records.
func TestTransactionExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeTransactionRepo()

	t1 := newTestTransaction(tenantID, "lunch")
	t2 := newTestTransaction(tenantID, "salary")
	_ = repo.Save(context.Background(), &t1)
	_ = repo.Save(context.Background(), &t2)

	e := NewTransactionExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []domain.Transaction
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d transactions, want 2", len(exported))
	}
	// Entries survived the marshal roundtrip.
	for _, tx := range exported {
		if len(tx.Entries) != 2 {
			t.Fatalf("transaction %s has %d entries, want 2", tx.ID, len(tx.Entries))
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
	// Entries restored too.
	for _, tx := range repo.data[tenantID] {
		if len(tx.Entries) != 2 {
			t.Fatalf("restored transaction %s has %d entries, want 2", tx.ID, len(tx.Entries))
		}
	}
}

// TestTransactionExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record so a backup restored under a new tenant does not
// leak the original tenant's ID.
func TestTransactionExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeTransactionRepo()
	tx := newTestTransaction(srcTenant, "coffee")
	_ = repo.Save(context.Background(), &tx)

	e := NewTransactionExporter(repo)
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
			t.Fatalf("imported transaction TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestTransactionExporter_Export_EmptyTenant verifies Export on a tenant with
// no transactions returns a valid empty JSON array, not null.
func TestTransactionExporter_Export_EmptyTenant(t *testing.T) {
	e := NewTransactionExporter(newFakeTransactionRepo())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"[]\"", string(raw))
	}
}

// TestTransactionExporter_Export_Error verifies Export propagates a
// FindAllForBackup error (error-path coverage).
func TestTransactionExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeTransactionRepo()
	repo.findAllErr = injected
	e := NewTransactionExporter(repo)
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestTransactionExporter_Import_SaveError verifies Import propagates a Save
// error (error-path coverage).
func TestTransactionExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeTransactionRepo()
	tx := newTestTransaction(tenantID, "x")
	_ = repo.Save(context.Background(), &tx)
	e := NewTransactionExporter(repo)
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestTransactionExporter_Purge_Error verifies Purge propagates a DeleteByTenant
// error (error-path coverage).
func TestTransactionExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeTransactionRepo()
	repo.deleteErr = injected
	e := NewTransactionExporter(repo)
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
