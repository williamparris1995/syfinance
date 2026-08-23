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

// HoldingTransaction is an append-only trade ledger entry.
type HoldingTransaction struct {
	ent.Schema
}

func (HoldingTransaction) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (HoldingTransaction) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (HoldingTransaction) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("account_id", uuid.UUID{}).Immutable(),
		field.UUID("security_id", uuid.UUID{}).Immutable(),
		field.String("trade_type").
			Comment("buy, sell, dividend, split"),
		field.Float("quantity").Min(0),
		field.Int64("price_cents").
			Default(0).Min(0),
		field.Int64("amount_cents").
			Default(0).Min(0),
		field.Int64("fee_cents").
			Default(0).Min(0),
		field.Int64("realized_pnl_cents").
			Default(0).
			Optional().
			Comment("FIFO realized P&L on sell (Task1 ConsumeLotsFIFO); 0 for other trade types"),
		field.Time("trade_date"),
		field.UUID("transaction_id", uuid.UUID{}).
			Optional().
			Nillable().
			Comment("Linked accounting transaction").Immutable(),
		field.String("notes").
			Optional().
			Default(""),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (HoldingTransaction) Edges() []ent.Edge {
	return nil
}

func (HoldingTransaction) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "account_id"),
		index.Fields("tenant_id", "security_id"),
	}
}
