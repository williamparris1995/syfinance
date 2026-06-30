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

// RateHistory holds daily exchange-rate history per currency (to base CNY).
// Tenant-free — currency is global reference (aligned with Currency table).
// currency SyncRates writes one row per refresh; holding reads for CNY折算.
type RateHistory struct {
	ent.Schema
}

func (RateHistory) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (RateHistory) Mixin() []ent.Mixin { return nil }

func (RateHistory) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.String("currency_code").
			Comment("ISO 4217 (CNY=base=1.0)"),
		field.Time("rate_date"),
		field.Float("exchange_rate").
			Comment("to base (CNY)"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (RateHistory) Edges() []ent.Edge {
	return nil
}

func (RateHistory) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("currency_code", "rate_date").Unique(),
	}
}
