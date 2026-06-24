package exchangerate

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newTestServer(status int, payload any) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		if payload != nil {
			_ = json.NewEncoder(w).Encode(payload)
		}
	}))
}

func TestFrankfurterProvider_FetchRates(t *testing.T) {
	srv := newTestServer(http.StatusOK, map[string]any{
		"base":  "EUR",
		"date":  "2026-06-24",
		"rates": map[string]float64{"USD": 1.08, "CNY": 7.81, "GBP": 0.86},
	})
	defer srv.Close()

	p := &FrankfurterProvider{baseURL: srv.URL, client: srv.Client()}
	got, err := p.FetchRates(context.Background(), []string{"USD", "CNY", "GBP", "EUR"})
	if err != nil {
		t.Fatalf("FetchRates returned error: %v", err)
	}
	want := map[string]float64{"USD": 1.08, "CNY": 7.81, "GBP": 0.86, "EUR": 1.0}
	if len(got) != len(want) {
		t.Fatalf("got %d rates, want %d: %v", len(got), len(want), got)
	}
	for k, v := range want {
		if got[k] != v {
			t.Errorf("rate[%s] = %v, want %v", k, got[k], v)
		}
	}
}

func TestFrankfurterProvider_FetchRates_HTTPError(t *testing.T) {
	srv := newTestServer(http.StatusInternalServerError, nil)
	defer srv.Close()

	p := &FrankfurterProvider{baseURL: srv.URL, client: srv.Client()}
	_, err := p.FetchRates(context.Background(), []string{"USD"})
	if err == nil {
		t.Fatal("expected error for HTTP 500, got nil")
	}
}

func TestFrankfurterProvider_FetchRates_EmptyCodes(t *testing.T) {
	srv := newTestServer(http.StatusOK, map[string]any{
		"base":  "EUR",
		"date":  "2026-06-24",
		"rates": map[string]float64{},
	})
	defer srv.Close()

	p := &FrankfurterProvider{baseURL: srv.URL, client: srv.Client()}
	got, err := p.FetchRates(context.Background(), nil)
	if err != nil {
		t.Fatalf("FetchRates returned error: %v", err)
	}
	if len(got) != 1 || got["EUR"] != 1.0 {
		t.Fatalf("got %v, want {EUR:1.0} for empty codes", got)
	}
}

func TestFrankfurterProvider_FetchRate(t *testing.T) {
	srv := newTestServer(http.StatusOK, map[string]any{
		"base":  "EUR",
		"date":  "2026-06-24",
		"rates": map[string]float64{"USD": 1.08},
	})
	defer srv.Close()

	p := &FrankfurterProvider{baseURL: srv.URL, client: srv.Client()}
	got, err := p.FetchRate(context.Background(), "USD")
	if err != nil {
		t.Fatalf("FetchRate returned error: %v", err)
	}
	if got != 1.08 {
		t.Errorf("FetchRate = %v, want 1.08", got)
	}
}

func TestFrankfurterProvider_FetchRate_NotFound(t *testing.T) {
	srv := newTestServer(http.StatusOK, map[string]any{
		"base":  "EUR",
		"date":  "2026-06-24",
		"rates": map[string]float64{"USD": 1.08},
	})
	defer srv.Close()

	p := &FrankfurterProvider{baseURL: srv.URL, client: srv.Client()}
	_, err := p.FetchRate(context.Background(), "XXX")
	if err == nil || !errors.Is(err, err) {
		t.Fatalf("expected error for unknown currency, got %v", err)
	}
}
