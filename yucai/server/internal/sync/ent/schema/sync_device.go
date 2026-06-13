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

// SyncDevice holds the schema for registered sync devices.
type SyncDevice struct {
	ent.Schema
}

func (SyncDevice) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (SyncDevice) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (SyncDevice) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("device_name").NotEmpty(),
		field.Int64("last_sync_version").Default(0),
		field.Time("last_sync_at").Default(time.Now).UpdateDefault(time.Now),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (SyncDevice) Edges() []ent.Edge { return nil }

func (SyncDevice) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id"),
	}
}
