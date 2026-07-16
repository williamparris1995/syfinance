package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// BackupSettings holds per-tenant auto-backup preferences.
type BackupSettings struct {
	ent.Schema
}

func (BackupSettings) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (BackupSettings) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (BackupSettings) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.Bool("auto_backup").Default(false),
		field.Int32("auto_backup_interval_hours").Default(24),
	}
}

func (BackupSettings) Edges() []ent.Edge { return nil }

// Indexes enforces one row per tenant so concurrent Save calls cannot create
// duplicate rows (which would break GetByTenant's .Only expectation).
//
// The unique index uses a custom StorageKey (name) so it coexists with
// TenantMixin's plain (non-unique) tenant_id index without a name collision.
// This keeps the constraint regen-durable: a future `go generate` re-emits
// both indexes cleanly instead of producing two same-named entries that break
// migration with "index already exists".
func (BackupSettings) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id").Unique().StorageKey("backupsettings_tenant_id_unique"),
	}
}
