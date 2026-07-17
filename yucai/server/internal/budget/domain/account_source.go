package domain

import (
	"context"

	"github.com/google/uuid"
)

// AccountCurrencySource is a port for looking up account currency codes
// (budget does not import account domain — mirrors networth's AccountBalanceSource
// / goal's AccountMarketValueSource pattern). Used by M3 actuals conversion to
// 折算 per-item actuals from the account's currency to the budget's currency.
type AccountCurrencySource interface {
	// CurrencyCodes returns account_id -> currency_code for the tenant's accounts.
	// Budget looks up each item's account currency to drive ConvertToBase.
	// Callers should cache the result per request (one query per ListBudgets).
	CurrencyCodes(ctx context.Context, tenantID uuid.UUID) (map[uuid.UUID]string, error)
}
