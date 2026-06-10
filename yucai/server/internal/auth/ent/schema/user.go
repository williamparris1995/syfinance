package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/ent/schema/mixin"
	"time"
)

// User holds the schema definition for the User entity.
// Users belong to a tenant and authenticate via email/password or OAuth.
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
			NotEmpty().
			Comment("User email address, unique per tenant"),
		field.String("password_hash").
			NotEmpty().
			Sensitive().
			Comment("bcrypt hashed password"),
		field.String("display_name").
			NotEmpty().
			Comment("User-visible display name"),
		field.String("avatar_url").
			Optional().
			Default("").
			Comment("URL to user avatar image"),
		field.String("oauth_provider").
			Optional().
			Default("").
			Comment("OAuth provider name (google, apple, etc.)"),
		field.String("oauth_id").
			Optional().
			Default("").
			Comment("OAuth provider user ID"),
		field.Enum("family_role").
			Values("owner", "admin", "member").
			Default("owner").
			Comment("Role within family tenant"),
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
	return nil
}

func (User) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "email").Unique(),
	}
}
