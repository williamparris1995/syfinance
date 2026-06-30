package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
	goalent "github.com/yucai/server/internal/goal/ent"
	"github.com/yucai/server/internal/goal/ent/goal"
)

// GoalRepository implements domain.GoalRepository using entGo.
type GoalRepository struct {
	client *goalent.Client
}

// NewGoalRepository creates a new GoalRepository.
func NewGoalRepository(client *goalent.Client) *GoalRepository {
	return &GoalRepository{client: client}
}

// Save persists a new goal.
func (r *GoalRepository) Save(ctx context.Context, g *domain.Goal) error {
	create := r.client.Goal.Create().
		SetID(g.ID).
		SetTenantID(g.TenantID).
		SetName(g.Name).
		SetGoalType(g.GoalType.String()).
		SetTargetAmountCents(g.TargetAmountCents).
		SetCurrentAmountCents(g.CurrentAmountCents).
		SetCurrencyCode(g.CurrencyCode).
		SetNotes(g.Notes).
		SetIsCompleted(g.IsCompleted).
		SetVersion(g.Version).
		SetCreatedAt(g.CreatedAt).
		SetUpdatedAt(g.UpdatedAt)

	if g.Deadline != nil {
		create.SetDeadline(*g.Deadline)
	}
	if g.LinkedAccountID != nil {
		create.SetLinkedAccountID(*g.LinkedAccountID)
	}
	if g.CompletedAt != nil {
		create.SetCompletedAt(*g.CompletedAt)
	}

	if _, err := create.Save(ctx); err != nil {
		return fmt.Errorf("save goal: %w", err)
	}
	return nil
}

// FindByID retrieves a goal by ID.
func (r *GoalRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Goal, error) {
	g, err := r.client.Goal.Query().
		Where(
			goal.ID(id),
			goal.TenantID(tenantID),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find goal: %w", err)
	}
	return toDomainGoal(g), nil
}

// FindAll returns paginated goals with optional completed and goalType filters.
func (r *GoalRepository) FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, goalType *domain.GoalType, page domain.PageRequest) (*domain.PaginatedResult[domain.Goal], error) {
	query := r.client.Goal.Query().
		Where(goal.TenantID(tenantID))

	if completed != nil {
		query.Where(goal.IsCompletedEQ(*completed))
	}

	if goalType != nil {
		query.Where(goal.GoalTypeEQ((*goalType).String()))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count goals: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(goal.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query goals: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	goals := make([]domain.Goal, len(results))
	for i, g := range results {
		goals[i] = *toDomainGoal(g)
	}

	return &domain.PaginatedResult[domain.Goal]{
		Items:         goals,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a goal (optimistic lock).
func (r *GoalRepository) Update(ctx context.Context, g *domain.Goal) error {
	update := r.client.Goal.UpdateOneID(g.ID).
		Where(goal.Version(g.Version - 1)).
		SetName(g.Name).
		SetTargetAmountCents(g.TargetAmountCents).
		SetCurrentAmountCents(g.CurrentAmountCents).
		SetNotes(g.Notes).
		SetIsCompleted(g.IsCompleted).
		SetVersion(g.Version).
		SetUpdatedAt(g.UpdatedAt)

	if g.Deadline != nil {
		update.SetDeadline(*g.Deadline)
	} else {
		update.ClearDeadline()
	}
	if g.LinkedAccountID != nil {
		update.SetLinkedAccountID(*g.LinkedAccountID)
	} else {
		update.ClearLinkedAccountID()
	}
	if g.CompletedAt != nil {
		update.SetCompletedAt(*g.CompletedAt)
	} else {
		update.ClearCompletedAt()
	}

	if _, err := update.Save(ctx); err != nil {
		return fmt.Errorf("update goal: %w", err)
	}
	return nil
}

// Delete removes a goal.
func (r *GoalRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	err := r.client.Goal.DeleteOneID(id).
		Where(goal.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete goal: %w", err)
	}
	return nil
}

func toDomainGoal(g *goalent.Goal) *domain.Goal {
	return &domain.Goal{
		ID:                 g.ID,
		TenantID:           g.TenantID,
		Name:               g.Name,
		GoalType:           domain.ParseGoalType(g.GoalType),
		TargetAmountCents:  g.TargetAmountCents,
		CurrentAmountCents: g.CurrentAmountCents,
		CurrencyCode:       g.CurrencyCode,
		Deadline:           g.Deadline,
		LinkedAccountID:    g.LinkedAccountID,
		Notes:              g.Notes,
		IsCompleted:        g.IsCompleted,
		CompletedAt:        g.CompletedAt,
		Version:            g.Version,
		CreatedAt:          g.CreatedAt,
		UpdatedAt:          g.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.GoalRepository = (*GoalRepository)(nil)

// Ensure time is imported.
var _ = time.Time{}
