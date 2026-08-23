package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/index"
	"entgo.io/ent/schema/field"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/ent/schema/mixin"
)

// User holds the schema definition for the User entity.
// Users belong to a tenant and authenticate exclusively via OIDC identities
// (one User may have multiple UserIdentity rows — one per provider).
type User struct {
	ent.Schema
}

func (User) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (User) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (User) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New).
			Comment("Primary key"),
		field.String("email").
			Optional().
			Default("").
			Comment("Profile email (from first OIDC identity, verified only)"),
		field.String("display_name").
			NotEmpty().
			Comment("User-visible display name"),
		field.String("avatar_url").
			Optional().
			Default("").
			Comment("URL to user avatar image"),
		field.Enum("family_role").
			Values("owner", "admin", "member").
			Default("owner").
			Comment("Role within family tenant"),
		field.Bool("is_admin").
			Default(false).
			Comment("Global platform admin — authorizes securities write RPCs (first-user-is-admin on JIT provisioning)"),
		field.Time("created_at").
			Default(time.Now).
			Immutable().
			Comment("Record creation time"),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now).
			Comment("Last update time"),
	}
}

func (User) Edges() []ent.Edge {
	return []ent.Edge{
		// StorageKey is intentionally omitted: UserIdentity declares the FK
		// column via edge.From("user").Field("user_id").Ref("identities"),
		// which ent resolves automatically. Re-declaring the column here
		// triggers "should be replaced with Field(...) on its reference".
		edge.To("identities", UserIdentity.Type),
	}
}

func (User) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("email").Unique().
			Annotations(&entsql.IndexAnnotation{Where: "email <> ''"}),
	}
}
