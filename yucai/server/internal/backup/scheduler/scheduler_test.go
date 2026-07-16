package scheduler

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	backupapp "github.com/yucai/server/internal/backup/application"
)

// --- Fakes ---

type mockTenantLister struct {
	ids []uuid.UUID
}

func (m *mockTenantLister) FindAllIDs(_ context.Context) ([]uuid.UUID, error) {
	return m.ids, nil
}

// createCall captures one BackupCreator.CreateBackup invocation.
type createCall struct {
	tenantID  uuid.UUID
	encrypted bool
	password  string
	auto      bool
}

type mockBackupCreator struct {
	mu    sync.Mutex
	calls []createCall
	errOn map[uuid.UUID]error // optional: per-tenant error simulation
}

func (m *mockBackupCreator) CreateBackup(_ context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*backupapp.BackupDTO, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.calls = append(m.calls, createCall{tenantID: tenantID, encrypted: encrypted, password: password, auto: auto})
	if m.errOn != nil {
		if e, ok := m.errOn[tenantID]; ok {
			return nil, e
		}
	}
	return &backupapp.BackupDTO{}, nil
}

func (m *mockBackupCreator) callCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.calls)
}

func (m *mockBackupCreator) snapshot() []createCall {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]createCall, len(m.calls))
	copy(out, m.calls)
	return out
}

type tenantSettings struct {
	autoBackup      bool
	intervalHours   int32
	readErr         error // optional: simulate per-tenant settings-read failure
}

type mockAutoBackupSource struct {
	mu        sync.Mutex
	calls     atomic.Int64
	perTenant map[uuid.UUID]tenantSettings
}

func (m *mockAutoBackupSource) AutoBackupSettings(_ context.Context, tenantID uuid.UUID) (bool, int32, error) {
	m.calls.Add(1)
	m.mu.Lock()
	defer m.mu.Unlock()
	cfg, ok := m.perTenant[tenantID]
	if !ok {
		// default: auto-backup off, 24h interval (mirrors Service default).
		return false, 24, nil
	}
	return cfg.autoBackup, cfg.intervalHours, cfg.readErr
}

// --- Tests ---

// TestSyncNowAutoBackupElapsedCreatesBackup: AutoBackup=true && interval
// elapsed (no prior backup → last unset → elapsed huge) → CreateBackup called
// exactly once with auto=true.
func TestSyncNowAutoBackupElapsedCreatesBackup(t *testing.T) {
	tid := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{tid}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		tid: {autoBackup: true, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 1 {
		t.Fatalf("created count = %d, want 1", count)
	}
	if got := creator.callCount(); got != 1 {
		t.Fatalf("CreateBackup calls = %d, want 1", got)
	}
	calls := creator.snapshot()
	if !calls[0].auto {
		t.Fatalf("CreateBackup auto flag = false, want true")
	}
	if calls[0].encrypted {
		t.Fatalf("CreateBackup encrypted = true, want false (auto backups are plaintext)")
	}
	if calls[0].tenantID != tid {
		t.Fatalf("CreateBackup tenantID = %s, want %s", calls[0].tenantID, tid)
	}
}

// TestSyncNowAutoBackupDisabledSkips: AutoBackup=false → CreateBackup not
// called.
func TestSyncNowAutoBackupDisabledSkips(t *testing.T) {
	tid := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{tid}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		tid: {autoBackup: false, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 0 {
		t.Fatalf("created count = %d, want 0 (auto-backup off)", count)
	}
	if got := creator.callCount(); got != 0 {
		t.Fatalf("CreateBackup calls = %d, want 0 (auto-backup off)", got)
	}
}

// TestSyncNowIntervalNotElapsedSkips: AutoBackup=true but interval not yet
// elapsed (last preset to now, interval 24h) → CreateBackup not called.
// Verifies the per-tenant gate honors a recent backup.
func TestSyncNowIntervalNotElapsedSkips(t *testing.T) {
	tid := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{tid}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		tid: {autoBackup: true, intervalHours: 24},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	// Simulate a backup that just ran: preset last[tid] to now.
	s.mu.Lock()
	s.last[tid] = time.Now()
	s.mu.Unlock()

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 0 {
		t.Fatalf("created count = %d, want 0 (interval not elapsed)", count)
	}
	if got := creator.callCount(); got != 0 {
		t.Fatalf("CreateBackup calls = %d, want 0 (interval not elapsed)", got)
	}
}

// TestSyncNowFansOutPerTenantIndependently: two tenants — t1 autoBackup=true
// (elapsed), t2 autoBackup=false → CreateBackup called once, only for t1.
// Verifies per-tenant independence (t2's off state does not block t1).
func TestSyncNowFansOutPerTenantIndependently(t *testing.T) {
	t1 := uuid.New()
	t2 := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{t1, t2}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		t1: {autoBackup: true, intervalHours: 1},
		t2: {autoBackup: false, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 1 {
		t.Fatalf("created count = %d, want 1 (only t1 should back up)", count)
	}
	calls := creator.snapshot()
	if len(calls) != 1 {
		t.Fatalf("CreateBackup calls = %d, want 1", len(calls))
	}
	if calls[0].tenantID != t1 {
		t.Fatalf("CreateBackup tenantID = %s, want %s (t1 only)", calls[0].tenantID, t1)
	}
	// Both tenants queried for settings (fan-out reached both).
	if got := src.calls.Load(); got != 2 {
		t.Fatalf("AutoBackupSettings calls = %d, want 2 (both tenants fanned out)", got)
	}
}

// TestSyncNowAutoBackupSourceErrContinues: t1's AutoBackupSettings returns an
// err (slog + continue), t2 healthy → CreateBackup called once for t2 only.
// Verifies per-tenant source error does not abort the batch.
func TestSyncNowAutoBackupSourceErrContinues(t *testing.T) {
	t1 := uuid.New()
	t2 := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{t1, t2}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		t1: {autoBackup: true, intervalHours: 1, readErr: errors.New("settings repo unavailable")},
		t2: {autoBackup: true, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("per-tenant source error must not propagate; got %v", err)
	}
	if count != 1 {
		t.Fatalf("created count = %d, want 1 (only t2 should back up)", count)
	}
	calls := creator.snapshot()
	if len(calls) != 1 {
		t.Fatalf("CreateBackup calls = %d, want 1 (t1 skipped, t2 backed up)", len(calls))
	}
	if calls[0].tenantID != t2 {
		t.Fatalf("CreateBackup tenantID = %s, want %s (t2 only)", calls[0].tenantID, t2)
	}
	if got := src.calls.Load(); got != 2 {
		t.Fatalf("AutoBackupSettings calls = %d, want 2 (both tenants attempted)", got)
	}
}

// TestSyncNowCreateBackupErrContinues: CreateBackup returns err for t1 (slog +
// continue), t2 healthy → CreateBackup called twice, count = 1 (only t2).
// Verifies per-tenant creator error does not abort the batch.
func TestSyncNowCreateBackupErrContinues(t *testing.T) {
	t1 := uuid.New()
	t2 := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{t1, t2}}
	creator := &mockBackupCreator{errOn: map[uuid.UUID]error{
		t1: errors.New("disk full"),
	}}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		t1: {autoBackup: true, intervalHours: 1},
		t2: {autoBackup: true, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	count, err := s.SyncNow(context.Background())
	if err != nil {
		t.Fatalf("per-tenant creator error must not propagate; got %v", err)
	}
	if count != 1 {
		t.Fatalf("created count = %d, want 1 (t2 succeeded, t1 failed)", count)
	}
	if got := creator.callCount(); got != 2 {
		t.Fatalf("CreateBackup calls = %d, want 2 (both attempted)", got)
	}
}

// TestSyncNowCtxCancelledShortCircuits: a cancelled ctx short-circuits before
// touching the creator.
func TestSyncNowCtxCancelledShortCircuits(t *testing.T) {
	tid := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{tid}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		tid: {autoBackup: true, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	before := creator.callCount()
	count, err := s.SyncNow(ctx)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled; got %v", err)
	}
	if count != 0 {
		t.Fatalf("count on cancelled ctx = %d, want 0", count)
	}
	if got := creator.callCount(); got != before {
		t.Fatalf("doSync should not call creator on cancelled ctx; before=%d after=%d", before, got)
	}
}

// TestStartRunsOnceImmediately: Start fans out an immediate doSync across both
// tenants (async goroutine + waitForCalls).
func TestStartRunsOnceImmediately(t *testing.T) {
	t1 := uuid.New()
	t2 := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{t1, t2}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		t1: {autoBackup: true, intervalHours: 1},
		t2: {autoBackup: true, intervalHours: 1},
	}}
	s := NewScheduler(creator, lister, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCreatorCalls(creator, 2, 100*time.Millisecond) {
		t.Fatalf("immediate doSync did not fan out to both tenants; calls=%d", creator.callCount())
	}
}

// TestCtxCancelStopsGoroutine: cancelling ctx returns Start and stops further
// passes. intervalHours=0 makes the per-tenant interval gate a no-op (every
// tick re-backs-up), so we can observe multiple passes before cancel.
func TestCtxCancelStopsGoroutine(t *testing.T) {
	tid := uuid.New()
	lister := &mockTenantLister{ids: []uuid.UUID{tid}}
	creator := &mockBackupCreator{}
	src := &mockAutoBackupSource{perTenant: map[uuid.UUID]tenantSettings{
		tid: {autoBackup: true, intervalHours: 0},
	}}
	// Short tick so multiple passes fire before cancel.
	s := NewScheduler(creator, lister, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	if !waitForCreatorCalls(creator, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple passes before cancel; calls=%d", creator.callCount())
	}
	beforeCancel := creator.callCount()

	cancel()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Start did not return after ctx cancel")
	}

	time.Sleep(30 * time.Millisecond)
	if got := creator.callCount(); got > beforeCancel+1 {
		t.Fatalf("goroutine backed up after cancel; before=%d after=%d", beforeCancel, got)
	}
}

func waitForCreatorCalls(creator *mockBackupCreator, want int, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if creator.callCount() >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return creator.callCount() >= want
}
