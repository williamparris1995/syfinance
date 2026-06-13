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

// Category is the tenant-scoped schema for income/expense classification.
type Category struct {
	ent.Schema
}

func (Category) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (Category) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (Category) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("name").NotEmpty(),
		field.String("category_type").Comment("income, expense"),
		field.String("icon").Default("").Comment("Emoji or icon name"),
		field.String("color").Default("#000000").Comment("Hex color"),
		field.UUID("parent_id", uuid.UUID{}).Optional().Nillable(),
		field.Bool("is_system").Default(false),
		field.Int32("sort_order").Default(0),
		field.Int64("version").Default(1),
		field.Time("deleted_at").Optional().Nillable(),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (Category) Edges() []ent.Edge { return nil }

func (Category) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "category_type"),
		index.Fields("tenant_id"),
	}
}
