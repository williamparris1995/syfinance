package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// GoalDebtLinks links a debt-payoff goal to multiple debts (DebtPayoff 多债务).
// 独立 join 表(因 debt 跨 ent module,不用 ent edge)。
type GoalDebtLinks struct {
	ent.Schema
}

func (GoalDebtLinks) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (GoalDebtLinks) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (GoalDebtLinks) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("goal_id", uuid.UUID{}),
		field.UUID("debt_id", uuid.UUID{}),
	}
}

func (GoalDebtLinks) Edges() []ent.Edge {
	return nil
}

func (GoalDebtLinks) Indexes() []ent.Index {
	return []ent.Index{
		// 跨 module join 表:唯一约束防重复 link
		index.Fields("tenant_id", "goal_id", "debt_id").Unique(),
		index.Fields("tenant_id", "goal_id"),
	}
}
