package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"time"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// TransactionTemplate holds the schema for recurring transaction templates.
type TransactionTemplate struct {
	ent.Schema
}

func (TransactionTemplate) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (TransactionTemplate) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (TransactionTemplate) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.String("name").
			NotEmpty(),
		field.String("description").
			Optional().
			Default(""),
		field.Int64("amount_cents"),
		field.String("direction").
			Comment("expense, income, transfer"),
		field.UUID("source_account_id", uuid.UUID{}).Immutable(),
		field.UUID("destination_account_id", uuid.UUID{}).
			Optional().
			Nillable().Immutable(),
		field.String("cycle").
			Comment("weekly, monthly, yearly, custom"),
		field.Int32("cycle_days").
			Optional().
			Default(0),
		field.Int32("billing_day").
			Optional().
			Default(0),
		field.Time("next_date"),
		field.Time("start_date"),
		field.Time("end_date").
			Optional().
			Nillable(),
		field.Bool("auto_record").
			Default(false),
		field.Bool("paused").
			Default(false),
		field.UUID("last_transaction_id", uuid.UUID{}).
			Optional().
			Nillable(),
		field.String("category").
			Optional().
			Default(""),
		field.Int64("version").
			Default(1),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now),
	}
}

func (TransactionTemplate) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("record_logs", TemplateRecordLog.Type).
			Annotations(entsql.OnDelete(entsql.Cascade)),
	}
}

func (TransactionTemplate) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "paused", "next_date"),
	}
}
