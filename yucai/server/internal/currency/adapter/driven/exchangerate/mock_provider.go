package exchangerate

import (
	"context"
	"fmt"
)

// MockProvider returns static exchange rates for development/testing.
// In production, this will be replaced with a real API provider (e.g. exchangerate-api.com).
type MockProvider struct {
	rates map[string]float64
}

// NewMockProvider creates a MockProvider with common currencies.
func NewMockProvider() *MockProvider {
	return &MockProvider{
		rates: map[string]float64{
			"CNY": 1.0,
			"USD": 7.2,
			"EUR": 7.8,
			"JPY": 0.048,
			"GBP": 9.1,
			"HKD": 0.92,
			"SGD": 5.3,
		},
	}
}

// FetchRate returns the mock rate for a currency code.
func (p *MockProvider) FetchRate(ctx context.Context, code string) (float64, error) {
	rate, ok := p.rates[code]
	if !ok {
		return 0, fmt.Errorf("rate not available for currency %s", code)
	}
	return rate, nil
}
