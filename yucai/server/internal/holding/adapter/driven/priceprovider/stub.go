package priceprovider

import "context"

// StubProvider is the terminal fallback: it covers nothing and returns
// ErrNoSource for every security. Non A-share types (US stock, OTC fund,
// SGE gold, option) land here in the first batch, meaning "no auto source"
// — their price stays at the manually-entered value (we never fabricate).
// Replace by appending a real provider before it in the router.
type StubProvider struct{}

// NewStubProvider builds a StubProvider.
func NewStubProvider() *StubProvider { return &StubProvider{} }

// FetchPrice always returns ErrNoSource.
func (p *StubProvider) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	return 0, "", ErrNoSource
}
