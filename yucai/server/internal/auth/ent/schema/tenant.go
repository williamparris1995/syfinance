package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"github.com/google/uuid"
	"time"
)

// Tenant holds the schema definition for the Tenant entity.
// Tenant is the data isolation boundary for multi-tenancy.
type Tenant struct {
	ent.Schema
}

func (Tenant) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Tenant) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New).
			Comment("Primary key"),
		field.Enum("type").
			Values("personal", "family").
			Default("personal").
			Comment("Tenant type: personal (single user) or family (shared)"),
		field.String("name").
			NotEmpty().
			Comment("Display name for the tenant"),
		field.Time("created_at").
			Default(time.Now).
			Immutable().
			Comment("Record creation time"),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now).
			Comment("Last update time"),
	}
}

func (Tenant) Edges() []ent.Edge {
	return nil
}
