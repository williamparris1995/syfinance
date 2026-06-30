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

// SaveAll upserts price rows. Each row is written via create-or-update against
// the UNIQUE(security_id, price_date) constraint: a fresh (security,date) is
// inserted; a pre-existing row (e.g. the B SyncPrices scheduler already wrote
// the current-day point before backfill ran) has its price_cents/source/currency
// updated in place. This lets BackfillPriceHistory refresh history for every
// Sina-covered security on every startup without skipping securities that
// already carry a today point. ent's generated code does not expose an
// OnConflict upsert (the sql/upsert feature is not enabled in this codegen), so
// the upsert is implemented as per-row create + conflict-then-update.
func (r *PriceHistoryRepository) SaveAll(ctx context.Context, ph []domain.SecurityPriceHistory) error {
	if len(ph) == 0 {
		return nil
	}
	for _, p := range ph {
		if err := r.upsertPrice(ctx, p); err != nil {
			return fmt.Errorf("upsert price history (security=%s date=%s): %w",
				p.SecurityID, p.PriceDate.Format("2006-01-02"), err)
		}
	}
	return nil
}

// upsertPrice inserts p, and on a UNIQUE(security_id, price_date) conflict
// updates the existing row's price_cents, currency_code and source in place.
func (r *PriceHistoryRepository) upsertPrice(ctx context.Context, p domain.SecurityPriceHistory) error {
	createErr := r.client.SecurityPriceHistory.Create().
		SetSecurityID(p.SecurityID).
		SetPriceDate(p.PriceDate).
		SetPriceCents(p.PriceCents).
		SetCurrencyCode(p.CurrencyCode).
		SetSource(p.Source).
		Exec(ctx)
	if createErr == nil {
		return nil
	}
	if !holdingent.IsConstraintError(createErr) {
		return createErr
	}
	// Conflict on UNIQUE(security_id, price_date) — update the existing row.
	n, err := r.client.SecurityPriceHistory.Update().
		Where(
			securitypricehistory.SecurityIDEQ(p.SecurityID),
			securitypricehistory.PriceDateEQ(p.PriceDate),
		).
		SetPriceCents(p.PriceCents).
		SetCurrencyCode(p.CurrencyCode).
		SetSource(p.Source).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update on conflict: %w", err)
	}
	if n == 0 {
		// No row matched yet the create reported a constraint error — the row
		// was inserted by a concurrent transaction between the two calls.
		// Treat as success (the constraint guarantees a row now exists).
	}
	return nil
}

// Save upserts one price history row against UNIQUE(security_id, price_date):
// a fresh (security,date) is inserted; a pre-existing row has price_cents,
// currency_code and source updated in place. Used by the B SyncPrices scheduler
// so same-day re-syncs (and backfill-after-sync overlaps) refresh the row
// instead of erroring. Callers truncate PriceDate to the day so the constraint
// key is stable.
func (r *PriceHistoryRepository) Save(ctx context.Context, p domain.SecurityPriceHistory) error {
	if err := r.upsertPrice(ctx, p); err != nil {
		return fmt.Errorf("save price history: %w", err)
	}
	return nil
}

// Exists reports whether any price row exists for the security. No longer used
// as a backfill gate (BackfillPriceHistory refreshes every Sina-covered security
// each startup), but kept for ad-hoc checks and the repo interface.
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
