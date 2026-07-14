package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	templatedomain "github.com/yucai/server/internal/template/domain"
)

// simpleTransactionCreator is the narrow subset of the transaction application
// Service that TransactionRecorderAdapter consumes. Declared locally so the
// adapter depends on an abstraction (mirrors the backup exporter pattern's
// repo-subset type alias in adapter/driven/exporter); *Service satisfies it
// structurally and is what wire injects. Keeping the surface narrow also lets
// the adapter be unit-tested with a lightweight fake instead of the full
// txn-repo/account-repo/balance graph the concrete Service drags in.
type simpleTransactionCreator interface {
	SimpleExpense(ctx context.Context, req SimpleExpenseRequest) (*TransactionDTO, error)
	SimpleIncome(ctx context.Context, req SimpleIncomeRequest) (*TransactionDTO, error)
	SimpleTransfer(ctx context.Context, req SimpleTransferRequest) (*TransactionDTO, error)
}

// TransactionRecorderAdapter implements template/domain.TransactionRecorder by
// translating a RecordRequest into the appropriate existing transaction Service
// creation method (SimpleExpense / SimpleIncome / SimpleTransfer).
//
// DDD port pattern: template domain defines the port without importing the
// transaction module; this adapter in transaction/application implements it and
// is wire-injected into the template Service. Mirrors backup TenantDataPort →
// adapter/driven/exporter.
//
// RecordRequest.Category is typed string, but the transaction Service needs the
// category (expense/income) account's uuid.UUID. Under the account-as-category
// model every category IS an account identified by UUID, so Category carries
// that account's stringified UUID at runtime and is parsed here. If a
// human-readable name were stored instead, name→UUID resolution would belong in
// the template layer before the port call (it cannot be done here — there is no
// account name-lookup port and the adapter must not gain one).
type TransactionRecorderAdapter struct {
	svc simpleTransactionCreator
}

// NewTransactionRecorderAdapter creates an adapter backed by the given
// transaction application Service (or any simpleTransactionCreator).
func NewTransactionRecorderAdapter(svc simpleTransactionCreator) *TransactionRecorderAdapter {
	return &TransactionRecorderAdapter{svc: svc}
}

// Compile-time assertion that the adapter satisfies the template domain port.
var _ templatedomain.TransactionRecorder = (*TransactionRecorderAdapter)(nil)

// Record instantiates a template as a double-entry transaction via the existing
// transaction Service. Direction selects the creation method and maps the
// RecordRequest fields onto the double-entry legs:
//
//   - DirectionExpense:  debit expense(category) + credit asset(source)
//   - DirectionIncome:   debit asset(source)     + credit income(category)
//   - DirectionTransfer: debit dest(destination) + credit asset(source)
//
// An unspecified (zero) or unknown Direction, a transfer missing its
// destination, or an unparseable category UUID yields an error and creates no
// transaction.
func (a *TransactionRecorderAdapter) Record(ctx context.Context, tenantID uuid.UUID, req templatedomain.RecordRequest) (uuid.UUID, error) {
	switch req.Direction {
	case templatedomain.DirectionExpense:
		categoryID, err := uuid.Parse(req.Category)
		if err != nil {
			return uuid.Nil, fmt.Errorf("template record: parse expense category account id %q: %w", req.Category, err)
		}
		dto, err := a.svc.SimpleExpense(ctx, SimpleExpenseRequest{
			TenantID:         tenantID,
			TransactionDate:  req.Date,
			ExpenseAccountID: categoryID,
			AssetAccountID:   req.SourceAccountID,
			AmountCents:      req.AmountCents,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("template record: create expense transaction: %w", err)
		}
		return dto.ID, nil

	case templatedomain.DirectionIncome:
		categoryID, err := uuid.Parse(req.Category)
		if err != nil {
			return uuid.Nil, fmt.Errorf("template record: parse income category account id %q: %w", req.Category, err)
		}
		dto, err := a.svc.SimpleIncome(ctx, SimpleIncomeRequest{
			TenantID:        tenantID,
			TransactionDate: req.Date,
			AssetAccountID:  req.SourceAccountID,
			IncomeAccountID: categoryID,
			AmountCents:     req.AmountCents,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("template record: create income transaction: %w", err)
		}
		return dto.ID, nil

	case templatedomain.DirectionTransfer:
		if req.DestinationAccount == nil {
			return uuid.Nil, fmt.Errorf("template record: transfer direction requires a destination account")
		}
		dto, err := a.svc.SimpleTransfer(ctx, SimpleTransferRequest{
			TenantID:        tenantID,
			TransactionDate: req.Date,
			FromAccountID:   req.SourceAccountID,
			ToAccountID:     *req.DestinationAccount,
			AmountCents:     req.AmountCents,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("template record: create transfer transaction: %w", err)
		}
		return dto.ID, nil

	default:
		// Zero value (unspecified) or any unknown direction — cannot record.
		return uuid.Nil, fmt.Errorf("template record: unsupported direction %v", req.Direction)
	}
}
