package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// SecurityPriceHistory holds daily price history per security (original
// currency). Tenant-free — price is global master data (aligned with Security).
type SecurityPriceHistory struct {
	ent.Schema
}

func (SecurityPriceHistory) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (SecurityPriceHistory) Mixin() []ent.Mixin { return nil }

func (SecurityPriceHistory) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("security_id", uuid.UUID{}).
			Comment("owning security (incl. benchmark 000300)"),
		field.Time("price_date").
			Comment("one row per security per date"),
		field.Int64("price_cents").
			Comment("close price in original currency cents"),
		field.String("currency_code").
			Default("CNY"),
		field.String("source").
			Default("sina").
			Comment("sina / backfill / manual"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (SecurityPriceHistory) Edges() []ent.Edge {
	return nil
}

func (SecurityPriceHistory) Indexes() []ent.Index {
	return []ent.Index{
		// UNIQUE(security_id, price_date) doubles as the per-security date-range
		// lookup index — the separate non-unique index on the same columns is
		// dropped: it collided with the unique index name under ent auto-migrate
		// ("index already exists") and was fully redundant.
		index.Fields("security_id", "price_date").Unique(),
	}
}
