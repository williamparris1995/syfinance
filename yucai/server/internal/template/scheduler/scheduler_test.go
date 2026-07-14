package scheduler

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	tmplapp "github.com/yucai/server/internal/template/application"
	tmpldomain "github.com/yucai/server/internal/template/domain"
)

// fakeAutoRecorder is a minimal AutoRecorder stand-in. FindDueForAutoRecord
// returns the configured slice (the scheduler trusts the service to apply the
// paused/autoRecord/nextDate filters — those are exercised in
// application/service_test.go); RecordTransaction records each call + errors
// on configured template IDs to simulate per-template failure.
type fakeAutoRecorder struct {
	mu       sync.Mutex
	due      []tmpldomain.TransactionTemplate
	errOn    map[uuid.UUID]error
	recorded []uuid.UUID // template IDs passed to RecordTransaction, in order
}

func (f *fakeAutoRecorder) FindDueForAutoRecord(_ context.Context, _ time.Time) ([]tmpldomain.TransactionTemplate, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.due, nil
}

func (f *fakeAutoRecorder) RecordTransaction(_ context.Context, _ uuid.UUID, templateID uuid.UUID) (*tmplapp.RecordResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.recorded = append(f.recorded, templateID)
	if f.errOn != nil {
		if e, ok := f.errOn[templateID]; ok {
			return nil, e
		}
	}
	return &tmplapp.RecordResult{TransactionID: uuid.New()}, nil
}

func (f *fakeAutoRecorder) recordedIDs() []uuid.UUID {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]uuid.UUID, len(f.recorded))
	copy(out, f.recorded)
	return out
}

func TestSyncNowRecordsAllDueTemplates(t *testing.T) {
	a := uuid.New()
	b := uuid.New()
	c := uuid.New()
	recorder := &fakeAutoRecorder{due: []tmpldomain.TransactionTemplate{
		{ID: a, TenantID: uuid.New(), AutoRecord: true},
		{ID: b, TenantID: uuid.New(), AutoRecord: true},
		{ID: c, TenantID: uuid.New(), AutoRecord: true},
	}}
	s := NewScheduler(recorder, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 3 {
		t.Fatalf("count = %d, want 3", count)
	}
	got := recorder.recordedIDs()
	if len(got) != 3 || got[0] != a || got[1] != b || got[2] != c {
		t.Fatalf("recorded IDs = %v, want [a b c] in order", got)
	}
}

func TestSyncNowContinuesPastTemplateError(t *testing.T) {
	good1 := uuid.New()
	bad := uuid.New()
	good2 := uuid.New()
	recorder := &fakeAutoRecorder{
		due: []tmpldomain.TransactionTemplate{
			{ID: good1, TenantID: uuid.New(), AutoRecord: true},
			{ID: bad, TenantID: uuid.New(), AutoRecord: true},
			{ID: good2, TenantID: uuid.New(), AutoRecord: true},
		},
		errOn: map[uuid.UUID]error{bad: errors.New("account closed")},
	}
	s := NewScheduler(recorder, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("per-template error must not propagate; got %v", err)
	}
	// All three attempted; only the two good ones counted.
	if count != 2 {
		t.Fatalf("count = %d, want 2 (good templates only)", count)
	}
	got := recorder.recordedIDs()
	if len(got) != 3 {
		t.Fatalf("all templates must be attempted; recorded = %v", got)
	}
}

func TestSyncNowEmptyDueIsZeroCount(t *testing.T) {
	recorder := &fakeAutoRecorder{due: nil}
	s := NewScheduler(recorder, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 0 {
		t.Fatalf("count = %d, want 0 for empty due list", count)
	}
}

func TestSyncNowCtxCancelledShortCircuits(t *testing.T) {
	recorder := &fakeAutoRecorder{due: []tmpldomain.TransactionTemplate{
		{ID: uuid.New(), TenantID: uuid.New(), AutoRecord: true},
	}}
	s := NewScheduler(recorder, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	count, err := s.SyncNow(ctx)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled; got %v", err)
	}
	if count != 0 {
		t.Fatalf("count on cancelled ctx should be 0; got %d", count)
	}
	if got := recorder.recordedIDs(); len(got) != 0 {
		t.Fatalf("doSync should not call recorder on cancelled ctx; got %v", got)
	}
}

func TestStartRunsImmediateThenTicks(t *testing.T) {
	a := uuid.New()
	b := uuid.New()
	// Two distinct due lists; the second call swaps in a fresh template so we
	// can observe the tick. FindDueForAutoRecord returns the current slice.
	recorder := &fakeAutoRecorder{due: []tmpldomain.TransactionTemplate{
		{ID: a, TenantID: uuid.New(), AutoRecord: true},
	}}
	s := NewScheduler(recorder, 20*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start records `a` immediately. Swap the due list so the next tick records
	// `b` too — proves the ticker re-fires doSync (not just the immediate run).
	go s.Start(ctx)

	// Immediate pass records template `a`.
	if !waitForCount(recorder, 1, 50*time.Millisecond) {
		t.Fatalf("immediate pass did not record; recorded=%d", len(recorder.recordedIDs()))
	}
	// Swap due list so the next tick records `b` as well — proves the ticker
	// re-fires doSync (not just the immediate run).
	recorder.mu.Lock()
	recorder.due = []tmpldomain.TransactionTemplate{
		{ID: a, TenantID: uuid.New(), AutoRecord: true},
		{ID: b, TenantID: uuid.New(), AutoRecord: true},
	}
	recorder.mu.Unlock()

	if !waitForID(recorder, b, 200*time.Millisecond) {
		t.Fatalf("tick did not fire within 200ms; recorded=%v", recorder.recordedIDs())
	}
}

func TestCtxCancelStopsGoroutine(t *testing.T) {
	recorder := &fakeAutoRecorder{due: []tmpldomain.TransactionTemplate{
		{ID: uuid.New(), TenantID: uuid.New(), AutoRecord: true},
	}}
	s := NewScheduler(recorder, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	if !waitForCount(recorder, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple passes before cancel; recorded=%d", len(recorder.recordedIDs()))
	}
	beforeCancel := len(recorder.recordedIDs())

	cancel()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Start did not return after ctx cancel")
	}

	time.Sleep(30 * time.Millisecond)
	if got := len(recorder.recordedIDs()); got > beforeCancel+1 {
		t.Fatalf("goroutine recorded after cancel; before=%d after=%d", beforeCancel, got)
	}
}

func waitForCount(r *fakeAutoRecorder, want int, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if len(r.recordedIDs()) >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return len(r.recordedIDs()) >= want
}

func waitForID(r *fakeAutoRecorder, id uuid.UUID, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		for _, got := range r.recordedIDs() {
			if got == id {
				return true
			}
		}
		time.Sleep(2 * time.Millisecond)
	}
	for _, got := range r.recordedIDs() {
		if got == id {
			return true
		}
	}
	return false
}
