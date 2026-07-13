package domain

import (
	"context"

	"github.com/google/uuid"
)

// BalanceCalculator computes account balances using double-entry rules.
// Asset/Expense accounts increase with debits.
// Liability/Equity/Income accounts increase with credits.
type BalanceCalculator struct{}

// Calculate returns the current balance based on account type and totals.
func (BalanceCalculator) Calculate(accountType AccountType, initialCents, debitTotal, creditTotal int64) int64 {
	switch accountType {
	case AccountTypeAsset, AccountTypeExpense:
		return initialCents + debitTotal - creditTotal
	case AccountTypeLiability, AccountTypeEquity, AccountTypeIncome:
		return initialCents + creditTotal - debitTotal
	default:
		return initialCents
	}
}

// ApplyEntryDelta computes the balance delta for a single entry on a given account type.
func (BalanceCalculator) ApplyEntryDelta(accountType AccountType, debitCents, creditCents int64) int64 {
	switch accountType {
	case AccountTypeAsset, AccountTypeExpense:
		return debitCents - creditCents
	case AccountTypeLiability, AccountTypeEquity, AccountTypeIncome:
		return creditCents - debitCents
	default:
		return 0
	}
}

// AccountFilter holds optional query filters for account listing.
type AccountFilter struct {
	AccountType *AccountType
	Status      *AccountStatus
}

// AccountRepository defines the port for Account persistence.
type AccountRepository interface {
	Save(ctx context.Context, account *Account) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Account, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, filter AccountFilter, page PageRequest) (*PaginatedResult[Account], error)
	// FindByAccountType returns all non-deleted accounts of a given type within a tenant.
	// Used for the transaction-form category dropdown (account-as-category): a category
	// is an account whose AccountType is Expense (for an expense transaction) or Income.
	FindByAccountType(ctx context.Context, tenantID uuid.UUID, accountType AccountType) ([]Account, error)
	Update(ctx context.Context, account *Account) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
	// FindAllForBackup returns all non-deleted accounts for a tenant (no
	// pagination, includes category accounts) for backup export.
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]Account, error)
	// DeleteByTenant hard-deletes all accounts for a tenant (restore purge,
	// includes categories). Used by backup Import to clear before re-import.
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// ChartRepository defines the port for ChartOfAccount persistence.
type ChartRepository interface {
	Save(ctx context.Context, chart *ChartOfAccount) error
	FindByCode(ctx context.Context, tenantID uuid.UUID, code string) (*ChartOfAccount, error)
	FindAll(ctx context.Context, tenantID uuid.UUID) ([]ChartOfAccount, error)
}

// PageRequest represents cursor-based pagination input.
type PageRequest struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
