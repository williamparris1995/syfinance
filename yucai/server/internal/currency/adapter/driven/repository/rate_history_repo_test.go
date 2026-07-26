package repository_test

import (
	"bytes"
	"context"
	"database/sql"
	"log/slog"
	"strings"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/yucai/server/internal/currency/adapter/driven/repository"
	"github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
)

// setupCurrencyTestDB opens an in-memory SQLite database and runs ent
// auto-migration for the currency schema. Mirrors account_repo_test.go.
func setupCurrencyTestDB(t *testing.T) *currencyent.Client {
	t.Helper()
	dbName := "currency_ent_" + sanitize(t.Name())
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

func day(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic("bad day fixture: " + err.Error())
	}
	return t.UTC()
}

func sanitize(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ' ' || c == ':' {
			out = append(out, '_')
			continue
		}
		out = append(out, c)
	}
	return string(out)
}

// TestRateHistoryRepoFindRate_ForwardFill verifies the forward-fill behavior:
// a query date with no exact row resolves to the most recent earlier rate
// (handles weekend/holiday gaps).
func TestRateHistoryRepoFindRate_ForwardFill(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()

	// USD rate history: Jan-02 = 7.10, Jan-06 = 7.20. Jan-03/04/05 are a gap
	// (weekend). Querying Jan-05 must forward-fill to Jan-02's 7.10.
	seedRate(t, client, "USD", day("2025-01-02"), 7.10)
	seedRate(t, client, "USD", day("2025-01-06"), 7.20)

	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRate(ctx, "USD", day("2025-01-05"))
	if err != nil {
		t.Fatalf("FindRate (forward-fill): %v", err)
	}
	if got != 7.10 {
		t.Errorf("FindRate(USD, 2025-01-05) = %v, want 7.10 (forward-fill from Jan-02)", got)
	}

	// Exact-match date returns its own rate, not an earlier one.
	got, err = repo.FindRate(ctx, "USD", day("2025-01-06"))
	if err != nil {
		t.Fatalf("FindRate (exact): %v", err)
	}
	if got != 7.20 {
		t.Errorf("FindRate(USD, 2025-01-06) = %v, want 7.20 (exact match)", got)
	}
}

// TestRateHistoryRepoFindRate_MissingReturnsBase confirms graceful degradation:
// no history at or before the date returns 1.0 (base currency / pre-history).
func TestRateHistoryRepoFindRate_MissingReturnsBase(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()

	// No history for CNY at all.
	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRate(ctx, "CNY", day("2025-01-05"))
	if err != nil {
		t.Fatalf("FindRate (missing): %v", err)
	}
	if got != 1.0 {
		t.Errorf("FindRate(CNY, no history) = %v, want 1.0 (base fallback)", got)
	}

	// Pre-history date also forward-fills to nothing → 1.0.
	seedRate(t, client, "USD", day("2025-06-01"), 7.30)
	got, err = repo.FindRate(ctx, "USD", day("2025-01-01"))
	if err != nil {
		t.Fatalf("FindRate (pre-history): %v", err)
	}
	if got != 1.0 {
		t.Errorf("FindRate(USD, pre-history) = %v, want 1.0 (no rate at/before date)", got)
	}
}

// TestRateHistoryRepoFindRange_Ordered verifies range query returns rows
// inclusive both ends, ascending by date.
func TestRateHistoryRepoFindRange_Ordered(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()

	seedRate(t, client, "USD", day("2025-01-01"), 7.00)
	seedRate(t, client, "USD", day("2025-01-02"), 7.05)
	seedRate(t, client, "USD", day("2025-01-03"), 7.10)
	seedRate(t, client, "USD", day("2025-01-04"), 7.15)

	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRange(ctx, "USD", day("2025-01-02"), day("2025-01-03"))
	if err != nil {
		t.Fatalf("FindRange: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 rows, got %d", len(got))
	}
	if !got[0].RateDate.Equal(day("2025-01-02")) {
		t.Errorf("first date = %s, want 2025-01-02", got[0].RateDate.Format("2006-01-02"))
	}
	if !got[1].RateDate.Equal(day("2025-01-03")) {
		t.Errorf("second date = %s, want 2025-01-03 (range inclusive)", got[1].RateDate.Format("2006-01-02"))
	}
}

// TestRateHistoryRepoSave_RoundTrip verifies Save persists and the row is
// queryable, isolating by currency code.
func TestRateHistoryRepoSave_RoundTrip(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()

	repo := repository.NewRateHistoryRepository(client)
	// Service callers leave ID empty; ent's Default(uuid.New) generates it.
	rh := domain.RateHistory{
		CurrencyCode: "EUR", RateDate: day("2025-05-01"),
		ExchangeRate: 7.80,
	}
	if err := repo.Save(ctx, rh); err != nil {
		t.Fatalf("Save: %v", err)
	}

	got, err := repo.FindRange(ctx, "EUR", day("2025-05-01"), day("2025-05-01"))
	if err != nil {
		t.Fatalf("FindRange: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 row, got %d", len(got))
	}
	if got[0].ExchangeRate != 7.80 || got[0].CurrencyCode != "EUR" {
		t.Errorf("round-trip mismatch: %+v", got[0])
	}

	// Different code is isolated.
	if others, err := repo.FindRange(ctx, "USD", day("2025-05-01"), day("2025-05-01")); err != nil {
		t.Fatalf("FindRange USD: %v", err)
	} else if len(others) != 0 {
		t.Errorf("expected 0 USD rows, got %d", len(others))
	}
}

func seedRate(t *testing.T, client *currencyent.Client, code string, rateDate time.Time, rate float64) {
	t.Helper()
	ctx := context.Background()
	if _, err := client.RateHistory.Create().
		SetCurrencyCode(code).SetRateDate(rateDate).SetExchangeRate(rate).
		Save(ctx); err != nil {
		t.Fatalf("seed rate: %v", err)
	}
}

// captureSlog swaps the default slog handler for a text handler writing to a
// buffer (Debug level), restored on t.Cleanup. Returns the buffer for assertion.
func captureSlog(t *testing.T) *bytes.Buffer {
	t.Helper()
	var buf bytes.Buffer
	prev := slog.Default()
	h := slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})
	slog.SetDefault(slog.New(h))
	t.Cleanup(func() { slog.SetDefault(prev) })
	return &buf
}

// TestRateHistoryRepoFindRate_GapWarns covers the P1-3 stopgap: when a TRACKED
// currency (has rows) is queried at a date its history doesn't reach, FindRate
// still returns 1.0 (no behavioral change) but emits a warning so the silent
// fallback becomes observable. Base/unconfigured currencies stay silent.
func TestRateHistoryRepoFindRate_GapWarns(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()
	buf := captureSlog(t)

	// Seed USD at 2024-06-01 (a tracked currency). Querying 2020-01-15 — before
	// the scheduler started — has no row at/before that date.
	seedRate(t, client, "USD", day("2024-06-01"), 7.2)

	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRate(ctx, "USD", day("2020-01-15"))
	if err != nil {
		t.Fatalf("FindRate (gap): %v", err)
	}
	if got != 1.0 {
		t.Errorf("FindRate(USD, pre-history) = %v, want 1.0 (fallback unchanged)", got)
	}
	if !strings.Contains(buf.String(), "exchange rate gap") {
		t.Errorf("expected gap warning in slog output, got:\n%s", buf.String())
	}
	if !strings.Contains(buf.String(), "currency_code=USD") {
		t.Errorf("expected currency_code=USD in slog output, got:\n%s", buf.String())
	}
}

// TestRateHistoryRepoFindRate_BaseSilent confirms the base/unconfigured path
// (no rows at all — e.g. CNY) stays SILENT: returns 1.0 with no gap warning.
func TestRateHistoryRepoFindRate_BaseSilent(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()
	buf := captureSlog(t)

	// No CNY rows seeded at all — identity 1.0, no warning.
	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRate(ctx, "CNY", day("2024-01-01"))
	if err != nil {
		t.Fatalf("FindRate (base): %v", err)
	}
	if got != 1.0 {
		t.Errorf("FindRate(CNY, no history) = %v, want 1.0 (identity)", got)
	}
	if strings.Contains(buf.String(), "exchange rate gap") {
		t.Errorf("expected NO gap warning for base currency, got:\n%s", buf.String())
	}
}

// TestRateHistoryRepoFindRate_FoundNoWarn confirms the happy path: an exact or
// forward-fill hit returns the rate and emits no gap warning.
func TestRateHistoryRepoFindRate_FoundNoWarn(t *testing.T) {
	client := setupCurrencyTestDB(t)
	ctx := context.Background()
	buf := captureSlog(t)

	seedRate(t, client, "USD", day("2024-06-01"), 7.2)

	repo := repository.NewRateHistoryRepository(client)
	got, err := repo.FindRate(ctx, "USD", day("2024-06-02"))
	if err != nil {
		t.Fatalf("FindRate (found): %v", err)
	}
	if got != 7.2 {
		t.Errorf("FindRate(USD, 2024-06-02) = %v, want 7.2", got)
	}
	if strings.Contains(buf.String(), "exchange rate gap") {
		t.Errorf("expected NO gap warning on found path, got:\n%s", buf.String())
	}
}
