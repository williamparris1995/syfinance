package application

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"
	currencydomain "github.com/yucai/server/internal/currency/domain"
	"github.com/yucai/server/internal/networth/domain"
)

// Service aggregates net-worth across account balances + holding market values
// − debt remaining,折算 each source currency to a configurable base currency via
// the CNY-base rate_history cross rate (currencydomain.ConvertToBase).
//
// The three source ports (account/holding/debt) are injected structurally —
// networth does not import those modules (mirrors goal's AccountMarketValueSource
// pattern). They are wired in Task 5.
type Service struct {
	accounts domain.AccountBalanceSource
	holdings domain.HoldingMarketValueSource
	debts    domain.DebtSource
	rateRepo currencydomain.RateHistoryRepository // CNY-base rates; nil → 1.0 (no conversion)
	log      *slog.Logger
}

// NewService constructs a networth service. rateRepo may be nil (graceful: no
// conversion, raw currency sums). log defaults to slog.Default() when nil.
func NewService(
	accounts domain.AccountBalanceSource,
	holdings domain.HoldingMarketValueSource,
	debts domain.DebtSource,
	rateRepo currencydomain.RateHistoryRepository,
	log *slog.Logger,
) *Service {
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		accounts: accounts,
		holdings: holdings,
		debts:    debts,
		rateRepo: rateRepo,
		log:      log,
	}
}

// GetNetWorth aggregates account balances + holding market value − debt
// remaining for a tenant,折算 every source currency to baseCurrency via the
// CNY-base rate_history cross rate. baseCurrency defaults to "CNY" when empty.
//
// Best-effort: if a source port fails (returns error or is nil), it is logged
// and skipped — the remaining sources still contribute. A nil rateRepo means
// no conversion (rates default to 1.0), so mixed currencies sum raw.
func (s *Service) GetNetWorth(ctx context.Context, tenantID uuid.UUID, baseCurrency string) (*domain.GetNetWorthResult, error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := 1.0
	if s.rateRepo != nil {
		rateBase, _ = s.rateRepo.FindRate(ctx, base, time.Now())
	}

	var assets, liab int64

	if s.accounts != nil {
		if m, err := s.accounts.SumBalancesByCurrency(ctx, tenantID); err == nil {
			for code, amt := range m {
				assets += s.toBase(ctx, amt, code, rateBase)
			}
		} else {
			s.log.Warn("networth: account balance sum failed, skipping", "error", err)
		}
	}

	if s.holdings != nil {
		if m, err := s.holdings.SumMarketValueByCurrency(ctx, tenantID); err == nil {
			for code, amt := range m {
				assets += s.toBase(ctx, amt, code, rateBase)
			}
		} else {
			s.log.Warn("networth: holding market-value sum failed, skipping", "error", err)
		}
	}

	if s.debts != nil {
		if m, err := s.debts.SumRemainingByCurrency(ctx, tenantID); err == nil {
			for code, amt := range m {
				liab += s.toBase(ctx, amt, code, rateBase)
			}
		} else {
			s.log.Warn("networth: debt remaining sum failed, skipping", "error", err)
		}
	}

	return &domain.GetNetWorthResult{
		TotalAssetsCents:      assets,
		TotalLiabilitiesCents: liab,
		NetWorthCents:         assets - liab,
		Currency:              base,
	}, nil
}

// toBase converts an amount denominated in `code` to the base currency using the
// CNY-base cross rate. rateBase is the pre-fetched base→CNY rate (1.0 if base is
// CNY or rateRepo missing). rateFrom is looked up per-code (missing → 1.0).
func (s *Service) toBase(ctx context.Context, amount int64, code string, rateBase float64) int64 {
	if amount == 0 || s.rateRepo == nil {
		return amount
	}
	rateFrom := 1.0
	if code != "" {
		rateFrom, _ = s.rateRepo.FindRate(ctx, code, time.Now())
	}
	return currencydomain.ConvertToBase(amount, rateFrom, rateBase)
}

