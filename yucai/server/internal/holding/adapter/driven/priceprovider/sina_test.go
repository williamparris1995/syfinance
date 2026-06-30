package priceprovider

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
)

func TestSinaNotCoveredExchange(t *testing.T) {
	p := NewSinaProvider()
	for _, ex := range []string{"NASDAQ", "OTC", "SGE", ""} {
		_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "X", Exchange: ex})
		if !errors.Is(err, ErrNoSource) {
			t.Fatalf("exchange %q must be ErrNoSource; got %v", ex, err)
		}
	}
}

// gbkQuote builds a fake sinajs response matching the REAL format: security
// name AND numeric fields are all INSIDE the double quotes (verified against
// hq.sinajs.cn live: var hq_str_sh600519="贵州茅台,open,prevClose,current,...").
// After the name, fields are: open(0), prevClose(1), current(2), high(3)...
// ASCII name keeps the payload valid UTF-8 (ASCII is a 1:1 subset of GBK),
// so the GBK decoder yields the same bytes and the test is deterministic.
func gbkQuote(current float64) []byte {
	return []byte("var hq_str_sh600519=\"TEST,35.00,34.50," +
		strconv.FormatFloat(current, 'f', 2, 64) + ",36.00,34.00,0,0,0,0,0,0,0,0,2024-01-02,15:00:00,00,\";")
}

func TestSinaCoversSSEAndSZSE(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Referer"); got != "https://finance.sina.com.cn" {
			t.Errorf("missing/wrong Referer: %q", got)
		}
		_, _ = w.Write(gbkQuote(34.80))
	}))
	defer srv.Close()

	p := newSinaProviderWithURL(srv.URL)
	for _, ex := range []string{"SSE", "SZSE"} {
		price, src, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: ex})
		if err != nil {
			t.Fatalf("exchange %s: unexpected error: %v", ex, err)
		}
		if price != 3480 {
			t.Fatalf("exchange %s: got %d cents, want 3480", ex, price)
		}
		if src != "sina" {
			t.Fatalf("source = %q, want sina", src)
		}
	}
}

func TestSinaHttpErrorPropagated(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("HTTP 500 must be a real error; got %v", err)
	}
}

func TestSinaEmptyQuoteIsError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("var hq_str_sh000000=\"\";"))
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "000000", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("empty quote must be a real error; got %v", err)
	}
}
