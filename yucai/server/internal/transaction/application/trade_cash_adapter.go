package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
)

// TradeCashRecorderAdapter implements holding/domain.TradeCashRecorder by
// delegating to the transaction application Service's RecordTransaction. It is
// the cash-side bridge for D2 (holding trades): when the holding service writes
// a buy/sell, it calls Record inside its sqltx.WithTx; this adapter translates
// the holding-owned TradeCashRecordRequest into transaction EntryInput + a
// RecordTransactionRequest and delegates to svc.RecordTransaction.
//
// svc.RecordTransaction wraps recordTransaction in runInTx (Task 4). When the
// caller's ctx already carries a tx driver (an outer sqltx.WithTx — the holding
// service's WithTx here), runInTx's join-existing-tx semantics run the record
// body against that outer driver without opening a new transaction. The
// outermost caller (the holding service) owns commit/rollback. So a holding
// write + the cash transaction are atomic on the same DB tx.
//
// DDD port pattern: holding/domain defines the port without importing the
// transaction module; this adapter in transaction/application implements it and
// is wire-injected into the holding Service. Mirrors backup TenantDataPort →
// adapter/driven/exporter and template TransactionRecorder →
// application/recorder_adapter.
type TradeCashRecorderAdapter struct {
	svc simpleTransactionCreatorWithRecord
}

// simpleTransactionCreatorWithRecord is the narrow subset of the transaction
// application Service that TradeCashRecorderAdapter consumes. Declared locally
// (mirrors simpleTransactionCreator in recorder_adapter.go) so the adapter
// depends on an abstraction; *Service satisfies it structurally and is what
// wire injects. Keeping the surface narrow lets the adapter be unit-tested
// with a lightweight fake instead of the full txn-repo/account-repo/balance
// graph the concrete Service drags in.
type simpleTransactionCreatorWithRecord interface {
	RecordTransaction(ctx context.Context, req RecordTransactionRequest) (*TransactionDTO, error)
}

// NewTradeCashRecorderAdapter creates an adapter backed by the given
// transaction application Service (or any simpleTransactionCreatorWithRecord).
func NewTradeCashRecorderAdapter(svc simpleTransactionCreatorWithRecord) *TradeCashRecorderAdapter {
	return &TradeCashRecorderAdapter{svc: svc}
}

// Compile-time assertion that the adapter satisfies the holding domain port.
var _ holdingdomain.TradeCashRecorder = (*TradeCashRecorderAdapter)(nil)

// Record translates the holding-owned TradeCashRecordRequest into transaction
// EntryInput legs and delegates to the transaction Service's RecordTransaction.
// Inside the holding service's WithTx, the Service's runInTx join-existing-tx
// semantics enlist RecordTransaction's writes in that outer tx — the trade and
// its cash legs commit or roll back together. Returns the new transaction's ID.
//
// An empty Entries list is rejected up front (the transaction service's domain
// validator would reject it anyway, but failing here yields a clearer error
// from the holding-side call site).
func (a *TradeCashRecorderAdapter) Record(ctx context.Context, req holdingdomain.TradeCashRecordRequest) (uuid.UUID, error) {
	if len(req.Entries) == 0 {
		return uuid.Nil, fmt.Errorf("trade cash record: entries empty")
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
		return uuid.Nil, fmt.Errorf("trade cash record: create transaction: %w", err)
	}
	return dto.ID, nil
}
