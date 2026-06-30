package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// TestPriceHistoryRepoFindBySecurity_RangeAndOrder verifies the date range
// filter (inclusive both ends) and ascending date ordering.
func TestPriceHistoryRepoFindBySecurity_RangeAndOrder(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	security := uuid.New()
	other := uuid.New()

	// Three rows for `security`: Jan-01, Jan-03, Jan-05. Query [Jan-02, Jan-05]
	// must return Jan-03 + Jan-05 (Jan-01 excluded), oldest-first.
	seedPrice(t, client, security, day("2025-01-01"), 10000)
	seedPrice(t, client, security, day("2025-01-03"), 10500)
	seedPrice(t, client, security, day("2025-01-05"), 11000)
	// A row for a different security — must be excluded.
	seedPrice(t, client, other, day("2025-01-03"), 99999)

	repo := repository.NewPriceHistoryRepository(client)
	got, err := repo.FindBySecurity(ctx, security, day("2025-01-02"), day("2025-01-05"))
	if err != nil {
		t.Fatalf("FindBySecurity: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 rows in range, got %d", len(got))
	}
	if !got[0].PriceDate.Before(got[1].PriceDate) {
		t.Errorf("rows not ASC by price_date")
	}
	if !got[0].PriceDate.Equal(day("2025-01-03")) {
		t.Errorf("first row date = %s, want 2025-01-03", got[0].PriceDate.Format("2006-01-02"))
	}
	// Range is inclusive on both ends — verify Jan-05 (== to) is included.
	if !got[1].PriceDate.Equal(day("2025-01-05")) {
		t.Errorf("second row date = %s, want 2025-01-05 (range should be inclusive)", got[1].PriceDate.Format("2006-01-02"))
	}
}

// TestPriceHistoryRepoExists confirms Exists distinguishes populated vs empty
// (Exists is no longer used as a backfill gate, but is kept for ad-hoc checks).
func TestPriceHistoryRepoExists(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	populated := uuid.New()
	empty := uuid.New()

	seedPrice(t, client, populated, day("2025-01-01"), 10000)

	repo := repository.NewPriceHistoryRepository(client)
	if exists, err := repo.Exists(ctx, populated); err != nil || !exists {
		t.Errorf("Exists(populated) = (%v, %v), want (true, nil)", exists, err)
	}
	if exists, err := repo.Exists(ctx, empty); err != nil || exists {
		t.Errorf("Exists(empty) = (%v, %v), want (false, nil)", exists, err)
	}
}

// TestPriceHistoryRepoSaveAll_BulkInsert verifies SaveAll persists a batch of
// zero-ID rows (ent Default generates ids) and they become queryable with the
// supplied price/source fields round-tripped.
func TestPriceHistoryRepoSaveAll_BulkInsert(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	security := uuid.New()

	// Service callers leave ID empty (uuid.Nil); the repo does not SetID, so
	// ent's Default(uuid.New) generates ids for each row. Passing empty IDs here
	// mirrors production and guards against the backfill pkey-collision bug
	// (every row in a bulk save sharing uuid.Nil).
	batch := []domain.SecurityPriceHistory{
		{SecurityID: security, PriceDate: day("2025-03-01"), PriceCents: 9000, CurrencyCode: "CNY", Source: "sina"},
		{SecurityID: security, PriceDate: day("2025-03-02"), PriceCents: 9100, CurrencyCode: "CNY", Source: "sina"},
	}
	repo := repository.NewPriceHistoryRepository(client)
	if err := repo.SaveAll(ctx, batch); err != nil {
		t.Fatalf("SaveAll: %v", err)
	}

	got, err := repo.FindBySecurity(ctx, security, day("2025-03-01"), day("2025-03-02"))
	if err != nil {
		t.Fatalf("FindBySecurity: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 rows after SaveAll, got %d", len(got))
	}
	// Source + price round-tripped.
	if got[0].Source != "sina" || got[0].PriceCents != 9000 {
		t.Errorf("first row round-trip mismatch: %+v", got[0])
	}
}

// TestPriceHistoryRepoSaveAll_UpsertOnConflict verifies SaveAll upserts on the
// UNIQUE(security_id, price_date) constraint: re-saving a (security,date) that
// already exists updates price_cents/source/currency_code in place instead of
// erroring. This is what lets BackfillPriceHistory refresh history for a
// security whose current-day row was already written by the B SyncPrices
// scheduler (the Task 10 e2e backfill-gate defect).
func TestPriceHistoryRepoSaveAll_UpsertOnConflict(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	security := uuid.New()

	// First save — fresh rows.
	first := []domain.SecurityPriceHistory{
		{SecurityID: security, PriceDate: day("2025-04-01"), PriceCents: 10000, CurrencyCode: "CNY", Source: "sina"},
		{SecurityID: security, PriceDate: day("2025-04-02"), PriceCents: 10100, CurrencyCode: "CNY", Source: "sina"},
	}
	repo := repository.NewPriceHistoryRepository(client)
	if err := repo.SaveAll(ctx, first); err != nil {
		t.Fatalf("SaveAll first: %v", err)
	}

	// Second save — same (security,date) keys, new price + source (as if
	// backfill re-fetched and upserted). Must NOT return a UNIQUE-constraint error.
	second := []domain.SecurityPriceHistory{
		{SecurityID: security, PriceDate: day("2025-04-01"), PriceCents: 9999, CurrencyCode: "CNY", Source: "backfill"},
		{SecurityID: security, PriceDate: day("2025-04-03"), PriceCents: 10200, CurrencyCode: "CNY", Source: "backfill"},
	}
	if err := repo.SaveAll(ctx, second); err != nil {
		t.Fatalf("SaveAll second (upsert): %v", err)
	}

	got, err := repo.FindBySecurity(ctx, security, day("2025-04-01"), day("2025-04-03"))
	if err != nil {
		t.Fatalf("FindBySecurity: %v", err)
	}
	// 3 distinct dates total (04-01 + 04-02 from first save, 04-03 new) — 04-01
	// upserted in place, NOT duplicated.
	if len(got) != 3 {
		t.Fatalf("expected 3 rows after upsert, got %d (04-01 should be updated, not duplicated)", len(got))
	}
	// 04-01 updated to the backfill value (9999, "backfill").
	var apr01 *domain.SecurityPriceHistory
	for i := range got {
		if got[i].PriceDate.Equal(day("2025-04-01")) {
			apr01 = &got[i]
			break
		}
	}
	if apr01 == nil {
		t.Fatal("04-01 row missing")
	}
	if apr01.PriceCents != 9999 || apr01.Source != "backfill" {
		t.Errorf("04-01 row = (price=%d source=%q), want (9999, backfill) — upsert did not refresh", apr01.PriceCents, apr01.Source)
	}
}

// TestPriceHistoryRepoSave_UpsertOnConflict verifies the single-row Save path
// (used by the B SyncPrices scheduler) also upserts — same-day re-syncs refresh
// the existing row instead of erroring.
func TestPriceHistoryRepoSave_UpsertOnConflict(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	security := uuid.New()
	repo := repository.NewPriceHistoryRepository(client)

	p := domain.SecurityPriceHistory{
		SecurityID: security, PriceDate: day("2025-05-01"),
		PriceCents: 5000, CurrencyCode: "CNY", Source: "sina",
	}
	if err := repo.Save(ctx, p); err != nil {
		t.Fatalf("Save first: %v", err)
	}
	// Re-save same (security,date) with refreshed price — must upsert, not error.
	p.PriceCents = 5500
	p.Source = "sina"
	if err := repo.Save(ctx, p); err != nil {
		t.Fatalf("Save second (upsert): %v", err)
	}

	got, err := repo.FindBySecurity(ctx, security, day("2025-05-01"), day("2025-05-01"))
	if err != nil {
		t.Fatalf("FindBySecurity: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 row (upserted), got %d", len(got))
	}
	if got[0].PriceCents != 5500 {
		t.Errorf("price = %d, want 5500 (upserted)", got[0].PriceCents)
	}
}

// TestPriceHistoryRepoSaveAll_Empty guards against CreateBulk(0) panics — an
// empty batch is a no-op.
func TestPriceHistoryRepoSaveAll_Empty(t *testing.T) {
	client := setupHoldingTestDB(t)
	ctx := context.Background()
	repo := repository.NewPriceHistoryRepository(client)
	if err := repo.SaveAll(ctx, nil); err != nil {
		t.Errorf("SaveAll(nil) = %v, want nil", err)
	}
}

// seedPrice inserts one price-history row for a security.
func seedPrice(t *testing.T, client *holdingent.Client, securityID uuid.UUID, priceDate time.Time, priceCents int64) {
	t.Helper()
	ctx := context.Background()
	if _, err := client.SecurityPriceHistory.Create().
		SetSecurityID(securityID).SetPriceDate(priceDate).
		SetPriceCents(priceCents).SetCurrencyCode("CNY").SetSource("sina").
		Save(ctx); err != nil {
		t.Fatalf("seed price: %v", err)
	}
}
