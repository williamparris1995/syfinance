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

// Budget holds the schema for the Budget entity.
type Budget struct {
	ent.Schema
}

func (Budget) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Budget) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (Budget) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.String("name").
			NotEmpty(),
		field.String("month").
			Comment("Format YYYY-MM"),
		field.Int64("total_amount_cents").
			Default(0).Min(0),
		field.String("currency_code").
			Default("CNY"),
		field.Bool("is_active").
			Default(true),
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

func (Budget) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("items", BudgetItem.Type).
			Annotations(entsql.OnDelete(entsql.Cascade)),
	}
}

func (Budget) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "month").Unique(),
	}
}
