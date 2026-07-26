package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// RepaymentCashEntry is one leg of the cash-side double-entry pair written for
// a debt repayment. Debt owns this DTO so the debt application service can
// shape the cash record without importing the transaction module (mirrors
// holding/domain.TradeCashEntry's role in the TradeCashRecorder port pattern).
// The transaction application's adapter maps each RepaymentCashEntry to its own
// EntryInput before delegating to transaction.Service.RecordTransaction.
type RepaymentCashEntry struct {
	// AccountID is the account the leg posts to (cash from-account on one leg,
	// the debt's liability/receivable account on the other).
	AccountID uuid.UUID
	// ChartOfAccountCode is the posting account's chart code (e.g. "1001" for
	// cash, "2202" for a liability) — the transaction service persists it on
	// the entry row so budget actuals and the ledger route correctly.
	ChartOfAccountCode string
	// DebitCents is the debit leg amount (in cents). A balanced record has
	// Σ(debit) == Σ(credit) across all entries.
	DebitCents int64
	// CreditCents is the credit leg amount (in cents).
	CreditCents int64
}

// RepaymentCashRecordRequest is the cash-side transaction the debt service
// asks the transaction module to record for a repayment, inside the same
// sqltx.WithTx as the schedule.Paid + principal persist (so the repayment is
// atomic with the cash move). Mirrors holding/domain.TradeCashRecordRequest.
type RepaymentCashRecordRequest struct {
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []RepaymentCashEntry
}

// RepaymentCashRecorder is the cross-module port the debt application service
// uses to write the cash side of a repayment. The transaction application
// service's adapter implements it (maps each RepaymentCashEntry to a
// transaction EntryInput, then calls transaction.Service.RecordTransaction —
// which via Task 4's runInTx join-existing-tx semantics enlists in the outer
// debt WithTx). Debt/domain owns the port so debt never imports transaction,
// mirroring backup TenantDataPort + template TransactionRecorder + holding
// TradeCashRecorder.
type RepaymentCashRecorder interface {
	// Record persists a double-entry transaction for the cash side of a debt
	// repayment and returns its ID. Must be invoked from within the debt
	// service's sqltx.WithTx so the writes share one DB transaction.
	Record(ctx context.Context, req RepaymentCashRecordRequest) (uuid.UUID, error)
}
