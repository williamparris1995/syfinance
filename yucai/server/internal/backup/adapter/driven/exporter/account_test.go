package exporter

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// fakeAccountRepo is an in-memory AccountRepository port for exporter tests.
type fakeAccountRepo struct {
	data map[uuid.UUID][]domain.Account
}

func newFakeAccountRepo() *fakeAccountRepo {
	return &fakeAccountRepo{data: map[uuid.UUID][]domain.Account{}}
}

func (f *fakeAccountRepo) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]domain.Account, error) {
	return f.data[tenantID], nil
}
func (f *fakeAccountRepo) Save(_ context.Context, a *domain.Account) error {
	f.data[a.TenantID] = append(f.data[a.TenantID], *a)
	return nil
}
func (f *fakeAccountRepo) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	delete(f.data, tenantID)
	return nil
}

// TestAccountExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestAccountExporter_Name(t *testing.T) {
	e := NewAccountExporter(newFakeAccountRepo())
	if got := e.Name(); got != "account" {
		t.Fatalf("Name = %q, want \"account\"", got)
	}
}

// TestAccountExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same accounts: Export serializes tenant data, Purge empties the repo, then
// Import re-creates the records from the exported JSON.
func TestAccountExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeAccountRepo()

	a1, err := domain.NewAccount(tenantID, "Cash", domain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("new account: %v", err)
	}
	a1.CurrentBalanceCents = 5000
	a2, err := domain.NewAccount(tenantID, "Food", domain.AccountTypeExpense, "CNY")
	if err != nil {
		t.Fatalf("new account: %v", err)
	}
	_ = repo.Save(context.Background(), a1)
	_ = repo.Save(context.Background(), a2)

	e := NewAccountExporter(repo)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var exported []domain.Account
	if err := json.Unmarshal(raw, &exported); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(exported) != 2 {
		t.Fatalf("exported %d accounts, want 2", len(exported))
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

// TestAccountExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record, so a backup restored under a new tenant does not
// leak the original tenant's IDs.
func TestAccountExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeAccountRepo()
	a, _ := domain.NewAccount(srcTenant, "Cash", domain.AccountTypeAsset, "CNY")
	_ = repo.Save(context.Background(), a)

	e := NewAccountExporter(repo)
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
			t.Fatalf("imported account TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestAccountExporter_Export_EmptyTenant verifies Export on a tenant with no
// accounts returns a valid empty JSON array, not null.
func TestAccountExporter_Export_EmptyTenant(t *testing.T) {
	e := NewAccountExporter(newFakeAccountRepo())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if string(raw) != "null" && string(raw) != "[]" {
		t.Fatalf("Export empty tenant = %s, want \"null\" or \"[]\"", string(raw))
	}
}
