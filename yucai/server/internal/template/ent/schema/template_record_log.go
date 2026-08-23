package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// TemplateRecordLog records the fact that autoRecord has already recorded a
// transaction for a given (template, record_date). It is the idempotency key
// for Task 8 (audit C1 / D4 concurrent-tick guard): a UNIQUE(tenant_id,
// template_id, record_date) constraint means a duplicate attempt — same
// scheduler tick firing twice, or a crash-retry against the same NextDate
// before the NextDate-advance persisted — conflicts at insert time and lets
// autoRecord skip recorder.Record entirely instead of double-counting.
//
// Lifecycle (inside the Task 7 RecordTransaction WithTx fn):
//  1. autoRecord calls logRepo.Upsert at the start of the tx fn. A fresh row
//     is inserted (inserted=true) → proceed with recorder.Record + NextDate.
//  2. transaction_id is back-filled via logRepo.SetTransactionID after
//     recorder.Record returns the new txnID, so the log row carries a pointer
//     to the transaction it gated (useful for reconciliation/audit).
//  3. A duplicate attempt (inserted=false on UNIQUE conflict) → autoRecord
//     skips recorder.Record entirely and returns nil; the empty tx commits.
//
// On rollback (any failure between Upsert and commit) the log row vanishes
// with the rest of the tx, so a transient mid-flow error does NOT poison the
// idempotency key — the retry re-inserts cleanly. Only a fully-committed
// autoRecord leaves a log row behind, which is exactly the guarantee we want.
type TemplateRecordLog struct {
	ent.Schema
}

func (TemplateRecordLog) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (TemplateRecordLog) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (TemplateRecordLog) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("template_id", uuid.UUID{}).
			Comment("FK to transaction_template — which template was recorded"),
		field.Time("record_date").
			Comment("The template.NextDate that was recorded (idempotency key component)"),
		field.UUID("transaction_id", uuid.UUID{}).
			Optional().
			Nillable().
			Comment("FK to the recorded transaction; back-filled after recorder.Record"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (TemplateRecordLog) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("template", TransactionTemplate.Type).Ref("record_logs").
			Field("template_id").Unique().Required(),
	}
}

func (TemplateRecordLog) Indexes() []ent.Index {
	return []ent.Index{
		// Idempotency key: at most one recorded transaction per (tenant,
		// template, record_date). A duplicate autoRecord attempt conflicts
		// here at insert time and is downgraded to a no-op by Upsert.
		index.Fields("tenant_id", "template_id", "record_date").Unique(),
	}
}
