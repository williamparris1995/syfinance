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

// SyncConflict holds the schema for sync conflict records.
type SyncConflict struct {
	ent.Schema
}

func (SyncConflict) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (SyncConflict) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (SyncConflict) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("entity_type").Comment("account, transaction, etc."),
		field.UUID("entity_id", uuid.UUID{}).Comment("ID of the conflicting entity"),
		field.String("conflict_type").Default("update_update").Comment("update_update, delete_update, create_create"),
		field.Bytes("server_payload").Comment("Server-side entity state"),
		field.Bytes("client_payload").Comment("Client-side entity state"),
		field.String("resolution").Default("pending").Comment("pending, server, client, merged"),
		field.Time("resolved_at").Optional().Nillable(),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (SyncConflict) Edges() []ent.Edge { return nil }

func (SyncConflict) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "resolution"),
		index.Fields("tenant_id", "entity_type", "entity_id"),
	}
}
