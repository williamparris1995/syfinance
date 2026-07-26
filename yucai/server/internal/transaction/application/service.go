package application

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/sqltx"
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
	// db is the shared *sql.DB backing every ent client (Task 1's provideDB).
	// The SimpleExpense/SimpleIncome/SimpleTransfer/RecordTransaction methods
	// wrap their write+balance-update sequence in a single sqltx.WithTx over db
	// so a partial failure (e.g. a balance-update error after the header was
	// saved) rolls back the whole operation. Nil is accepted for backward
	// compatibility with mock-based unit tests that do not exercise
	// transactionality; when nil, the wrapping is skipped and the methods run
	// legacy (auto-commit) semantics.
	db *sql.DB
}

// NewService creates a new transaction application service. db is the shared
// *sql.DB (Task 1's provideDB); pass nil only in narrow unit tests that inject
// mock repos and never persist.
func NewService(txnRepo domain.TransactionRepository, accountRepo AccountLookup, balanceUpd BalanceUpdater, db *sql.DB) *Service {
	return &Service{txnRepo: txnRepo, accountRepo: accountRepo, balanceUpd: balanceUpd, db: db}
}

// runInTx wraps fn in a single sqltx.WithTx over the shared *sql.DB so the
// transaction header write, its entries write, and every balance-updater
// account Update join one atomic DB transaction. A failure anywhere in fn
// (e.g. an insufficient-balance error returned by SimpleExpense's validation,
// or a balance-update failure after the header was saved) rolls back the whole
// operation.
//
// When s.db is nil the wrapper is skipped and fn runs directly against the
// repos' default (auto-commit) clients. This preserves the legacy
// non-transactional behavior that mock-based unit tests rely on (they inject
// mock repos without a *sql.DB); production wire always injects the shared db
// from Task 1's provideDB, so the rollback guarantee holds in deployment.
//
// Join-existing-tx semantics: when ctx already carries a tx driver (an outer
// WithTx from a holding/debt/template service calling the recorder adapter in
// Tasks 5-7), sqltx.WithTx runs fn against that outer driver without opening a
// new transaction — the outermost caller owns commit/rollback.
func (s *Service) runInTx(ctx context.Context, fn func(ctx context.Context) (*TransactionDTO, error)) (*TransactionDTO, error) {
	if s.db == nil {
		return fn(ctx)
	}
	var dto *TransactionDTO
	err := sqltx.WithTx(ctx, s.db, "postgres", nil, func(ctxT context.Context) error {
		d, e := fn(ctxT)
		dto = d
		return e
	})
	return dto, err
}

// RecordTransaction validates and persists a new double-entry transaction.
// The header write, entries writes, and balance updates are wrapped in a
// single sqltx.WithTx so a partial failure (e.g. a balance-update error after
// the header was saved) rolls back the whole operation.
func (s *Service) RecordTransaction(ctx context.Context, req RecordTransactionRequest) (*TransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*TransactionDTO, error) {
		return s.recordTransaction(ctx, req)
	})
}

// recordTransaction is the transactional-body implementation of
// RecordTransaction. It must be called inside runInTx (directly or via one of
// the SimpleXxx wrappers) so every repo/balance-updater call it makes joins
// the surrounding transaction.
func (s *Service) recordTransaction(ctx context.Context, req RecordTransactionRequest) (*TransactionDTO, error) {
	// Cross-tenant guard: every entry's account_id must belong to req.TenantID.
	// Without this, a malicious caller could attach another tenant's account_id
	// to its transaction, polluting the victim's balances and budget actuals
	// (SumEntryTotalsByAccount sums by account_id regardless of tenant on the
	// posting side; the entry write itself has no FK to account.tenant_id).
	for _, e := range req.Entries {
		if _, err := s.accountRepo.FindByID(ctx, req.TenantID, e.AccountID); err != nil {
			return nil, fmt.Errorf("entry account %s not owned by tenant %s: %w", e.AccountID, req.TenantID, err)
		}
	}

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

// SpendingByAccount returns the debit/credit totals of entries posted to
// accountID in [from, to], tenant-scoped. Used by budget actuals: budget items
// track Expense accounts (= categories), so an item's period spend is the debit
// total and refunds are the credit total. Transfers are asset→asset flows that
// never touch Expense accounts, so they are excluded automatically — no type
// filter.
//
// tenantID is required defense-in-depth: even though RecordTransaction now
// rejects cross-tenant entries at write time, historical or directly-inserted
// rows could otherwise leak into another tenant's budget actuals through the
// account_id-only join. Signature matches budget.EntryTotalsFunc exactly so the
// wire delegate closure is a direct forward. Thin wrapper: delegates to the
// repository and wraps errors.
func (s *Service) SpendingByAccount(ctx context.Context, tenantID, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
	debit, credit, err := s.txnRepo.SumEntryTotalsByAccount(ctx, tenantID, accountID, from, to)
	if err != nil {
		return 0, 0, fmt.Errorf("spending by account %s: %w", accountID, err)
	}
	return debit, credit, nil
}

// SpendingByAccountByMonth returns debit/credit totals grouped by account_id
// for [from, to], tenant-scoped. Budget batch actuals port: one query per
// month replaces N×M per-item SpendingByAccount calls across a budget list.
// Thin wrapper: delegates to the repository and wraps errors.
func (s *Service) SpendingByAccountByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	totals, err := s.txnRepo.SumEntryTotalsByMonth(ctx, tenantID, from, to)
	if err != nil {
		return nil, fmt.Errorf("spending by account by month: %w", err)
	}
	return totals, nil
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

	// Cross-tenant guard (same as RecordTransaction): every new entry's
	// account_id must belong to req.TenantID. ReverseBalances above already
	// ran on the old (validated) entries; we only need to gate the new ones.
	for _, e := range entries {
		if _, err := s.accountRepo.FindByID(ctx, req.TenantID, e.AccountID); err != nil {
			return nil, fmt.Errorf("entry account %s not owned by tenant %s: %w", e.AccountID, req.TenantID, err)
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

// SimpleIncome creates a debit-asset + credit-income transaction. The
// validation, header/entries writes, and balance updates run inside one
// sqltx.WithTx so a failure at any step rolls back the whole operation.
func (s *Service) SimpleIncome(ctx context.Context, req SimpleIncomeRequest) (*TransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*TransactionDTO, error) {
		return s.recordTransaction(ctx, RecordTransactionRequest{
			TenantID:        req.TenantID,
			TransactionDate: req.TransactionDate,
			TransactionTime: req.TransactionTime,
			Description:     req.Description,
			Entries:         BuildSimpleEntries(req.AmountCents, req.AssetAccountID, req.IncomeAccountID, req.Note),
		})
	})
}

// SimpleExpense creates a debit-expense + credit-asset transaction.
// It rejects the expense when the asset account's current balance is
// insufficient to cover the amount (prevents overdraft on the spot). The
// balance check, header/entries writes, and balance updates run inside one
// sqltx.WithTx so a failure at any step rolls back the whole operation.
func (s *Service) SimpleExpense(ctx context.Context, req SimpleExpenseRequest) (*TransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*TransactionDTO, error) {
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

		return s.recordTransaction(ctx, RecordTransactionRequest{
			TenantID:        req.TenantID,
			TransactionDate: req.TransactionDate,
			TransactionTime: req.TransactionTime,
			Description:     req.Description,
			Entries:         BuildSimpleEntries(req.AmountCents, req.ExpenseAccountID, req.AssetAccountID, req.Note),
		})
	})
}

// SimpleTransfer creates a debit-to + credit-from transaction.
// It rejects transfers between accounts that use different currencies
// (cross-currency transfers require explicit FX handling, out of scope here).
// The currency check, header/entries writes, and balance updates run inside one
// sqltx.WithTx so a failure at any step rolls back the whole operation.
func (s *Service) SimpleTransfer(ctx context.Context, req SimpleTransferRequest) (*TransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*TransactionDTO, error) {
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

		return s.recordTransaction(ctx, RecordTransactionRequest{
			TenantID:        req.TenantID,
			TransactionDate: req.TransactionDate,
			TransactionTime: req.TransactionTime,
			Description:     req.Description,
			Entries:         BuildSimpleEntries(req.AmountCents, req.ToAccountID, req.FromAccountID, req.Note),
		})
	})
}
