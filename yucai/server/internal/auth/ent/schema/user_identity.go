package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/ent/schema/mixin"
)

// UserIdentity binds an external OIDC identity (provider+subject) to a User.
// One User may have multiple identities (one per provider) — enables future
// account-link. Login lookup is by (provider, subject) global unique.
type UserIdentity struct {
	ent.Schema
}

func (UserIdentity) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (UserIdentity) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (UserIdentity) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New).Comment("Primary key"),
		field.UUID("user_id", uuid.UUID{}).Comment("Owning user"),
		field.String("provider").NotEmpty().Comment("OIDC provider name (google, github, ...)"),
		field.String("subject").NotEmpty().Comment("IDP sub claim, unique per provider"),
		field.String("issuer").Optional().Default("").Comment("IDP issuer URL"),
		field.String("email_at_provider").Optional().Default("").Comment("Email returned by this IDP"),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (UserIdentity) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("user", User.Type).
			Ref("identities").
			Field("user_id").
			Unique().
			Required(),
	}
}

func (UserIdentity) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("provider", "subject").Unique(),
		index.Fields("user_id", "provider").Unique(),
	}
}
