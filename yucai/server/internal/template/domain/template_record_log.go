package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// TemplateRecordLog is the idempotency-key row for autoRecord (Task 8 / audit
// C1 + D4 concurrent-tick guard). At most one log row may exist per
// (tenant_id, template_id, record_date); the underlying UNIQUE index is the
// mechanism that downgrades a duplicate autoRecord attempt (concurrent
// scheduler tick, or crash-retry against a NextDate that has not yet
// advanced) to a no-op.
//
// Lifecycle: autoRecord creates a log row at the START of its WithTx fn (with
// only tenant/template/record_date set); transaction_id is back-filled after
// recorder.Record returns the new txnID. On rollback the log row vanishes with
// the rest of the tx, so the idempotency key is NOT poisoned by transient
// mid-flow failures.
type TemplateRecordLog struct {
	ID            uuid.UUID
	TenantID      uuid.UUID
	TemplateID    uuid.UUID
	RecordDate    time.Time
	TransactionID *uuid.UUID
	CreatedAt     time.Time
}

// TemplateRecordLogRepository is the port for the template_record_log table.
// Implemented by infrastructure/repository.TemplateRecordLogRepository; wire
// injects it into template/application.Service. Mirrors the cross-module port
// pattern (e.g. backup TenantDataPort): domain owns the interface, infra impls.
type TemplateRecordLogRepository interface {
	// Upsert inserts a fresh log row. Returns inserted=true on a successful
	// first-time insert; inserted=false (no error) when a row already exists
	// for the same (tenant_id, template_id, record_date) — this is the
	// idempotency-hit signal that tells autoRecord to SKIP recorder.Record.
	// Any other error (DB connection, NOT NULL violation, etc.) is surfaced
	// verbatim and MUST NOT be treated as an idempotency hit by callers.
	Upsert(ctx context.Context, log *TemplateRecordLog) (inserted bool, err error)

	// SetTransactionID back-fills the transaction_id on an existing log row
	// after recorder.Record returns the new txnID. Called inside the same
	// WithTx as Upsert + recorder.Record so the back-fill rolls back if any
	// later step (e.g. template NextDate-advance Update) fails — without this
	// rollback guarantee a stale transaction_id would survive a rolled-back
	// autoRecord and mislead reconciliation.
	SetTransactionID(ctx context.Context, logID, txnID uuid.UUID) error
}
