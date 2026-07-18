package application

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// Service orchestrates goal operations.
type Service struct {
	repo    domain.GoalRepository
	mvSrc   domain.AccountMarketValueSource // nil = Investment goals skipped (best-effort)
	balSrc  domain.AccountBalanceSource     // nil = Savings goals skipped
	debtSrc domain.DebtProgressSource       // nil = DebtPayoff goals skipped
}

// NewService creates a new goal application service.
func NewService(repo domain.GoalRepository) *Service {
	return &Service{repo: repo}
}

// CreateGoal validates and persists a new goal.
func (s *Service) CreateGoal(ctx context.Context, req CreateGoalRequest) (*GoalDTO, error) {
	goal, err := domain.NewGoal(
		req.TenantID,
		req.Name,
		req.GoalType,
		req.TargetAmountCents,
		req.CurrencyCode,
		req.Deadline,
		req.LinkedAccountIDs,
		req.LinkedDebtIDs,
		req.Notes,
	)
	if err != nil {
		return nil, fmt.Errorf("create goal: %w", err)
	}

	if err := s.repo.Save(ctx, goal); err != nil {
		return nil, fmt.Errorf("save goal: %w", err)
	}

	dto := GoalToDTO(goal)
	return &dto, nil
}

// CloneGoal duplicates an existing goal into a fresh row with reset progress.
// The caller may override targetAmountCents (≤0 → keep source), deadline
// (nil → drop), and name ("" → keep source). Linked account/debt IDs are
// deep-copied by domain.Clone. The cloned goal is saved as a new entity.
func (s *Service) CloneGoal(ctx context.Context, tenantID, sourceID uuid.UUID, targetAmountCents int64, deadline *time.Time, name string) (*GoalDTO, error) {
	src, err := s.repo.FindByID(ctx, tenantID, sourceID)
	if err != nil {
		return nil, fmt.Errorf("source goal not found: %w", err)
	}
	cloned, err := src.Clone(tenantID, targetAmountCents, deadline, name)
	if err != nil {
		return nil, fmt.Errorf("clone goal: %w", err)
	}
	if err := s.repo.Save(ctx, cloned); err != nil {
		return nil, fmt.Errorf("save cloned goal: %w", err)
	}
	dto := GoalToDTO(cloned)
	return &dto, nil
}

// GetGoal retrieves a goal by ID.
func (s *Service) GetGoal(ctx context.Context, tenantID, id uuid.UUID) (*GoalDTO, error) {
	goal, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("goal not found: %w", err)
	}
	dto := GoalToDTO(goal)
	return &dto, nil
}

// GetGoalProgressHistory returns progress snapshots for goalID in [from, to],
// ordered by date asc. Phase 2 trend-curve data source (Flutter goal detail
// chart). Reads the goal_progress_snapshot rows written daily by SyncAllGoals.
func (s *Service) GetGoalProgressHistory(ctx context.Context, tenantID, goalID uuid.UUID, from, to time.Time) ([]ProgressPointDTO, error) {
	pts, err := s.repo.FindSnapshotRange(ctx, tenantID, goalID, from, to)
	if err != nil {
		return nil, fmt.Errorf("goal progress history: %w", err)
	}
	dtos := make([]ProgressPointDTO, len(pts))
	for i, p := range pts {
		dtos[i] = ProgressPointDTO{Date: p.Date, CurrentAmountCents: p.CurrentAmountCents}
	}
	return dtos, nil
}

// UpdateGoal updates a goal's mutable fields.
func (s *Service) UpdateGoal(ctx context.Context, req UpdateGoalRequest) (*GoalDTO, error) {
	goal, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("goal not found: %w", err)
	}

	if goal.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, goal.Version)
	}

	goal.Name = req.Name
	goal.TargetAmountCents = req.TargetAmountCents
	goal.Deadline = req.Deadline
	goal.Notes = req.Notes
	goal.UpdateLinks(req.LinkedAccountIDs, req.LinkedDebtIDs) // M2: full-replace links (setter, no version bump)
	goal.IncrementVersion()                                   // 统一 version bump (现状已有,保留)

	if err := s.repo.Update(ctx, goal); err != nil {
		return nil, fmt.Errorf("update goal: %w", err)
	}

	dto := GoalToDTO(goal)
	return &dto, nil
}

// UpdateGoalProgress adds progress to a goal.
func (s *Service) UpdateGoalProgress(ctx context.Context, req UpdateProgressRequest) (*GoalDTO, error) {
	goal, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("goal not found: %w", err)
	}

	goal.AddProgress(req.AmountCents)
	goal.IncrementVersion()

	if err := s.repo.Update(ctx, goal); err != nil {
		return nil, fmt.Errorf("update goal: %w", err)
	}

	dto := GoalToDTO(goal)
	return &dto, nil
}

// CompleteGoal marks a goal as completed.
func (s *Service) CompleteGoal(ctx context.Context, tenantID, id uuid.UUID) error {
	goal, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return fmt.Errorf("goal not found: %w", err)
	}

	goal.MarkCompleted()
	goal.IncrementVersion()

	return s.repo.Update(ctx, goal)
}

// DeleteGoal deletes a goal.
func (s *Service) DeleteGoal(ctx context.Context, tenantID, id uuid.UUID) error {
	return s.repo.Delete(ctx, tenantID, id)
}

// SyncGoalProgress syncs progress from a linked account balance.
// For now, this is a stub that would fetch account balance via callback.
func (s *Service) SyncGoalProgress(ctx context.Context, tenantID, id uuid.UUID, currentBalance int64) (*GoalDTO, error) {
	goal, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("goal not found: %w", err)
	}

	// Set current amount to the linked account balance
	goal.CurrentAmountCents = currentBalance
	if goal.CurrentAmountCents >= goal.TargetAmountCents && !goal.IsCompleted {
		goal.MarkCompleted()
	}
	goal.IncrementVersion()

	if err := s.repo.Update(ctx, goal); err != nil {
		return nil, fmt.Errorf("update goal: %w", err)
	}

	dto := GoalToDTO(goal)
	return &dto, nil
}

// ListGoals returns a paginated list of goals.
func (s *Service) ListGoals(ctx context.Context, req ListGoalsRequest) (*ListGoalsResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.Completed, req.GoalType, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list goals: %w", err)
	}
	dtos := make([]GoalDTO, len(result.Items))
	for i, g := range result.Items {
		dtos[i] = GoalToDTO(&g)
	}
	return &ListGoalsResult{
		Goals:         dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// SetAccountMarketValueSource injects the holding market-value source used by
// SyncAllGoals for Investment goals. Called by wire after construction
// (NewService signature unchanged). *holding/application.Service implements
// this port structurally.
func (s *Service) SetAccountMarketValueSource(src domain.AccountMarketValueSource) {
	s.mvSrc = src
}

// SetAccountBalanceSource injects the account-balance source used by
// SyncAllGoals for Savings goals. *account/application.Service implements this
// port structurally.
func (s *Service) SetAccountBalanceSource(src domain.AccountBalanceSource) {
	s.balSrc = src
}

// SetDebtProgressSource injects the debt-progress source used by SyncAllGoals
// for DebtPayoff goals. *debt/application.Service implements this port
// structurally.
func (s *Service) SetDebtProgressSource(src domain.DebtProgressSource) {
	s.debtSrc = src
}

// SyncAllGoals recomputes current_amount for every goal by type and writes a
// daily snapshot. Per-goal branching:
//   - Investment → mvSrc.GetAccountsMarketValue(LinkedAccountIDs)
//   - Savings    → balSrc.GetAccountsBalance(LinkedAccountIDs)
//   - DebtPayoff → debtSrc.GetDebtsPaid(LinkedDebtIDs)
//
// Best-effort: a goal whose port is nil, has no links, whose port call fails,
// or whose Update fails is logged and skipped without aborting the batch.
// Already-completed goals are skipped (mv/balance may fluctuate; we don't
// un-complete). Snapshot write failures are warned, not fatal (the current
// value is already persisted via Update). Implements goal/scheduler.GoalSyncer.
func (s *Service) SyncAllGoals(ctx context.Context, tenantID uuid.UUID) (int, error) {
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.repo.FindAll(ctx, tenantID, nil, nil, page)
		if err != nil {
			return synced, fmt.Errorf("sync all goals: list: %w", err)
		}
		for _, g := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			if g.IsCompleted {
				continue
			}
			cur, perr := s.computeGoalProgress(ctx, tenantID, &g)
			if perr != nil {
				slog.Error("goal sync: port failed",
					slog.String("goal_id", g.ID.String()),
					slog.String("type", g.GoalType.String()),
					slog.String("error", perr.Error()),
					slog.String("operation", "SyncAllGoals"))
				continue
			}
			g.SetCurrentAmount(cur)
			g.IncrementVersion()
			if err := s.repo.Update(ctx, &g); err != nil {
				slog.Error("goal sync: update failed",
					slog.String("goal_id", g.ID.String()),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncAllGoals"))
				continue
			}
			if err := s.repo.WriteSnapshot(ctx, &g); err != nil {
				slog.Warn("goal sync: snapshot write failed",
					slog.String("goal_id", g.ID.String()),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncAllGoals"))
			}
			synced++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return synced, nil
}

// computeGoalProgress dispatches to the per-type port and returns the current
// progress (cents). Returns an error when the port is nil for the goal's type,
// the goal has no links, or the port call fails — the caller logs and skips.
func (s *Service) computeGoalProgress(ctx context.Context, tenantID uuid.UUID, g *domain.Goal) (int64, error) {
	switch g.GoalType {
	case domain.GoalTypeInvestment:
		if s.mvSrc == nil || len(g.LinkedAccountIDs) == 0 {
			return 0, fmt.Errorf("investment goal: market-value source not configured or no linked accounts")
		}
		return s.mvSrc.GetAccountsMarketValue(ctx, tenantID, g.LinkedAccountIDs)
	case domain.GoalTypeSavings:
		if s.balSrc == nil || len(g.LinkedAccountIDs) == 0 {
			return 0, fmt.Errorf("savings goal: balance source not configured or no linked accounts")
		}
		return s.balSrc.GetAccountsBalance(ctx, tenantID, g.LinkedAccountIDs)
	case domain.GoalTypeDebtPayoff:
		if s.debtSrc == nil || len(g.LinkedDebtIDs) == 0 {
			return 0, fmt.Errorf("debtpayoff goal: debt source not configured or no linked debts")
		}
		return s.debtSrc.GetDebtsPaid(ctx, tenantID, g.LinkedDebtIDs)
	default:
		return 0, fmt.Errorf("unknown goal type: %s", g.GoalType.String())
	}
}
