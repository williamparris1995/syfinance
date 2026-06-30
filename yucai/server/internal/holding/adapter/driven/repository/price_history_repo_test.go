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
// (the backfill gate: skip securities that already have history).
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
