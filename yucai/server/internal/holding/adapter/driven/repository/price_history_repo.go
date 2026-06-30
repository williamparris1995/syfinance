package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/securitypricehistory"
)

// PriceHistoryRepository implements domain.PriceHistoryRepository.
type PriceHistoryRepository struct {
	client *holdingent.Client
}

// NewPriceHistoryRepository creates a new PriceHistoryRepository.
func NewPriceHistoryRepository(client *holdingent.Client) *PriceHistoryRepository {
	return &PriceHistoryRepository{client: client}
}

// FindBySecurity returns price rows for a security in [from, to] ordered by
// PriceDate ascending (oldest first — chart/curve friendly).
func (r *PriceHistoryRepository) FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	rows, err := r.client.SecurityPriceHistory.Query().
		Where(
			securitypricehistory.SecurityIDEQ(securityID),
			securitypricehistory.PriceDateGTE(from),
			securitypricehistory.PriceDateLTE(to),
		).
		Order(holdingent.Asc(securitypricehistory.FieldPriceDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query price history: %w", err)
	}
	out := make([]domain.SecurityPriceHistory, 0, len(rows))
	for _, row := range rows {
		out = append(out, toDomainPriceHistory(row))
	}
	return out, nil
}

// SaveAll bulk-inserts price rows. Backfill is idempotent at the call site
// (UNIQUE(security_id, price_date) guards duplicates); callers backfilling an
// empty range will hit no conflicts.
func (r *PriceHistoryRepository) SaveAll(ctx context.Context, ph []domain.SecurityPriceHistory) error {
	if len(ph) == 0 {
		return nil
	}
	bulk := make([]*holdingent.SecurityPriceHistoryCreate, 0, len(ph))
	for _, p := range ph {
		bulk = append(bulk, r.client.SecurityPriceHistory.Create().
			SetID(p.ID).
			SetSecurityID(p.SecurityID).
			SetPriceDate(p.PriceDate).
			SetPriceCents(p.PriceCents).
			SetCurrencyCode(p.CurrencyCode).
			SetSource(p.Source))
	}
	if _, err := r.client.SecurityPriceHistory.CreateBulk(bulk...).Save(ctx); err != nil {
		return fmt.Errorf("bulk save price history: %w", err)
	}
	return nil
}

// Save inserts one price history row. Idempotent at the call site via the
// UNIQUE(security_id, price_date) constraint — same-day re-sync from the B
// scheduler upserts the same row; callers truncate PriceDate to the day so the
// constraint key is stable. A conflict surfaces as an error here and is logged
// (not fatal) by SyncPrices; first-of-day writes succeed.
func (r *PriceHistoryRepository) Save(ctx context.Context, p domain.SecurityPriceHistory) error {
	if _, err := r.client.SecurityPriceHistory.Create().
		SetSecurityID(p.SecurityID).
		SetPriceDate(p.PriceDate).
		SetPriceCents(p.PriceCents).
		SetCurrencyCode(p.CurrencyCode).
		SetSource(p.Source).
		Save(ctx); err != nil {
		return fmt.Errorf("save price history: %w", err)
	}
	return nil
}

// Exists reports whether any price row exists for the security (gates// backfill — skip already-populated securities).
func (r *PriceHistoryRepository) Exists(ctx context.Context, securityID uuid.UUID) (bool, error) {
	exists, err := r.client.SecurityPriceHistory.Query().
		Where(securitypricehistory.SecurityIDEQ(securityID)).
		Exist(ctx)
	if err != nil {
		return false, fmt.Errorf("check price history exists: %w", err)
	}
	return exists, nil
}

func toDomainPriceHistory(row *holdingent.SecurityPriceHistory) domain.SecurityPriceHistory {
	return domain.SecurityPriceHistory{
		ID:           row.ID,
		SecurityID:   row.SecurityID,
		PriceDate:    row.PriceDate,
		PriceCents:   row.PriceCents,
		CurrencyCode: row.CurrencyCode,
		Source:       row.Source,
		CreatedAt:    row.CreatedAt,
	}
}

var _ domain.PriceHistoryRepository = (*PriceHistoryRepository)(nil)
