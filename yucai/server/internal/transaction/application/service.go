package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/transaction/domain"
)

// AccountLookup is the account-reading port used by the transaction service
// for business validation (currency consistency, balance sufficiency).
// Only the read methods needed for validation are exposed here; the concrete
// account domain.AccountRepository satisfies this interface.
type AccountLookup interface {
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*accountdomain.Account, error)
}

// Service orchestrates transaction operations.
type Service struct {
	txnRepo     domain.TransactionRepository
	accountRepo AccountLookup
	balanceUpd  BalanceUpdater
}

// NewService creates a new transaction application service.
func NewService(txnRepo domain.TransactionRepository, accountRepo AccountLookup, balanceUpd BalanceUpdater) *Service {
	return &Service{txnRepo: txnRepo, accountRepo: accountRepo, balanceUpd: balanceUpd}
}

// RecordTransaction validates and persists a new double-entry transaction.
func (s *Service) RecordTransaction(ctx context.Context, req RecordTransactionRequest) (*TransactionDTO, error) {
	entries := make([]domain.TransactionEntry, len(req.Entries))
	for i, e := range req.Entries {
		entries[i] = domain.TransactionEntry{
			ID:                 uuid.New(),
			AccountID:          e.AccountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
			Note:               e.Note,
		}
	}

	txn, err := domain.NewTransaction(req.TenantID, req.TransactionDate, req.TransactionTime, req.Description, entries)
	if err != nil {
		return nil, fmt.Errorf("create transaction: %w", err)
	}

	if err := s.txnRepo.Save(ctx, txn); err != nil {
		return nil, fmt.Errorf("save transaction: %w", err)
	}

	if err := s.balanceUpd.UpdateBalances(ctx, req.TenantID, txn.Entries); err != nil {
		return nil, fmt.Errorf("update balances: %w", err)
	}

	dto := TransactionToDTO(txn)
	return &dto, nil
}

// GetTransaction retrieves a transaction with its entries.
func (s *Service) GetTransaction(ctx context.Context, tenantID, txnID uuid.UUID) (*TransactionDTO, error) {
	txn, err := s.txnRepo.FindByID(ctx, tenantID, txnID)
	if err != nil {
		return nil, fmt.Errorf("transaction not found: %w", err)
	}
	dto := TransactionToDTO(txn)
	return &dto, nil
}

// ListTransactions returns a paginated, filtered list.
func (s *Service) ListTransactions(ctx context.Context, req ListTransactionsRequest) (*ListTransactionsResult, error) {
	result, err := s.txnRepo.FindAll(ctx, req.TenantID, req.Filter, req.PageRequest)
	if err != nil {
		return nil, fmt.Errorf("list transactions: %w", err)
	}
	dtos := make([]TransactionDTO, len(result.Items))
	for i, tx := range result.Items {
		dtos[i] = TransactionToDTO(&tx)
	}
	return &ListTransactionsResult{
		Transactions:  dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// ListRecentByAccount returns the most recent transactions touching the given
// account (the "same-category recent transactions" view under
// account-as-category), newest first. Thin wrapper over the repository: it
// delegates tenant scoping, soft-delete exclusion, ordering and limit clamping
// to the repo and just maps domain entities to DTOs. Useful for the
// transaction-detail page's "recent same-category" panel.
func (s *Service) ListRecentByAccount(ctx context.Context, tenantID, accountID uuid.UUID, limit int) ([]TransactionDTO, error) {
	txns, err := s.txnRepo.FindRecentByAccount(ctx, tenantID, accountID, limit)
	if err != nil {
		return nil, fmt.Errorf("list recent transactions by account %s: %w", accountID, err)
	}
	dtos := make([]TransactionDTO, len(txns))
	for i, tx := range txns {
		dtos[i] = TransactionToDTO(&tx)
	}
	return dtos, nil
}

// TransactionSummary returns the income/expense summary for a tenant over a
// period selected by scope (DAY/MONTH/YEAR), optionally narrowed to a single
// account (the account_detail view). It delegates aggregation to the repository
// and maps the domain MonthlySummary to a DTO.
//
// IncomeCents/ExpenseCents follow the account-as-category + double-entry
// direction rules (Income account credit legs; Expense account debit legs).
//
//   - scope == ScopeMonth (or the zero value) aggregates per calendar day for
//     (year, month); DailyAvgCents is meaningful only in this case.
//   - scope == ScopeYear aggregates per calendar month for year; month is
//     ignored; day must be nil.
//   - scope == ScopeDay aggregates the single calendar day (year, month, *day);
//     day must be non-nil and in [1,31] (the handler enforces this).
func (s *Service) TransactionSummary(ctx context.Context, tenantID uuid.UUID, year, month int, accountID *uuid.UUID, scope domain.Scope, day *int) (MonthlySummaryDTO, error) {
	summary, err := s.txnRepo.TransactionSummary(ctx, domain.SummaryScope{
		TenantID:  tenantID,
		Year:      year,
		Month:     month,
		Day:       day,
		Scope:     scope,
		AccountID: accountID,
	})
	if err != nil {
		return MonthlySummaryDTO{}, fmt.Errorf("transaction summary for %04d-%02d: %w", year, month, err)
	}
	return SummaryToDTO(summary), nil
}

// UpdateTransaction replaces entries and adjusts balances.
func (s *Service) UpdateTransaction(ctx context.Context, req UpdateTransactionRequest) (*TransactionDTO, error) {
	txn, err := s.txnRepo.FindByID(ctx, req.TenantID, req.TransactionID)
	if err != nil {
		return nil, fmt.Errorf("transaction not found: %w", err)
	}

	if err := ValidateUpdateVersion(txn.Version, req.Version); err != nil {
		return nil, err
	}

	// Reverse old balance effects
	if err := s.balanceUpd.ReverseBalances(ctx, req.TenantID, txn.Entries); err != nil {
		return nil, fmt.Errorf("reverse old balances: %w", err)
	}

	// Build new entries
	entries := make([]domain.TransactionEntry, len(req.Entries))
	for i, e := range req.Entries {
		entries[i] = domain.TransactionEntry{
			ID:                 uuid.New(),
			AccountID:          e.AccountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
			Note:               e.Note,
		}
	}

	// Validate new entries
	validator := domain.DoubleEntryValidator{}
	if err := validator.Validate(entries); err != nil {
		return nil, fmt.Errorf("invalid entries: %w", err)
	}

	txn.TransactionDate = req.TransactionDate
	txn.Description = req.Description
	txn.Entries = entries
	txn.IncrementVersion()

	if err := s.txnRepo.Update(ctx, txn); err != nil {
		return nil, fmt.Errorf("update transaction: %w", err)
	}

	// Apply new balance effects
	if err := s.balanceUpd.UpdateBalances(ctx, req.TenantID, txn.Entries); err != nil {
		return nil, fmt.Errorf("apply new balances: %w", err)
	}

	dto := TransactionToDTO(txn)
	return &dto, nil
}

// DeleteTransaction reverses balances and soft-deletes.
func (s *Service) DeleteTransaction(ctx context.Context, tenantID, txnID uuid.UUID) error {
	txn, err := s.txnRepo.FindByID(ctx, tenantID, txnID)
	if err != nil {
		return fmt.Errorf("transaction not found: %w", err)
	}

	if err := s.balanceUpd.ReverseBalances(ctx, tenantID, txn.Entries); err != nil {
		return fmt.Errorf("reverse balances: %w", err)
	}

	return s.txnRepo.SoftDelete(ctx, tenantID, txnID)
}

// SimpleIncome creates a debit-asset + credit-income transaction.
func (s *Service) SimpleIncome(ctx context.Context, req SimpleIncomeRequest) (*TransactionDTO, error) {
	return s.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		TransactionTime: req.TransactionTime,
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.AssetAccountID, req.IncomeAccountID, req.Note),
	})
}

// SimpleExpense creates a debit-expense + credit-asset transaction.
// It rejects the expense when the asset account's current balance is
// insufficient to cover the amount (prevents overdraft on the spot).
func (s *Service) SimpleExpense(ctx context.Context, req SimpleExpenseRequest) (*TransactionDTO, error) {
	asset, err := s.accountRepo.FindByID(ctx, req.TenantID, req.AssetAccountID)
	if err != nil {
		return nil, fmt.Errorf("find asset account %s: %w", req.AssetAccountID, err)
	}
	if asset.CurrentBalanceCents < req.AmountCents {
		return nil, fmt.Errorf(
			"insufficient balance: account %s has %d cents, expense requires %d cents",
			req.AssetAccountID, asset.CurrentBalanceCents, req.AmountCents,
		)
	}

	return s.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		TransactionTime: req.TransactionTime,
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.ExpenseAccountID, req.AssetAccountID, req.Note),
	})
}

// SimpleTransfer creates a debit-to + credit-from transaction.
// It rejects transfers between accounts that use different currencies
// (cross-currency transfers require explicit FX handling, out of scope here).
func (s *Service) SimpleTransfer(ctx context.Context, req SimpleTransferRequest) (*TransactionDTO, error) {
	from, err := s.accountRepo.FindByID(ctx, req.TenantID, req.FromAccountID)
	if err != nil {
		return nil, fmt.Errorf("find from account %s: %w", req.FromAccountID, err)
	}
	to, err := s.accountRepo.FindByID(ctx, req.TenantID, req.ToAccountID)
	if err != nil {
		return nil, fmt.Errorf("find to account %s: %w", req.ToAccountID, err)
	}
	if from.CurrencyCode != to.CurrencyCode {
		return nil, fmt.Errorf(
			"currency mismatch: from account %s uses %s, to account %s uses %s",
			req.FromAccountID, from.CurrencyCode, req.ToAccountID, to.CurrencyCode,
		)
	}

	return s.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		TransactionTime: req.TransactionTime,
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.ToAccountID, req.FromAccountID, req.Note),
	})
}
