package application

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// CreateAccountRequest holds input for creating an account.
type CreateAccountRequest struct {
	TenantID            uuid.UUID
	Name                string
	AccountType         domain.AccountType
	Category            domain.AccountCategory
	CurrencyCode        string
	InitialBalanceCents int64
	Ownership           domain.Ownership
	Icon                string
	Color               string
	ChartCode           string
	ParentID            *uuid.UUID
	Institution         string
	CreditLimitCents    int64
}

// UpdateAccountRequest holds input for updating an account.
type UpdateAccountRequest struct {
	TenantID         uuid.UUID
	AccountID        uuid.UUID
	Name             string
	Icon             string
	Color            string
	ChartCode        string
	Institution      string
	CreditLimitCents int64
	Version          int64
}

// DeleteAccountRequest holds input for soft-deleting an account.
type DeleteAccountRequest struct {
	TenantID  uuid.UUID
	AccountID uuid.UUID
}

// ListAccountsRequest holds input for listing accounts with filters.
type ListAccountsRequest struct {
	TenantID    uuid.UUID
	Filter      domain.AccountFilter
	PageRequest domain.PageRequest
}

// AccountDTO is the data transfer object for accounts.
type AccountDTO struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	Name                string
	AccountType         domain.AccountType
	Category            domain.AccountCategory
	CurrencyCode        string
	InitialBalanceCents int64
	CurrentBalanceCents int64
	Ownership           domain.Ownership
	Icon                string
	Color               string
	ChartCode           string
	ParentID            *uuid.UUID
	Institution         string
	CreditLimitCents    int64
	Status              domain.AccountStatus
	Version             int64
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// ListAccountsResult wraps paginated account DTOs.
type ListAccountsResult struct {
	Accounts      []AccountDTO
	NextPageToken string
	TotalCount    int32
}

// AccountToDTO converts a domain Account to AccountDTO.
func AccountToDTO(a *domain.Account) AccountDTO {
	return AccountDTO{
		ID:                  a.ID,
		TenantID:            a.TenantID,
		Name:                a.Name,
		AccountType:         a.AccountType,
		Category:            a.Category,
		CurrencyCode:        a.CurrencyCode,
		InitialBalanceCents: a.InitialBalanceCents,
		CurrentBalanceCents: a.CurrentBalanceCents,
		Ownership:           a.Ownership,
		Icon:                a.Icon,
		Color:               a.Color,
		ChartCode:           a.ChartCode,
		ParentID:            a.ParentID,
		Institution:         a.Institution,
		CreditLimitCents:    a.CreditLimitCents,
		Status:              a.Status,
		Version:             a.Version,
		CreatedAt:           a.CreatedAt,
		UpdatedAt:           a.UpdatedAt,
	}
}

// ApplyCreateDefaults applies optional fields from the request to the account entity.
func ApplyCreateDefaults(a *domain.Account, req CreateAccountRequest) {
	a.InitialBalanceCents = req.InitialBalanceCents
	a.CurrentBalanceCents = req.InitialBalanceCents
	a.Ownership = req.Ownership
	a.Icon = req.Icon
	a.Color = req.Color
	a.ChartCode = req.ChartCode
	a.ParentID = req.ParentID
	a.Institution = req.Institution
	a.CreditLimitCents = req.CreditLimitCents
	if a.Ownership == 0 {
		a.Ownership = domain.OwnershipPersonal
	}
	if a.CurrencyCode == "" {
		a.CurrencyCode = "CNY"
	}
}

// ValidateUpdateVersion checks optimistic locking.
func ValidateUpdateVersion(current, expected int64) error {
	if current != expected {
		return fmt.Errorf("optimistic lock conflict: current version %d, expected %d", current, expected)
	}
	return nil
}
