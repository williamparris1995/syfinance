package scheduler

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// mockSnapshotter implements Snapshotter for the SnapshotScheduler tests.
// fakeIntervalSource and waitForCalls are shared with scheduler_test.go
// (same package).
type mockSnapshotter struct {
	calls atomic.Int64
	err   error
}

func (m *mockSnapshotter) SnapshotAllHoldings(_ context.Context) (int, error) {
	m.calls.Add(1)
	if m.err != nil {
		return 0, m.err
	}
	return 5, nil
}

func TestSnapshotStartRunsOnceImmediately(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSnapshotter{}
	s := NewSnapshotScheduler(syncer, src, 10*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForSnapshotCalls(syncer, 1, 50*time.Millisecond) {
		t.Fatalf("SnapshotAllHoldings not called within 50ms; calls=%d", syncer.calls.Load())
	}
}

func TestSnapshotStartDoesNotSyncBeforeInterval(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSnapshotter{}
	s := NewSnapshotScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForSnapshotCalls(syncer, 1, 100*time.Millisecond) {
		t.Fatalf("initial snapshot did not occur; calls=%d", syncer.calls.Load())
	}
	initial := syncer.calls.Load()
	time.Sleep(40 * time.Millisecond)
	if got := syncer.calls.Load(); got != initial {
		t.Fatalf("unexpected extra snapshot: initial=%d now=%d", initial, got)
	}
}

func TestSnapshotCtxCancelStopsGoroutine(t *testing.T) {
	src := &fakeIntervalSource{hours: 0}
	syncer := &mockSnapshotter{}
	s := NewSnapshotScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	if !waitForSnapshotCalls(syncer, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple snapshots before cancel; calls=%d", syncer.calls.Load())
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
		t.Fatalf("goroutine snapshotted after cancel; before=%d after=%d", beforeCancel, got)
	}
}

func TestSnapshotSyncNowPropagatesError(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	wantErr := errors.New("snapshot repo unavailable")
	syncer := &mockSnapshotter{err: wantErr}
	s := NewSnapshotScheduler(syncer, src, time.Hour, nil)

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

func TestSnapshotSyncNowCtxCancelledShortCircuits(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSnapshotter{}
	s := NewSnapshotScheduler(syncer, src, time.Hour, nil)

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

func waitForSnapshotCalls(syncer *mockSnapshotter, want int64, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if syncer.calls.Load() >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return syncer.calls.Load() >= want
}
