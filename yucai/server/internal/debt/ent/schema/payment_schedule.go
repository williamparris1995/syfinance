package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// PaymentSchedule holds the schema for amortization payment schedule entries.
type PaymentSchedule struct {
	ent.Schema
}

func (PaymentSchedule) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (PaymentSchedule) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("debt_id", uuid.UUID{}).
			Comment("FK to DebtDetails"),
		field.Time("payment_date"),
		field.Int64("principal_cents").
			Default(0),
		field.Int64("interest_cents").
			Default(0),
		field.Int64("total_cents").
			Default(0),
		field.Bool("paid").
			Default(false),
		field.Int64("paid_cents").
			Default(0),
		field.UUID("transaction_id", uuid.UUID{}).
			Optional().
			Nillable().
			Comment("Linked transaction"),
	}
}

func (PaymentSchedule) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("debt", DebtDetails.Type).Ref("schedule").
			Field("debt_id").Unique().Required(),
	}
}

func (PaymentSchedule) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("debt_id"),
		index.Fields("payment_date"),
	}
}
