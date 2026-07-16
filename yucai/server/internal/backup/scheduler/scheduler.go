// Package scheduler runs periodic automatic backups as a background task.
// Mirrors the currency/holding/goal/debt scheduler shape — time.NewTicker +
// context cancellation + immediate first pass — but the interval gate is
// per-tenant (each tenant's AutoBackupSettings owns its own AutoBackup flag and
// AutoBackupIntervalHours), so each tick fans out across tenants and re-checks
// every tenant individually.
//
// Cross-tenant fan-out follows the goal/debt scheduler: per-tenant errors are
// logged and the loop continues (one tenant with a broken settings row must not
// block the rest). The last-backup timestamp is tracked per-tenant so a single
// tick can back up tenant A (elapsed >= its interval) while skipping tenant B.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"

	backupapp "github.com/yucai/server/internal/backup/application"
)

// BackupCreator is the narrow subset of backup/application.Service that the
// scheduler consumes: create one backup for a tenant. Declared locally so the
// scheduler depends on an abstraction (mirrors holding Snapshotter / goal
// GoalSyncer / template AutoRecorder); *application.Service satisfies it
// structurally. auto=true marks the backup as scheduler-produced.
type BackupCreator interface {
	CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*backupapp.BackupDTO, error)
}

// TenantLister enumerates tenant IDs to fan out the backup pass. Implemented by
// auth.TenantRepository (structural — scheduler does not import auth), reusing
// the same port the goal/debt schedulers consume.
type TenantLister interface {
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
}

// AutoBackupSource reports a tenant's auto-backup preferences (AutoBackup flag
// + AutoBackupIntervalHours). Implemented by backup/application.Service
// (structural — wraps BackupSettingsRepository and applies defaults when no row
// exists); declared locally so the scheduler depends on an abstraction.
type AutoBackupSource interface {
	AutoBackupSettings(ctx context.Context, tenantID uuid.UUID) (autoBackup bool, intervalHours int32, err error)
}

// Scheduler periodically fans out BackupCreator across all tenants, gated
// per-tenant by AutoBackupSource. Mirrors goal/debt scheduler shape + tenant
// fan-out; the interval gate is per-tenant (not global) because each tenant
// owns its own AutoBackup + AutoBackupIntervalHours settings.
type Scheduler struct {
	creator BackupCreator
	lister  TenantLister
	src     AutoBackupSource
	tick    time.Duration
	log     *slog.Logger

	mu   sync.Mutex
	last map[uuid.UUID]time.Time
}

// NewScheduler builds a Scheduler. tick is the polling cadence (prod 1h; tests
// use ~10ms). A nil log falls back to slog.Default().
func NewScheduler(creator BackupCreator, lister TenantLister, src AutoBackupSource, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{
		creator: creator,
		lister:  lister,
		src:     src,
		tick:    tick,
		log:     log,
		last:    make(map[uuid.UUID]time.Time),
	}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate doSync pass, then on each tick runs another pass. Errors are
// logged but never exit the loop; the loop only exits on ctx cancellation.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("auto backup pass failed", "error", err, "operation", "BackupScheduler.Start")
	}

	ticker := time.NewTicker(s.tick)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if _, err := s.doSync(ctx); err != nil {
				s.log.Error("auto backup pass failed", "error", err, "operation", "BackupScheduler.Start")
			}
		}
	}
}

// SyncNow triggers an immediate backup pass (manual trigger). Returns the
// count of backups created this pass and propagates only ctx errors;
// per-tenant errors are logged + skipped (same contract as goal/debt
// schedulers — a single broken tenant must not abort the batch).
func (s *Scheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs one backup pass: fan out across tenants, and per tenant read its
// AutoBackupSettings; if AutoBackup is on and at least AutoBackupIntervalHours
// have elapsed since that tenant's last backup (or it has never backed up),
// create one auto=true backup. Per-tenant errors (settings read or CreateBackup)
// are logged and the loop continues. ctx cancel short-circuits between tenants.
// Returns the count of backups created this pass.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	tenants, err := s.lister.FindAllIDs(ctx)
	if err != nil {
		s.log.Error("auto backup: list tenants failed", "error", err, "operation", "BackupScheduler")
		return 0, err
	}
	created := 0
	for _, tid := range tenants {
		if err := ctx.Err(); err != nil {
			return created, err
		}
		autoBackup, intervalHours, err := s.src.AutoBackupSettings(ctx, tid)
		if err != nil {
			s.log.Error("auto backup: read settings failed, continue",
				"tenant_id", tid.String(), "error", err, "operation", "BackupScheduler")
			continue
		}
		if !autoBackup {
			continue
		}
		interval := time.Duration(intervalHours) * time.Hour
		s.mu.Lock()
		last, ok := s.last[tid]
		s.mu.Unlock()
		if ok && time.Since(last) < interval {
			continue
		}
		if _, err := s.creator.CreateBackup(ctx, tid, false, "", true); err != nil {
			s.log.Error("auto backup: create failed, continue",
				"tenant_id", tid.String(), "error", err, "operation", "BackupScheduler")
			continue
		}
		s.mu.Lock()
		s.last[tid] = time.Now()
		s.mu.Unlock()
		created++
	}
	s.log.Info("auto backup pass completed",
		"created", created, "tenants", len(tenants), "operation", "BackupScheduler")
	return created, nil
}
