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
		// UNIQUE (F16 ADR-1): per-tenant version numbers are strictly
		// serialized. The non-unique index let two concurrent PushChanges
		// batches both read LatestVersion=N and both append N+1.., duplicating
		// versions (multi-device hazard #2). The unique index turns the race
		// into a constraint failure the service catches and retries with a
		// fresh LatestVersion (application.Service.PushChanges).
		//
		// Migration note: there is no production migration tool — the wire
		// provider (wire/providers.go provideSyncEntClient) runs ent's
		// Schema.Create auto-migration at startup. CAVEAT (holistic review):
		// on a DEPLOYED database where the pre-fix NON-unique index of the
		// same name already exists, ent auto-migration SILENTLY SKIPS the
		// new unique definition (it sees the same-name index and keeps it)
		// — the race window stays open with no error. Operators upgrading a
		// pre-fix deployment must drop the old synclog_tenant_id_version
		// index and deduplicate any duplicate (tenant_id, version) rows, then
		// restart so the unique index is created. Fresh and test databases
		// (all schemas created anew) are unaffected.
		index.Fields("tenant_id", "version").Unique(),
		index.Fields("tenant_id", "entity_type", "entity_id"),
	}
}
