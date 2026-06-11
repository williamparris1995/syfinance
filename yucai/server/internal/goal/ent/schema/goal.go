package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"time"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// Goal holds the schema for savings/debt-payoff/investment goals.
type Goal struct {
	ent.Schema
}

func (Goal) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Goal) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (Goal) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.String("name").
			NotEmpty(),
		field.String("goal_type").
			Comment("savings, debt_payoff, investment"),
		field.Int64("target_amount_cents"),
		field.Int64("current_amount_cents").
			Default(0),
		field.String("currency_code").
			Default("CNY"),
		field.Time("deadline").
			Optional().
			Nillable(),
		field.UUID("linked_account_id", uuid.UUID{}).
			Optional().
			Nillable(),
		field.String("notes").
			Optional().
			Default(""),
		field.Bool("is_completed").
			Default(false),
		field.Time("completed_at").
			Optional().
			Nillable(),
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

func (Goal) Edges() []ent.Edge {
	return nil
}

func (Goal) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "is_completed"),
	}
}
