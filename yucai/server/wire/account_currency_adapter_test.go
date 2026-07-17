package wire

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
)

// newAccountTestClient opens an in-memory SQLite database and runs ent auto-
// migration for the account schema, mirroring newCurrencyTestClient above and
// the account package's setupAccountTestDB.
func newAccountTestClient(t *testing.T) *accountent.Client {
	t.Helper()
	dbName := "account_adapter_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	drv := entsql.OpenDB("sqlite3", db)
	client := accountent.NewClient(accountent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	return client
}

// TestAccountCurrencyAdapter_CurrencyCodes_MapsIDToCode verifies the adapter
// builds account_id -> currency_code from FindAllForBackup, scoped to the
// tenant (cross-tenant isolation). This is the thin wire bridge between the
// account repo and budget's AccountCurrencySource port; the conversion logic
// that consumes the map is covered by Task 1's fake-port test.
func TestAccountCurrencyAdapter_CurrencyCodes_MapsIDToCode(t *testing.T) {
	client := newAccountTestClient(t)
	t.Cleanup(func() { client.Close() })
	repo := accountrepo.NewAccountRepository(client)
	tenantID := uuid.New()

	accUSD, err := accountdomain.NewAccount(tenantID, "USD Account", accountdomain.AccountTypeAsset, "USD")
	if err != nil {
		t.Fatalf("new USD account: %v", err)
	}
	if err := repo.Save(context.Background(), accUSD); err != nil {
		t.Fatalf("save USD account: %v", err)
	}
	accCNY, err := accountdomain.NewAccount(tenantID, "CNY Account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("new CNY account: %v", err)
	}
	if err := repo.Save(context.Background(), accCNY); err != nil {
		t.Fatalf("save CNY account: %v", err)
	}

	// Other tenant's account must be excluded (FindAllForBackup is tenant-scoped).
	otherAcc, err := accountdomain.NewAccount(uuid.New(), "Other Tenant", accountdomain.AccountTypeAsset, "EUR")
	if err != nil {
		t.Fatalf("new other-tenant account: %v", err)
	}
	if err := repo.Save(context.Background(), otherAcc); err != nil {
		t.Fatalf("save other-tenant account: %v", err)
	}

	got, err := (&accountCurrencyAdapter{inner: repo}).CurrencyCodes(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("CurrencyCodes: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 entries, got %d (%v)", len(got), got)
	}
	if got[accUSD.ID] != "USD" {
		t.Errorf("USD account: got code %q, want USD", got[accUSD.ID])
	}
	if got[accCNY.ID] != "CNY" {
		t.Errorf("CNY account: got code %q, want CNY", got[accCNY.ID])
	}
	if _, leaked := got[otherAcc.ID]; leaked {
		t.Errorf("other tenant's account leaked into map (tenant isolation broken)")
	}
}

// TestAccountCurrencyAdapter_CurrencyCodes_DBError verifies the adapter
// propagates underlying repo errors (wraps with "account currencies:").
func TestAccountCurrencyAdapter_CurrencyCodes_DBError(t *testing.T) {
	client := newAccountTestClient(t)
	repo := accountrepo.NewAccountRepository(client)
	if err := client.Close(); err != nil {
		t.Fatalf("close client: %v", err)
	}

	_, err := (&accountCurrencyAdapter{inner: repo}).CurrencyCodes(context.Background(), uuid.New())
	if err == nil {
		t.Fatal("expected error for DB failure, got nil")
	}
}
