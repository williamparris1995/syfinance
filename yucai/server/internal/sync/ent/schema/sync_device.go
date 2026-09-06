package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
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

// Indexes: deliberately no unique index. F16 ADR-2 considered
// UNIQUE(tenant_id, device_id), but the table's PRIMARY KEY id IS the device
// id (the device uuid clients register), so (tenant_id, id) uniqueness is
// already enforced by the PK itself — an extra index would be redundant.
// Idempotent re-registration (same id, same tenant -> return the existing
// row) is implemented in the repository's Register, not via a constraint.
// device_name is NOT a user key (two devices may share a display name).
func (SyncDevice) Indexes() []ent.Index {
	return nil
}
