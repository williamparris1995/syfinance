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

// Account holds the schema definition for the Account entity.
// Account is the core aggregate root for the double-entry bookkeeping system.
type Account struct {
	ent.Schema
}

func (Account) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (Account) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (Account) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New).
			Comment("Primary key"),
		field.String("name").
			NotEmpty().
			Comment("Account display name"),
		field.Enum("account_type").
			Values("asset", "liability", "equity", "income", "expense").
			Comment("Account type per Chinese accounting standards"),
		field.Enum("category").
			Values("savings", "credit_card", "investment", "fixed_deposit",
				"gold_fx", "real_estate", "loan", "other_asset", "other_liability").
			Default("savings").
			Comment("User-facing account category; drives account_type"),
		field.String("currency_code").
			Default("CNY").
			Comment("ISO 4217 currency code"),
		field.Int64("initial_balance_cents").
			Default(0).
			Comment("Initial balance in integer cents"),
		field.Int64("current_balance_cents").
			Default(0).
			Comment("Current calculated balance in integer cents"),
		field.Enum("ownership").
			Values("personal", "joint").
			Default("personal").
			Comment("Account ownership type"),
		field.String("icon").
			Optional().
			Default("").
			Comment("Icon name or emoji"),
		field.String("color").
			Optional().
			Default("").
			Comment("Hex color for display"),
		field.String("chart_code").
			Optional().
			Default("").
			Comment("Chart of accounts code"),
		field.UUID("parent_id", uuid.UUID{}).
			Optional().
			Nillable().
			Comment("Parent account for hierarchical structure"),
		field.String("institution").
			Optional().
			Default("").
			Comment("Bank or financial institution name"),
		field.Int64("credit_limit_cents").
			Default(0).
			Comment("Credit limit in cents (for credit cards/lines)"),
		field.Enum("status").
			Values("active", "archived").
			Default("active").
			Comment("Account status"),
		field.Int64("version").
			Default(1).
			Comment("Optimistic locking version"),
		field.Time("deleted_at").
			Optional().
			Nillable().
			Comment("Soft delete timestamp"),
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

func (Account) Edges() []ent.Edge {
	return nil
}

func (Account) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "account_type"),
		index.Fields("tenant_id", "status"),
		index.Fields("tenant_id", "chart_code"),
	}
}
