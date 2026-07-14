package application

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	templatedomain "github.com/yucai/server/internal/template/domain"
)

// fakeSimpleCreator is a test double for simpleTransactionCreator. It records
// which Simple* method ran and with what request, then returns the configured
// returnID (or returnErr). Only the one method the adapter is expected to call
// for a given direction increments its counter; the test asserts the others
// stayed at zero to catch mis-routing.
type fakeSimpleCreator struct {
	expenseCalled  int
	expenseReq     SimpleExpenseRequest
	incomeCalled   int
	incomeReq      SimpleIncomeRequest
	transferCalled int
	transferReq    SimpleTransferRequest
	returnID       uuid.UUID
	returnErr      error
}

func (f *fakeSimpleCreator) SimpleExpense(_ context.Context, req SimpleExpenseRequest) (*TransactionDTO, error) {
	f.expenseCalled++
	f.expenseReq = req
	if f.returnErr != nil {
		return nil, f.returnErr
	}
	return &TransactionDTO{ID: f.returnID}, nil
}

func (f *fakeSimpleCreator) SimpleIncome(_ context.Context, req SimpleIncomeRequest) (*TransactionDTO, error) {
	f.incomeCalled++
	f.incomeReq = req
	if f.returnErr != nil {
		return nil, f.returnErr
	}
	return &TransactionDTO{ID: f.returnID}, nil
}

func (f *fakeSimpleCreator) SimpleTransfer(_ context.Context, req SimpleTransferRequest) (*TransactionDTO, error) {
	f.transferCalled++
	f.transferReq = req
	if f.returnErr != nil {
		return nil, f.returnErr
	}
	return &TransactionDTO{ID: f.returnID}, nil
}

func newAdapter(fake *fakeSimpleCreator) *TransactionRecorderAdapter {
	return NewTransactionRecorderAdapter(fake)
}

func TestTransactionRecorderAdapter_ExpenseMapping(t *testing.T) {
	categoryID := uuid.New()
	sourceID := uuid.New()
	tenantID := uuid.New()
	wantTxn := uuid.New()
	date := time.Date(2026, 7, 14, 0, 0, 0, 0, time.UTC)

	fake := &fakeSimpleCreator{returnID: wantTxn}
	a := newAdapter(fake)

	got, err := a.Record(context.Background(), tenantID, templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionExpense,
		AmountCents:     5000,
		SourceAccountID: sourceID,
		Category:        categoryID.String(),
		Date:            date,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != wantTxn {
		t.Errorf("returned txn id: want %s, got %s", wantTxn, got)
	}
	if fake.expenseCalled != 1 {
		t.Fatalf("SimpleExpense call count: want 1, got %d", fake.expenseCalled)
	}
	if fake.incomeCalled != 0 || fake.transferCalled != 0 {
		t.Errorf("expense must not call income/transfer (income=%d transfer=%d)", fake.incomeCalled, fake.transferCalled)
	}
	// EXPENSE: debit expense(category) + credit asset(source).
	if fake.expenseReq.ExpenseAccountID != categoryID {
		t.Errorf("ExpenseAccountID: want %s, got %s", categoryID, fake.expenseReq.ExpenseAccountID)
	}
	if fake.expenseReq.AssetAccountID != sourceID {
		t.Errorf("AssetAccountID (source): want %s, got %s", sourceID, fake.expenseReq.AssetAccountID)
	}
	if fake.expenseReq.AmountCents != 5000 {
		t.Errorf("AmountCents: want 5000, got %d", fake.expenseReq.AmountCents)
	}
	if fake.expenseReq.TenantID != tenantID {
		t.Errorf("TenantID: want %s, got %s", tenantID, fake.expenseReq.TenantID)
	}
	if !fake.expenseReq.TransactionDate.Equal(date) {
		t.Errorf("TransactionDate: want %s, got %s", date, fake.expenseReq.TransactionDate)
	}
}

func TestTransactionRecorderAdapter_IncomeMapping(t *testing.T) {
	categoryID := uuid.New()
	sourceID := uuid.New()
	tenantID := uuid.New()
	wantTxn := uuid.New()
	date := time.Date(2026, 7, 14, 0, 0, 0, 0, time.UTC)

	fake := &fakeSimpleCreator{returnID: wantTxn}
	a := newAdapter(fake)

	got, err := a.Record(context.Background(), tenantID, templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionIncome,
		AmountCents:     7500,
		SourceAccountID: sourceID,
		Category:        categoryID.String(),
		Date:            date,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != wantTxn {
		t.Errorf("returned txn id: want %s, got %s", wantTxn, got)
	}
	if fake.incomeCalled != 1 {
		t.Fatalf("SimpleIncome call count: want 1, got %d", fake.incomeCalled)
	}
	if fake.expenseCalled != 0 || fake.transferCalled != 0 {
		t.Errorf("income must not call expense/transfer (expense=%d transfer=%d)", fake.expenseCalled, fake.transferCalled)
	}
	// INCOME: debit asset(source) + credit income(category).
	if fake.incomeReq.IncomeAccountID != categoryID {
		t.Errorf("IncomeAccountID: want %s, got %s", categoryID, fake.incomeReq.IncomeAccountID)
	}
	if fake.incomeReq.AssetAccountID != sourceID {
		t.Errorf("AssetAccountID (source): want %s, got %s", sourceID, fake.incomeReq.AssetAccountID)
	}
	if fake.incomeReq.AmountCents != 7500 {
		t.Errorf("AmountCents: want 7500, got %d", fake.incomeReq.AmountCents)
	}
	if fake.incomeReq.TenantID != tenantID {
		t.Errorf("TenantID: want %s, got %s", tenantID, fake.incomeReq.TenantID)
	}
}

func TestTransactionRecorderAdapter_TransferMapping(t *testing.T) {
	sourceID := uuid.New()
	destID := uuid.New()
	tenantID := uuid.New()
	wantTxn := uuid.New()
	date := time.Date(2026, 7, 14, 0, 0, 0, 0, time.UTC)

	fake := &fakeSimpleCreator{returnID: wantTxn}
	a := newAdapter(fake)

	got, err := a.Record(context.Background(), tenantID, templatedomain.RecordRequest{
		Direction:          templatedomain.DirectionTransfer,
		AmountCents:        3000,
		SourceAccountID:    sourceID,
		DestinationAccount: &destID,
		Date:               date,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != wantTxn {
		t.Errorf("returned txn id: want %s, got %s", wantTxn, got)
	}
	if fake.transferCalled != 1 {
		t.Fatalf("SimpleTransfer call count: want 1, got %d", fake.transferCalled)
	}
	if fake.expenseCalled != 0 || fake.incomeCalled != 0 {
		t.Errorf("transfer must not call expense/income (expense=%d income=%d)", fake.expenseCalled, fake.incomeCalled)
	}
	// TRANSFER: debit dest + credit source → FromAccountID=source, ToAccountID=dest.
	if fake.transferReq.FromAccountID != sourceID {
		t.Errorf("FromAccountID (source): want %s, got %s", sourceID, fake.transferReq.FromAccountID)
	}
	if fake.transferReq.ToAccountID != destID {
		t.Errorf("ToAccountID (dest): want %s, got %s", destID, fake.transferReq.ToAccountID)
	}
	if fake.transferReq.AmountCents != 3000 {
		t.Errorf("AmountCents: want 3000, got %d", fake.transferReq.AmountCents)
	}
	if fake.transferReq.TenantID != tenantID {
		t.Errorf("TenantID: want %s, got %s", tenantID, fake.transferReq.TenantID)
	}
}

func TestTransactionRecorderAdapter_UnspecifiedDirectionErrors(t *testing.T) {
	fake := &fakeSimpleCreator{returnID: uuid.New()}
	a := newAdapter(fake)

	_, err := a.Record(context.Background(), uuid.New(), templatedomain.RecordRequest{
		Direction:   0, // unspecified / zero value
		AmountCents: 100,
	})
	if err == nil {
		t.Fatal("expected error for unspecified direction, got nil")
	}
	if fake.expenseCalled != 0 || fake.incomeCalled != 0 || fake.transferCalled != 0 {
		t.Errorf("unspecified direction must not call any Service method (expense=%d income=%d transfer=%d)",
			fake.expenseCalled, fake.incomeCalled, fake.transferCalled)
	}
}

func TestTransactionRecorderAdapter_TransferMissingDestinationErrors(t *testing.T) {
	fake := &fakeSimpleCreator{returnID: uuid.New()}
	a := newAdapter(fake)

	_, err := a.Record(context.Background(), uuid.New(), templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionTransfer,
		AmountCents:     3000,
		SourceAccountID: uuid.New(),
		// DestinationAccount intentionally nil
	})
	if err == nil {
		t.Fatal("expected error for transfer with nil destination, got nil")
	}
	if fake.transferCalled != 0 {
		t.Errorf("must not call SimpleTransfer when destination missing, got %d calls", fake.transferCalled)
	}
}

func TestTransactionRecorderAdapter_ExpenseBadCategoryErrors(t *testing.T) {
	fake := &fakeSimpleCreator{returnID: uuid.New()}
	a := newAdapter(fake)

	_, err := a.Record(context.Background(), uuid.New(), templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionExpense,
		AmountCents:     5000,
		SourceAccountID: uuid.New(),
		Category:        "not-a-uuid",
	})
	if err == nil {
		t.Fatal("expected error for unparseable category, got nil")
	}
	if fake.expenseCalled != 0 {
		t.Errorf("must not call SimpleExpense when category is unparseable, got %d calls", fake.expenseCalled)
	}
}

func TestTransactionRecorderAdapter_IncomeBadCategoryErrors(t *testing.T) {
	fake := &fakeSimpleCreator{returnID: uuid.New()}
	a := newAdapter(fake)

	_, err := a.Record(context.Background(), uuid.New(), templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionIncome,
		AmountCents:     5000,
		SourceAccountID: uuid.New(),
		Category:        "groceries",
	})
	if err == nil {
		t.Fatal("expected error for unparseable category, got nil")
	}
	if fake.incomeCalled != 0 {
		t.Errorf("must not call SimpleIncome when category is unparseable, got %d calls", fake.incomeCalled)
	}
}

func TestTransactionRecorderAdapter_ServiceErrorPropagates(t *testing.T) {
	svcErr := errors.New("boom: insufficient balance")
	fake := &fakeSimpleCreator{returnErr: svcErr}
	a := newAdapter(fake)

	_, err := a.Record(context.Background(), uuid.New(), templatedomain.RecordRequest{
		Direction:       templatedomain.DirectionExpense,
		AmountCents:     5000,
		SourceAccountID: uuid.New(),
		Category:        uuid.New().String(),
	})
	if err == nil {
		t.Fatal("expected propagated error, got nil")
	}
	if !errors.Is(err, svcErr) {
		t.Errorf("expected error to wrap %v, got %v", svcErr, err)
	}
}
