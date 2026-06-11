package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// Service orchestrates goal operations.
type Service struct {
	repo domain.GoalRepository
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
		req.LinkedAccountID,
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

// GetGoal retrieves a goal by ID.
func (s *Service) GetGoal(ctx context.Context, tenantID, id uuid.UUID) (*GoalDTO, error) {
	goal, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("goal not found: %w", err)
	}
	dto := GoalToDTO(goal)
	return &dto, nil
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
	goal.IncrementVersion()

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
	result, err := s.repo.FindAll(ctx, req.TenantID, req.Completed, req.Page)
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
