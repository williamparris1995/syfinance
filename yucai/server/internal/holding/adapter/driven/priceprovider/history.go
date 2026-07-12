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

// HistoricalProvider fetches daily K-line history for backfill. Implementers:
// SinaProvider (A-share SSE/SZSE + CSI300), YahooProvider (non A-share fallback,
// e.g. US/global), and HistoricalRouter which routes to the first covering
// provider (Sina → Yahoo). The application calls this via HistoricalRouter
// (wire-injected) during backfill; exchanges no provider covers return
// ErrNoSource. datalen is the requested number of bars (DAY 30 / MONTH 250 /
// YEAR 1200).
type HistoricalProvider interface {
	FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error)
}
