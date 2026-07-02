package scheduler

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
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

type mockTenantLister struct {
	ids []uuid.UUID
}

func (m *mockTenantLister) FindAllIDs(_ context.Context) ([]uuid.UUID, error) {
	return m.ids, nil
}

type mockGoalSyncer struct {
	calls     atomic.Int64
	perTenant int                 // returned count per tenant
	errOn     map[uuid.UUID]error // simulate per-tenant error
}

func (m *mockGoalSyncer) SyncAllGoals(_ context.Context, tenantID uuid.UUID) (int, error) {
	m.calls.Add(1)
	if m.errOn != nil {
		if e, ok := m.errOn[tenantID]; ok {
			return 0, e
		}
	}
	return m.perTenant, nil
}

func TestStartRunsOnceImmediately(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	lister := &mockTenantLister{ids: []uuid.UUID{uuid.New(), uuid.New()}}
	syncer := &mockGoalSyncer{perTenant: 2}
	s := NewScheduler(syncer, lister, src, 10*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	// Immediate doSync fans out across both tenants (2 calls).
	if !waitForCalls(syncer, 2, 50*time.Millisecond) {
		t.Fatalf("SyncAllGoals not fanned out within 50ms; calls=%d", syncer.calls.Load())
	}
}

func TestStartDoesNotSyncBeforeInterval(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	lister := &mockTenantLister{ids: []uuid.UUID{uuid.New()}}
	syncer := &mockGoalSyncer{perTenant: 1}
	s := NewScheduler(syncer, lister, src, 5*time.Millisecond, nil)

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
	lister := &mockTenantLister{ids: []uuid.UUID{uuid.New()}}
	syncer := &mockGoalSyncer{perTenant: 1}
	s := NewScheduler(syncer, lister, src, 5*time.Millisecond, nil)

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

func TestSyncNowContinuesPastTenantError(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	good := uuid.New()
	bad := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{good, bad}}
	syncer := &mockGoalSyncer{
		perTenant: 3,
		errOn:     map[uuid.UUID]error{bad: errors.New("upstream holding provider unavailable")},
	}
	s := NewScheduler(syncer, lister, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	count, err := s.SyncNow(ctx)
	if err != nil {
		t.Fatalf("per-tenant error must not propagate; got %v", err)
	}
	// Both tenants attempted; only the good one contributes.
	if got := syncer.calls.Load(); got != 2 {
		t.Fatalf("expected both tenants attempted; calls=%d", got)
	}
	if count != 3 {
		t.Fatalf("count should Σ only successful tenants; got %d want 3", count)
	}
}

func TestSyncNowCtxCancelledShortCircuits(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	lister := &mockTenantLister{ids: []uuid.UUID{uuid.New()}}
	syncer := &mockGoalSyncer{perTenant: 1}
	s := NewScheduler(syncer, lister, src, time.Hour, nil)

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

func waitForCalls(syncer *mockGoalSyncer, want int64, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if syncer.calls.Load() >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return syncer.calls.Load() >= want
}
