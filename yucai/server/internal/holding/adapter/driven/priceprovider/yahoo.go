package priceprovider

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"time"
)

// YahooProvider fetches daily K-line history from Yahoo Finance
// (query1.finance.yahoo.com/v8/finance/chart). Free, no API key. Covers any
// symbol Yahoo knows (US stocks/ETFs, HK, global) — used as the fallback
// after SinaProvider (which covers A-share SSE/SZSE + CSI300 only).
//
// Returns ErrNoSource on HTTP 404 (symbol not in Yahoo); HTTP 403/429
// (rate-limit) are real errors so BackfillPriceHistory logs + skips the
// security (best-effort, mirroring Sina SyncPrices). No retry/rate-limit
// sleep (YAGNI; rerun the BackfillPriceHistory RPC to refill skips).
type YahooProvider struct {
	baseURL string
	client  *http.Client
}

// NewYahooProvider builds a YahooProvider pointing at the public endpoint.
func NewYahooProvider() *YahooProvider {
	return &YahooProvider{
		baseURL: "https://query1.finance.yahoo.com",
		client:  &http.Client{Timeout: 10 * time.Second},
	}
}

// newYahooProviderWithURL is the test seam: point at a httptest server.
func newYahooProviderWithURL(baseURL string) *YahooProvider {
	return &YahooProvider{baseURL: baseURL, client: &http.Client{Timeout: 5 * time.Second}}
}

// yahooChartResponse matches the v8 chart API JSON shape. close is []*float64
// so null entries (holiday/missing) decode to nil and can be skipped distinctly
// from a real 0.0 price (which stocks never have).
type yahooChartResponse struct {
	Chart struct {
		Result []struct {
			Timestamp []int64 `json:"timestamp"`
			Indicators struct {
				Quote []struct {
					Close []*float64 `json:"close"`
				} `json:"quote"`
			} `json:"indicators"`
		} `json:"result"`
	} `json:"chart"`
}

// FetchHistory fetches daily K-line history from Yahoo chart API.
// datalen is the number of bars requested (DAY 30 / MONTH 250 / YEAR 1200).
func (p *YahooProvider) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
	sym := yahooSymbol(v.Symbol)
	period1 := time.Now().AddDate(0, 0, -datalen).Unix()
	period2 := time.Now().Unix()
	url := fmt.Sprintf("%s/v8/finance/chart/%s?period1=%d&period2=%d&interval=1d",
		p.baseURL, sym, period1, period2)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("yahoo history build request: %w", err)
	}
	// Yahoo chart API rejects requests without a browser-like User-Agent (HTTP 403).
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("yahoo history request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, ErrNoSource // symbol not in Yahoo → router falls through
	}
	if resp.StatusCode != http.StatusOK {
		// 403/429 (rate-limit) → real error; BackfillPriceHistory logs + skips.
		return nil, fmt.Errorf("yahoo history status %d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("yahoo history read body: %w", err)
	}
	var yc yahooChartResponse
	if err := json.Unmarshal(raw, &yc); err != nil {
		return nil, fmt.Errorf("yahoo history parse json: %w", err)
	}
	if len(yc.Chart.Result) == 0 {
		return nil, ErrNoSource // empty result → no data for this symbol
	}
	res := yc.Chart.Result[0]
	if len(res.Indicators.Quote) == 0 {
		return nil, fmt.Errorf("yahoo history: no quote indicators")
	}
	closes := res.Indicators.Quote[0].Close
	pts := make([]HistoryPoint, 0, len(res.Timestamp))
	for i, ts := range res.Timestamp {
		if i >= len(closes) || closes[i] == nil {
			continue // null close (holiday/missing) → skip
		}
		pts = append(pts, HistoryPoint{
			// UTC midnight: Yahoo timestamp is UTC sec; Truncate(24h) gives the
			// trading-day UTC date (US EST 9:30 open = 14:30 UTC, same calendar day).
			Date:       time.Unix(ts, 0).UTC().Truncate(24 * time.Hour),
			PriceCents: int64(math.Round(*closes[i] * 100)),
		})
	}
	return pts, nil
}

// yahooSymbol maps a security symbol to Yahoo's chart-API form: Yahoo uses
// '-' in place of '.' (BRK.B → BRK-B, BRK.A → BRK-A). Other symbols pass
// through unchanged.
func yahooSymbol(symbol string) string {
	return strings.ReplaceAll(strings.TrimSpace(symbol), ".", "-")
}
