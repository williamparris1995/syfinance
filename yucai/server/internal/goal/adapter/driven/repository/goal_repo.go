package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
	goalent "github.com/yucai/server/internal/goal/ent"
	"github.com/yucai/server/internal/goal/ent/goal"
	"github.com/yucai/server/internal/goal/ent/goalaccountlinks"
	"github.com/yucai/server/internal/goal/ent/goaldebtlinks"
	"github.com/yucai/server/internal/goal/ent/goalprogresssnapshot"
)

// GoalRepository implements domain.GoalRepository using entGo.
//
// Multi-account links: Investment + Savings goals store their linked accounts in
// the goal_account_links join table; DebtPayoff goals store linked debts in
// goal_debt_links. The legacy single-column goals.linked_account_id is kept in
// sync for backwards compatibility (set to the first linked account, if any)
// but the authoritative store is the link tables.
//
// WriteSnapshot upserts a daily progress snapshot keyed by
// (tenant_id, goal_id, snapshot_date): same-day re-runs overwrite the row
// (delete-then-insert — ent code has no OnConflict helper generated here).
type GoalRepository struct {
	client *goalent.Client
}

// NewGoalRepository creates a new GoalRepository.
func NewGoalRepository(client *goalent.Client) *GoalRepository {
	return &GoalRepository{client: client}
}

// Save persists a new goal and its multi-account links.
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
	// Legacy single-column (backwards compat): first linked account if any.
	if len(g.LinkedAccountIDs) > 0 {
		create.SetLinkedAccountID(g.LinkedAccountIDs[0])
	}
	if g.CompletedAt != nil {
		create.SetCompletedAt(*g.CompletedAt)
	}

	if _, err := create.Save(ctx); err != nil {
		return fmt.Errorf("save goal: %w", err)
	}
	if err := r.replaceAccountLinks(ctx, g); err != nil {
		return err
	}
	if err := r.replaceDebtLinks(ctx, g); err != nil {
		return err
	}
	return nil
}

// FindByID retrieves a goal by ID, including its multi-account links.
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
	return r.toDomainGoal(ctx, g)
}

// FindAll returns paginated goals with optional completed and goalType filters.
// Eager-loads multi-account links per goal (single batched query per link table).
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

	// Batch-load account + debt links for all goals on this page (avoids N+1).
	goalIDs := make([]uuid.UUID, len(results))
	for i, g := range results {
		goalIDs[i] = g.ID
	}
	accByGoal, err := r.loadAccountLinks(ctx, tenantID, goalIDs)
	if err != nil {
		return nil, err
	}
	debtByGoal, err := r.loadDebtLinks(ctx, tenantID, goalIDs)
	if err != nil {
		return nil, err
	}

	goals := make([]domain.Goal, len(results))
	for i, g := range results {
		dg := toDomainGoalBase(g)
		dg.LinkedAccountIDs = accByGoal[g.ID]
		dg.LinkedDebtIDs = debtByGoal[g.ID]
		// Fallback: if link table empty but legacy column set, use it.
		if len(dg.LinkedAccountIDs) == 0 && g.LinkedAccountID != nil {
			dg.LinkedAccountIDs = []uuid.UUID{*g.LinkedAccountID}
		}
		goals[i] = *dg
	}

	return &domain.PaginatedResult[domain.Goal]{
		Items:         goals,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a goal (optimistic lock) and replaces its
// multi-account links (delete-all-then-insert).
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
	// Legacy single-column sync.
	if len(g.LinkedAccountIDs) > 0 {
		update.SetLinkedAccountID(g.LinkedAccountIDs[0])
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
	if err := r.replaceAccountLinks(ctx, g); err != nil {
		return err
	}
	if err := r.replaceDebtLinks(ctx, g); err != nil {
		return err
	}
	return nil
}

// Delete removes a goal and its multi-account links.
func (r *GoalRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	if _, err := r.client.GoalAccountLinks.Delete().
		Where(
			goalaccountlinks.TenantID(tenantID),
			goalaccountlinks.GoalIDEQ(id),
		).Exec(ctx); err != nil {
		return fmt.Errorf("delete goal account links: %w", err)
	}
	if _, err := r.client.GoalDebtLinks.Delete().
		Where(
			goaldebtlinks.TenantID(tenantID),
			goaldebtlinks.GoalIDEQ(id),
		).Exec(ctx); err != nil {
		return fmt.Errorf("delete goal debt links: %w", err)
	}
	err := r.client.Goal.DeleteOneID(id).
		Where(goal.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete goal: %w", err)
	}
	return nil
}

// WriteSnapshot upserts a daily progress snapshot for the goal keyed by
// (tenant_id, goal_id, snapshot_date). Same-day re-runs overwrite
// current_amount_cents. Snapshot date is normalized to UTC midnight so two
// syncs within the same calendar day collapse to one row (mirrors the holding
// snapshot scheduler's daily granularity).
func (r *GoalRepository) WriteSnapshot(ctx context.Context, g *domain.Goal) error {
	day := truncateToDay(time.Now())

	// Delete existing same-day row(s) for this (tenant, goal). UNIQUE index
	// makes (tenant_id, goal_id, snapshot_date) unique so at most one row exists,
	// but the delete-all is defensive against any partial state.
	if _, err := r.client.GoalProgressSnapshot.Delete().
		Where(
			goalprogresssnapshot.TenantIDEQ(g.TenantID),
			goalprogresssnapshot.GoalIDEQ(g.ID),
			goalprogresssnapshot.SnapshotDateEQ(day),
		).Exec(ctx); err != nil {
		return fmt.Errorf("delete goal snapshot: %w", err)
	}
	if err := r.client.GoalProgressSnapshot.Create().
		SetTenantID(g.TenantID).
		SetGoalID(g.ID).
		SetSnapshotDate(day).
		SetCurrentAmountCents(g.CurrentAmountCents).
		Exec(ctx); err != nil {
		return fmt.Errorf("save goal snapshot: %w", err)
	}
	return nil
}

// --- multi-account link helpers ---

// replaceAccountLinks deletes all account links for the goal then re-inserts
// the current set (mirror of the budget delete-all-then-insert item pattern).
// Idempotent: empty LinkedAccountIDs clears the table.
func (r *GoalRepository) replaceAccountLinks(ctx context.Context, g *domain.Goal) error {
	if _, err := r.client.GoalAccountLinks.Delete().
		Where(
			goalaccountlinks.TenantIDEQ(g.TenantID),
			goalaccountlinks.GoalIDEQ(g.ID),
		).Exec(ctx); err != nil {
		return fmt.Errorf("delete goal account links: %w", err)
	}
	for _, accID := range g.LinkedAccountIDs {
		if err := r.client.GoalAccountLinks.Create().
			SetTenantID(g.TenantID).
			SetGoalID(g.ID).
			SetAccountID(accID).
			Exec(ctx); err != nil {
			return fmt.Errorf("save goal account link: %w", err)
		}
	}
	return nil
}

// replaceDebtLinks deletes all debt links for the goal then re-inserts the
// current set. Idempotent: empty LinkedDebtIDs clears the table.
func (r *GoalRepository) replaceDebtLinks(ctx context.Context, g *domain.Goal) error {
	if _, err := r.client.GoalDebtLinks.Delete().
		Where(
			goaldebtlinks.TenantIDEQ(g.TenantID),
			goaldebtlinks.GoalIDEQ(g.ID),
		).Exec(ctx); err != nil {
		return fmt.Errorf("delete goal debt links: %w", err)
	}
	for _, debtID := range g.LinkedDebtIDs {
		if err := r.client.GoalDebtLinks.Create().
			SetTenantID(g.TenantID).
			SetGoalID(g.ID).
			SetDebtID(debtID).
			Exec(ctx); err != nil {
			return fmt.Errorf("save goal debt link: %w", err)
		}
	}
	return nil
}

// loadAccountLinks returns a goalID → []accountID map for the given goal IDs.
// A single batched query (IN goalIDs) avoids N+1 per-goal link lookups.
func (r *GoalRepository) loadAccountLinks(ctx context.Context, tenantID uuid.UUID, goalIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := make(map[uuid.UUID][]uuid.UUID, len(goalIDs))
	if len(goalIDs) == 0 {
		return out, nil
	}
	rows, err := r.client.GoalAccountLinks.Query().
		Where(
			goalaccountlinks.TenantIDEQ(tenantID),
			goalaccountlinks.GoalIDIn(goalIDs...),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("load account links: %w", err)
	}
	for _, row := range rows {
		out[row.GoalID] = append(out[row.GoalID], row.AccountID)
	}
	return out, nil
}

// loadDebtLinks returns a goalID → []debtID map for the given goal IDs.
func (r *GoalRepository) loadDebtLinks(ctx context.Context, tenantID uuid.UUID, goalIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := make(map[uuid.UUID][]uuid.UUID, len(goalIDs))
	if len(goalIDs) == 0 {
		return out, nil
	}
	rows, err := r.client.GoalDebtLinks.Query().
		Where(
			goaldebtlinks.TenantIDEQ(tenantID),
			goaldebtlinks.GoalIDIn(goalIDs...),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("load debt links: %w", err)
	}
	for _, row := range rows {
		out[row.GoalID] = append(out[row.GoalID], row.DebtID)
	}
	return out, nil
}

// toDomainGoal is used by FindByID (single goal): loads links inline.
func (r *GoalRepository) toDomainGoal(ctx context.Context, g *goalent.Goal) (*domain.Goal, error) {
	dg := toDomainGoalBase(g)
	accs, err := r.loadAccountLinks(ctx, g.TenantID, []uuid.UUID{g.ID})
	if err != nil {
		return nil, err
	}
	debts, err := r.loadDebtLinks(ctx, g.TenantID, []uuid.UUID{g.ID})
	if err != nil {
		return nil, err
	}
	dg.LinkedAccountIDs = accs[g.ID]
	dg.LinkedDebtIDs = debts[g.ID]
	if len(dg.LinkedAccountIDs) == 0 && g.LinkedAccountID != nil {
		dg.LinkedAccountIDs = []uuid.UUID{*g.LinkedAccountID}
	}
	return dg, nil
}

// toDomainGoalBase maps the ent goal row to the domain goal (no links). Link
// tables are loaded separately (batched in FindAll, inline in FindByID).
func toDomainGoalBase(g *goalent.Goal) *domain.Goal {
	return &domain.Goal{
		ID:                 g.ID,
		TenantID:           g.TenantID,
		Name:               g.Name,
		GoalType:           domain.ParseGoalType(g.GoalType),
		TargetAmountCents:  g.TargetAmountCents,
		CurrentAmountCents: g.CurrentAmountCents,
		CurrencyCode:       g.CurrencyCode,
		Deadline:           g.Deadline,
		Notes:              g.Notes,
		IsCompleted:        g.IsCompleted,
		CompletedAt:        g.CompletedAt,
		Version:            g.Version,
		CreatedAt:          g.CreatedAt,
		UpdatedAt:          g.UpdatedAt,
	}
}

// truncateToDay strips the time-of-day component, returning the UTC midnight
// boundary of the given instant. Used to collapse multiple same-day syncs into
// a single daily snapshot row.
func truncateToDay(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// Compile-time check.
var _ domain.GoalRepository = (*GoalRepository)(nil)
