package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/account/ent"
	chartent "github.com/yucai/server/internal/account/ent/chartofaccounts"
)

// ChartRepository implements domain.ChartRepository using entGo.
type ChartRepository struct {
	client *ent.Client
}

// NewChartRepository creates a new ChartRepository.
func NewChartRepository(client *ent.Client) *ChartRepository {
	return &ChartRepository{client: client}
}

// Save persists a new chart of accounts entry.
func (r *ChartRepository) Save(ctx context.Context, c *domain.ChartOfAccount) error {
	_, err := r.client.ChartOfAccounts.Create().
		SetID(c.ID).
		SetCode(c.Code).
		SetName(c.Name).
		SetLevel(c.Level).
		SetAccountType(chartent.AccountType(c.AccountType.String())).
		SetParentCode(c.ParentCode).
		SetBalanceDirection(chartent.BalanceDirection(c.BalanceDirection.String())).
		SetCreatedAt(c.CreatedAt).
		SetUpdatedAt(c.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save chart: %w", err)
	}
	return nil
}

// FindByCode retrieves a chart entry by code within a tenant.
func (r *ChartRepository) FindByCode(ctx context.Context, tenantID uuid.UUID, code string) (*domain.ChartOfAccount, error) {
	c, err := r.client.ChartOfAccounts.Query().
		Where(
			chartent.TenantID(tenantID),
			chartent.Code(code),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find chart by code: %w", err)
	}
	return toDomainChart(c), nil
}

// FindAll retrieves all chart entries for a tenant.
func (r *ChartRepository) FindAll(ctx context.Context, tenantID uuid.UUID) ([]domain.ChartOfAccount, error) {
	results, err := r.client.ChartOfAccounts.Query().
		Where(chartent.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find all charts: %w", err)
	}
	charts := make([]domain.ChartOfAccount, len(results))
	for i, c := range results {
		charts[i] = *toDomainChart(c)
	}
	return charts, nil
}

func toDomainChart(c *ent.ChartOfAccounts) *domain.ChartOfAccount {
	return &domain.ChartOfAccount{
		ID:               c.ID,
		TenantID:         c.TenantID,
		Code:             c.Code,
		Name:             c.Name,
		Level:            c.Level,
		AccountType:      domain.ParseAccountType(string(c.AccountType)),
		ParentCode:       c.ParentCode,
		BalanceDirection: domain.ParseBalanceDirection(string(c.BalanceDirection)),
		CreatedAt:        c.CreatedAt,
		UpdatedAt:        c.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.ChartRepository = (*ChartRepository)(nil)
