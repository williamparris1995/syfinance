package domain

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Account is the aggregate root for the accounting system.
type Account struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	Name                string
	AccountType         AccountType
	CurrencyCode        string
	InitialBalanceCents int64
	CurrentBalanceCents int64
	Ownership           Ownership
	Icon                string
	Color               string
	ChartCode           string
	ParentID            *uuid.UUID
	Institution         string
	CreditLimitCents    int64
	Status              AccountStatus
	Version             int64
	DeletedAt           *time.Time
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// NewAccount creates a validated Account entity.
func NewAccount(tenantID uuid.UUID, name string, accountType AccountType, currencyCode string) (*Account, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("account name must not be empty")
	}
	if accountType < AccountTypeAsset || accountType > AccountTypeExpense {
		return nil, fmt.Errorf("invalid account type")
	}
	currencyCode = strings.TrimSpace(strings.ToUpper(currencyCode))
	if currencyCode == "" {
		currencyCode = "CNY"
	}
	return &Account{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		AccountType:  accountType,
		CurrencyCode: currencyCode,
		Status:       AccountStatusActive,
		Version:      1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}, nil
}

// UpdateName changes the account display name.
func (a *Account) UpdateName(name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("account name must not be empty")
	}
	a.Name = name
	a.UpdatedAt = time.Now()
	return nil
}

// UpdateDetails updates mutable display fields.
func (a *Account) UpdateDetails(name, icon, color, chartCode, institution string, creditLimitCents int64) {
	if name = strings.TrimSpace(name); name != "" {
		a.Name = name
	}
	a.Icon = icon
	a.Color = color
	a.ChartCode = chartCode
	a.Institution = institution
	a.CreditLimitCents = creditLimitCents
	a.UpdatedAt = time.Now()
}

// Archive marks the account as archived.
func (a *Account) Archive() {
	a.Status = AccountStatusArchived
	a.UpdatedAt = time.Now()
}

// SoftDelete marks the account as deleted.
func (a *Account) SoftDelete() {
	now := time.Now()
	a.DeletedAt = &now
	a.Status = AccountStatusArchived
	a.UpdatedAt = now
}

// IncrementVersion bumps the optimistic lock version.
func (a *Account) IncrementVersion() {
	a.Version++
	a.UpdatedAt = time.Now()
}

// IsDeleted returns true if the account has been soft-deleted.
func (a *Account) IsDeleted() bool {
	return a.DeletedAt != nil
}

// ChartOfAccount represents an entry in the tenant's chart of accounts.
type ChartOfAccount struct {
	ID               uuid.UUID
	TenantID         uuid.UUID
	Code             string
	Name             string
	Level            int
	AccountType      AccountType
	ParentCode       string
	BalanceDirection BalanceDirection
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// NewChartOfAccount creates a validated ChartOfAccount entity.
func NewChartOfAccount(tenantID uuid.UUID, code, name string, accountType AccountType, balanceDir BalanceDirection) (*ChartOfAccount, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, fmt.Errorf("chart code must not be empty")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("chart name must not be empty")
	}
	return &ChartOfAccount{
		ID:               uuid.New(),
		TenantID:         tenantID,
		Code:             code,
		Name:             name,
		Level:            1,
		AccountType:      accountType,
		BalanceDirection: balanceDir,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}, nil
}
