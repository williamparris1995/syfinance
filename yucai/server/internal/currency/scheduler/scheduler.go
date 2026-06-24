// Package scheduler runs periodic exchange-rate sync as a background task.
// It is the first background-task pattern in the 御财 server: time.NewTicker
// + context.WithCancel + go func.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// IntervalSource reports the minimum interval (in hours) that must elapse
// between automatic rate syncs. Implemented by auth TenantRepository in prod.
type IntervalSource interface {
	MinIntervalHours(ctx context.Context) int
}

// RateSyncer syncs exchange rates for all active currencies, returning the
// number of currencies updated. Implemented by currency/application.Service.
type RateSyncer interface {
	SyncRates(ctx context.Context) (int, error)
}

// Scheduler periodically calls RateSyncer.SyncRates, gated by IntervalSource.
type Scheduler struct {
	syncer RateSyncer
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

// NewScheduler builds a Scheduler. tick is the polling cadence (prod 1h;
// tests use ~10ms).
func NewScheduler(syncer RateSyncer, src IntervalSource, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{syncer: syncer, src: src, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate SyncRates, then on each tick re-syncs only if at least
// MinIntervalHours have elapsed since the last sync. Errors are logged but
// never exit the loop.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("rate sync failed", "error", err, "operation", "scheduler.Start.doSync")
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
					s.log.Error("rate sync failed", "error", err, "operation", "scheduler.Start.doSync")
				}
			}
		}
	}
}

// SyncNow triggers an immediate rate sync (manual trigger) and refreshes
// lastSync so the next automatic sync is gated from this point. It returns
// the count and propagates the syncer error to the caller (honest contract).
func (s *Scheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs SyncRates once, updates lastSync, logs the result, and returns
// the count plus the syncer error (if any). A cancelled ctx short-circuits
// before invoking the syncer.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	count, err := s.syncer.SyncRates(ctx)
	if err != nil {
		s.log.Error("rate sync failed", "error", err, "operation", "scheduler.SyncRates")
	} else {
		s.log.Info("rate sync completed", "count", count, "operation", "scheduler.SyncRates")
	}
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return count, err
}
