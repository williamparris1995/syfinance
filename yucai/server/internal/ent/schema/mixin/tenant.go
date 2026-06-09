package mixin

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entmixin "entgo.io/ent/schema/mixin"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// TenantMixin adds tenant_id to any schema for multi-tenancy isolation.
// Embed in any schema that needs tenant-scoped data.
type TenantMixin struct {
	entmixin.Schema
}

func (TenantMixin) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (TenantMixin) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("tenant_id", uuid.UUID{}).
			Immutable().
			Comment("FK to tenants table — data isolation boundary"),
	}
}

func (TenantMixin) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id"),
	}
}
