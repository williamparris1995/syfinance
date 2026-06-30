package scheduler

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type fakeIntervalSource struct {
	hours int
	mu    sync.Mutex
}

func (f *fakeIntervalSource) MinIntervalHours(_ context.Context) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.hours
}

type mockSyncer struct {
	calls atomic.Int64
	err   error
}

func (m *mockSyncer) SyncPrices(_ context.Context) (int, error) {
	m.calls.Add(1)
	if m.err != nil {
		return 0, m.err
	}
	return 3, nil
}

func TestStartRunsOnceImmediately(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 10*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCalls(syncer, 1, 50*time.Millisecond) {
		t.Fatalf("SyncPrices not called within 50ms; calls=%d", syncer.calls.Load())
	}
}

func TestStartDoesNotSyncBeforeInterval(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCalls(syncer, 1, 100*time.Millisecond) {
		t.Fatalf("initial sync did not occur; calls=%d", syncer.calls.Load())
	}
	initial := syncer.calls.Load()
	time.Sleep(40 * time.Millisecond)
	if got := syncer.calls.Load(); got != initial {
		t.Fatalf("unexpected extra sync: initial=%d now=%d", initial, got)
	}
}

func TestCtxCancelStopsGoroutine(t *testing.T) {
	src := &fakeIntervalSource{hours: 0}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	if !waitForCalls(syncer, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple syncs before cancel; calls=%d", syncer.calls.Load())
	}
	beforeCancel := syncer.calls.Load()

	cancel()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Start did not return after ctx cancel")
	}

	time.Sleep(30 * time.Millisecond)
	if got := syncer.calls.Load(); got > beforeCancel+1 {
		t.Fatalf("goroutine synced after cancel; before=%d after=%d", beforeCancel, got)
	}
}

func TestSyncNowPropagatesError(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	wantErr := errors.New("upstream price provider unavailable")
	syncer := &mockSyncer{err: wantErr}
	s := NewScheduler(syncer, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	count, err := s.SyncNow(ctx)
	if !errors.Is(err, wantErr) {
		t.Fatalf("SyncNow did not propagate error; got %v want %v", err, wantErr)
	}
	if count != 0 {
		t.Fatalf("count on error should be 0; got %d", count)
	}
}

func TestSyncNowCtxCancelledShortCircuits(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	before := syncer.calls.Load()
	count, err := s.SyncNow(ctx)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled; got %v", err)
	}
	if count != 0 {
		t.Fatalf("count on cancelled ctx should be 0; got %d", count)
	}
	if got := syncer.calls.Load(); got != before {
		t.Fatalf("doSync should not call syncer on cancelled ctx; before=%d after=%d", before, got)
	}
}

func waitForCalls(syncer *mockSyncer, want int64, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if syncer.calls.Load() >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return syncer.calls.Load() >= want
}
