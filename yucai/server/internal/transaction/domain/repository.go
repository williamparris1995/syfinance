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
	// FindRecentByAccount returns the most recent transactions that touch the
	// given account (the account-as-category "same-category recent transactions"
	// view, e.g. other meals charged to the same Food expense account), ordered
	// by transaction_date DESC. limit <= 0 falls back to a default and is capped
	// to a sane maximum; the caller decides whether to exclude a specific tx.
	FindRecentByAccount(ctx context.Context, tenantID, accountID uuid.UUID, limit int) ([]Transaction, error)
	Update(ctx context.Context, tx *Transaction) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
	// TransactionSummary returns the monthly income/expense summary broken down
	// by day and by Income/Expense account (category). See MonthlySummary.
	TransactionSummary(ctx context.Context, scope SummaryScope) (*MonthlySummary, error)
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

// SummaryCategoryItem is one account's (account-as-category) contribution to a
// single day's income or expense. AccountID identifies the Income/Expense
// account; Name/AccountType are denormalized for the client so it does not need
// a second account lookup. Amount is signed by direction (income = credit_cents
// on an Income account, expense = debit_cents on an Expense account).
type SummaryCategoryItem struct {
	AccountID   uuid.UUID
	Name        string
	AccountType string // "income" | "expense"
	Amount      int64
}

// SummaryDailyItem aggregates all income/expense entries for a single calendar
// day within the queried month. ByCategory breaks the day down by the Income or
// Expense account that absorbed each leg (the account-as-category breakdown for
// the home/dashboard "by category" chart).
type SummaryDailyItem struct {
	Date        time.Time
	TotalIncome int64
	ByCategory  []SummaryCategoryItem
}

// MonthlySummary is the result of TransactionSummary for a (tenant, year, month)
// scope, optionally narrowed to a single account. IncomeCents/ExpenseCents are
// month totals; NetCents = Income - Expense; DailyAvgCents is the month mean
// over the number of distinct days that had any income or expense activity.
type MonthlySummary struct {
	IncomeCents   int64
	ExpenseCents  int64
	NetCents      int64
	DailyAvgCents int64
	ByDay         []SummaryDailyItem
}

// SummaryScope narrows a TransactionSummary query to a month, optionally to a
// single account (account_detail view). AccountID == nil means all accounts.
type SummaryScope struct {
	TenantID  uuid.UUID
	Year      int
	Month     int // 1-12
	AccountID *uuid.UUID
}

// TransactionSummary returns the monthly income/expense summary, broken down by
// day and by Income/Expense account (category). Implements the account-as-
// category + double-entry aggregation:
//   - IncomeCents  = sum of credit_cents on Income accounts
//   - ExpenseCents = sum of debit_cents on Expense accounts
//   - asset/liability/equity legs are not income or expense and are ignored
//   - transfers (asset→asset) therefore contribute 0 to both totals
