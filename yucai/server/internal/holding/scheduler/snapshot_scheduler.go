// Package scheduler also runs the daily holding-snapshot job as a background
// task. Mirrors the price Scheduler (scheduler.go) 1:1: time.NewTicker +
// context.WithCancel + go func, gated by IntervalSource so the tick only fires
// when MinIntervalHours elapsed. Snapshotter is cross-tenant (unlike PriceSyncer
// which is global security master), so the implementing service fans out per
// tenant internally.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// Snapshotter writes one daily market-value snapshot across all holdings of
// every tenant. Implemented by holding/application.Service.SnapshotAllHoldings.
type Snapshotter interface {
	SnapshotAllHoldings(ctx context.Context) (int, error)
}

// SnapshotScheduler periodically calls Snapshotter, gated by IntervalSource
// (reused from the price scheduler — same auth TenantRepository provider).
// Mirrors Scheduler (scheduler.go) 1:1, just Snapshotter→PriceSyncer.
type SnapshotScheduler struct {
	syncer Snapshotter
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

// NewSnapshotScheduler builds a SnapshotScheduler. tick is the polling cadence
// (prod 1h; tests use ~10ms).
func NewSnapshotScheduler(syncer Snapshotter, src IntervalSource, tick time.Duration, log *slog.Logger) *SnapshotScheduler {
	if log == nil {
		log = slog.Default()
	}
	return &SnapshotScheduler{syncer: syncer, src: src, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate SnapshotAllHoldings, then on each tick re-syncs only if at least
// MinIntervalHours have elapsed since the last sync. Errors are logged but
// never exit the loop.
func (s *SnapshotScheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler.Start.doSync")
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
					s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler.Start.doSync")
				}
			}
		}
	}
}

// SyncNow triggers an immediate snapshot (manual trigger). Returns the count
// and propagates the syncer error (honest contract).
func (s *SnapshotScheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs SnapshotAllHoldings once, updates lastSync, logs the result, and
// returns the count plus the syncer error (if any). A cancelled ctx short-
// circuits.
func (s *SnapshotScheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	count, err := s.syncer.SnapshotAllHoldings(ctx)
	if err != nil {
		s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler.SnapshotAllHoldings")
	} else {
		s.log.Info("holding snapshot completed", "count", count, "operation", "SnapshotScheduler.SnapshotAllHoldings")
	}
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return count, err
}
