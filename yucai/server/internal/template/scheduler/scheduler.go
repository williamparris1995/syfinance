// Package scheduler runs the daily auto-record pass for recurring transaction
// templates as a background task. Mirrors the currency/holding/goal scheduler
// shape — NewTicker + context cancellation + immediate first run — but drops
// the IntervalSource gate: autoRecord is idempotent per day (RecordTransaction
// advances NextDate past today, so a second tick the same day finds nothing
// due), so the scheduler fires the full pass on every tick.
//
// Cross-tenant fan-out is handled inside the application Service via
// repo.FindDue (no TenantLister iteration): FindDue queries every tenant in one
// query with a NextDate<=today + paused=false filter, and the service applies
// the AutoRecord policy filter on top. See application.FindDueForAutoRecord.
package scheduler

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"
	tmplapp "github.com/yucai/server/internal/template/application"
	tmpldomain "github.com/yucai/server/internal/template/domain"
)

// AutoRecorder is the narrow subset of template/application.Service that the
// scheduler consumes: enumerate due auto-record templates (cross-tenant) +
// record a transaction for one template. Declared locally so the scheduler
// depends on an abstraction (mirrors currency RateSyncer / holding Snapshotter
// / goal GoalSyncer); *application.Service satisfies it structurally.
type AutoRecorder interface {
	FindDueForAutoRecord(ctx context.Context, today time.Time) ([]tmpldomain.TransactionTemplate, error)
	RecordTransaction(ctx context.Context, tenantID, templateID uuid.UUID) (*tmplapp.RecordResult, error)
}

// Scheduler periodically records transactions for every due auto-record
// template across all tenants. tick is the cadence (prod 24h; tests use ~10ms).
type Scheduler struct {
	recorder AutoRecorder
	tick     time.Duration
	log      *slog.Logger
}

// NewScheduler builds a Scheduler. tick is the polling cadence (prod 24h;
// tests use ~10ms). A nil log falls back to slog.Default().
func NewScheduler(recorder AutoRecorder, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{recorder: recorder, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate pass, then on each tick runs another pass. Per-template errors are
// logged but never exit the loop (other templates still record); the loop only
// exits on ctx cancellation.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("template auto-record failed", "error", err, "operation", "TemplateScheduler.Start")
	}

	ticker := time.NewTicker(s.tick)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if _, err := s.doSync(ctx); err != nil {
				s.log.Error("template auto-record failed", "error", err, "operation", "TemplateScheduler.Start")
			}
		}
	}
}

// SyncNow triggers an immediate auto-record pass (manual trigger). Returns the
// count of templates recorded and propagates only ctx errors (per-template
// errors are logged + skipped, never propagated — same contract as goal/debt
// schedulers).
func (s *Scheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs one auto-record pass: load all due auto-record templates
// (cross-tenant), then RecordTransaction each. Per-template errors are logged
// and the loop continues (a single template with a broken account/category must
// not block the rest). ctx cancel short-circuits between templates. Returns
// the count of successfully recorded templates.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	today := time.Now()
	templates, err := s.recorder.FindDueForAutoRecord(ctx, today)
	if err != nil {
		s.log.Error("template auto-record: list due failed", "error", err, "operation", "TemplateScheduler")
		return 0, err
	}
	recorded := 0
	for _, t := range templates {
		if err := ctx.Err(); err != nil {
			return recorded, err
		}
		if _, err := s.recorder.RecordTransaction(ctx, t.TenantID, t.ID); err != nil {
			s.log.Error("template auto-record: record failed, continuing",
				"template_id", t.ID.String(), "tenant_id", t.TenantID.String(),
				"error", err, "operation", "TemplateScheduler")
			continue
		}
		recorded++
	}
	s.log.Info("template auto-record completed",
		"recorded", recorded, "due", len(templates), "operation", "TemplateScheduler")
	return recorded, nil
}
