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

// Holding tracks a position in a security for a tenant account.
type Holding struct {
	ent.Schema
}

func (Holding) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Holding) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (Holding) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("account_id", uuid.UUID{}),
		field.UUID("security_id", uuid.UUID{}),
		field.Float("quantity").
			Default(0),
		field.Int64("avg_cost_cents").
			Default(0),
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

func (Holding) Edges() []ent.Edge {
	return nil
}

func (Holding) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "account_id", "security_id").Unique(),
	}
}
