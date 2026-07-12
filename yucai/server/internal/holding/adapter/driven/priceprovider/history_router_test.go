package priceprovider

import (
	"context"
	"errors"
	"testing"
	"time"
)

// historyProbe is a test HistoricalProvider returning a configured result,
// driving the router through all branches (ok / real-error / no-source).
type historyProbe struct {
	pts []HistoryPoint
	err error
}

func (p *historyProbe) FetchHistory(_ context.Context, _ PriceView, _ int) ([]HistoryPoint, error) {
	return p.pts, p.err
}

func TestHistoricalRouterReturnsFirstCovering(t *testing.T) {
	// First provider no-source (Sina for non-A-share), second covers (Yahoo).
	want := []HistoryPoint{{Date: time.Unix(1609459200, 0).UTC(), PriceCents: 12941}}
	r := NewHistoricalRouter(
		&historyProbe{err: ErrNoSource},
		&historyProbe{pts: want},
	)
	got, err := r.FetchHistory(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 1 || got[0].PriceCents != 12941 {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestHistoricalRouterFallsThroughAllNoSource(t *testing.T) {
	// All no-source → router returns ErrNoSource.
	r := NewHistoricalRouter(&historyProbe{err: ErrNoSource}, &historyProbe{err: ErrNoSource})
	_, err := r.FetchHistory(context.Background(), PriceView{Symbol: "X"}, 30)
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("all-no-source router must return ErrNoSource; got %v", err)
	}
}

func TestHistoricalRouterPropagatesRealError(t *testing.T) {
	// A real (non ErrNoSource) error is propagated, not swallowed.
	wantErr := errors.New("yahoo timeout")
	r := NewHistoricalRouter(&historyProbe{err: ErrNoSource}, &historyProbe{err: wantErr})
	_, err := r.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if !errors.Is(err, wantErr) {
		t.Fatalf("router must propagate real error; got %v want %v", err, wantErr)
	}
}

func TestHistoricalRouterRealErrorStopsSearch(t *testing.T) {
	// If an earlier provider returns a real error, later providers are not tried.
	called := false
	later := &recordingHistoryProbe{onCall: func() { called = true }, pts: []HistoryPoint{{PriceCents: 1}}}
	r := NewHistoricalRouter(&historyProbe{err: errors.New("boom")}, later)
	_, _ = r.FetchHistory(context.Background(), PriceView{}, 30)
	if called {
		t.Fatal("router must not try later provider after a real error")
	}
}

// recordingHistoryProbe records whether FetchHistory was called.
type recordingHistoryProbe struct {
	onCall func()
	pts    []HistoryPoint
}

func (p *recordingHistoryProbe) FetchHistory(_ context.Context, _ PriceView, _ int) ([]HistoryPoint, error) {
	if p.onCall != nil {
		p.onCall()
	}
	return p.pts, nil
}
