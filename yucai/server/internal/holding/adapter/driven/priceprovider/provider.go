// Package priceprovider is the port for security price data sources
// (aligned with currency/adapter/driven/exchangerate). Providers live on
// the server so scheduling, symbol mapping and any future API keys stay
// centralized; the client triggers sync via the SyncPrices RPC.
package priceprovider

import (
	"context"
	"errors"

	"github.com/yucai/server/internal/holding/domain"
)

// ErrNoSource signals that a provider does not cover the given security.
// Routers use it to fall through to the next provider; the service treats
// it as "skip, keep old price" (not a failure).
var ErrNoSource = errors.New("price: no source for security")

// PriceView is the minimal, safe view of a security that a provider needs
// to fetch a price. It does not leak the full Security aggregate.
type PriceView struct {
	Symbol   string
	Exchange string
	Type     domain.SecurityType
}

// Provider is the port interface for price data sources.
type Provider interface {
	// FetchPrice returns the latest price in cents plus a source label.
	// ErrNoSource means this provider does not cover the security.
	FetchPrice(ctx context.Context, v PriceView) (priceCents int64, source string, err error)
}

// Router routes a security to the first covering provider. Implemented by
// CompositeRouter; defined separately so the application service depends on
// the abstraction, not the concrete composite.
type Router interface {
	FetchPrice(ctx context.Context, v PriceView) (priceCents int64, source string, err error)
}
