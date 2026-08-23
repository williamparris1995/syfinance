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

// HoldingLot is a FIFO cost lot. Buy creates a lot; sell consumes
// RemainingQuantity in acquired_date order; split adjusts Quantity and
// RemainingQuantity by ratio. remaining=0 lots retained for audit.
type HoldingLot struct {
	ent.Schema
}

func (HoldingLot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (HoldingLot) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (HoldingLot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("holding_id", uuid.UUID{}),
		field.UUID("security_id", uuid.UUID{}).
			Comment("denormalized").Immutable(),
		field.Time("acquired_date").
			Comment("buy trade date; FIFO ordering key"),
		field.UUID("acquired_trade_id", uuid.UUID{}).
			Comment("holding_transaction.id of the buy").Immutable(),
		field.Int64("price_cents").
			Comment("buy cost price").Min(0),
		field.Float("quantity").
			Comment("original acquired quantity").Min(0),
		field.Float("remaining_quantity").
			Comment("remaining after sells/splits").Min(0),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (HoldingLot) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("holding", Holding.Type).Ref("lots").
			Field("holding_id").Unique().Required(),
	}
}

func (HoldingLot) Indexes() []ent.Index {
	return []ent.Index{
		// FIFO consume order
		index.Fields("tenant_id", "holding_id", "acquired_date"),
	}
}
