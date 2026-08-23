package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/ent/schema/mixin"
	"time"
)

// Transaction holds the schema for the Transaction entity (aggregate root).
type Transaction struct {
	ent.Schema
}

func (Transaction) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Transaction) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (Transaction) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.Time("transaction_date").
			Comment("The date of the transaction"),
		field.Time("transaction_time").
			Optional().
			Nillable().
			Default(time.Now).
			Comment("The wall-clock time of the transaction (HH:MM granularity for display); NULL falls back to transaction_date"),
		field.String("description").
			Default(""),
		field.Int64("version").
			Default(1),
		field.Time("deleted_at").
			Optional().
			Nillable(),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now),
	}
}

func (Transaction) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("entries", TransactionEntry.Type).
			Annotations(entsql.OnDelete(entsql.Cascade)),
	}
}

func (Transaction) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "transaction_date"),
	}
}
