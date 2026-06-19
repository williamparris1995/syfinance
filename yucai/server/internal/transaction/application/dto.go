package application

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/domain"
)

// RecordTransactionRequest holds input for recording a transaction.
type RecordTransactionRequest struct {
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []EntryInput
}

// EntryInput is the input DTO for a transaction entry.
type EntryInput struct {
	AccountID          uuid.UUID
	ChartOfAccountCode string
	DebitCents         int64
	CreditCents        int64
	Note               string
}

// UpdateTransactionRequest holds input for updating a transaction.
type UpdateTransactionRequest struct {
	TenantID        uuid.UUID
	TransactionID   uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []EntryInput
	Version         int64
}

// DeleteTransactionRequest holds input for soft-deleting a transaction.
type DeleteTransactionRequest struct {
	TenantID      uuid.UUID
	TransactionID uuid.UUID
}

// ListTransactionsRequest holds input for listing transactions.
type ListTransactionsRequest struct {
	TenantID    uuid.UUID
	Filter      domain.TransactionFilter
	PageRequest domain.PageRequest
}

// SimpleIncomeRequest creates an income transaction.
type SimpleIncomeRequest struct {
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	AssetAccountID  uuid.UUID
	IncomeAccountID uuid.UUID
	AmountCents     int64
	Note            string
}

// SimpleExpenseRequest creates an expense transaction.
type SimpleExpenseRequest struct {
	TenantID         uuid.UUID
	TransactionDate  time.Time
	Description      string
	ExpenseAccountID uuid.UUID
	AssetAccountID   uuid.UUID
	AmountCents      int64
	Note             string
}

// SimpleTransferRequest creates a transfer transaction.
type SimpleTransferRequest struct {
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	FromAccountID   uuid.UUID
	ToAccountID     uuid.UUID
	AmountCents     int64
	Note            string
}

// TransactionDTO is the data transfer object.
type TransactionDTO struct {
	ID              uuid.UUID
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []EntryDTO
	Version         int64
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// EntryDTO is the DTO for transaction entries.
type EntryDTO struct {
	ID                 uuid.UUID
	AccountID          uuid.UUID
	ChartOfAccountCode string
	DebitCents         int64
	CreditCents        int64
	Note               string
}

// ListTransactionsResult wraps paginated transaction DTOs.
type ListTransactionsResult struct {
	Transactions  []TransactionDTO
	NextPageToken string
	TotalCount    int32
}

// CategoryItemDTO is one account-as-category contribution to a day's income or
// expense. AccountType is "income" or "expense"; Amount is signed by direction.
type CategoryItemDTO struct {
	AccountID   uuid.UUID
	Name        string
	AccountType string
	Amount      int64
}

// DailyItemDTO aggregates a single day's income/expense and its category breakdown.
type DailyItemDTO struct {
	Date        time.Time
	TotalIncome int64
	ByCategory  []CategoryItemDTO
}

// MonthlySummaryDTO is the TransactionSummary result for a (tenant, year, month)
// scope. IncomeCents/ExpenseCents are month totals; NetCents = Income - Expense;
// DailyAvgCents is the net mean over distinct active days.
type MonthlySummaryDTO struct {
	IncomeCents   int64
	ExpenseCents  int64
	NetCents      int64
	DailyAvgCents int64
	ByDay         []DailyItemDTO
}

// SummaryToDTO maps a domain MonthlySummary to its DTO form.
func SummaryToDTO(m *domain.MonthlySummary) MonthlySummaryDTO {
	if m == nil {
		return MonthlySummaryDTO{}
	}
	byDay := make([]DailyItemDTO, len(m.ByDay))
	for i, d := range m.ByDay {
		cats := make([]CategoryItemDTO, len(d.ByCategory))
		for j, c := range d.ByCategory {
			cats[j] = CategoryItemDTO{
				AccountID:   c.AccountID,
				Name:        c.Name,
				AccountType: c.AccountType,
				Amount:      c.Amount,
			}
		}
		byDay[i] = DailyItemDTO{
			Date:        d.Date,
			TotalIncome: d.TotalIncome,
			ByCategory:  cats,
		}
	}
	return MonthlySummaryDTO{
		IncomeCents:   m.IncomeCents,
		ExpenseCents:  m.ExpenseCents,
		NetCents:      m.NetCents,
		DailyAvgCents: m.DailyAvgCents,
		ByDay:         byDay,
	}
}

// TransactionToDTO converts domain Transaction to DTO.
func TransactionToDTO(tx *domain.Transaction) TransactionDTO {
	entries := make([]EntryDTO, len(tx.Entries))
	for i, e := range tx.Entries {
		entries[i] = EntryDTO{
			ID:                 e.ID,
			AccountID:          e.AccountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
			Note:               e.Note,
		}
	}
	return TransactionDTO{
		ID:              tx.ID,
		TenantID:        tx.TenantID,
		TransactionDate: tx.TransactionDate,
		Description:     tx.Description,
		Entries:         entries,
		Version:         tx.Version,
		CreatedAt:       tx.CreatedAt,
		UpdatedAt:       tx.UpdatedAt,
	}
}

// BalanceUpdater updates account balances after transaction changes.
type BalanceUpdater interface {
	UpdateBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error
	ReverseBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error
}

// BuildSimpleEntries creates debit/credit entry pairs for convenience methods.
func BuildSimpleEntries(amount int64, debitAccountID, creditAccountID uuid.UUID, note string) []EntryInput {
	return []EntryInput{
		{AccountID: debitAccountID, DebitCents: amount, Note: note},
		{AccountID: creditAccountID, CreditCents: amount, Note: note},
	}
}

// ValidateUpdateVersion checks optimistic locking.
func ValidateUpdateVersion(current, expected int64) error {
	if current != expected {
		return fmt.Errorf("optimistic lock conflict: current version %d, expected %d", current, expected)
	}
	return nil
}
