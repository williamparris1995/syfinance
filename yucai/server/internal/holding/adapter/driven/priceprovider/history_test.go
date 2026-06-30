package priceprovider

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"
)

// sinaKLineOrdered builds a fake CN_MarketDataService.getKLineData JSONP
// response. Format: var _=<json array>;  where each el is
// {"day":"YYYY-MM-DD","open":...,"close":"<close>",...}.
// Output is deterministic: dates sorted ascending.
func sinaKLineOrdered(closes map[string]float64) string {
	type pt struct {
		day   string
		close float64
	}
	pts := make([]pt, 0, len(closes))
	for d, c := range closes {
		pts = append(pts, pt{d, c})
	}
	// sort by day for determinism
	for i := 0; i < len(pts); i++ {
		for j := i + 1; j < len(pts); j++ {
			if pts[j].day < pts[i].day {
				pts[i], pts[j] = pts[j], pts[i]
			}
		}
	}
	out := `var _=[`
	for i, p := range pts {
		if i > 0 {
			out += ","
		}
		out += `{"day":"` + p.day + `","open":"1","high":"1","low":"1","close":"` +
			strconv.FormatFloat(p.close, 'f', 2, 64) + `","volume":"0"}`
	}
	out += `];`
	return out
}

func TestSinaFetchHistoryNotCoveredExchange(t *testing.T) {
	p := NewSinaProvider()
	for _, ex := range []string{"NASDAQ", "OTC", ""} {
		_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "X", Exchange: ex}, 30)
		if !errors.Is(err, ErrNoSource) {
			t.Fatalf("exchange %q must be ErrNoSource; got %v", ex, err)
		}
	}
}

func TestSinaFetchHistoryParsesKLine(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// assert symbol passed in query
		if q := r.URL.Query().Get("symbol"); q != "sh600519" {
			t.Errorf("symbol query = %q, want sh600519", q)
		}
		_, _ = w.Write([]byte(sinaKLineOrdered(map[string]float64{
			"2025-01-02": 100.0,
			"2025-01-03": 102.50,
		})))
	}))
	defer srv.Close()

	p := newSinaProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 2 {
		t.Fatalf("got %d points, want 2", len(pts))
	}
	if pts[0].PriceCents != 10000 {
		t.Fatalf("pts[0] = %d cents, want 10000 (100.00)", pts[0].PriceCents)
	}
	if pts[1].PriceCents != 10250 {
		t.Fatalf("pts[1] = %d cents, want 10250 (102.50)", pts[1].PriceCents)
	}
	want, _ := time.Parse("2006-01-02", "2025-01-02")
	if !pts[0].Date.Equal(want) {
		t.Fatalf("pts[0].Date = %v, want %v", pts[0].Date, want)
	}
}

func TestSinaFetchHistoryHttpError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"}, 30)
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("HTTP 500 must be real error; got %v", err)
	}
}
