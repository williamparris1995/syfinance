package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	debttdomain "github.com/yucai/server/internal/debt/domain"
)

// RepaymentCashRecorderAdapter implements debt/domain.RepaymentCashRecorder by
// delegating to the transaction application Service's RecordTransaction. It is
// the cash-side bridge for D3 (debt repayment): when the debt service marks a
// schedule entry paid + persists principal, it calls Record inside its
// sqltx.WithTx; this adapter translates the debt-owned RepaymentCashRecordRequest
// into transaction EntryInput + a RecordTransactionRequest and delegates to
// svc.RecordTransaction.
//
// svc.RecordTransaction wraps recordTransaction in runInTx (Task 4). When the
// caller's ctx already carries a tx driver (an outer sqltx.WithTx — the debt
// service's WithTx here), runInTx's join-existing-tx semantics run the record
// body against that outer driver without opening a new transaction. The
// outermost caller (the debt service) owns commit/rollback. So a debt write +
// the cash transaction are atomic on the same DB tx.
//
// DDD port pattern: debt/domain defines the port without importing the
// transaction module; this adapter in transaction/application implements it and
// is wire-injected into the debt Service. Mirrors TradeCashRecorderAdapter
// (Task 5 / D2) and TransactionRecorderAdapter (template) — sibling-shaped by
// design so each consumer module owns its own port while the transaction
// application owns one adapter per port.
type RepaymentCashRecorderAdapter struct {
	svc simpleTransactionCreatorWithRecord
}

// NewRepaymentCashRecorderAdapter creates an adapter backed by the given
// transaction application Service (or any simpleTransactionCreatorWithRecord).
func NewRepaymentCashRecorderAdapter(svc simpleTransactionCreatorWithRecord) *RepaymentCashRecorderAdapter {
	return &RepaymentCashRecorderAdapter{svc: svc}
}

// Compile-time assertion that the adapter satisfies the debt domain port.
var _ debttdomain.RepaymentCashRecorder = (*RepaymentCashRecorderAdapter)(nil)

// Record translates the debt-owned RepaymentCashRecordRequest into transaction
// EntryInput legs and delegates to the transaction Service's RecordTransaction.
// Inside the debt service's WithTx, the Service's runInTx join-existing-tx
// semantics enlist RecordTransaction's writes in that outer tx — the debt
// schedule/principal write and its cash legs commit or roll back together.
// Returns the new transaction's ID.
//
// An empty Entries list is rejected up front (the transaction service's domain
// validator would reject it anyway, but failing here yields a clearer error
// from the debt-side call site).
func (a *RepaymentCashRecorderAdapter) Record(ctx context.Context, req debttdomain.RepaymentCashRecordRequest) (uuid.UUID, error) {
	if len(req.Entries) == 0 {
		return uuid.Nil, fmt.Errorf("repayment cash record: entries empty")
	}
	entries := make([]EntryInput, len(req.Entries))
	for i, e := range req.Entries {
		entries[i] = EntryInput{
			AccountID:          e.AccountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
		}
	}
	dto, err := a.svc.RecordTransaction(ctx, RecordTransactionRequest{
		TenantID:        req.TenantID,
		TransactionDate: req.TransactionDate,
		Description:     req.Description,
		Entries:         entries,
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("repayment cash record: create transaction: %w", err)
	}
	return dto.ID, nil
}
