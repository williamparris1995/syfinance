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

// ChartOfAccounts holds the schema definition for the ChartOfAccounts entity.
// Per-tenant chart of accounts following Chinese accounting standards.
type ChartOfAccounts struct {
	ent.Schema
}

func (ChartOfAccounts) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (ChartOfAccounts) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (ChartOfAccounts) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New).
			Comment("Primary key"),
		field.String("code").
			NotEmpty().
			Comment("Chart of accounts code (unique per tenant, e.g. '1001')"),
		field.String("name").
			NotEmpty().
			Comment("Account name in chart"),
		field.Int("level").
			Default(1).
			Comment("Hierarchy level (1=top, 2=sub, etc.)"),
		field.Enum("account_type").
			Values("asset", "liability", "equity", "income", "expense").
			Comment("Account type this chart entry belongs to"),
		field.String("parent_code").
			Optional().
			Default("").
			Comment("Parent chart code for hierarchy"),
		field.Enum("balance_direction").
			Values("debit", "credit").
			Default("debit").
			Comment("Normal balance direction for this account type"),
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

func (ChartOfAccounts) Edges() []ent.Edge {
	return nil
}

func (ChartOfAccounts) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "code").Unique(),
	}
}
