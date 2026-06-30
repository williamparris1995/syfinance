package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// HoldingSnapshot holds daily market-value snapshot per holding (original
// currency). Tenant-scoped. Portfolio curve = Σ snapshots × rate_history → CNY.
type HoldingSnapshot struct {
	ent.Schema
}

func (HoldingSnapshot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (HoldingSnapshot) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (HoldingSnapshot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("holding_id", uuid.UUID{}),
		field.UUID("security_id", uuid.UUID{}).
			Comment("denormalized for security-level aggregation"),
		field.UUID("account_id", uuid.UUID{}).
			Comment("denormalized for account filter"),
		field.Time("snapshot_date"),
		field.Int64("market_value_cents").
			Comment("qty × day's price, original currency"),
		field.Int64("unrealized_pnl_cents").
			Comment("original currency"),
		field.String("currency_code").
			Default("CNY"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (HoldingSnapshot) Edges() []ent.Edge {
	return nil
}

func (HoldingSnapshot) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "holding_id", "snapshot_date").Unique(),
		index.Fields("tenant_id", "snapshot_date"),
		index.Fields("tenant_id", "security_id", "snapshot_date"),
	}
}
