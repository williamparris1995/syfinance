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
		// F18 review fix round 1 (FAIL-2): the default stamps UTC (and strips
		// the monotonic clock reading time.Now carries). ent persists time
		// columns on SQLite through time.Time's String() form INCLUDING the
		// zone, so UTC-uniform writes keep newest-first text ordering ==
		// chronological, and the FindPending keyset cursor re-binds the exact
		// stored text for the tuple equality arm. PostgreSQL (timestamptz) is
		// zone-agnostic and unaffected.
		field.Time("created_at").Default(func() time.Time { return time.Now().UTC() }).Immutable(),
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
