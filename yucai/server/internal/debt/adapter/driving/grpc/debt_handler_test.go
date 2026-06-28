package grpc

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
	pb "github.com/yucai/server/internal/proto/debt/v1"
	txnApp "github.com/yucai/server/internal/transaction/application"
	txnDomain "github.com/yucai/server/internal/transaction/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// TestProtoDebtTypeMapping verifies the NAME-BASED mapping between the proto
// DebtType enum and the domain DebtType enum (not by numeric coincidence).
func TestProtoDebtTypeMapping(t *testing.T) {
	cases := []struct {
		proto pb.DebtType
		dom   domain.DebtType
	}{
		{pb.DebtType_DEBT_TYPE_BORROWED_IN, domain.BorrowedIn},
		{pb.DebtType_DEBT_TYPE_BORROWED_OUT, domain.BorrowedOut},
		// UNSPECIFIED / unknown resolve to BorrowedIn (matches ent default).
		{pb.DebtType_DEBT_TYPE_UNSPECIFIED, domain.BorrowedIn},
	}
	for _, c := range cases {
		if got := protoToDebtType(c.proto); got != c.dom {
			t.Errorf("protoToDebtType(%v) = %v, want %v", c.proto, got, c.dom)
		}
	}

	// Reverse direction: domain -> proto.
	for _, c := range cases {
		// UNSPECIFIED is not a distinct proto value; skip it for the reverse check.
		if c.proto == pb.DebtType_DEBT_TYPE_UNSPECIFIED {
			continue
		}
		if got := debtTypeToProto(c.dom); got != c.proto {
			t.Errorf("debtTypeToProto(%v) = %v, want %v", c.dom, got, c.proto)
		}
	}

	// Domain unspecified maps to BORROWED_IN on the way out.
	if got := debtTypeToProto(domain.DebtTypeUnspecified); got != pb.DebtType_DEBT_TYPE_BORROWED_IN {
		t.Errorf("debtTypeToProto(Unspecified) = %v, want BORROWED_IN", got)
	}
}

// TestDebtToProto_EmitsDebtType checks debtToProto carries the DebtType through.
func TestDebtToProto_EmitsDebtType(t *testing.T) {
	dto := application.DebtDTO{DebtType: domain.BorrowedOut}
	p := debtToProto(dto)
	if p.DebtType != pb.DebtType_DEBT_TYPE_BORROWED_OUT {
		t.Errorf("debtToProto DebtType = %v, want BORROWED_OUT", p.DebtType)
	}

	dto.DebtType = domain.BorrowedIn
	p = debtToProto(dto)
	if p.DebtType != pb.DebtType_DEBT_TYPE_BORROWED_IN {
		t.Errorf("debtToProto DebtType = %v, want BORROWED_IN", p.DebtType)
	}
}

// TestDebtToProto_EmitsSubtype verifies debtToProto carries the Subtype string
// through verbatim (no enum mapping — unlike DebtType).
func TestDebtToProto_EmitsSubtype(t *testing.T) {
	for _, tc := range []struct {
		name    string
		subtype string
	}{
		{"empty", ""},
		{"mortgage_const", domain.DebtSubtypeMortgage},
		{"auto_loan_const", domain.DebtSubtypeAutoLoan},
		{"credit_card_const", domain.DebtSubtypeCreditCard},
		{"receivable_personal", domain.ReceivableSubtypePersonal},
		{"unknown_custom", "custom_value"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dto := application.DebtDTO{Subtype: tc.subtype}
			p := debtToProto(dto)
			if p.Subtype != tc.subtype {
				t.Errorf("debtToProto Subtype = %q, want %q", p.Subtype, tc.subtype)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// RecordPayment double-write tests (credit-card-sync Task 2)
// ---------------------------------------------------------------------------

// fakeDebtRepo is an in-memory DebtRepository for handler-level tests. It
// stores one debt by ID and supports the Save/FindByID/Update path used by
// application.Service.RecordPayment + GetDebt. Other methods panic.
type fakeDebtRepo struct {
	byID map[uuid.UUID]*domain.DebtDetails
}

func newFakeDebtRepo() *fakeDebtRepo {
	return &fakeDebtRepo{byID: make(map[uuid.UUID]*domain.DebtDetails)}
}

func (r *fakeDebtRepo) Save(_ context.Context, d *domain.DebtDetails) error {
	c := *d
	r.byID[d.ID] = &c
	return nil
}

func (r *fakeDebtRepo) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*domain.DebtDetails, error) {
	d, ok := r.byID[id]
	if !ok {
		return nil, fmt.Errorf("debt %s not found", id)
	}
	c := *d
	return &c, nil
}

func (r *fakeDebtRepo) Update(_ context.Context, d *domain.DebtDetails) error {
	c := *d
	r.byID[d.ID] = &c
	return nil
}

func (r *fakeDebtRepo) Delete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected Delete call")
}
func (r *fakeDebtRepo) FindAll(context.Context, uuid.UUID, domain.PageRequest, *domain.DebtType) (*domain.PaginatedResult[domain.DebtDetails], error) {
	panic("unexpected FindAll call")
}
func (r *fakeDebtRepo) FindUpcomingPayments(context.Context, uuid.UUID, int) ([]domain.PaymentScheduleEntry, error) {
	panic("unexpected FindUpcomingPayments call")
}

// fakeAccountLookup implements txnApp.AccountLookup and returns copies of
// seeded accounts so the balance updater can mutate independent copies.
type fakeAccountLookup struct {
	byID map[uuid.UUID]*accountdomain.Account
}

func newFakeAccountLookup() *fakeAccountLookup {
	return &fakeAccountLookup{byID: make(map[uuid.UUID]*accountdomain.Account)}
}

func (l *fakeAccountLookup) seed(a *accountdomain.Account) {
	c := *a
	l.byID[a.ID] = &c
}

func (l *fakeAccountLookup) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*accountdomain.Account, error) {
	a, ok := l.byID[id]
	if !ok {
		return nil, fmt.Errorf("account %s not found", id)
	}
	c := *a
	return &c, nil
}

// recordingTxnRepo records the most recent saved transaction so the test can
// assert the entries built by buildPaymentEntries flowed through unchanged.
type recordingTxnRepo struct {
	saved *txnDomain.Transaction
}

func (r *recordingTxnRepo) Save(_ context.Context, t *txnDomain.Transaction) error {
	c := *t
	r.saved = &c
	return nil
}
func (r *recordingTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*txnDomain.Transaction, error) {
	panic("unexpected FindByID call")
}
func (r *recordingTxnRepo) FindAll(context.Context, uuid.UUID, txnDomain.TransactionFilter, txnDomain.PageRequest) (*txnDomain.PaginatedResult[txnDomain.Transaction], error) {
	panic("unexpected FindAll call")
}
func (r *recordingTxnRepo) FindRecentByAccount(context.Context, uuid.UUID, uuid.UUID, int) ([]txnDomain.Transaction, error) {
	panic("unexpected FindRecentByAccount call")
}
func (r *recordingTxnRepo) Update(context.Context, *txnDomain.Transaction) error {
	panic("unexpected Update call")
}
func (r *recordingTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}
func (r *recordingTxnRepo) TransactionSummary(context.Context, txnDomain.SummaryScope) (*txnDomain.MonthlySummary, error) {
	panic("unexpected TransactionSummary call")
}

// mutatingBalanceUpdater applies each entry's (debit - credit) to the matching
// account in the lookup so tests can assert balance movement end-to-end.
type mutatingBalanceUpdater struct {
	lookup *fakeAccountLookup
}

func (u mutatingBalanceUpdater) UpdateBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		a, ok := u.lookup.byID[e.AccountID]
		if !ok {
			continue // ignore unknown accounts (best-effort in test)
		}
		a.CurrentBalanceCents += e.DebitCents - e.CreditCents
	}
	return nil
}

func (u mutatingBalanceUpdater) ReverseBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		a, ok := u.lookup.byID[e.AccountID]
		if !ok {
			continue
		}
		a.CurrentBalanceCents -= e.DebitCents - e.CreditCents
	}
	return nil
}

// setupRecordPaymentHarness wires a DebtHandler with a fake debt repo (one
// seeded debt of the given type), a fake account lookup (from-account + the
// debt's liability/receivable account), and a real transaction service backed
// by a recording repo + mutating balance updater. Returns every handle the
// tests need to drive RecordPayment and assert on post-state.
func setupRecordPaymentHarness(t *testing.T, debtType domain.DebtType) (
	h *DebtHandler,
	tenantID, debtID, fromAccID, debtAccID, entryID uuid.UUID,
	txnRepo *recordingTxnRepo,
	accLookup *fakeAccountLookup,
) {
	t.Helper()
	tenantID = uuid.New()

	debtAcc, err := accountdomain.NewAccount(tenantID, "loan/receivable account", accountdomain.AccountTypeLiability, "CNY")
	if err != nil {
		t.Fatalf("seed debt account: %v", err)
	}
	debtAcc.ChartCode = "2202" // liability-ish chart code placeholder
	debtAccID = debtAcc.ID

	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	due := time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC)
	debt, err := domain.NewDebtDetails(tenantID, debtAccID, "counterparty", 5.0,
		domain.AmortizationLumpSum, start, due, 1_000_00, debtType, "")
	if err != nil {
		t.Fatalf("seed debt: %v", err)
	}
	debt.GenerateSchedule()
	if len(debt.Schedule) == 0 {
		t.Fatalf("seed debt: schedule empty")
	}
	debtID = debt.ID
	entryID = debt.Schedule[0].ID

	debtRepo := newFakeDebtRepo()
	if err := debtRepo.Save(context.Background(), debt); err != nil {
		t.Fatalf("seed debt repo: %v", err)
	}

	fromAcc, err := accountdomain.NewAccount(tenantID, "cash account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed from account: %v", err)
	}
	fromAcc.ChartCode = "1001" // asset chart code placeholder
	fromAcc.CurrentBalanceCents = 10_000_00
	fromAccID = fromAcc.ID

	accLookup = newFakeAccountLookup()
	accLookup.seed(fromAcc)
	accLookup.seed(debtAcc)

	txnRepo = &recordingTxnRepo{}
	txnSvc := txnApp.NewService(txnRepo, accLookup, mutatingBalanceUpdater{lookup: accLookup})

	debtSvc := application.NewService(debtRepo)
	h = NewDebtHandler(debtSvc, txnSvc, accLookup)
	return
}

// ctxWithTenant builds a context carrying both user_id and tenant_id, matching
// what the auth interceptor injects in production.
func ctxWithTenant(tenantID uuid.UUID) context.Context {
	ctx := authgrpc.WithTenantID(context.Background(), tenantID)
	return authgrpc.WithUserID(ctx, uuid.New())
}

// entryPair pulls the two entries (order-independent) for the given accounts.
func entryPair(txn *txnDomain.Transaction, fromAccID, debtAccID uuid.UUID) (from, debt txnDomain.TransactionEntry) {
	for _, e := range txn.Entries {
		switch e.AccountID {
		case fromAccID:
			from = e
		case debtAccID:
			debt = e
		}
	}
	return
}

// TestRecordPayment_BorrowedIn verifies the borrowedIn path: the schedule entry
// is marked paid AND a balancing transaction is created crediting from_account
// (asset -) and debiting debt.account_id (liability -), with both account
// balances moving accordingly.
func TestRecordPayment_BorrowedIn(t *testing.T) {
	h, tenantID, debtID, fromAccID, debtAccID, entryID, txnRepo, accLookup :=
		setupRecordPaymentHarness(t, domain.BorrowedIn)

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   fromAccID.String(),
	})
	if err != nil {
		t.Fatalf("RecordPayment: %v", err)
	}
	if resp.TransactionId == "" {
		t.Fatal("RecordPayment returned empty transaction_id")
	}

	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	fromEntry, debtEntry := entryPair(txnRepo.saved, fromAccID, debtAccID)
	if fromEntry.CreditCents == 0 || fromEntry.DebitCents != 0 {
		t.Errorf("borrowedIn from_account entry: expected credit only, got debit=%d credit=%d",
			fromEntry.DebitCents, fromEntry.CreditCents)
	}
	if debtEntry.DebitCents == 0 || debtEntry.CreditCents != 0 {
		t.Errorf("borrowedIn debt_account entry: expected debit only, got debit=%d credit=%d",
			debtEntry.DebitCents, debtEntry.CreditCents)
	}
	if fromEntry.CreditCents != debtEntry.DebitCents {
		t.Errorf("borrowedIn: unbalanced entries credit=%d debit=%d",
			fromEntry.CreditCents, debtEntry.DebitCents)
	}
	// Chart codes carried through from the accounts.
	if fromEntry.ChartOfAccountCode != "1001" {
		t.Errorf("from_account chart code: got %q, want 1001", fromEntry.ChartOfAccountCode)
	}
	if debtEntry.ChartOfAccountCode != "2202" {
		t.Errorf("debt_account chart code: got %q, want 2202", debtEntry.ChartOfAccountCode)
	}

	// Balances moved: from_account (asset) decreased by the payment amount;
	// the liability account received a debit (raw balance += debit), which in
	// double-entry terms reduces a credit-normal liability.
	const fromBefore int64 = 10_000_00
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != fromBefore-fromEntry.CreditCents {
		t.Errorf("from_account balance: got %d, want %d", got, fromBefore-fromEntry.CreditCents)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != debtEntry.DebitCents {
		t.Errorf("debt_account balance: got %d, want %d (debit applied to liability)",
			got, debtEntry.DebitCents)
	}
}

// TestRecordPayment_BorrowedOut creates the balancing transaction with the
// entries flipped (debit from_account, credit debt.account_id) and moves both
// balances in the opposite direction.
func TestRecordPayment_BorrowedOut(t *testing.T) {
	h, tenantID, debtID, fromAccID, debtAccID, entryID, txnRepo, accLookup :=
		setupRecordPaymentHarness(t, domain.BorrowedOut)

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   fromAccID.String(),
	})
	if err != nil {
		t.Fatalf("RecordPayment: %v", err)
	}
	if resp.TransactionId == "" {
		t.Fatal("RecordPayment returned empty transaction_id")
	}

	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	fromEntry, debtEntry := entryPair(txnRepo.saved, fromAccID, debtAccID)
	if fromEntry.DebitCents == 0 || fromEntry.CreditCents != 0 {
		t.Errorf("borrowedOut from_account entry: expected debit only, got debit=%d credit=%d",
			fromEntry.DebitCents, fromEntry.CreditCents)
	}
	if debtEntry.CreditCents == 0 || debtEntry.DebitCents != 0 {
		t.Errorf("borrowedOut debt_account entry: expected credit only, got debit=%d credit=%d",
			debtEntry.DebitCents, debtEntry.CreditCents)
	}
	if fromEntry.DebitCents != debtEntry.CreditCents {
		t.Errorf("borrowedOut: unbalanced entries debit=%d credit=%d",
			fromEntry.DebitCents, debtEntry.CreditCents)
	}

	// Balances moved: from_account (asset, collecting receivable) increased;
	// the receivable account (starts at 0) went negative, indicating reduction.
	const fromBefore int64 = 10_000_00
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != fromBefore+fromEntry.DebitCents {
		t.Errorf("from_account balance: got %d, want %d", got, fromBefore+fromEntry.DebitCents)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != -debtEntry.CreditCents {
		t.Errorf("debt_account balance: got %d, want %d", got, -debtEntry.CreditCents)
	}
}

// TestRecordPayment_BestEffortTxnFailureSwallowed confirms that when the
// transaction write fails AFTER the debt is already marked paid, RecordPayment
// still returns success (debt stays paid) — the transaction error is logged,
// not surfaced. Task 3 will refine failure handling.
func TestRecordPayment_BestEffortTxnFailureSwallowed(t *testing.T) {
	h, tenantID, debtID, fromAccID, _, entryID, _, _ :=
		setupRecordPaymentHarness(t, domain.BorrowedIn)

	// Inject a transaction-write failure by swapping in a txn repo whose Save
	// always errors. We rebuild the transaction service with the failing repo
	// but keep the same handler wiring (debt service + account lookup).
	failingRepo := &failingTxnRepo{err: fmt.Errorf("simulated txn write failure")}
	txnSvc := txnApp.NewService(failingRepo, h.accountLookup, mutatingBalanceUpdater{lookup: h.accountLookup.(*fakeAccountLookup)})
	h.transactionSvc = txnSvc

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   fromAccID.String(),
	})
	if err != nil {
		t.Fatalf("RecordPayment should swallow best-effort txn failure, got: %v", err)
	}
	if resp.TransactionId == "" {
		t.Fatal("RecordPayment returned empty transaction_id (debt-side txn id should still be set)")
	}
	if !resp.Entry.Paid {
		t.Error("debt schedule entry should be marked paid despite txn write failure")
	}
}

// failingTxnRepo is a TransactionRepository whose Save always returns an error.
type failingTxnRepo struct{ err error }

func (r *failingTxnRepo) Save(context.Context, *txnDomain.Transaction) error { return r.err }
func (r *failingTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*txnDomain.Transaction, error) {
	panic("unexpected FindByID call")
}
func (r *failingTxnRepo) FindAll(context.Context, uuid.UUID, txnDomain.TransactionFilter, txnDomain.PageRequest) (*txnDomain.PaginatedResult[txnDomain.Transaction], error) {
	panic("unexpected FindAll call")
}
func (r *failingTxnRepo) FindRecentByAccount(context.Context, uuid.UUID, uuid.UUID, int) ([]txnDomain.Transaction, error) {
	panic("unexpected FindRecentByAccount call")
}
func (r *failingTxnRepo) Update(context.Context, *txnDomain.Transaction) error {
	panic("unexpected Update call")
}
func (r *failingTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}
func (r *failingTxnRepo) TransactionSummary(context.Context, txnDomain.SummaryScope) (*txnDomain.MonthlySummary, error) {
	panic("unexpected TransactionSummary call")
}

// ---------------------------------------------------------------------------
// RecordPayment validation tests (credit-card-sync Task 3)
//
// Validation runs BEFORE the debt is marked paid, so an invalid from_account
// fails fast and the debt schedule entry stays unpaid. Each test asserts both
// the gRPC error code AND that the entry remained unpaid (fail-fast invariant).
// ---------------------------------------------------------------------------

// requireNotPaid fetches the debt detail and fails the test if the seeded
// schedule entry has been marked paid — used to assert the fail-fast invariant.
func requireNotPaid(t *testing.T, h *DebtHandler, tenantID, debtID, entryID uuid.UUID) {
	t.Helper()
	detail, err := h.service.GetDebt(context.Background(), tenantID, debtID)
	if err != nil {
		t.Fatalf("verify unpaid: GetDebt: %v", err)
	}
	for _, e := range detail.Schedule {
		if e.ID == entryID && e.Paid {
			t.Fatal("fail-fast invariant violated: entry was marked paid despite validation error")
		}
	}
}

// TestRecordPayment_NonAssetFromAccount_RejectsAndLeavesDebtUntouched: a
// from_account whose AccountType is not asset is rejected with InvalidArgument
// BEFORE the debt is marked paid.
func TestRecordPayment_NonAssetFromAccount_RejectsAndLeavesDebtUntouched(t *testing.T) {
	h, tenantID, debtID, _, _, entryID, txnRepo, accLookup :=
		setupRecordPaymentHarness(t, domain.BorrowedIn)

	// Replace the seeded asset from_account with a liability from_account by
	// seeding a new account under the same id slot is awkward; instead add a
	// fresh liability account and point the request at it.
	liabilityAcc, err := accountdomain.NewAccount(tenantID, "liability from", accountdomain.AccountTypeLiability, "CNY")
	if err != nil {
		t.Fatalf("seed liability account: %v", err)
	}
	liabilityAcc.ChartCode = "2202"
	liabilityAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(liabilityAcc)

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   liabilityAcc.ID.String(),
	})

	if err == nil {
		t.Fatal("RecordPayment should reject non-asset from_account, got nil error")
	}
	if resp != nil {
		t.Errorf("expected nil response on validation failure, got %+v", resp)
	}
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}

	// Fail-fast: no transaction written and the entry stays unpaid.
	if txnRepo.saved != nil {
		t.Error("no transaction should be written when validation fails")
	}
	requireNotPaid(t, h, tenantID, debtID, entryID)
}

// TestRecordPayment_BorrowedInInsufficientBalance_RejectsAndLeavesDebtUntouched:
// for a BorrowedIn repayment, a from_account whose balance is below the entry
// total is rejected with FailedPrecondition before the debt is marked paid.
func TestRecordPayment_BorrowedInInsufficientBalance_RejectsAndLeavesDebtUntouched(t *testing.T) {
	h, tenantID, debtID, fromAccID, _, entryID, txnRepo, accLookup :=
		setupRecordPaymentHarness(t, domain.BorrowedIn)

	// Drain the from_account balance below the entry total. The harness seeds
	// a lump-sum debt of 1000.00 principal + 5000.00 interest = 6000.00 total,
	// and a from_account balance of 10000.00. Drop it to 1000.00 (< 6000.00).
	accLookup.byID[fromAccID].CurrentBalanceCents = 1_000_00

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   fromAccID.String(),
	})

	if err == nil {
		t.Fatal("RecordPayment should reject insufficient balance, got nil error")
	}
	if resp != nil {
		t.Errorf("expected nil response on validation failure, got %+v", resp)
	}
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.FailedPrecondition {
		t.Errorf("error code: got %v, want FailedPrecondition", err)
	}

	if txnRepo.saved != nil {
		t.Error("no transaction should be written when validation fails")
	}
	requireNotPaid(t, h, tenantID, debtID, entryID)
}

// TestRecordPayment_CrossCurrency_RejectsAndLeavesDebtUntouched: a from_account
// whose currency differs from the debt account's currency is rejected with
// InvalidArgument before the debt is marked paid.
func TestRecordPayment_CrossCurrency_RejectsAndLeavesDebtUntouched(t *testing.T) {
	h, tenantID, debtID, _, _, entryID, txnRepo, accLookup :=
		setupRecordPaymentHarness(t, domain.BorrowedIn)

	// Seed an asset from_account in USD; the debt account is CNY (harness default).
	usdAcc, err := accountdomain.NewAccount(tenantID, "usd cash", accountdomain.AccountTypeAsset, "USD")
	if err != nil {
		t.Fatalf("seed usd account: %v", err)
	}
	usdAcc.ChartCode = "1001"
	usdAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(usdAcc)

	resp, err := h.RecordPayment(ctxWithTenant(tenantID), &pb.RecordPaymentRequest{
		DebtId:          debtID.String(),
		ScheduleEntryId: entryID.String(),
		FromAccountId:   usdAcc.ID.String(),
	})

	if err == nil {
		t.Fatal("RecordPayment should reject cross-currency, got nil error")
	}
	if resp != nil {
		t.Errorf("expected nil response on validation failure, got %+v", resp)
	}
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}

	if txnRepo.saved != nil {
		t.Error("no transaction should be written when validation fails")
	}
	requireNotPaid(t, h, tenantID, debtID, entryID)
}
