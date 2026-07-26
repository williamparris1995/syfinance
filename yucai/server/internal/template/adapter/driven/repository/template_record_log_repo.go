package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/template/domain"
	tmplent "github.com/yucai/server/internal/template/ent"
)

// TemplateRecordLogRepository implements domain.TemplateRecordLogRepository
// using ent. It backs the autoRecord idempotency check (Task 8 / audit C1 +
// D4 concurrent-tick guard): a UNIQUE(tenant_id, template_id, record_date)
// constraint on the table means a duplicate autoRecord attempt (concurrent
// scheduler tick, or crash-retry against a NextDate that hasn't advanced yet)
// conflicts at insert time and is downgraded to a no-op by Upsert.
//
// The ent codegen in this repo does NOT enable the sql/upsert feature (no
// OnConflictDoNothing helper is generated — see price_history_repo.go and
// debt_snapshot_repo.go for the canonical pattern). We follow that pattern:
// try INSERT; on IsConstraintError return inserted=false (idempotency hit);
// on any other error surface verbatim. This matches the codebase's only
// known-safe way to do ent upserts against a UNIQUE constraint.
type TemplateRecordLogRepository struct {
	client *tmplent.Client
}

// NewTemplateRecordLogRepository creates a new TemplateRecordLogRepository.
func NewTemplateRecordLogRepository(client *tmplent.Client) *TemplateRecordLogRepository {
	return &TemplateRecordLogRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose writes
// join the outer transaction; otherwise it returns the default r.client
// (preserving the legacy non-transactional path for mock-free unit tests).
// Mirrors TemplateRepository.clientFor (Task 7).
func (r *TemplateRecordLogRepository) clientFor(ctx context.Context) *tmplent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return tmplent.NewClient(tmplent.Driver(d))
	}
	return r.client
}

// Upsert inserts a fresh log row. Returns inserted=true on success, or
// inserted=false (no error) when a row already exists for the same
// (tenant_id, template_id, record_date) — the idempotency-hit signal that
// tells autoRecord to skip recorder.Record. Any other error surfaces verbatim
// and must NOT be treated as an idempotency hit by callers.
//
// Implementation: try INSERT; on UNIQUE constraint error return false. The
// ent codegen does not expose OnConflictDoNothing (sql/upsert feature not
// enabled in this repo), so we follow the canonical pattern from
// price_history_repo.go and debt_snapshot_repo.go. Unlike those callers we do
// NOT fall back to UPDATE — for idempotency we only need to know whether the
// row is fresh; a duplicate means "already recorded, skip" regardless of what
// the pre-existing row's transaction_id is.
//
// ID, TenantID, TemplateID and RecordDate on the input log are the load-bearing
// fields; TransactionID is back-filled separately via SetTransactionID (so
// Upsert itself doesn't need to know the txnID — autoRecord learns that only
// after recorder.Record).
func (r *TemplateRecordLogRepository) Upsert(ctx context.Context, log *domain.TemplateRecordLog) (bool, error) {
	create := r.clientFor(ctx).TemplateRecordLog.Create().
		SetID(log.ID).
		SetTenantID(log.TenantID).
		SetTemplateID(log.TemplateID).
		SetRecordDate(log.RecordDate)
	if err := create.Exec(ctx); err != nil {
		// UNIQUE(tenant_id, template_id, record_date) conflict → idempotency
		// hit. Any other constraint or DB error must surface verbatim — never
		// swallow a NOT NULL / FK / connection error as "already recorded".
		if tmplent.IsConstraintError(err) {
			return false, nil
		}
		return false, fmt.Errorf("upsert record log: %w", err)
	}
	return true, nil
}

// SetTransactionID back-fills the transaction_id on an existing log row after
// recorder.Record returns the new txnID. Called inside the same WithTx as
// Upsert + recorder.Record, so the back-fill rolls back if any later step
// (e.g. template NextDate-advance Update) fails — preventing a stale
// transaction_id from surviving a rolled-back autoRecord.
func (r *TemplateRecordLogRepository) SetTransactionID(ctx context.Context, logID, txnID uuid.UUID) error {
	if _, err := r.clientFor(ctx).TemplateRecordLog.UpdateOneID(logID).
		SetTransactionID(txnID).
		Save(ctx); err != nil {
		return fmt.Errorf("set log transaction_id: %w", err)
	}
	return nil
}

// Compile-time check.
var _ domain.TemplateRecordLogRepository = (*TemplateRecordLogRepository)(nil)
