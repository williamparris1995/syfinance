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

// BudgetItem holds the schema for budget line items.
type BudgetItem struct {
	ent.Schema
}

func (BudgetItem) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (BudgetItem) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("budget_id", uuid.UUID{}).
			Comment("FK to Budget").Immutable(),
		field.UUID("account_id", uuid.UUID{}).
			Comment("FK to Account").Immutable(),
		field.Int64("planned_amount_cents").
			Default(0).Min(0),
		field.Int64("actual_amount_cents").
			Default(0).Min(0),
		field.String("notes").
			Optional().
			Default(""),
	}
}

func (BudgetItem) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("budget", Budget.Type).Ref("items").
			Field("budget_id").Unique().Required(),
	}
}

func (BudgetItem) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("budget_id", "account_id").Unique(),
		index.Fields("account_id"),
	}
}
