package domain

import (
	"context"

	"github.com/google/uuid"
)

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

// GoalRepository defines the port for Goal persistence.
//
// Save/Update/FindByID/FindAll read+write the goal's multi-account links
// (goal_account_links + goal_debt_links, Task 6). WriteSnapshot upserts a daily
// progress snapshot keyed by (tenant_id, goal_id, snapshot_date) — same-day
// re-runs overwrite current_amount_cents rather than duplicating rows.
type GoalRepository interface {
	Save(ctx context.Context, goal *Goal) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Goal, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, goalType *GoalType, page PageRequest) (*PaginatedResult[Goal], error)
	Update(ctx context.Context, goal *Goal) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
	WriteSnapshot(ctx context.Context, goal *Goal) error
}

// AccountMarketValueSource reports Σ market value of holdings under the given
// accounts (Investment goal). Implemented by holding/application.Service
// (structural type — goal does not import holding).
type AccountMarketValueSource interface {
	GetAccountsMarketValue(ctx context.Context, tenantID uuid.UUID, accountIDs []uuid.UUID) (int64, error)
}

// AccountBalanceSource reports Σ current balance of the given asset accounts
// (Savings goal). Implemented by account/application.Service.
type AccountBalanceSource interface {
	GetAccountsBalance(ctx context.Context, tenantID uuid.UUID, accountIDs []uuid.UUID) (int64, error)
}

// DebtProgressSource reports Σ paid amount (original − remaining) of the given
// debts (DebtPayoff goal). Implemented by debt/application.Service.
type DebtProgressSource interface {
	GetDebtsPaid(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID) (int64, error)
}
