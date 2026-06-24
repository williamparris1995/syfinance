package scheduler

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fakeIntervalSource returns a configurable min interval (hours).
type fakeIntervalSource struct {
	hours int
	mu    sync.Mutex
}

func (f *fakeIntervalSource) MinIntervalHours(_ context.Context) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.hours
}

func (f *fakeIntervalSource) set(hours int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.hours = hours
}

// mockSyncer counts SyncRates calls and returns configured n/err.
type mockSyncer struct {
	calls atomic.Int64
	err   error
}

func (m *mockSyncer) SyncRates(_ context.Context) (int, error) {
	m.calls.Add(1)
	if m.err != nil {
		return 0, m.err
	}
	return 3, nil
}

// TestStartRunsOnceImmediately: 启动先 SyncRates 一次。
func TestStartRunsOnceImmediately(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 10*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	// 50ms 内 SyncRates 至少被调一次（启动即调）。
	if !waitForCalls(syncer, 1, 50*time.Millisecond) {
		t.Fatalf("SyncRates not called within 50ms; calls=%d", syncer.calls.Load())
	}
}

// TestStartDoesNotSyncBeforeInterval: 启动后 interval 太大，tick 内不再调。
func TestStartDoesNotSyncBeforeInterval(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	// 等启动那次发生。
	if !waitForCalls(syncer, 1, 100*time.Millisecond) {
		t.Fatalf("initial sync did not occur; calls=%d", syncer.calls.Load())
	}
	initial := syncer.calls.Load()

	// 再等几个 tick，interval 太大，不应再调。
	time.Sleep(40 * time.Millisecond)
	if got := syncer.calls.Load(); got != initial {
		t.Fatalf("unexpected extra sync: initial=%d now=%d", initial, got)
	}
}

// TestCtxCancelStopsGoroutine: ctx cancel 后 goroutine 退出，不再调 SyncRates。
func TestCtxCancelStopsGoroutine(t *testing.T) {
	src := &fakeIntervalSource{hours: 0} // interval=0 → 每 tick 都会同步
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	// 确认有多次调用（interval=0, 每 tick 同步）。
	if !waitForCalls(syncer, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple syncs before cancel; calls=%d", syncer.calls.Load())
	}
	beforeCancel := syncer.calls.Load()

	cancel()
	// Start 应在 cancel 后立即返回。
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Start did not return after ctx cancel")
	}

	// 再等一会，确认 calls 不再增长（goroutine 已退出）。
	time.Sleep(30 * time.Millisecond)
	if got := syncer.calls.Load(); got > beforeCancel+1 {
		t.Fatalf("goroutine synced after cancel; before=%d after=%d", beforeCancel, got)
	}
}

// TestSyncNowTriggersSync: SyncNow 立即触发并更新 lastSync。
func TestSyncNowTriggersSync(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCalls(syncer, 1, 100*time.Millisecond) {
		t.Fatalf("initial sync did not occur; calls=%d", syncer.calls.Load())
	}
	initial := syncer.calls.Load()

	if _, err := s.SyncNow(ctx); err != nil {
		t.Fatalf("SyncNow returned error: %v", err)
	}
	if got := syncer.calls.Load(); got != initial+1 {
		t.Fatalf("SyncNow did not trigger exactly one sync; before=%d after=%d", initial, got)
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
