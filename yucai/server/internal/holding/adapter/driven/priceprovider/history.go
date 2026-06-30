package priceprovider

import (
	"context"
	"time"
)

// HistoryPoint is one daily price from a historical fetch (backfill).
type HistoryPoint struct {
	Date       time.Time
	PriceCents int64
}

// HistoricalProvider fetches daily K-line history for backfill. Only
// SinaProvider implements this (A-share + CSI300). The application calls it
// directly (not via Router) during backfill; non-covered exchanges return
// ErrNoSource. datalen is the requested number of bars (DAY 30 / MONTH 250 /
// YEAR 1200).
type HistoricalProvider interface {
	FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error)
}
