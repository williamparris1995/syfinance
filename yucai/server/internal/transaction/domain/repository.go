package domain

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
)

// TransactionRepository defines the port for Transaction persistence.
type TransactionRepository interface {
	Save(ctx context.Context, tx *Transaction) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Transaction, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, filter TransactionFilter, page PageRequest) (*PaginatedResult[Transaction], error)
	Update(ctx context.Context, tx *Transaction) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}

// TransactionType classifies a transaction by its economic effect for the
// account-as-category + double-entry model:
//   - Income:   has a credit entry on an Income account (debit asset, credit income)
//   - Expense:  has a debit entry on an Expense account (debit expense, credit asset)
//   - Transfer: both legs are Asset accounts (debit asset, credit asset)
type TransactionType int

const (
	// TransactionTypeIncome is a SimpleIncome flow.
	TransactionTypeIncome TransactionType = iota + 1
	// TransactionTypeExpense is a SimpleExpense flow.
	TransactionTypeExpense
	// TransactionTypeTransfer is a SimpleTransfer flow.
	TransactionTypeTransfer
)

// String returns the lowercase name used for logs and API serialization.
func (t TransactionType) String() string {
	switch t {
	case TransactionTypeIncome:
		return "income"
	case TransactionTypeExpense:
		return "expense"
	case TransactionTypeTransfer:
		return "transfer"
	default:
		return "unknown"
	}
}

// ParseTransactionType converts a string (case-insensitive) to a TransactionType.
// Returns false for unknown values.
func ParseTransactionType(s string) (TransactionType, bool) {
	switch strings.ToLower(s) {
	case "income":
		return TransactionTypeIncome, true
	case "expense":
		return TransactionTypeExpense, true
	case "transfer":
		return TransactionTypeTransfer, true
	default:
		return 0, false
	}
}

// TransactionFilter holds optional query filters.
type TransactionFilter struct {
	AccountID *uuid.UUID
	DateFrom  *time.Time
	DateTo    *time.Time
	// Type filters by the economic flow (income/expense/transfer), inferred
	// from the account types touched by the transaction's entries. nil = no filter.
	Type *TransactionType
}

// PageRequest for cursor-based pagination.
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
