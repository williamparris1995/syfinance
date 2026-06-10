package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/domain"
)

// Service orchestrates transaction operations.
type Service struct {
	txnRepo      domain.TransactionRepository
	balanceUpd   BalanceUpdater
}

// NewService creates a new transaction application service.
func NewService(txnRepo domain.TransactionRepository, balanceUpd BalanceUpdater) *Service {
	return &Service{txnRepo: txnRepo, balanceUpd: balanceUpd}
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

	txn, err := domain.NewTransaction(req.TenantID, req.TransactionDate, req.Description, entries)
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
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.AssetAccountID, req.IncomeAccountID, req.Note),
	})
}

// SimpleExpense creates a debit-expense + credit-asset transaction.
func (s *Service) SimpleExpense(ctx context.Context, req SimpleExpenseRequest) (*TransactionDTO, error) {
	return s.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.ExpenseAccountID, req.AssetAccountID, req.Note),
	})
}

// SimpleTransfer creates a debit-to + credit-from transaction.
func (s *Service) SimpleTransfer(ctx context.Context, req SimpleTransferRequest) (*TransactionDTO, error) {
	return s.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		Description:     req.Description,
		Entries:         BuildSimpleEntries(req.AmountCents, req.ToAccountID, req.FromAccountID, req.Note),
	})
}
