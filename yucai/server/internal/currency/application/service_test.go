package application_test

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/yucai/server/internal/currency/adapter/driven/repository"
	"github.com/yucai/server/internal/currency/application"
	"github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
)

// setupCurrencyTestDB opens an in-memory SQLite database and runs ent auto-migration
// for the currency schema. Mirrors the account_repo_test.go pattern.
func setupCurrencyTestDB(t *testing.T) *currencyent.Client {
	t.Helper()
	dbName := "currency_ent_" + t.Name()
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
	client := currencyent.NewClient(currencyent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// stubProvider is a test double for exchangerate.Provider returning a fixed rate map.
type stubProvider struct {
	rates map[string]float64
	err   error
}

func (p *stubProvider) FetchRate(ctx context.Context, code string) (float64, error) {
	r, ok := p.rates[code]
	if !ok {
		return 0, nil
	}
	return r, nil
}

func (p *stubProvider) FetchRates(ctx context.Context, codes []string) (map[string]float64, error) {
	if p.err != nil {
		return nil, p.err
	}
	return p.rates, nil
}

func seedCurrency(t *testing.T, repo *repository.CurrencyRepository, code, name, symbol string, rate float64, active bool) *domain.Currency {
	t.Helper()
	c, err := domain.NewCurrency(code, name, symbol, rate)
	if err != nil {
		t.Fatalf("new currency %s: %v", code, err)
	}
	if !active {
		c.Deactivate()
	}
	if err := repo.Save(context.Background(), c); err != nil {
		t.Fatalf("save currency %s: %v", code, err)
	}
	return c
}

func TestService_SyncRates_UpdatesActiveCurrencies(t *testing.T) {
	client := setupCurrencyTestDB(t)
	repo := repository.NewCurrencyRepository(client)

	cny := seedCurrency(t, repo, "CNY", "Chinese Yuan", "¥", 1.0, true)
	usd := seedCurrency(t, repo, "USD", "US Dollar", "$", 7.2, true)
	eur := seedCurrency(t, repo, "EUR", "Euro", "€", 7.8, true)
	jpy := seedCurrency(t, repo, "JPY", "Japanese Yen", "¥", 0.048, false)

	provider := &stubProvider{
		rates: map[string]float64{
			"CNY": 7.81,
			"USD": 1.08,
			"EUR": 1.0,
		},
	}
	svc := application.NewService(repo, provider)

	updated, err := svc.SyncRates(context.Background())
	if err != nil {
		t.Fatalf("SyncRates: %v", err)
	}
	if updated != 3 {
		t.Fatalf("expected 3 updated, got %d", updated)
	}

	cases := []struct {
		id       string
		code     string
		wantRate float64
	}{
		{cny.ID.String(), "CNY", 7.81},
		{usd.ID.String(), "USD", 1.08},
		{eur.ID.String(), "EUR", 1.0},
		{jpy.ID.String(), "JPY", 0.048}, // inactive, unchanged
	}
	for _, tc := range cases {
		got, err := repo.FindByCode(context.Background(), tc.code)
		if err != nil {
			t.Fatalf("FindByCode %s: %v", tc.code, err)
		}
		if got.ExchangeRate != tc.wantRate {
			t.Errorf("%s rate = %v, want %v", tc.code, got.ExchangeRate, tc.wantRate)
		}
	}
}

func TestService_SeedDefaults_Idempotent(t *testing.T) {
	client := setupCurrencyTestDB(t)
	repo := repository.NewCurrencyRepository(client)
	svc := application.NewService(repo, &stubProvider{rates: map[string]float64{}})

	// First seed creates the built-in reference currencies.
	n, err := svc.SeedDefaults(context.Background())
	if err != nil {
		t.Fatalf("SeedDefaults first: %v", err)
	}
	if n == 0 {
		t.Fatal("expected >0 currencies seeded on empty db")
	}

	// All default codes exist and are active.
	for _, code := range []string{"CNY", "USD", "EUR", "GBP", "HKD", "JPY"} {
		c, err := repo.FindByCode(context.Background(), code)
		if err != nil {
			t.Fatalf("FindByCode %s after seed: %v", code, err)
		}
		if !c.IsActive {
			t.Errorf("%s not active after seed", code)
		}
	}

	// Second seed is a no-op (idempotent — existing codes skipped).
	n2, err := svc.SeedDefaults(context.Background())
	if err != nil {
		t.Fatalf("SeedDefaults second: %v", err)
	}
	if n2 != 0 {
		t.Errorf("expected 0 seeded on second run (idempotent), got %d", n2)
	}
}
