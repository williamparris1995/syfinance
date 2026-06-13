package exchangerate

import "context"

// Provider is the port interface for exchange rate data sources.
type Provider interface {
	// FetchRate retrieves the exchange rate for the given currency code.
	FetchRate(ctx context.Context, code string) (float64, error)
}
