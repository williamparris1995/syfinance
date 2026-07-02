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

// GoalAccountLinks links a goal to multiple accounts (Investment + Savings).
// 独立 join 表(因 account 跨 ent module,不用 ent edge)。
// 跨 module 关联通过查询时手动 join 维护,不用 ent edge。
type GoalAccountLinks struct {
	ent.Schema
}

func (GoalAccountLinks) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (GoalAccountLinks) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (GoalAccountLinks) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("goal_id", uuid.UUID{}),
		field.UUID("account_id", uuid.UUID{}),
	}
}

func (GoalAccountLinks) Edges() []ent.Edge {
	return nil
}

func (GoalAccountLinks) Indexes() []ent.Index {
	return []ent.Index{
		// 跨 module join 表:唯一约束防重复 link
		index.Fields("tenant_id", "goal_id", "account_id").Unique(),
		index.Fields("tenant_id", "goal_id"),
	}
}
