package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// Currency is a global reference table — no TenantMixin.
type Currency struct {
	ent.Schema
}

func (Currency) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (Currency) Mixin() []ent.Mixin { return nil }

func (Currency) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("code").Unique().Comment("ISO 4217 code, e.g. CNY"),
		field.String("name").NotEmpty(),
		field.String("symbol").Default(""),
		field.Float("exchange_rate").Default(1.0).Comment("Rate to base currency"),
		field.Bool("is_active").Default(true),
	}
}

func (Currency) Edges() []ent.Edge { return nil }

func (Currency) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("code"),
	}
}
