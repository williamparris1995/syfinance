package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"time"
)

// Feedback stores in-app user feedback submissions (issue / idea / other).
//
// It is a GLOBAL table by design: feedback is anonymously submittable (guest
// mode must be able to report problems), so there is no TenantMixin and no
// tenant_id column — deliberately unlike every other module schema here.
type Feedback struct {
	ent.Schema
}

func (Feedback) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

// Mixin intentionally omitted: no TenantMixin (see type comment).
func (Feedback) Fields() []ent.Field {
	return []ent.Field{
		// id is the DB auto-increment primary key (no Default → auto).
		field.Int("id"),
		field.String("type").MaxLen(8).Comment("issue, idea, other"),
		field.String("body"),
		field.String("contact").Default(""),
		field.String("app_version"),
		field.String("platform"),
		field.String("account_mode"),
		field.String("theme_mode"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (Feedback) Edges() []ent.Edge { return nil }
