package balance

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/transaction/application"
	"github.com/yucai/server/internal/transaction/domain"
)

// BalanceUpdaterImpl updates account balances using direct increment/decrement.
type BalanceUpdaterImpl struct {
	accountRepo accountdomain.AccountRepository
}

// NewBalanceUpdater creates a new BalanceUpdater.
func NewBalanceUpdater(accountRepo accountdomain.AccountRepository) *BalanceUpdaterImpl {
	return &BalanceUpdaterImpl{accountRepo: accountRepo}
}

// UpdateBalances applies transaction entries to account balances.
func (u *BalanceUpdaterImpl) UpdateBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, 1)
}

// ReverseBalances reverses the balance effects of transaction entries.
func (u *BalanceUpdaterImpl) ReverseBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, -1)
}

func (u *BalanceUpdaterImpl) applyEntries(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry, sign int64) error {
	calc := accountdomain.BalanceCalculator{}
	for _, e := range entries {
		account, err := u.accountRepo.FindByID(ctx, tenantID, e.AccountID)
		if err != nil {
			return fmt.Errorf("find account %s: %w", e.AccountID, err)
		}
		delta := calc.ApplyEntryDelta(account.AccountType, e.DebitCents, e.CreditCents) * sign
		account.CurrentBalanceCents += delta
		account.IncrementVersion()
		if err := u.accountRepo.Update(ctx, account); err != nil {
			return fmt.Errorf("update account balance: %w", err)
		}
	}
	return nil
}

// Compile-time check.
var _ application.BalanceUpdater = (*BalanceUpdaterImpl)(nil)
