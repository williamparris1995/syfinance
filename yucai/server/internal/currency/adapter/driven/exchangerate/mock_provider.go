package exchangerate

import (
	"context"
	"fmt"
	"strings"
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

// FetchRates returns a subset of mock rates for the requested codes.
// EUR is forced to 1.0 (rates relative to EUR); unavailable codes are omitted.
func (p *MockProvider) FetchRates(ctx context.Context, codes []string) (map[string]float64, error) {
	out := make(map[string]float64, len(codes)+1)
	out["EUR"] = 1.0
	for _, c := range codes {
		up := strings.ToUpper(strings.TrimSpace(c))
		if up == "" || up == "EUR" {
			continue
		}
		if rate, ok := p.rates[up]; ok {
			out[up] = rate
		}
	}
	return out, nil
}
