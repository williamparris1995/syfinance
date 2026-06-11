package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"time"
)

// Security is a global reference to a tradable security (no tenant).
type Security struct {
	ent.Schema
}

func (Security) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Security) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.String("symbol").
			NotEmpty(),
		field.String("name").
			NotEmpty(),
		field.String("security_type").
			Comment("stock, fund, etf, bond, gold, option, other"),
		field.String("exchange").
			Optional().
			Default(""),
		field.String("currency_code").
			Default("CNY"),
		field.Int64("current_price_cents").
			Optional().
			Default(0),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (Security) Edges() []ent.Edge {
	return nil
}

func (Security) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("symbol", "exchange").Unique(),
	}
}
