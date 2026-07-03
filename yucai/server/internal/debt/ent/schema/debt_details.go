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

// DebtDetails holds the schema for debt/loan tracking (1:1 with liability accounts).
type DebtDetails struct {
	ent.Schema
}

func (DebtDetails) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (DebtDetails) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (DebtDetails) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("account_id", uuid.UUID{}).
			Comment("FK to Account (UNIQUE, 1:1)"),
		field.String("counterparty").
			Comment("Lender name"),
		field.Float("interest_rate").
			Comment("Annual rate, e.g. 0.05 = 5%"),
		field.String("amortization_method").
			Comment("equal_principal_interest, equal_principal, lump_sum"),
		field.Time("start_date"),
		field.Time("due_date"),
		field.Int64("total_principal_cents"),
		field.String("debt_type").
			Default("borrowed_in").
			Comment("borrowed_in(我借入) / borrowed_out(我借出/债权)"),
		field.String("subtype").
			Default("").
			Comment("debt subtype key: mortgage/auto_loan/credit_card/family/other (borrowedIn); personal/business/family/other (borrowedOut)"),
		field.Int64("version").
			Default(1),
		// Receivables align (Task 2): 3 nullable contact/contract/collection fields.
		// contact/contract_ref: free-text, default empty string (optional but non-null column).
		// collection_account_id: FK to Account (collection account for receivables),
		//   optional + nillable (NULL when unset).
		field.String("contact").
			Default("").
			Comment("Contact person for this debt/receivable"),
		field.String("contract_ref").
			Default("").
			Comment("Contract / agreement reference"),
		field.UUID("collection_account_id", uuid.UUID{}).
			Optional().
			Nillable().
			Comment("FK to Account — collection account for receivables (borrowed_out)"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now),
	}
}

func (DebtDetails) Edges() []ent.Edge {
	return nil
}

func (DebtDetails) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "account_id").Unique(),
	}
}
