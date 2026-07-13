package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holding"
	"github.com/yucai/server/internal/holding/ent/holdingtransaction"
)

// HoldingRepository implements domain.HoldingRepository.
type HoldingRepository struct {
	client *holdingent.Client
}

// NewHoldingRepository creates a new HoldingRepository.
func NewHoldingRepository(client *holdingent.Client) *HoldingRepository {
	return &HoldingRepository{client: client}
}

func (r *HoldingRepository) SaveOrUpdate(ctx context.Context, h *domain.Holding) error {
	// Try to find existing
	existing, err := r.client.Holding.Query().
		Where(holding.AccountID(h.AccountID), holding.SecurityID(h.SecurityID)).
		Only(ctx)
	if err != nil {
		// Create new
		_, err := r.client.Holding.Create().
			SetID(h.ID).SetTenantID(h.TenantID).
			SetAccountID(h.AccountID).SetSecurityID(h.SecurityID).
			SetQuantity(h.Quantity).SetAvgCostCents(h.AvgCostCents).
			SetVersion(h.Version).SetCreatedAt(h.CreatedAt).SetUpdatedAt(h.UpdatedAt).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("create holding: %w", err)
		}
		return nil
	}
	// Update existing
	_, err = r.client.Holding.UpdateOneID(existing.ID).
		SetQuantity(h.Quantity).SetAvgCostCents(h.AvgCostCents).
		SetVersion(h.Version).SetUpdatedAt(h.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update holding: %w", err)
	}
	return nil
}

func (r *HoldingRepository) FindByAccountAndSecurity(ctx context.Context, tenantID, accountID, securityID uuid.UUID) (*domain.Holding, error) {
	h, err := r.client.Holding.Query().
		Where(holding.TenantID(tenantID), holding.AccountID(accountID), holding.SecurityID(securityID)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find holding: %w", err)
	}
	return toDomainHolding(h), nil
}

// FindByID retrieves a single holding by its primary key. Tenant scope is the
// caller's responsibility (used by GetHoldingPerformance, where the holdingID
// is already tenant-scoped at the handler).
func (r *HoldingRepository) FindByID(ctx context.Context, holdingID uuid.UUID) (*domain.Holding, error) {
	h, err := r.client.Holding.Query().
		Where(holding.ID(holdingID)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find holding by id: %w", err)
	}
	return toDomainHolding(h), nil
}

func (r *HoldingRepository) FindAll(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	query := r.client.Holding.Query().Where(holding.TenantID(tenantID))
	if accountID != nil {
		query.Where(holding.AccountID(*accountID))
	}
	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count holdings: %w", err)
	}
	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)
	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(holding.IDGTE(cursorID))
	}
	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query holdings: %w", err)
	}
	var nextToken string
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}
	items := make([]domain.Holding, len(results))
	for i, h := range results {
		items[i] = *toDomainHolding(h)
	}
	return &domain.PaginatedResult[domain.Holding]{Items: items, NextPageToken: nextToken, TotalCount: int32(total)}, nil
}

func toDomainHolding(h *holdingent.Holding) *domain.Holding {
	return &domain.Holding{
		ID: h.ID, TenantID: h.TenantID, AccountID: h.AccountID,
		SecurityID: h.SecurityID, Quantity: h.Quantity,
		AvgCostCents: h.AvgCostCents, Version: h.Version,
		CreatedAt: h.CreatedAt, UpdatedAt: h.UpdatedAt,
	}
}

// FindAllForBackup returns every holding for a tenant plus every holding
// transaction (trade ledger row) for the same tenant. Two tenant-scoped queries
// (no per-holding N+1). Holdings have no soft-delete column; transactions are
// append-only (no delete at all) — both are returned in full.
func (r *HoldingRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Holding, []domain.HoldingTransaction, error) {
	holdingRows, err := r.client.Holding.Query().
		Where(holding.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("backup query holdings: %w", err)
	}
	holdings := make([]domain.Holding, len(holdingRows))
	for i, h := range holdingRows {
		holdings[i] = *toDomainHolding(h)
	}

	tradeRows, err := r.client.HoldingTransaction.Query().
		Where(holdingtransaction.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("backup query holding transactions: %w", err)
	}
	trades := make([]domain.HoldingTransaction, len(tradeRows))
	for i, tr := range tradeRows {
		trades[i] = *toDomainTrade(tr)
	}
	return holdings, trades, nil
}

// DeleteByTenant hard-deletes all of a tenant's holding data. Holding
// transactions first (logically child of holdings — linked by tenant+account+
// security, no ent FK), then holdings. Both are tenant-scoped so no ID
// collection is needed.
func (r *HoldingRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	if _, err := r.client.HoldingTransaction.Delete().
		Where(holdingtransaction.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete holding transactions: %w", err)
	}
	if _, err := r.client.Holding.Delete().
		Where(holding.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete holdings: %w", err)
	}
	return nil
}

var _ domain.HoldingRepository = (*HoldingRepository)(nil)
