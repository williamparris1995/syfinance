package priceprovider

import (
	"context"
	"errors"
	"testing"

	"github.com/yucai/server/internal/holding/domain"
)

// stubProbe is a test provider that returns a configured result, letting us
// drive the router through all three branches (ok / real-error / no-source).
type stubProbe struct {
	price  int64
	source string
	err    error
}

func (p *stubProbe) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	return p.price, p.source, p.err
}

func TestStubProviderAlwaysNoSource(t *testing.T) {
	p := NewStubProvider()
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("StubProvider must return ErrNoSource; got %v", err)
	}
}

func TestRouterReturnsFirstCovering(t *testing.T) {
	// First provider no-source, second covers → second wins.
	r := NewCompositeRouter(
		NewStubProvider(),
		&stubProbe{price: 168000, source: "test"},
	)
	price, src, err := r.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if price != 168000 || src != "test" {
		t.Fatalf("got price=%d src=%q, want 168000/test", price, src)
	}
}

func TestRouterFallsThroughNoSource(t *testing.T) {
	// All no-source → router returns ErrNoSource.
	r := NewCompositeRouter(NewStubProvider(), NewStubProvider())
	_, _, err := r.FetchPrice(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"})
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("all-no-source router must return ErrNoSource; got %v", err)
	}
}

func TestRouterPropagatesRealError(t *testing.T) {
	// A real (non ErrNoSource) error is propagated, not swallowed.
	wantErr := errors.New("upstream timeout")
	r := NewCompositeRouter(&stubProbe{err: wantErr})
	_, _, err := r.FetchPrice(context.Background(), PriceView{Type: domain.SecurityTypeStock})
	if !errors.Is(err, wantErr) {
		t.Fatalf("router must propagate real error; got %v want %v", err, wantErr)
	}
}

func TestRouterRealErrorStopsSearch(t *testing.T) {
	// If an earlier provider returns a real error, later providers are not tried.
	called := false
	later := &recordingProbe{onCall: func() { called = true }, err: nil, price: 1}
	r := NewCompositeRouter(&stubProbe{err: errors.New("boom")}, later)
	_, _, _ = r.FetchPrice(context.Background(), PriceView{})
	if called {
		t.Fatal("router must not try later provider after a real error")
	}
}

// recordingProbe records whether FetchPrice was called.
type recordingProbe struct {
	onCall func()
	price  int64
	err    error
}

func (p *recordingProbe) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	if p.onCall != nil {
		p.onCall()
	}
	return p.price, "rec", p.err
}
