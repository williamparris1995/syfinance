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

var _ domain.TradeRepository = (*TradeRepository)(nil)
