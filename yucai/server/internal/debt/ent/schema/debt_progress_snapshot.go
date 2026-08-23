package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// DebtProgressSnapshot holds daily progress snapshot per DebtDetails row
// (original currency). Tenant-scoped. 用于绘制债务/债权余额下降曲线
// (Task 4+ repo WriteSnapshot + proto remaining_trend_cents)。
//
// Unique(tenant_id, debt_id, snapshot_date):同一 debt 同一日期唯一,
// 写入时用 ent Upsert / OnConflict 语义,按这三列去重更新。
type DebtProgressSnapshot struct {
	ent.Schema
}

func (DebtProgressSnapshot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{
		entsql.WithComments(true),
	}
}

func (DebtProgressSnapshot) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.TenantMixin{},
	}
}

func (DebtProgressSnapshot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).
			Default(uuid.New),
		field.UUID("debt_id", uuid.UUID{}).
			Comment("FK to DebtDetails"),
		field.Time("snapshot_date"),
		field.Int64("total_principal_cents").
			Comment("debt total principal at snapshot_date, original currency"),
		field.Int64("remaining_principal_cents").
			Comment("remaining principal at snapshot_date, original currency"),
		field.Int64("paid_total_cents").
			Comment("cumulative paid (principal+interest) at snapshot_date, original currency"),
		field.Time("created_at").
			Default(time.Now).
			Immutable(),
	}
}

func (DebtProgressSnapshot) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("debt", DebtDetails.Type).Ref("progress_snapshots").
			Field("debt_id").Unique().Required(),
	}
}

func (DebtProgressSnapshot) Indexes() []ent.Index {
	return []ent.Index{
		// Unique(tenant_id, debt_id, snapshot_date):repo WriteSnapshot 按这三列去重 upsert
		index.Fields("tenant_id", "debt_id", "snapshot_date").Unique(),
		index.Fields("tenant_id", "snapshot_date"),
		index.Fields("tenant_id", "debt_id"),
	}
}
