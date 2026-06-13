package domain

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Currency is a global reference entity for ISO 4217 currencies.
// No tenant_id — shared across all tenants.
type Currency struct {
	ID           uuid.UUID
	Code         string // ISO 4217, e.g. "CNY"
	Name         string // e.g. "Chinese Yuan"
	Symbol       string // e.g. "¥"
	ExchangeRate float64
	IsActive     bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// NewCurrency creates a new currency.
func NewCurrency(code, name, symbol string, exchangeRate float64) (*Currency, error) {
	code = strings.ToUpper(strings.TrimSpace(code))
	if code == "" {
		return nil, fmt.Errorf("currency code must not be empty")
	}
	if len(code) != 3 {
		return nil, fmt.Errorf("currency code must be 3 characters (ISO 4217)")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("currency name must not be empty")
	}
	if exchangeRate <= 0 {
		return nil, fmt.Errorf("exchange rate must be positive")
	}
	now := time.Now()
	return &Currency{
		ID: uuid.New(), Code: code, Name: name, Symbol: symbol,
		ExchangeRate: exchangeRate, IsActive: true,
		CreatedAt: now, UpdatedAt: now,
	}, nil
}

// UpdateRate updates the exchange rate.
func (c *Currency) UpdateRate(rate float64) error {
	if rate <= 0 {
		return fmt.Errorf("exchange rate must be positive")
	}
	c.ExchangeRate = rate
	c.UpdatedAt = time.Now()
	return nil
}

// Deactivate marks the currency as inactive.
func (c *Currency) Deactivate() {
	c.IsActive = false
	c.UpdatedAt = time.Now()
}

// Activate marks the currency as active.
func (c *Currency) Activate() {
	c.IsActive = true
	c.UpdatedAt = time.Now()
}
