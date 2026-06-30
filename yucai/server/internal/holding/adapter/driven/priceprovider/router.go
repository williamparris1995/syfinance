package priceprovider

import (
	"context"
	"errors"
)

// CompositeRouter routes FetchPrice to the first provider that covers the
// security. ErrNoSource from a provider means "try the next"; any other
// error is a real failure and is propagated immediately (the service logs
// it and counts it as failed, but does not abort the batch). If every
// provider returns ErrNoSource, the router returns ErrNoSource.
type CompositeRouter struct {
	providers []Provider
}

// NewCompositeRouter builds a CompositeRouter from an ordered provider list.
// Order matters: put specific providers (e.g. SinaProvider) before the
// StubProvider fallback.
func NewCompositeRouter(providers ...Provider) *CompositeRouter {
	return &CompositeRouter{providers: providers}
}

func (r *CompositeRouter) FetchPrice(ctx context.Context, v PriceView) (int64, string, error) {
	for _, p := range r.providers {
		price, source, err := p.FetchPrice(ctx, v)
		if err == nil {
			return price, source, nil
		}
		if !errors.Is(err, ErrNoSource) {
			return 0, "", err
		}
	}
	return 0, "", ErrNoSource
}
