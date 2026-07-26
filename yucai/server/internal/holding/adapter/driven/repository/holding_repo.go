package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holding"
	"github.com/yucai/server/internal/holding/ent/holdingtransaction"
	"github.com/yucai/server/internal/sqltx"
)

// HoldingRepository implements domain.HoldingRepository.
type HoldingRepository struct {
	client *holdingent.Client
}

// NewHoldingRepository creates a new HoldingRepository.
func NewHoldingRepository(client *holdingent.Client) *HoldingRepository {
	return &HoldingRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose writes
// join the outer transaction; otherwise it returns the default r.client (the
// non-transactional path, preserving backward compatibility).
//
// NOTE: defined but NOT yet used by any write method. Tasks 4-7 will switch
// each write method from r.client to r.clientFor(ctx). Until then this is a
// no-op helper with zero behavior change.
func (r *HoldingRepository) clientFor(ctx context.Context) *holdingent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return holdingent.NewClient(holdingent.Driver(d))
	}
	return r.client
}

func (r *HoldingRepository) SaveOrUpdate(ctx context.Context, h *domain.Holding) error {
	// Try to find existing (tenant-scoped defense-in-depth: a cross-tenant
	// collision on (accountID, securityID) cannot happen given account is
	// tenant-scoped, but the predicate guarantees a miss returns NotFound
	// instead of matching another tenant's row).
	existing, err := r.client.Holding.Query().
		Where(holding.TenantID(h.TenantID), holding.AccountID(h.AccountID), holding.SecurityID(h.SecurityID)).
		Only(ctx)
	if err != nil {
		// Create new
		create := r.client.Holding.Create().
			SetID(h.ID).SetTenantID(h.TenantID).
			SetAccountID(h.AccountID).SetSecurityID(h.SecurityID).
			SetQuantity(h.Quantity).SetAvgCostCents(h.AvgCostCents).
			SetVersion(h.Version).SetUpdatedAt(h.UpdatedAt)
		// CreatedAt: 显式值透传;zero 时不 SetCreatedAt -> ent Default(time.Now) 生效
		// (修 BuyHolding omit CreatedAt 致 portfolioCAGR nil bug;e2e 套件 Task 5 发现)。
		if !h.CreatedAt.IsZero() {
			create = create.SetCreatedAt(h.CreatedAt)
		}
		if _, err := create.Save(ctx); err != nil {
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

// FindByID retrieves a single holding by its primary key, tenant-scoped. A
// cross-tenant hit returns NotFound (ent Only semantics) so no existence is
// leaked to a caller passing another tenant's holdingID.
func (r *HoldingRepository) FindByID(ctx context.Context, tenantID, holdingID uuid.UUID) (*domain.Holding, error) {
	h, err := r.client.Holding.Query().
		Where(holding.ID(holdingID), holding.TenantID(tenantID)).
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
