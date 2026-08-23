package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// TransactionEntry holds the schema for individual debit/credit entries.
type TransactionEntry struct {
	ent.Schema
}

func (TransactionEntry) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
		entsql.Check("((debit_cents > 0 AND credit_cents = 0) OR (credit_cents > 0 AND debit_cents = 0))"),
	}
}

func (TransactionEntry) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("transaction_id", uuid.UUID{}).
			Comment("FK to Transaction"),
		field.UUID("account_id", uuid.UUID{}).
			Comment("FK to Account"),
		field.String("chart_of_account_code").
			Default(""),
		field.Int64("debit_cents").
			Default(0).
			Comment("Debit amount in cents").Min(0),
		field.Int64("credit_cents").
			Default(0).
			Comment("Credit amount in cents").Min(0),
		field.String("note").
			Optional().
			Default(""),
	}
}

func (TransactionEntry) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("transaction", Transaction.Type).Ref("entries").
			Field("transaction_id").Unique().Required(),
	}
}

func (TransactionEntry) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("transaction_id"),
		index.Fields("account_id"),
	}
}
