package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holding"
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

var _ domain.HoldingRepository = (*HoldingRepository)(nil)
