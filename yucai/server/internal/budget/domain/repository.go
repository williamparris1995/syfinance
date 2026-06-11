package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// BudgetRepository defines the port for Budget persistence.
type BudgetRepository interface {
	Save(ctx context.Context, budget *Budget) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Budget, error)
	FindByMonth(ctx context.Context, tenantID uuid.UUID, month string) (*Budget, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, activeOnly bool, page PageRequest) (*PaginatedResult[Budget], error)
	Update(ctx context.Context, budget *Budget) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}

// PageRequest for cursor-based pagination.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// BudgetActualsService computes actual spending from transactions.
type BudgetActualsService struct{}

// ComputeActualsForItem calculates actual spending for a single budget item
// by summing transaction entries for the account in the budget's month.
func (s *BudgetActualsService) ComputeActualsForItem(ctx context.Context, item *BudgetItem, month string, getEntries func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (debitTotal, creditTotal int64, err error)) error {
	from, to := monthRange(month)
	debitTotal, creditTotal, err := getEntries(ctx, item.AccountID, from, to)
	if err != nil {
		return err
	}
	// For expense accounts, actual spending = debits; for income, actual = credits
	// Simplified: use the larger of debit/credit as "spending direction"
	if debitTotal > creditTotal {
		item.ActualAmountCents = debitTotal
	} else {
		item.ActualAmountCents = creditTotal
	}
	return nil
}

// monthRange returns the first and last moment of a YYYY-MM month.
func monthRange(month string) (time.Time, time.Time) {
	t, _ := time.Parse("2006-01", month)
	from := time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	to := from.AddDate(0, 1, 0).Add(-time.Nanosecond)
	return from, to
}
