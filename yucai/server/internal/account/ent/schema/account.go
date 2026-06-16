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
		field.String("card_number_tail").Optional().Default("").Comment("Card/account last digits (financial types)"),
		field.String("notes").Optional().Default("").Comment("Free-form notes"),
		field.Time("opening_date").Optional().Nillable().Comment("Account opening date (financial types)"),
		field.Float("interest_rate").Optional().Nillable().Comment("Annual rate %: savings/fixed/loan rate, credit card APR"),
		field.Int("credit_billing_day").Optional().Nillable().Comment("Credit card billing day (1-31)"),
		field.Int("credit_repayment_day").Optional().Nillable().Comment("Credit card repayment day (1-31)"),
		field.Int64("credit_annual_fee_cents").Optional().Nillable().Comment("Credit card annual fee in cents"),
		field.Int64("invest_cost_cents").Optional().Nillable().Comment("Investment total cost basis in cents"),
		field.Int64("invest_market_value_cents").Optional().Nillable().Comment("Investment current market value in cents"),
		field.Float("invest_return_ytd").Optional().Nillable().Comment("Investment year-to-date return rate (%)"),
		field.Int64("fixed_principal_cents").Optional().Nillable().Comment("Fixed deposit principal in cents"),
		field.Time("fixed_start_date").Optional().Nillable().Comment("Fixed deposit start (value) date"),
		field.Time("fixed_maturity_date").Optional().Nillable().Comment("Fixed deposit maturity date"),
		field.Int("fixed_term_months").Optional().Nillable().Comment("Fixed deposit term in months"),
		field.String("gold_product_type").Optional().Default("").Comment("Gold/FX product type (e.g. gold, usd)"),
		field.Float("gold_quantity").Optional().Nillable().Comment("Gold/FX holding quantity"),
		field.Int64("gold_buy_price_cents").Optional().Nillable().Comment("Gold/FX buy price in cents"),
		field.Int64("gold_current_price_cents").Optional().Nillable().Comment("Gold/FX current price in cents"),
		field.Int64("estate_purchase_price_cents").Optional().Nillable().Comment("Real estate purchase price in cents"),
		field.Int64("estate_current_value_cents").Optional().Nillable().Comment("Real estate current appraised value in cents"),
		field.Time("estate_purchase_date").Optional().Nillable().Comment("Real estate purchase date"),
		field.Float("estate_depreciation_rate").Optional().Nillable().Comment("Real estate depreciation rate (%)"),
		field.Int64("loan_original_cents").Optional().Nillable().Comment("Loan original principal in cents"),
		field.Int64("loan_remaining_cents").Optional().Nillable().Comment("Loan remaining principal in cents"),
		field.Int64("loan_monthly_cents").Optional().Nillable().Comment("Loan monthly payment in cents"),
		field.Time("loan_next_payment_date").Optional().Nillable().Comment("Loan next payment date"),
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
