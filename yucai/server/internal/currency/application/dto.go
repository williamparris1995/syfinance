package application

import (
	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/domain"
)

// CurrencyDTO is the read model for currencies.
type CurrencyDTO struct {
	ID           uuid.UUID
	Code         string
	Name         string
	Symbol       string
	ExchangeRate float64
	IsActive     bool
}

// AddCurrencyRequest holds parameters for creating a currency.
type AddCurrencyRequest struct {
	Code         string
	Name         string
	Symbol       string
	ExchangeRate float64
}

// ListCurrenciesResult holds a paginated list of currencies.
type ListCurrenciesResult struct {
	Currencies    []CurrencyDTO
	NextPageToken string
	TotalCount    int32
}

// CurrencyToDTO converts a domain Currency to a DTO.
func CurrencyToDTO(c *domain.Currency) CurrencyDTO {
	return CurrencyDTO{
		ID: c.ID, Code: c.Code, Name: c.Name, Symbol: c.Symbol,
		ExchangeRate: c.ExchangeRate, IsActive: c.IsActive,
	}
}
