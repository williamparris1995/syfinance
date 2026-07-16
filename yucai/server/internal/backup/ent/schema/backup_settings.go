package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
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

func (BackupSettings) Indexes() []ent.Index { return nil }
