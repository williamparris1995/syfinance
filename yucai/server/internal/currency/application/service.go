package application

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	"github.com/yucai/server/internal/currency/domain"
)

// Service orchestrates currency operations.
type Service struct {
	repo           domain.CurrencyRepository
	provider       exchangerate.Provider
	rateHistoryRepo domain.RateHistoryRepository // C: daily rate history (nil = skip history write)
}

// NewService creates a new currency application service.
func NewService(repo domain.CurrencyRepository, provider exchangerate.Provider) *Service {
	return &Service{repo: repo, provider: provider}
}

// SetRateHistoryRepository injects the FX rate history repo (Task 7 C). When
// set, SyncRates records one daily rate point per updated currency (idempotent
// via UNIQUE(currency_code, rate_date)). Structural — holding's repo also
// satisfies this; wire binds currency's own RateHistoryRepository.
func (s *Service) SetRateHistoryRepository(r domain.RateHistoryRepository) {
	s.rateHistoryRepo = r
}

// truncateToDate clips a time to 00:00 UTC of its day, so same-day re-syncs
// land on the same rate_history row (UNIQUE(currency_code, rate_date) guard).
func truncateToDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// AddCurrency creates a new global currency.
func (s *Service) AddCurrency(ctx context.Context, req AddCurrencyRequest) (*CurrencyDTO, error) {
	currency, err := domain.NewCurrency(req.Code, req.Name, req.Symbol, req.ExchangeRate)
	if err != nil {
		return nil, fmt.Errorf("create currency: %w", err)
	}
	if err := s.repo.Save(ctx, currency); err != nil {
		return nil, fmt.Errorf("save currency: %w", err)
	}
	dto := CurrencyToDTO(currency)
	return &dto, nil
}

// UpdateExchangeRate updates the rate of an existing currency.
func (s *Service) UpdateExchangeRate(ctx context.Context, id uuid.UUID, rate float64) (*CurrencyDTO, error) {
	currency, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find currency: %w", err)
	}
	if err := currency.UpdateRate(rate); err != nil {
		return nil, fmt.Errorf("update rate: %w", err)
	}
	if err := s.repo.Update(ctx, currency); err != nil {
		return nil, fmt.Errorf("update currency: %w", err)
	}
	dto := CurrencyToDTO(currency)
	return &dto, nil
}

// FetchExchangeRate retrieves the current rate from the external provider.
func (s *Service) FetchExchangeRate(ctx context.Context, code string) (float64, error) {
	rate, err := s.provider.FetchRate(ctx, code)
	if err != nil {
		return 0, fmt.Errorf("fetch rate: %w", err)
	}
	return rate, nil
}

// ListCurrencies returns paginated currencies.
func (s *Service) ListCurrencies(ctx context.Context, activeOnly bool, page domain.PageRequest) (*ListCurrenciesResult, error) {
	result, err := s.repo.FindAll(ctx, activeOnly, page)
	if err != nil {
		return nil, fmt.Errorf("list currencies: %w", err)
	}
	dtos := make([]CurrencyDTO, len(result.Items))
	for i, c := range result.Items {
		dtos[i] = CurrencyToDTO(&c)
	}
	return &ListCurrenciesResult{
		Currencies:    dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// SyncRates fetches fresh rates from the provider and bulk-updates all active currencies.
// Currencies without a returned rate (or non-positive rate) are skipped. Returns the
// count of currencies actually updated.
func (s *Service) SyncRates(ctx context.Context) (int, error) {
	active, err := s.repo.FindAllActive(ctx)
	if err != nil {
		return 0, fmt.Errorf("list active currencies: %w", err)
	}
	codes := make([]string, 0, len(active))
	for _, c := range active {
		codes = append(codes, c.Code)
	}
	rates, err := s.provider.FetchRates(ctx, codes)
	if err != nil {
		return 0, fmt.Errorf("fetch rates: %w", err)
	}
	updated := 0
	for i := range active {
		c := &active[i]
		r, ok := rates[c.Code]
		if !ok || r <= 0 {
			continue
		}
		if err := c.UpdateRate(r); err != nil {
			continue
		}
		if err := s.repo.Update(ctx, c); err != nil {
			return updated, fmt.Errorf("update currency %s: %w", c.Code, err)
		}
		// C: record daily rate history point (idempotent — same-day re-sync hits
		// the same row via UNIQUE(currency_code, rate_date); a duplicate is logged
		// and skipped, not fatal). Mirrors holding SyncPrices writing price_history.
		if s.rateHistoryRepo != nil {
			rh := domain.RateHistory{
				ID:           uuid.New(),
				CurrencyCode: c.Code,
				RateDate:     truncateToDate(time.Now()),
				ExchangeRate: r,
			}
			if err := s.rateHistoryRepo.Save(ctx, rh); err != nil {
				slog.Warn("currency rate sync: save history failed",
					slog.String("code", c.Code),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncRates"))
				// not fatal — rate_history missing just means thinner curves
			}
		}
		updated++
	}
	return updated, nil
}

// defaultCurrencies are the built-in reference currencies seeded at startup.
// Rates are EUR-base (frankfurter convention: rate[EUR] = 1.0). SyncRates
// refreshes these from frankfurter; currencies frankfurter does not serve
// (e.g. HKD) keep these fallback rates.
var defaultCurrencies = []struct {
	code, name, symbol string
	rate               float64
}{
	{"EUR", "Euro", "€", 1.0},
	{"USD", "US Dollar", "$", 1.08},
	{"CNY", "Chinese Yuan", "¥", 7.8},
	{"GBP", "British Pound", "£", 0.85},
	{"HKD", "Hong Kong Dollar", "HK$", 8.4},
	{"JPY", "Japanese Yen", "¥", 170},
}

// SeedDefaults ensures the built-in reference currencies exist. Idempotent:
// currencies already present (by code) are skipped; a Save that hits a unique
// constraint (concurrent seed) is also skipped. Returns the count created.
// Runs at server startup so the rate-sync scheduler and the client currency
// dropdown always have reference data even before the first frankfurter fetch.
func (s *Service) SeedDefaults(ctx context.Context) (int, error) {
	created := 0
	for _, d := range defaultCurrencies {
		if existing, err := s.repo.FindByCode(ctx, d.code); err == nil && existing != nil {
			continue
		}
		c, err := domain.NewCurrency(d.code, d.name, d.symbol, d.rate)
		if err != nil {
			return created, fmt.Errorf("new currency %s: %w", d.code, err)
		}
		if err := s.repo.Save(ctx, c); err != nil {
			// FindByCode returned a NotFound (wrapped), but a concurrent seed
			// already inserted this code → unique-constraint violation. Skip.
			continue
		}
		created++
	}
	return created, nil
}
