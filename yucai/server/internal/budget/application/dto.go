package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/budget/domain"
)

// CreateBudgetRequest holds input for creating a budget.
type CreateBudgetRequest struct {
	TenantID     uuid.UUID
	Name         string
	Month        string
	CurrencyCode string
	Items        []BudgetItemInput
}

// BudgetItemInput is the input DTO for a budget item.
type BudgetItemInput struct {
	AccountID          uuid.UUID
	PlannedAmountCents int64
	Notes              string
}

// AddBudgetItemRequest holds input for adding a budget item.
type AddBudgetItemRequest struct {
	TenantID           uuid.UUID
	BudgetID           uuid.UUID
	AccountID          uuid.UUID
	PlannedAmountCents int64
	Notes              string
}

// UpdateBudgetRequest holds input for editing a budget in place (M1).
type UpdateBudgetRequest struct {
	TenantID     uuid.UUID
	BudgetID     uuid.UUID
	Name         string
	CurrencyCode string
	Items        []BudgetItemInput
}

// RemoveBudgetItemRequest holds input for removing a budget item.
type RemoveBudgetItemRequest struct {
	TenantID uuid.UUID
	BudgetID uuid.UUID
	ItemID   uuid.UUID
}

// CloneBudgetRequest holds input for cloning a budget to a new month.
type CloneBudgetRequest struct {
	TenantID       uuid.UUID
	SourceBudgetID uuid.UUID
	TargetMonth    string
	Name           string
}

// ComputeActualsRequest holds input for computing budget actuals.
type ComputeActualsRequest struct {
	TenantID uuid.UUID
	BudgetID uuid.UUID
}

// ListBudgetsRequest holds input for listing budgets.
type ListBudgetsRequest struct {
	TenantID   uuid.UUID
	ActiveOnly bool
	Page       domain.PageRequest
}

// BudgetDTO is the data transfer object.
type BudgetDTO struct {
	ID               uuid.UUID
	TenantID         uuid.UUID
	Name             string
	Month            string
	TotalAmountCents int64
	CurrencyCode     string
	IsActive         bool
	Items            []BudgetItemDTO
	Version          int64
	CreatedAt        time.Time
	UpdatedAt        time.Time
	TotalActualCents int64
	UsagePct         float64
}

// BudgetItemDTO is the DTO for budget items.
type BudgetItemDTO struct {
	ID                 uuid.UUID
	BudgetID           uuid.UUID
	AccountID          uuid.UUID
	PlannedAmountCents int64
	ActualAmountCents  int64
	Notes              string
}

// BudgetDetailDTO extends BudgetDTO with computed fields.
type BudgetDetailDTO struct {
	Budget              BudgetDTO
	TotalActualCents    int64
	TotalRemainingCents int64
	UsagePct            float64
}

// ListBudgetsResult wraps paginated budget DTOs.
type ListBudgetsResult struct {
	Budgets       []BudgetDTO
	NextPageToken string
	TotalCount    int32
}

// BudgetToDTO converts domain Budget to DTO.
func BudgetToDTO(b *domain.Budget) BudgetDTO {
	items := make([]BudgetItemDTO, len(b.Items))
	for i, item := range b.Items {
		items[i] = BudgetItemDTO{
			ID:                 item.ID,
			BudgetID:           item.BudgetID,
			AccountID:          item.AccountID,
			PlannedAmountCents: item.PlannedAmountCents,
			ActualAmountCents:  item.ActualAmountCents,
			Notes:              item.Notes,
		}
	}
	return BudgetDTO{
		ID:               b.ID,
		TenantID:         b.TenantID,
		Name:             b.Name,
		Month:            b.Month,
		TotalAmountCents: b.TotalAmountCents,
		CurrencyCode:     b.CurrencyCode,
		IsActive:         b.IsActive,
		Items:            items,
		Version:          b.Version,
		CreatedAt:        b.CreatedAt,
		UpdatedAt:        b.UpdatedAt,
		TotalActualCents: b.TotalActual(),
		UsagePct:         b.UsagePct(),
	}
}

// BudgetToDetailDTO converts domain Budget to detail DTO with computed fields.
func BudgetToDetailDTO(b *domain.Budget) BudgetDetailDTO {
	return BudgetDetailDTO{
		Budget:              BudgetToDTO(b),
		TotalActualCents:    b.TotalActual(),
		TotalRemainingCents: b.TotalRemaining(),
		UsagePct:            b.UsagePct(),
	}
}
