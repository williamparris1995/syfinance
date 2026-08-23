// Package scheduler runs periodic debt snapshot sync (Σ debt remaining/paid
// totals → debt_snapshot) as a background task. Mirrors goal/scheduler 1:1;
// fans out across tenants via TenantLister.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
)

// IntervalSource reports the minimum hours between automatic syncs.
// Reused from B/C (same auth.TenantRepository provider).
type IntervalSource interface {
	MinIntervalHours(ctx context.Context) int
}

// TenantLister enumerates tenant IDs to fan out the sync. Implemented by
// auth.TenantRepository (structural — scheduler does not import auth).
type TenantLister interface {
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
}

// DebtSyncer recomputes debt snapshots for one tenant.
// Implemented by debt/application.Service.SyncAllDebts.
type DebtSyncer interface {
	SyncAllDebts(ctx context.Context, tenantID uuid.UUID) (int, error)
}

// Scheduler periodically fans out DebtSyncer across all tenants, gated by
// IntervalSource. Mirrors goal/scheduler 1:1 + tenant fan-out.
type Scheduler struct {
	syncer DebtSyncer
	lister TenantLister
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger
	freeze FreezeChecker // nil = no restore-freeze check (tests)

	mu       sync.Mutex
	lastSync time.Time
}

func NewScheduler(syncer DebtSyncer, lister TenantLister, src IntervalSource, tick time.Duration, log *slog.Logger, freeze FreezeChecker) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{syncer: syncer, lister: lister, src: src, tick: tick, log: log, freeze: freeze}
}

// Start runs the scheduler loop until ctx is cancelled. Immediate doSync on
// start, then on each tick re-syncs only if MinIntervalHours elapsed.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("debt sync failed", "error", err, "operation", "DebtScheduler.Start")
	}
	ticker := time.NewTicker(s.tick)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			interval := time.Duration(s.src.MinIntervalHours(ctx)) * time.Hour
			s.mu.Lock()
			elapsed := time.Since(s.lastSync)
			s.mu.Unlock()
			if elapsed >= interval {
				if _, err := s.doSync(ctx); err != nil {
					s.log.Error("debt sync failed", "error", err, "operation", "DebtScheduler.Start")
				}
			}
		}
	}
}

func (s *Scheduler) SyncNow(ctx context.Context) (int, error) { return s.doSync(ctx) }

// doSync fans out across all tenants: Σ per-tenant synced counts. Per-tenant
// errors logged, not fatal (other tenants still sync). ctx cancel short-circuits.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	tenants, err := s.lister.FindAllIDs(ctx)
	if err != nil {
		s.log.Error("debt sync: list tenants failed", "error", err, "operation", "DebtScheduler")
		s.mu.Lock()
		s.lastSync = time.Now()
		s.mu.Unlock()
		return 0, err
	}
	total := 0
	for _, tid := range tenants {
		if s.freeze != nil && s.freeze.IsFrozen(tid) {
			s.log.Debug("skip: restore in progress", "tenant_id", tid.String(), "operation", "DebtScheduler")
			continue
		}
		if err := ctx.Err(); err != nil {
			return total, err
		}
		count, err := s.syncer.SyncAllDebts(ctx, tid)
		if err != nil {
			s.log.Error("debt sync: tenant failed, continue", "tenant_id", tid.String(), "error", err, "operation", "DebtScheduler")
			continue
		}
		total += count
	}
	s.log.Info("debt sync completed", "count", total, "tenants", len(tenants), "operation", "DebtScheduler")
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return total, nil
}


// FreezeChecker is the restore-freeze probe (satisfied structurally by
// *backup/application.RestoreFreeze; declared locally to keep the module
// boundary — D12).
type FreezeChecker interface {
	IsFrozen(tenantID uuid.UUID) bool
}
