package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// TransactionTag holds the schema for the tag-transaction junction table.
type TransactionTag struct {
	ent.Schema
}

func (TransactionTag) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (TransactionTag) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("transaction_id", uuid.UUID{}),
		field.UUID("tag_id", uuid.UUID{}),
	}
}

func (TransactionTag) Edges() []ent.Edge {
	return nil
}

func (TransactionTag) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("transaction_id"),
		index.Fields("tag_id"),
		index.Fields("transaction_id", "tag_id").Unique(),
	}
}
