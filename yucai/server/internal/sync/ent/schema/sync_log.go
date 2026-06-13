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

// SyncLog holds the schema for the append-only sync change log.
type SyncLog struct {
	ent.Schema
}

func (SyncLog) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (SyncLog) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (SyncLog) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("entity_type").Comment("account, transaction, budget, etc."),
		field.UUID("entity_id", uuid.UUID{}).Comment("ID of the changed entity"),
		field.String("operation").Comment("create, update, delete"),
		field.Bytes("payload").Comment("Serialized entity JSON"),
		field.Int64("version").Comment("Monotonically increasing per tenant"),
		field.UUID("device_id", uuid.UUID{}).Comment("Device that originated the change"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (SyncLog) Edges() []ent.Edge { return nil }

func (SyncLog) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "version"),
		index.Fields("tenant_id", "entity_type", "entity_id"),
	}
}
