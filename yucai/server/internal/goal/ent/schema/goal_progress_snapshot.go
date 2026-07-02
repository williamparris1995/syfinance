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

// GoalProgressSnapshot holds daily progress snapshot per goal (original
// currency). Tenant-scoped. 用于绘制目标进度曲线(Task 6 WriteSnapshot)。
//
// Unique(tenant_id, goal_id, snapshot_date):同一 goal 同一日期唯一,
// 写入时用 ent Upsert / OnConflict 语义,按这三列去重更新。
type GoalProgressSnapshot struct {
	ent.Schema
}

func (GoalProgressSnapshot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (GoalProgressSnapshot) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (GoalProgressSnapshot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("goal_id", uuid.UUID{}),
		field.Time("snapshot_date"),
		field.Int64("current_amount_cents").
			Comment("goal progress at snapshot_date, original currency"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (GoalProgressSnapshot) Edges() []ent.Edge {
	return nil
}

func (GoalProgressSnapshot) Indexes() []ent.Index {
	return []ent.Index{
		// Unique(goal_id, snapshot_date):Task 6 WriteSnapshot 按 tenant_id+goal_id+snapshot_date 去重 upsert
		index.Fields("tenant_id", "goal_id", "snapshot_date").Unique(),
		index.Fields("tenant_id", "snapshot_date"),
		index.Fields("tenant_id", "goal_id"),
	}
}
