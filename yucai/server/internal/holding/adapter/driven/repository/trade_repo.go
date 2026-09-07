package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holdingtransaction"
	"github.com/yucai/server/internal/sqltx"
)

// TradeRepository implements domain.TradeRepository.
type TradeRepository struct {
	client *holdingent.Client
}

// NewTradeRepository creates a new TradeRepository.
func NewTradeRepository(client *holdingent.Client) *TradeRepository {
	return &TradeRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose writes
// join the outer transaction; otherwise it returns the default r.client (the
// non-transactional path, preserving backward compatibility). Mirrors
// HoldingRepository.clientFor — holding+trade+lot share one ent package so the
// helper shape is identical.
func (r *TradeRepository) clientFor(ctx context.Context) *holdingent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return holdingent.NewClient(holdingent.Driver(d))
	}
	return r.client
}

func (r *TradeRepository) Save(ctx context.Context, tr *domain.HoldingTransaction) error {
	create := r.clientFor(ctx).HoldingTransaction.Create().
		SetID(tr.ID).SetTenantID(tr.TenantID).
		SetAccountID(tr.AccountID).SetSecurityID(tr.SecurityID).
		SetTradeType(tr.TradeType.String()).
		SetQuantity(tr.Quantity).SetPriceCents(tr.PriceCents).
		SetAmountCents(tr.AmountCents).SetFeeCents(tr.FeeCents).
		SetRealizedPnlCents(tr.RealizedPnLCents).
		SetTradeDate(tr.TradeDate).SetNotes(tr.Notes).
		SetCreatedAt(tr.CreatedAt)
	if tr.TransactionID != nil {
		create.SetTransactionID(*tr.TransactionID)
	}
	if _, err := create.Save(ctx); err != nil {
		return fmt.Errorf("save trade: %w", err)
	}
	return nil
}

func (r *TradeRepository) FindAll(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, page domain.PageRequest) (*domain.PaginatedResult[domain.HoldingTransaction], error) {
	query := r.client.HoldingTransaction.Query().Where(holdingtransaction.TenantID(tenantID))
	if accountID != nil {
		query.Where(holdingtransaction.AccountID(*accountID))
	}
	if securityID != nil {
		query.Where(holdingtransaction.SecurityID(*securityID))
	}
	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count trades: %w", err)
	}
	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)
	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(holdingtransaction.IDGTE(cursorID))
	}
	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query trades: %w", err)
	}
	var nextToken string
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}
	items := make([]domain.HoldingTransaction, len(results))
	for i, tr := range results {
		items[i] = *toDomainTrade(tr)
	}
	return &domain.PaginatedResult[domain.HoldingTransaction]{Items: items, NextPageToken: nextToken, TotalCount: int32(total)}, nil
}

func toDomainTrade(tr *holdingent.HoldingTransaction) *domain.HoldingTransaction {
	return &domain.HoldingTransaction{
		ID: tr.ID, TenantID: tr.TenantID, AccountID: tr.AccountID,
		SecurityID: tr.SecurityID, TradeType: domain.ParseTradeType(tr.TradeType),
		Quantity: tr.Quantity, PriceCents: tr.PriceCents,
		AmountCents: tr.AmountCents, FeeCents: tr.FeeCents,
		RealizedPnLCents: tr.RealizedPnlCents,
		TradeDate:        tr.TradeDate, TransactionID: tr.TransactionID,
		Notes: tr.Notes, CreatedAt: tr.CreatedAt,
	}
}

// --- F17-T2 holding_ledger sync writers(ADR-4 台账查证裁决=实施)---
//
// 台账查证结论(2026-09-06,task-brief-f17-2 第 5 节):本 repo/ent 即 server
// 侧台账存储(ent HoldingTransaction 表 + Save 写入路径 + FindAll 读回),
// 台账并非「仅 client 概念」→ 按 ADR-4 落地第 9 个 entityType
// "holding_ledger" 的三件套(与 HoldingRepository 的 *ForSync 家族同构,
// tx-aware via clientFor,写加入 push 批事务)。

// UpsertForSync applies one offline-sync push for a single trade ledger row:
// find by id+tenant, then full-field update, or a create with the client
// trade id. Keyed by entity id (append-only ledger: the client never re-issues
// an id, so the update branch only serves idempotent re-push of the SAME row —
// re-push is accepted per F11 FR-3). AccountID/SecurityID/CreatedAt/
// TransactionID are immutable (ent schema) — set at create only. TradeType
// crosses the wire as the client int enum (buy=1/sell=2/dividend=3/split=4,
// same value domain as domain.TradeType) and is persisted as its string form
// (column contract shared with the holding service write path).
func (r *TradeRepository) UpsertForSync(ctx context.Context, tr *domain.HoldingTransaction) error {
	c := r.clientFor(ctx)
	_, err := c.HoldingTransaction.Query().
		Where(holdingtransaction.ID(tr.ID), holdingtransaction.TenantID(tr.TenantID)).
		First(ctx)
	switch {
	case err == nil:
		if _, err := c.HoldingTransaction.UpdateOneID(tr.ID).
			SetTradeType(tr.TradeType.String()).
			SetQuantity(tr.Quantity).
			SetPriceCents(tr.PriceCents).
			SetAmountCents(tr.AmountCents).
			SetFeeCents(tr.FeeCents).
			SetRealizedPnlCents(tr.RealizedPnLCents).
			SetTradeDate(tr.TradeDate).
			SetNotes(tr.Notes).
			Save(ctx); err != nil {
			return fmt.Errorf("sync upsert trade %s: %w", tr.ID, err)
		}
		return nil
	case holdingent.IsNotFound(err):
		create := c.HoldingTransaction.Create().
			SetID(tr.ID).SetTenantID(tr.TenantID).
			SetAccountID(tr.AccountID).SetSecurityID(tr.SecurityID).
			SetTradeType(tr.TradeType.String()).
			SetQuantity(tr.Quantity).
			SetPriceCents(tr.PriceCents).
			SetAmountCents(tr.AmountCents).
			SetFeeCents(tr.FeeCents).
			SetRealizedPnlCents(tr.RealizedPnLCents).
			SetTradeDate(tr.TradeDate).
			SetNotes(tr.Notes)
		// CreatedAt passthrough(mirror Save):zero value falls back to ent
		// Default(time.Now);TransactionID 可空(离线台账无关联交易)。
		if !tr.CreatedAt.IsZero() {
			create = create.SetCreatedAt(tr.CreatedAt)
		}
		if tr.TransactionID != nil {
			create = create.SetTransactionID(*tr.TransactionID)
		}
		if _, err := create.Save(ctx); err != nil {
			return fmt.Errorf("sync create trade %s: %w", tr.ID, err)
		}
		return nil
	default:
		return fmt.Errorf("sync find trade %s: %w", tr.ID, err)
	}
}

// HardDeleteForSync physically removes one ledger row on the offline-sync
// DELETE path. Idempotent by design (tombstone re-delivery is a no-op).
// The client collector never emits holding_ledger tombstones today (the
// offline trade path has no user-facing delete) — this exists for wire
// completeness so a future ledger delete cannot fail the batch.
func (r *TradeRepository) HardDeleteForSync(ctx context.Context, tenantID, tradeID uuid.UUID) error {
	if _, err := r.clientFor(ctx).HoldingTransaction.Delete().
		Where(holdingtransaction.ID(tradeID), holdingtransaction.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync hard delete trade %s: %w", tradeID, err)
	}
	return nil
}

// FindForSync returns the tenant's current ledger row for the sync conflict
// check (F16 ADR-4) — the read dual of UpsertForSync. found=false means the
// tenant holds no row for the id.
func (r *TradeRepository) FindForSync(ctx context.Context, tenantID, tradeID uuid.UUID) (*domain.HoldingTransaction, bool, error) {
	tr, err := r.clientFor(ctx).HoldingTransaction.Query().
		Where(holdingtransaction.ID(tradeID), holdingtransaction.TenantID(tenantID)).
		First(ctx)
	if err != nil {
		if holdingent.IsNotFound(err) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("sync find trade %s: %w", tradeID, err)
	}
	return toDomainTrade(tr), true, nil
}

var _ domain.TradeRepository = (*TradeRepository)(nil)
