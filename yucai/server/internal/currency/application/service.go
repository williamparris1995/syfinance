package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	"github.com/yucai/server/internal/currency/domain"
)

// Service orchestrates currency operations.
type Service struct {
	repo     domain.CurrencyRepository
	provider exchangerate.Provider
}

// NewService creates a new currency application service.
func NewService(repo domain.CurrencyRepository, provider exchangerate.Provider) *Service {
	return &Service{repo: repo, provider: provider}
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
