package priceprovider

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestYahooFetchHistoryParsesChart(t *testing.T) {
	close129, close130 := 129.41, 130.92
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") == "" {
			t.Errorf("missing User-Agent header")
		}
		if path := r.URL.Path; path != "/v8/finance/chart/AAPL" {
			t.Errorf("path = %q, want /v8/finance/chart/AAPL", path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"chart": map[string]interface{}{
				"result": []map[string]interface{}{
					{
						"timestamp": []int64{1609459200, 1609545600},
						"indicators": map[string]interface{}{
							"quote": []map[string]interface{}{
								{"close": []*float64{&close129, &close130}},
							},
						},
					},
				},
			},
		})
	}))
	defer srv.Close()

	p := newYahooProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 2 {
		t.Fatalf("got %d points, want 2", len(pts))
	}
	if pts[0].PriceCents != 12941 || pts[1].PriceCents != 13092 {
		t.Errorf("prices = %d/%d, want 12941/13092", pts[0].PriceCents, pts[1].PriceCents)
	}
	// UTC date truncation: 1609459200 = 2021-01-01 00:00:00 UTC.
	wantDate := time.Unix(1609459200, 0).UTC().Truncate(24 * time.Hour)
	if !pts[0].Date.Equal(wantDate) {
		t.Errorf("date = %v, want %v", pts[0].Date, wantDate)
	}
}

func TestYahooNullCloseSkipped(t *testing.T) {
	close130 := 130.92
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"chart": map[string]interface{}{
				"result": []map[string]interface{}{
					{
						"timestamp": []int64{1609459200, 1609545600},
						"indicators": map[string]interface{}{
							"quote": []map[string]interface{}{
								{"close": []*float64{nil, &close130}},
							},
						},
					},
				},
			},
		})
	}))
	defer srv.Close()

	p := newYahooProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 1 || pts[0].PriceCents != 13092 {
		t.Fatalf("null close must be skipped; got %v", pts)
	}
}

func TestYahoo404NoSource(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "UNKNOWN"}, 30)
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("404 must be ErrNoSource; got %v", err)
	}
}

func TestYahoo403RealError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("403 must be a real error (not ErrNoSource); got %v", err)
	}
}

func TestYahooSymbolConversion(t *testing.T) {
	var gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		_, _ = w.Write([]byte(`{"chart":{"result":[{"timestamp":[],"indicators":{"quote":[{"close":[]}]}}]}}`))
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, _ = p.FetchHistory(context.Background(), PriceView{Symbol: "BRK.B"}, 30)
	if gotPath != "/v8/finance/chart/BRK-B" {
		t.Errorf("BRK.B → path %q, want /v8/finance/chart/BRK-B", gotPath)
	}
}
