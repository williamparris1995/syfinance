package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// TradeCashEntry is one leg of the cash-side double-entry pair written for a
// holding trade (buy or sell). Holding owns this DTO so the holding application
// service can shape the cash record without importing the transaction module
// (mirrors template/domain.RecordRequest's role in the
// TransactionRecorderAdapter port pattern). The transaction application's
// adapter maps each TradeCashEntry to its own EntryInput before delegating to
// transaction.Service.RecordTransaction.
type TradeCashEntry struct {
	// AccountID is the account the leg posts to (cash from-account on one leg,
	// holding investment account on the other).
	AccountID uuid.UUID
	// ChartOfAccountCode is the posting account's chart code (e.g. "1001" for
	// cash, "1511" for investments) — the transaction service persists it on
	// the entry row so budget actuals and the ledger route correctly.
	ChartOfAccountCode string
	// DebitCents is the debit leg amount (in cents). A balanced record has
	// Σ(debit) == Σ(credit) across all entries.
	DebitCents int64
	// CreditCents is the credit leg amount (in cents).
	CreditCents int64
}

// TradeCashRecordRequest is the cash-side transaction the holding service asks
// the transaction module to record for a buy/sell, inside the same sqltx.WithTx
// as the holding/trade/lot writes (so the trade is atomic with the cash move).
type TradeCashRecordRequest struct {
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []TradeCashEntry
}

// TradeCashRecorder is the cross-module port the holding application service
// uses to write the cash side of a holding trade. The transaction application
// service's adapter implements it (maps each TradeCashEntry to a transaction
// EntryInput, then calls transaction.Service.RecordTransaction — which via
// Task 4's runInTx join-existing-tx semantics enlists in the outer holding
// WithTx). Holding/domain owns the port so holding never imports transaction,
// mirroring backup TenantDataPort + template TransactionRecorder.
type TradeCashRecorder interface {
	// Record persists a double-entry transaction for the cash side of a trade
	// and returns its ID. Must be invoked from within the holding service's
	// sqltx.WithTx so the writes share one DB transaction.
	Record(ctx context.Context, req TradeCashRecordRequest) (uuid.UUID, error)
}
