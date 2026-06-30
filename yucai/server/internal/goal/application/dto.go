package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// CreateGoalRequest holds input for creating a goal.
type CreateGoalRequest struct {
	TenantID           uuid.UUID
	Name               string
	GoalType           domain.GoalType
	TargetAmountCents  int64
	CurrencyCode       string
	Deadline           *time.Time
	LinkedAccountID    *uuid.UUID
	Notes              string
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
	LinkedAccountID    *uuid.UUID
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
		LinkedAccountID:    g.LinkedAccountID,
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
