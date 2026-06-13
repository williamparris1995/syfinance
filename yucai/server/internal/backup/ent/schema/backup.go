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

type Backup struct {
	ent.Schema
}

func (Backup) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (Backup) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (Backup) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("provider").Comment("local, webdav, dropbox, google_drive, one_drive"),
		field.String("filename").NotEmpty(),
		field.Int64("size_bytes").Default(0),
		field.String("checksum").Default(""),
		field.Bool("encrypted").Default(false),
		field.Bool("auto").Default(false),
		field.Int64("version").Default(1),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (Backup) Edges() []ent.Edge { return nil }

func (Backup) Indexes() []ent.Index {
	return []ent.Index{index.Fields("tenant_id")}
}
