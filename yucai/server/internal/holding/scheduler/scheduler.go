// Package scheduler runs periodic security-price sync as a background task.
// Mirrors currency/scheduler: time.NewTicker + context.WithCancel + go func,
// gated by IntervalSource so the tick only fires when MinIntervalHours elapsed.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// IntervalSource reports the minimum hours between automatic price syncs.
// Reused from the currency scheduler (same auth TenantRepository provider).
type IntervalSource interface {
	MinIntervalHours(ctx context.Context) int
}

// PriceSyncer refreshes security prices, returning the count updated.
// Implemented by holding/application.Service.SyncPrices.
type PriceSyncer interface {
	SyncPrices(ctx context.Context) (int, error)
}

// Scheduler periodically calls PriceSyncer.SyncPrices, gated by IntervalSource.
type Scheduler struct {
	syncer PriceSyncer
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

// NewScheduler builds a Scheduler. tick is the polling cadence (prod 1h;
// tests use ~10ms).
func NewScheduler(syncer PriceSyncer, src IntervalSource, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{syncer: syncer, src: src, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate SyncPrices, then on each tick re-syncs only if at least
// MinIntervalHours have elapsed since the last sync. Errors are logged but
// never exit the loop.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("price sync failed", "error", err, "operation", "scheduler.Start.doSync")
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
					s.log.Error("price sync failed", "error", err, "operation", "scheduler.Start.doSync")
				}
			}
		}
	}
}

// SyncNow triggers an immediate price sync (manual trigger). Returns the count
// and propagates the syncer error (honest contract).
func (s *Scheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs SyncPrices once, updates lastSync, logs the result, and returns
// the count plus the syncer error (if any). A cancelled ctx short-circuits.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	count, err := s.syncer.SyncPrices(ctx)
	if err != nil {
		s.log.Error("price sync failed", "error", err, "operation", "scheduler.SyncPrices")
	} else {
		s.log.Info("price sync completed", "count", count, "operation", "scheduler.SyncPrices")
	}
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return count, err
}
