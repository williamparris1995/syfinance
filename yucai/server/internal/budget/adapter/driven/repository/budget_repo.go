package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
	budgetent "github.com/yucai/server/internal/budget/ent"
	"github.com/yucai/server/internal/budget/ent/budget"
	"github.com/yucai/server/internal/budget/ent/budgetitem"
	"github.com/yucai/server/internal/sqltx"
)

// BudgetRepository implements domain.BudgetRepository using entGo.
type BudgetRepository struct {
	client *budgetent.Client
}

// NewBudgetRepository creates a new BudgetRepository.
func NewBudgetRepository(client *budgetent.Client) *BudgetRepository {
	return &BudgetRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose reads
// join the outer transaction (so backup reads share the REPEATABLE READ
// snapshot tx instead of a fresh connection that could tear the backup);
// otherwise it returns the default r.client.
func (r *BudgetRepository) clientFor(ctx context.Context) *budgetent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return budgetent.NewClient(budgetent.Driver(d))
	}
	return r.client
}

// Save persists a budget and its items.
func (r *BudgetRepository) Save(ctx context.Context, b *domain.Budget) error {
	_, err := r.client.Budget.Create().
		SetID(b.ID).
		SetTenantID(b.TenantID).
		SetName(b.Name).
		SetMonth(b.Month).
		SetTotalAmountCents(b.TotalAmountCents).
		SetCurrencyCode(b.CurrencyCode).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetCreatedAt(b.CreatedAt).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save budget: %w", err)
	}

	for _, item := range b.Items {
		_, err := r.client.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("save budget item: %w", err)
		}
	}
	return nil
}

// FindByID retrieves a budget with its items.
func (r *BudgetRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Budget, error) {
	b, err := r.client.Budget.Query().
		Where(
			budget.ID(id),
			budget.TenantID(tenantID),
			budget.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find budget: %w", err)
	}

	items, err := r.client.BudgetItem.Query().
		Where(budgetitem.BudgetID(b.ID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find budget items: %w", err)
	}

	return toDomainBudget(b, items), nil
}

// FindByMonth retrieves a budget by month.
func (r *BudgetRepository) FindByMonth(ctx context.Context, tenantID uuid.UUID, month string) (*domain.Budget, error) {
	b, err := r.client.Budget.Query().
		Where(
			budget.TenantID(tenantID),
			budget.Month(month),
			budget.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find budget by month: %w", err)
	}

	items, err := r.client.BudgetItem.Query().
		Where(budgetitem.BudgetID(b.ID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find budget items: %w", err)
	}

	return toDomainBudget(b, items), nil
}

// FindAll returns paginated budgets.
func (r *BudgetRepository) FindAll(ctx context.Context, tenantID uuid.UUID, activeOnly bool, page domain.PageRequest) (*domain.PaginatedResult[domain.Budget], error) {
	query := r.client.Budget.Query().
		Where(
			budget.TenantID(tenantID),
			budget.DeletedAtIsNil(),
		)

	if activeOnly {
		query.Where(budget.IsActiveEQ(true))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count budgets: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(budget.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query budgets: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	budgets := make([]domain.Budget, len(results))
	for i, b := range results {
		items, err := r.client.BudgetItem.Query().
			Where(budgetitem.BudgetID(b.ID)).
			All(ctx)
		if err != nil {
			return nil, fmt.Errorf("load items for budget %s: %w", b.ID, err)
		}
		budgets[i] = *toDomainBudget(b, items)
	}

	return &domain.PaginatedResult[domain.Budget]{
		Items:         budgets,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a budget atomically (ent tx: delete old items +
// insert new items + update budget) with optimistic locking. A version
// conflict (concurrent edit since the caller's FindByID) returns an
// "optimistic lock: ..." error with NO "not found" substring, so budget
// mapError routes it to codes.Aborted (not codes.NotFound — the switch checks
// "not found" before "optimistic lock"). All callers (AddBudgetItem /
// RemoveBudgetItem / UpdateBudget / ComputeActuals) share this path, so all
// inherit atomicity + correct conflict mapping.
func (r *BudgetRepository) Update(ctx context.Context, b *domain.Budget) error {
	tx, err := r.client.Tx(ctx)
	if err != nil {
		return fmt.Errorf("begin budget tx: %w", err)
	}

	// Delete old items (tx-scoped).
	if _, err := tx.BudgetItem.Delete().
		Where(budgetitem.BudgetID(b.ID)).
		Exec(ctx); err != nil {
		_ = tx.Rollback()
		return fmt.Errorf("delete old budget items: %w", err)
	}

	// Insert new items (tx-scoped, full replace — item IDs change, budget ID stable).
	for _, item := range b.Items {
		if _, err := tx.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("insert budget item: %w", err)
		}
	}

	// Update budget (tx-scoped, optimistic lock WHERE version = v-1).
	if _, err := tx.Budget.UpdateOneID(b.ID).
		Where(budget.Version(b.Version - 1)).
		SetName(b.Name).
		SetCurrencyCode(b.CurrencyCode). // M1 fix: currency edits previously not persisted
		SetTotalAmountCents(b.TotalAmountCents).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx); err != nil {
		_ = tx.Rollback()
		if budgetent.IsNotFound(err) {
			// WHERE matched 0 rows — budget was modified concurrently since
			// FindByID (caller confirmed existence). Pure phrasing, no "not
			// found", so mapError -> codes.Aborted (refresh-and-retry signal).
			return fmt.Errorf("optimistic lock: budget %s was modified concurrently, refresh and retry", b.ID)
		}
		return fmt.Errorf("update budget: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit budget tx: %w", err)
	}
	return nil
}

// Delete soft-deletes a budget.
func (r *BudgetRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Budget.UpdateOneID(id).
		Where(budget.TenantID(tenantID)).
		SetDeletedAt(now).
		SetIsActive(false).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("delete budget: %w", err)
	}
	return nil
}

// FindAllForBackup returns all non-deleted budgets for a tenant (with items,
// no pagination) for backup export. Items are loaded in a single batched query
// (WHERE budget_id IN (...)) to avoid the N+1 that FindAll incurs per row.
func (r *BudgetRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Budget, error) {
	results, err := r.clientFor(ctx).Budget.Query().
		Where(
			budget.TenantID(tenantID),
			budget.DeletedAtIsNil(),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup find budgets: %w", err)
	}
	if len(results) == 0 {
		return []domain.Budget{}, nil
	}

	budgetIDs := make([]uuid.UUID, len(results))
	for i, b := range results {
		budgetIDs[i] = b.ID
	}
	itemRows, err := r.clientFor(ctx).BudgetItem.Query().
		Where(budgetitem.BudgetIDIn(budgetIDs...)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup load budget items: %w", err)
	}
	itemsByBudget := make(map[uuid.UUID][]*budgetent.BudgetItem, len(results))
	for _, it := range itemRows {
		itemsByBudget[it.BudgetID] = append(itemsByBudget[it.BudgetID], it)
	}

	out := make([]domain.Budget, len(results))
	for i, b := range results {
		out[i] = *toDomainBudget(b, itemsByBudget[b.ID])
	}
	return out, nil
}

// DeleteByTenant hard-deletes all budgets and their items for a tenant.
// Items have no tenant_id (scoped via budget_id FK), so collect budget IDs first,
// delete items, then delete budgets. Used by backup Import's purge step.
func (r *BudgetRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	budgetIDs, err := r.client.Budget.Query().
		Where(budget.TenantID(tenantID)).
		IDs(ctx)
	if err != nil {
		return fmt.Errorf("backup collect budget ids: %w", err)
	}
	if len(budgetIDs) > 0 {
		if _, err := r.client.BudgetItem.Delete().
			Where(budgetitem.BudgetIDIn(budgetIDs...)).
			Exec(ctx); err != nil {
			return fmt.Errorf("backup purge budget items: %w", err)
		}
	}
	if _, err := r.client.Budget.Delete().
		Where(budget.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("backup purge budgets: %w", err)
	}
	return nil
}

func toDomainBudget(b *budgetent.Budget, items []*budgetent.BudgetItem) *domain.Budget {
	domainItems := make([]domain.BudgetItem, len(items))
	for i, item := range items {
		domainItems[i] = domain.BudgetItem{
			ID:                 item.ID,
			BudgetID:           item.BudgetID,
			AccountID:          item.AccountID,
			PlannedAmountCents: item.PlannedAmountCents,
			ActualAmountCents:  item.ActualAmountCents,
			Notes:              item.Notes,
		}
	}
	return &domain.Budget{
		ID:               b.ID,
		TenantID:         b.TenantID,
		Name:             b.Name,
		Month:            b.Month,
		TotalAmountCents: b.TotalAmountCents,
		CurrencyCode:     b.CurrencyCode,
		IsActive:         b.IsActive,
		Items:            domainItems,
		Version:          b.Version,
		DeletedAt:        b.DeletedAt,
		CreatedAt:        b.CreatedAt,
		UpdatedAt:        b.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.BudgetRepository = (*BudgetRepository)(nil)
