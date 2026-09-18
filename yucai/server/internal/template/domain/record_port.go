package domain

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// ErrTemplatePaused is returned when attempting to record a transaction from a
// paused template. Sentinel value so the application layer (and callers) can
// distinguish a paused rejection from other record failures.
var ErrTemplatePaused = errors.New("template is paused")

// RecordRequest 是 template 模块请求 transaction 模块记账的入参。
// 由 template application 组装(template 不 import transaction),经
// TransactionRecorder port 传递给 transaction application 的 adapter。
type RecordRequest struct {
	// Direction 收支方向(expense 借 category 贷 asset;income 借 asset 贷 income;
	// transfer 借 dest 贷 source)。
	Direction TemplateDirection
	// AmountCents 金额(分)。
	AmountCents int64
	// SourceAccountID 源账户(expense 的资产账户 / income 的资产账户 / transfer 的贷方)。
	SourceAccountID uuid.UUID
	// DestinationAccount 目标账户(仅 transfer 非空;expense/income 为 nil)。
	DestinationAccount *uuid.UUID
	// Category 业务分类(expense 的 category 账户名)。
	Category string
	// Date 记账日期(模板的 NextDate)。
	Date time.Time
}

// TransactionRecorder 是 template domain 定义的 port:把模板实例化为 transaction。
// template 不 import transaction;由 transaction application 的 adapter 实现此接口,
// wire 注入到 template Service。对齐 backup TenantDataPort 跨模块 port 惯例。
type TransactionRecorder interface {
	// Record 基于 req 创建一笔 transaction,返回新 transaction 的 ID。
	Record(ctx context.Context, tenantID uuid.UUID, req RecordRequest) (txnID uuid.UUID, err error)
}
