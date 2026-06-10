package command

import (
	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// CreateAccountCommand creates a new account.
type CreateAccountCommand struct {
	TenantID            uuid.UUID
	Name                string
	AccountType         domain.AccountType
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

// UpdateAccountCommand updates an existing account.
type UpdateAccountCommand struct {
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

// DeleteAccountCommand soft-deletes an account.
type DeleteAccountCommand struct {
	TenantID  uuid.UUID
	AccountID uuid.UUID
}
