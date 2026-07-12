package priceprovider

import (
	"context"
	"errors"
)

// HistoricalRouter routes FetchHistory to the first HistoricalProvider that
// covers the security. ErrNoSource from a provider means "try the next"; any
// other error is a real failure and propagates immediately (BackfillPriceHistory
// logs it and skips the security, but does not abort the batch). If every
// provider returns ErrNoSource, the router returns ErrNoSource.
//
// Mirrors CompositeRouter (FetchPrice routing). Ordered: SinaProvider
// (A-share SSE/SZSE + CSI300) → YahooProvider (non A-share fallback).
type HistoricalRouter struct {
	providers []HistoricalProvider
}

// NewHistoricalRouter builds a HistoricalRouter from an ordered provider list.
// Order matters: put specific providers (SinaProvider) before the broader
// fallback (YahooProvider).
func NewHistoricalRouter(providers ...HistoricalProvider) *HistoricalRouter {
	return &HistoricalRouter{providers: providers}
}

// FetchHistory implements HistoricalProvider (structural). Iterates providers
// in order; returns the first non-ErrNoSource result.
func (r *HistoricalRouter) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
	for _, p := range r.providers {
		pts, err := p.FetchHistory(ctx, v, datalen)
		if err == nil {
			return pts, nil
		}
		if !errors.Is(err, ErrNoSource) {
			return nil, err // real error → propagate, stop search
		}
	}
	return nil, ErrNoSource // all providers no-source
}
