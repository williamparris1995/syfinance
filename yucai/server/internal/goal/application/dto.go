package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// CreateGoalRequest holds input for creating a goal.
type CreateGoalRequest struct {
	TenantID          uuid.UUID
	Name              string
	GoalType          domain.GoalType
	TargetAmountCents int64
	CurrencyCode      string
	Deadline          *time.Time
	LinkedAccountIDs  []uuid.UUID // Investment/Savings: ≥1; DebtPayoff: may be nil
	LinkedDebtIDs     []uuid.UUID // DebtPayoff: ≥1; others: may be nil
	Notes             string
}

// UpdateGoalRequest holds input for updating a goal.
type UpdateGoalRequest struct {
	TenantID          uuid.UUID
	ID                uuid.UUID
	Name              string
	TargetAmountCents int64
	Deadline          *time.Time
	Notes             string
	Version           int64
	LinkedAccountIDs  []uuid.UUID // M2: full-replace linked accounts (nil clears)
	LinkedDebtIDs     []uuid.UUID // M2: full-replace linked debts (nil clears)
}

// UpdateProgressRequest holds input for updating goal progress.
type UpdateProgressRequest struct {
	TenantID    uuid.UUID
	ID          uuid.UUID
	AmountCents int64
}

// ListGoalsRequest holds input for listing goals.
type ListGoalsRequest struct {
	TenantID  uuid.UUID
	Completed *bool
	GoalType  *domain.GoalType // D-goal: nil=全部, investment=scheduler/Flutter filter
	Page      domain.PageRequest
}

// GoalDTO is the data transfer object.
type GoalDTO struct {
	ID                 uuid.UUID
	TenantID           uuid.UUID
	Name               string
	GoalType           domain.GoalType
	TargetAmountCents  int64
	CurrentAmountCents int64
	CurrencyCode       string
	Deadline           *time.Time
	LinkedAccountIDs   []uuid.UUID
	LinkedDebtIDs      []uuid.UUID
	Notes              string
	IsCompleted        bool
	CompletedAt        *time.Time
	ProgressPct        float64
	RemainingCents     int64
	Version            int64
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// ListGoalsResult wraps paginated goal DTOs.
type ListGoalsResult struct {
	Goals         []GoalDTO
	NextPageToken string
	TotalCount    int32
}

// GoalToDTO converts domain Goal to DTO.
func GoalToDTO(g *domain.Goal) GoalDTO {
	return GoalDTO{
		ID:                 g.ID,
		TenantID:           g.TenantID,
		Name:               g.Name,
		GoalType:           g.GoalType,
		TargetAmountCents:  g.TargetAmountCents,
		CurrentAmountCents: g.CurrentAmountCents,
		CurrencyCode:       g.CurrencyCode,
		Deadline:           g.Deadline,
		LinkedAccountIDs:   g.LinkedAccountIDs,
		LinkedDebtIDs:      g.LinkedDebtIDs,
		Notes:              g.Notes,
		IsCompleted:        g.IsCompleted,
		CompletedAt:        g.CompletedAt,
		ProgressPct:        g.ProgressPct(),
		RemainingCents:     g.RemainingAmount(),
		Version:            g.Version,
		CreatedAt:          g.CreatedAt,
		UpdatedAt:          g.UpdatedAt,
	}
}

// ProgressPointDTO is one point in a goal's progress-history trend curve (a
// daily snapshot). Returned by GetGoalProgressHistory. Date is the snapshot_date
// (UTC midnight); CurrentAmountCents is the goal's progress at that point.
type ProgressPointDTO struct {
	Date               time.Time
	CurrentAmountCents int64
}
