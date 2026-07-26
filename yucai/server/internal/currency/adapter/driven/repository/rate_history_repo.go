package repository

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
	"github.com/yucai/server/internal/currency/ent/ratehistory"
)

// RateHistoryRepository implements domain.RateHistoryRepository.
type RateHistoryRepository struct {
	client *currencyent.Client
}

// NewRateHistoryRepository creates a new RateHistoryRepository.
func NewRateHistoryRepository(client *currencyent.Client) *RateHistoryRepository {
	return &RateHistoryRepository{client: client}
}

// FindRate returns the exchange rate for `date`, forward-filling to the most
// recent rate at or before `date` (handles weekend/holiday gaps). Returns 1.0
// when no history exists — graceful degradation for the base currency (CNY) or
// pre-history dates; callers that need strict correctness should log the gap.
func (r *RateHistoryRepository) FindRate(ctx context.Context, code string, date time.Time) (float64, error) {
	row, err := r.client.RateHistory.Query().
		Where(
			ratehistory.CurrencyCodeEQ(code),
			ratehistory.RateDateLTE(date),
		).
		Order(currencyent.Desc(ratehistory.FieldRateDate)).
		First(ctx)
	if err != nil {
		if currencyent.IsNotFound(err) {
			// Distinguish a genuine GAP (currency is tracked — has rows — but history
			// doesn't reach [date]; usually an old trade date before the rate scheduler
			// started) from base/unconfigured (no rows at all — e.g. CNY has no rate row
			// by design, identity 1.0). Gap → warn loudly (the 1.0 fallback produces a
			// wrong conversion downstream); base/unconfigured → silent.
			//
			// Log-only stopgap for missing-rate silence (P1-3); the full fix — degrading
			// the metric to nil — requires threading base currency through the
			// portfolio-calc stack and is deferred.
			if _, probeErr := r.client.RateHistory.Query().
				Where(ratehistory.CurrencyCodeEQ(code)).
				Limit(1).First(ctx); probeErr == nil {
				slog.Warn("exchange rate gap: no row at/before date, falling back to 1.0 (tracked currency — converted amount may be wrong)",
					slog.String("currency_code", code),
					slog.String("date", date.Format("2006-01-02")),
					slog.String("operation", "RateHistoryRepository.FindRate"))
			}
			return 1.0, nil
		}
		return 0, fmt.Errorf("query rate for %s @ %s: %w", code, date.Format("2006-01-02"), err)
	}
	return row.ExchangeRate, nil
}

// FindRange returns rate rows for a currency in [from, to] ordered by RateDate
// ascending (oldest first — curve-friendly).
func (r *RateHistoryRepository) FindRange(ctx context.Context, code string, from, to time.Time) ([]domain.RateHistory, error) {
	rows, err := r.client.RateHistory.Query().
		Where(
			ratehistory.CurrencyCodeEQ(code),
			ratehistory.RateDateGTE(from),
			ratehistory.RateDateLTE(to),
		).
		Order(currencyent.Asc(ratehistory.FieldRateDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query rate range: %w", err)
	}
	out := make([]domain.RateHistory, 0, len(rows))
	for _, row := range rows {
		out = append(out, toDomainRateHistory(row))
	}
	return out, nil
}

// Save inserts one daily rate row. UNIQUE(currency_code, rate_date) guards
// against duplicate days; the daily scheduler is the sole writer.
func (r *RateHistoryRepository) Save(ctx context.Context, rh domain.RateHistory) error {
	if err := r.client.RateHistory.Create().
		SetCurrencyCode(rh.CurrencyCode).
		SetRateDate(rh.RateDate).
		SetExchangeRate(rh.ExchangeRate).
		Exec(ctx); err != nil {
		return fmt.Errorf("save rate history: %w", err)
	}
	return nil
}

func toDomainRateHistory(row *currencyent.RateHistory) domain.RateHistory {
	return domain.RateHistory{
		ID:           row.ID,
		CurrencyCode: row.CurrencyCode,
		RateDate:     row.RateDate,
		ExchangeRate: row.ExchangeRate,
		CreatedAt:    row.CreatedAt,
	}
}

var _ domain.RateHistoryRepository = (*RateHistoryRepository)(nil)
