package application

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
)

// EntryTotalsFunc fetches debit/credit totals for an account in a date range.
type EntryTotalsFunc func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)

// EntryTotals is one account's debit/credit over a period (budget-local copy
// of transaction.AccountTotals — budget does not import transaction domain).
type EntryTotals struct {
	DebitCents  int64
	CreditCents int64
}

// EntryTotalsMonthFunc returns debit/credit totals grouped by account_id for
// [from, to], tenant-scoped. Batch port for read-time actuals (replaces the
// per-item EntryTotalsFunc for ListBudgets/GetBudget*). nil → actuals stay 0.
type EntryTotalsMonthFunc func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error)

// Service orchestrates budget operations.
type Service struct {
	repo           domain.BudgetRepository
	entryFunc      EntryTotalsFunc      // single-account (ComputeActuals persist RPC)
	entryMonthFunc EntryTotalsMonthFunc // batch (read-time actuals: ListBudgets/GetBudget*)
}

// NewService creates a new budget application service. entryFunc backs the
// persist-path ComputeActuals (per-item); entryMonthFunc backs read-time
// actuals (one query per month). Either may be nil (graceful: actuals stay 0).
func NewService(repo domain.BudgetRepository, entryFunc EntryTotalsFunc, entryMonthFunc EntryTotalsMonthFunc) *Service {
	return &Service{repo: repo, entryFunc: entryFunc, entryMonthFunc: entryMonthFunc}
}

// CreateBudget validates and persists a new budget.
func (s *Service) CreateBudget(ctx context.Context, req CreateBudgetRequest) (*BudgetDTO, error) {
	items := make([]domain.BudgetItem, len(req.Items))
	for i, input := range req.Items {
		items[i] = domain.BudgetItem{
			AccountID:          input.AccountID,
			PlannedAmountCents: input.PlannedAmountCents,
			Notes:              input.Notes,
		}
	}

	budget, err := domain.NewBudget(req.TenantID, req.Name, req.Month, req.CurrencyCode, items)
	if err != nil {
		return nil, fmt.Errorf("create budget: %w", err)
	}

	if err := s.repo.Save(ctx, budget); err != nil {
		return nil, fmt.Errorf("save budget: %w", err)
	}

	dto := BudgetToDTO(budget)
	return &dto, nil
}

// GetBudget retrieves a budget by ID.
func (s *Service) GetBudget(ctx context.Context, tenantID, id uuid.UUID) (*BudgetDetailDTO, error) {
	budget, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}
	s.computeActualsReadTime(ctx, budget) // D-budget: read-time actuals
	dto := BudgetToDetailDTO(budget)
	return &dto, nil
}

// GetBudgetByMonth retrieves a budget by month.
func (s *Service) GetBudgetByMonth(ctx context.Context, tenantID uuid.UUID, month string) (*BudgetDetailDTO, error) {
	budget, err := s.repo.FindByMonth(ctx, tenantID, month)
	if err != nil {
		return nil, fmt.Errorf("budget not found for month %s: %w", month, err)
	}
	s.computeActualsReadTime(ctx, budget) // D-budget: read-time actuals
	dto := BudgetToDetailDTO(budget)
	return &dto, nil
}

// ListBudgets returns a paginated list of budgets.
func (s *Service) ListBudgets(ctx context.Context, req ListBudgetsRequest) (*ListBudgetsResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.ActiveOnly, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list budgets: %w", err)
	}
	s.computeActualsReadTimeBatch(ctx, req.TenantID, result.Items)
	dtos := make([]BudgetDTO, len(result.Items))
	for i, b := range result.Items {
		dtos[i] = BudgetToDTO(&b)
	}
	return &ListBudgetsResult{
		Budgets:       dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// DeleteBudget deletes a budget.
func (s *Service) DeleteBudget(ctx context.Context, tenantID, id uuid.UUID) error {
	return s.repo.Delete(ctx, tenantID, id)
}

// UpdateBudget edits a budget's name/currency/items in place (no ID change,
// no delete+recreate). Month is immutable. Optimistic lock: domain.Update
// bumps version (v→v+1), repo.Update matches WHERE version = v-1, so a
// concurrent edit since FindByID is rejected. Read-time actuals are not
// recomputed here (next GetBudget computes them via the M2 batch path).
func (s *Service) UpdateBudget(ctx context.Context, req UpdateBudgetRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}
	items := make([]domain.BudgetItem, len(req.Items))
	for i, input := range req.Items {
		items[i] = domain.BudgetItem{
			AccountID:          input.AccountID,
			PlannedAmountCents: input.PlannedAmountCents,
			Notes:              input.Notes,
		}
	}
	if err := budget.Update(req.Name, req.CurrencyCode, items); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}
	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("persist budget: %w", err)
	}
	dto := BudgetToDTO(budget)
	return &dto, nil
}

// AddBudgetItem adds an item to an existing budget.
func (s *Service) AddBudgetItem(ctx context.Context, req AddBudgetItemRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}

	budget.AddItem(domain.BudgetItem{
		AccountID:          req.AccountID,
		PlannedAmountCents: req.PlannedAmountCents,
		Notes:              req.Notes,
	})
	budget.IncrementVersion()

	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}

	dto := BudgetToDTO(budget)
	return &dto, nil
}

// RemoveBudgetItem removes an item from a budget.
func (s *Service) RemoveBudgetItem(ctx context.Context, req RemoveBudgetItemRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}

	if err := budget.RemoveItem(req.ItemID); err != nil {
		return nil, err
	}
	budget.IncrementVersion()

	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}

	dto := BudgetToDTO(budget)
	return &dto, nil
}

// ComputeActuals recalculates actual spending for each budget item.
func (s *Service) ComputeActuals(ctx context.Context, req ComputeActualsRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}

	svc := domain.BudgetActualsService{}
	for i := range budget.Items {
		err := svc.ComputeActualsForItem(ctx, &budget.Items[i], budget.Month, func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
			return s.entryFunc(ctx, accountID, from, to)
		})
		if err != nil {
			return nil, fmt.Errorf("compute actuals for item %s: %w", budget.Items[i].ID, err)
		}
	}

	budget.IncrementVersion()
	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}

	dto := BudgetToDTO(budget)
	return &dto, nil
}

// CloneBudgetToMonth clones a budget to a new month.
func (s *Service) CloneBudgetToMonth(ctx context.Context, req CloneBudgetRequest) (*BudgetDTO, error) {
	source, err := s.repo.FindByID(ctx, req.TenantID, req.SourceBudgetID)
	if err != nil {
		return nil, fmt.Errorf("source budget not found: %w", err)
	}

	cloned, err := source.CloneToMonth(req.TargetMonth, req.Name)
	if err != nil {
		return nil, fmt.Errorf("clone budget: %w", err)
	}

	if err := s.repo.Save(ctx, cloned); err != nil {
		return nil, fmt.Errorf("save cloned budget: %w", err)
	}

	dto := BudgetToDTO(cloned)
	return &dto, nil
}

// monthRange parses "YYYY-MM" into [first day 00:00:00, last day 23:59:59.999999999].
// Returns zero times on parse failure (should not happen; domain regex already validates).
func monthRange(month string) (time.Time, time.Time) {
	t, err := time.Parse("2006-01", month)
	if err != nil {
		return time.Time{}, time.Time{}
	}
	from := t
	to := t.AddDate(0, 1, -1).Add(24*time.Hour - time.Nanosecond)
	return from, to
}

// computeActualsReadTime fills each item's ActualAmountCents via one batch
// month query (entryMonthFunc), not per-item. nil entryMonthFunc → actuals 0.
// err → all items 0 + slog (best-effort, NOT propagated).
// actual = debit - credit (spending - refunds = net spend).
func (s *Service) computeActualsReadTime(ctx context.Context, b *domain.Budget) {
	if s.entryMonthFunc == nil {
		return // actuals stay 0 (stored value or zero)
	}
	from, to := monthRange(b.Month)
	totals, err := s.entryMonthFunc(ctx, b.TenantID, from, to)
	if err != nil {
		slog.Error("budget actuals: entryMonthFunc failed",
			"operation", "budget.computeActualsReadTime",
			"budget_id", b.ID.String(), "error", err.Error())
		for i := range b.Items {
			b.Items[i].ActualAmountCents = 0
		}
		return
	}
	for i := range b.Items {
		if t, ok := totals[b.Items[i].AccountID]; ok {
			b.Items[i].ActualAmountCents = t.DebitCents - t.CreditCents
		} else {
			b.Items[i].ActualAmountCents = 0
		}
	}
}

// computeActualsReadTimeBatch fills actuals for many budgets with one query
// per distinct month (vs N×M per-item). nil entryMonthFunc → no-op. A failed
// month is cached as nil so it is not retried; its items stay 0. ListBudgets
// passes its tenantID (already tenant-scoped by FindAll).
func (s *Service) computeActualsReadTimeBatch(ctx context.Context, tenantID uuid.UUID, budgets []domain.Budget) {
	if s.entryMonthFunc == nil {
		return
	}
	monthCache := map[string]map[uuid.UUID]EntryTotals{}
	for i := range budgets {
		month := budgets[i].Month
		if _, cached := monthCache[month]; cached {
			continue
		}
		from, to := monthRange(month)
		totals, err := s.entryMonthFunc(ctx, tenantID, from, to)
		if err != nil {
			slog.Error("budget actuals batch: entryMonthFunc failed",
				"operation", "budget.computeActualsReadTimeBatch",
				"month", month, "error", err.Error())
			monthCache[month] = nil // mark attempted (items stay 0, no retry)
			continue
		}
		monthCache[month] = totals
	}
	for i := range budgets {
		totals := monthCache[budgets[i].Month]
		for j := range budgets[i].Items {
			if totals != nil {
				if t, ok := totals[budgets[i].Items[j].AccountID]; ok {
					budgets[i].Items[j].ActualAmountCents = t.DebitCents - t.CreditCents
					continue
				}
			}
			budgets[i].Items[j].ActualAmountCents = 0
		}
	}
}
