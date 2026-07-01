package domain

import (
	"context"

	"github.com/google/uuid"
)

// AccountBalanceSource reports per-currency Σ balances (asset accounts only).
// Implemented by account/application.Service (structural — networth doesn't
// import account), to be added in Task 5.
type AccountBalanceSource interface {
	SumBalancesByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// HoldingMarketValueSource reports per-currency Σ market value
// (qty × current price). Implemented by holding/application.Service
// (structural — networth doesn't import holding), to be added in Task 5.
type HoldingMarketValueSource interface {
	SumMarketValueByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// DebtSource reports per-currency Σ remaining principal. Implemented by
// debt/application.Service (structural — networth doesn't import debt),
// to be added in Task 5.
type DebtSource interface {
	SumRemainingByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// GetNetWorthResult is the aggregated net-worth converted to baseCurrency.
type GetNetWorthResult struct {
	TotalAssetsCents      int64
	TotalLiabilitiesCents int64
	NetWorthCents         int64
	Currency              string
}
