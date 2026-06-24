package wire

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	currencyent "github.com/yucai/server/internal/currency/ent"
)

// newCurrencyTestClient opens an in-memory SQLite database and runs ent
// auto-migration for the currency schema, mirroring the currency package tests.
func newCurrencyTestClient(t *testing.T) *currencyent.Client {
	t.Helper()
	db, err := sql.Open("sqlite", "file:currency_checker_"+t.Name()+"?mode=memory&_fk=1")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	drv := entsql.OpenDB("sqlite3", db)
	client := currencyent.NewClient(currencyent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	return client
}

func TestCurrencyCodeChecker_FindByCode_NotFound(t *testing.T) {
	client := newCurrencyTestClient(t)
	t.Cleanup(func() { client.Close() })
	checker := provideCurrencyCodeChecker(currencyrepo.NewCurrencyRepository(client))

	exists, err := currencyCodeChecker{repo: currencyrepo.NewCurrencyRepository(client)}.
		FindByCode(context.Background(), "USD")
	if err != nil {
		t.Fatalf("expected nil error for missing code, got %v", err)
	}
	if exists {
		t.Fatal("expected exists=false for code not in catalog")
	}
	_ = checker
}

func TestCurrencyCodeChecker_FindByCode_Exists(t *testing.T) {
	client := newCurrencyTestClient(t)
	t.Cleanup(func() { client.Close() })
	repo := currencyrepo.NewCurrencyRepository(client)

	// Seed a currency row directly via ent so FindByCode returns it.
	if err := client.Currency.Create().
		SetCode("USD").
		SetName("US Dollar").
		SetSymbol("$").
		SetIsActive(true).
		Exec(context.Background()); err != nil {
		t.Fatalf("seed currency: %v", err)
	}

	exists, err := currencyCodeChecker{repo: repo}.FindByCode(context.Background(), "USD")
	if err != nil {
		t.Fatalf("expected nil error, got %v", err)
	}
	if !exists {
		t.Fatal("expected exists=true for seeded code")
	}
}

func TestCurrencyCodeChecker_FindByCode_DBError(t *testing.T) {
	client := newCurrencyTestClient(t)
	repo := currencyrepo.NewCurrencyRepository(client)
	// Close the underlying connection to simulate a transient DB failure.
	if err := client.Close(); err != nil {
		t.Fatalf("close client: %v", err)
	}

	exists, err := currencyCodeChecker{repo: repo}.FindByCode(context.Background(), "USD")
	if err == nil {
		t.Fatal("expected error for DB failure, got nil")
	}
	if exists {
		t.Fatal("expected exists=false on DB error")
	}
}
