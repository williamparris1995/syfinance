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

// FindAll returns every stored debt for the tenant, optionally filtered by
// DebtType. Used by GetReceivablesSummary (which fetches BorrowedOut only).
// Implemented as a real scan (not panic) so the summary handler test can drive
// the real application Service end-to-end without a separate fake.
func (r *fakeDebtRepo) FindAll(_ context.Context, tenantID uuid.UUID, _ domain.PageRequest, typeFilter *domain.DebtType) (*domain.PaginatedResult[domain.DebtDetails], error) {
	out := &domain.PaginatedResult[domain.DebtDetails]{}
	for _, d := range r.byID {
		if d.TenantID != tenantID {
			continue
		}
		if typeFilter != nil && d.DebtType != *typeFilter {
			continue
		}
		c := *d
		out.Items = append(out.Items, c)
	}
	out.TotalCount = int32(len(out.Items))
	return out, nil
}
func (r *fakeDebtRepo) FindUpcomingPayments(context.Context, uuid.UUID, int) ([]domain.PaymentScheduleEntry, error) {
	panic("unexpected FindUpcomingPayments call")
}
func (r *fakeDebtRepo) FindAllForBackup(context.Context, uuid.UUID) ([]domain.DebtDetails, error) {
	panic("unexpected FindAllForBackup call")
}
func (r *fakeDebtRepo) DeleteByTenant(context.Context, uuid.UUID) error {
	panic("unexpected DeleteByTenant call")
}

// fakeDebtSnapshotRepo is an in-memory DebtSnapshotRepository used by the
// GetReceivablesSummary handler test to seed month-pair snapshots and assert
// the trend flows through. FindLatestByDebt is not exercised by the summary
// path; SaveSnapshot stores but is unused for the read-only summary test.
type fakeDebtSnapshotRepo struct {
	rangeOut map[uuid.UUID][]domain.DebtProgressSnapshot
}

func newFakeDebtSnapshotRepo() *fakeDebtSnapshotRepo {
	return &fakeDebtSnapshotRepo{rangeOut: make(map[uuid.UUID][]domain.DebtProgressSnapshot)}
}

func (r *fakeDebtSnapshotRepo) SaveSnapshot(_ context.Context, snap *domain.DebtProgressSnapshot) error {
	return nil
}
func (r *fakeDebtSnapshotRepo) FindLatestByDebt(context.Context, uuid.UUID, uuid.UUID, time.Time) (*domain.DebtProgressSnapshot, error) {
	panic("unexpected FindLatestByDebt call")
}
func (r *fakeDebtSnapshotRepo) FindSnapshotRange(_ context.Context, _ uuid.UUID, debtIDs []uuid.UUID, _, _ time.Time) ([]domain.DebtProgressSnapshot, error) {
	var out []domain.DebtProgressSnapshot
	for _, id := range debtIDs {
		out = append(out, r.rangeOut[id]...)
	}
	return out, nil
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
func (r *recordingTxnRepo) SumEntryTotalsByAccount(context.Context, uuid.UUID, time.Time, time.Time) (int64, int64, error) {
	panic("unexpected SumEntryTotalsByAccount call")
}
func (r *recordingTxnRepo) FindAllForBackup(context.Context, uuid.UUID) ([]txnDomain.Transaction, error) {
	panic("unexpected FindAllForBackup call")
}
func (r *recordingTxnRepo) DeleteByTenant(context.Context, uuid.UUID) error {
	panic("unexpected DeleteByTenant call")
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
		domain.AmortizationLumpSum, start, due, 1_000_00, debtType, "", "", "", nil)
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
func (r *failingTxnRepo) SumEntryTotalsByAccount(context.Context, uuid.UUID, time.Time, time.Time) (int64, int64, error) {
	panic("unexpected SumEntryTotalsByAccount call")
}
func (r *failingTxnRepo) FindAllForBackup(context.Context, uuid.UUID) ([]txnDomain.Transaction, error) {
	panic("unexpected FindAllForBackup call")
}
func (r *failingTxnRepo) DeleteByTenant(context.Context, uuid.UUID) error {
	panic("unexpected DeleteByTenant call")
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

// ---------------------------------------------------------------------------
// CreateDebt double-write tests (create-debt-dual-write)
// ---------------------------------------------------------------------------

// setupCreateDebtHarness wires a DebtHandler with empty debt repo, a fake
// account lookup seeding a receivable (debt) account [req.AccountId] + a cash
// source account [req.source_account_id], and a real transaction service
// backed by a recording repo + mutating balance updater. No debt is pre-seeded
// (CreateDebt creates it). Returns debtRepo so fail-fast tests can assert no
// debt was persisted.
func setupCreateDebtHarness(t *testing.T) (
	h *DebtHandler,
	tenantID, sourceAccID, debtAccID uuid.UUID,
	txnRepo *recordingTxnRepo,
	accLookup *fakeAccountLookup,
	debtRepo *fakeDebtRepo,
) {
	t.Helper()
	tenantID = uuid.New()

	// Receivable account = req.AccountId (asset / otherAsset).
	rcvAcc, err := accountdomain.NewAccount(tenantID, "receivable account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed receivable account: %v", err)
	}
	rcvAcc.ChartCode = "1122" // receivable-ish chart code placeholder
	debtAccID = rcvAcc.ID

	// Source account = req.source_account_id (cash asset), ample balance.
	srcAcc, err := accountdomain.NewAccount(tenantID, "cash account", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed source account: %v", err)
	}
	srcAcc.ChartCode = "1001"
	srcAcc.CurrentBalanceCents = 10_000_00
	sourceAccID = srcAcc.ID

	accLookup = newFakeAccountLookup()
	accLookup.seed(rcvAcc)
	accLookup.seed(srcAcc)

	debtRepo = newFakeDebtRepo()
	txnRepo = &recordingTxnRepo{}
	txnSvc := txnApp.NewService(txnRepo, accLookup, mutatingBalanceUpdater{lookup: accLookup})
	debtSvc := application.NewService(debtRepo)
	h = NewDebtHandler(debtSvc, txnSvc, accLookup)
	return
}

// TestCreateDebt_BorrowedOut_DoubleWrite: creating a borrowedOut debt records
// a balancing transaction crediting source (cash −) and debiting the receivable
// account (+principal), and both balances move accordingly.
func TestCreateDebt_BorrowedOut_DoubleWrite(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, _ :=
		setupCreateDebtHarness(t)

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(),
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
		Subtype:             domain.ReceivableSubtypePersonal,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("CreateDebt returned empty debt")
	}

	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	srcEntry, rcvEntry := entryPair(txnRepo.saved, sourceAccID, debtAccID)
	if srcEntry.CreditCents == 0 || srcEntry.DebitCents != 0 {
		t.Errorf("source entry: expected credit only, got debit=%d credit=%d",
			srcEntry.DebitCents, srcEntry.CreditCents)
	}
	if rcvEntry.DebitCents == 0 || rcvEntry.CreditCents != 0 {
		t.Errorf("receivable entry: expected debit only, got debit=%d credit=%d",
			rcvEntry.DebitCents, rcvEntry.CreditCents)
	}
	if srcEntry.CreditCents != rcvEntry.DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", srcEntry.CreditCents, rcvEntry.DebitCents)
	}
	if srcEntry.CreditCents != 1_000_00 {
		t.Errorf("amount: got %d, want 100000", srcEntry.CreditCents)
	}

	// Balances: source (cash) decreased by principal; receivable increased.
	const srcBefore int64 = 10_000_00
	if got := accLookup.byID[sourceAccID].CurrentBalanceCents; got != srcBefore-1_000_00 {
		t.Errorf("source balance: got %d, want %d", got, srcBefore-1_000_00)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != 1_000_00 {
		t.Errorf("receivable balance: got %d, want 100000", got)
	}
}

// TestCreateDebt_BorrowedIn_NoDoubleWrite: borrowedIn ignores the source
// (even when supplied) and records NO transaction — debt is created, balances
// untouched. borrowedIn balances are driven by consumption transactions.
func TestCreateDebt_BorrowedIn_NoDoubleWrite(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, _ :=
		setupCreateDebtHarness(t)

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(), // supplied but must be ignored
		Counterparty:        "银行",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_IN,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("CreateDebt returned empty debt")
	}
	if txnRepo.saved != nil {
		t.Error("borrowedIn must NOT create a transaction")
	}
	const srcBefore int64 = 10_000_00
	if got := accLookup.byID[sourceAccID].CurrentBalanceCents; got != srcBefore {
		t.Errorf("source balance must be unchanged: got %d, want %d", got, srcBefore)
	}
	if got := accLookup.byID[debtAccID].CurrentBalanceCents; got != 0 {
		t.Errorf("receivable balance must be unchanged: got %d, want 0", got)
	}
}

// TestCreateDebt_BestEffortTxnFailureSwallowed: when the transaction write
// fails AFTER the debt is created, CreateDebt still returns success — the
// error is logged, not surfaced.
func TestCreateDebt_BestEffortTxnFailureSwallowed(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, _, _, _ :=
		setupCreateDebtHarness(t)

	// Swap in a failing txn repo; keep the same handler wiring.
	failingRepo := &failingTxnRepo{err: fmt.Errorf("simulated txn write failure")}
	h.transactionSvc = txnApp.NewService(failingRepo, h.accountLookup, mutatingBalanceUpdater{lookup: h.accountLookup.(*fakeAccountLookup)})

	resp, err := h.CreateDebt(ctxWithTenant(tenantID), &pb.CreateDebtRequest{
		AccountId:           debtAccID.String(),
		SourceAccountId:     sourceAccID.String(),
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
	})
	if err != nil {
		t.Fatalf("CreateDebt should swallow best-effort txn failure, got: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("debt should still be created despite txn write failure")
	}
}

// TestBuildCreateEntries_BorrowedOut verifies the borrowedOut creation
// double-entry pair: credit source (cash out) + debit receivable (asset +),
// balanced, with each account's ChartCode carried through. This is the
// inverse of buildPaymentEntries for BorrowedOut.
func TestBuildCreateEntries_BorrowedOut(t *testing.T) {
	src := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"}
	rcv := accountdomain.Account{ID: uuid.New(), ChartCode: "1122"}
	const amount int64 = 1_000_00

	entries := buildCreateEntries(src, rcv, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	// entries[0]: source — credit only (cash out).
	if entries[0].AccountID != src.ID {
		t.Errorf("entries[0] account: got %s, want source %s", entries[0].AccountID, src.ID)
	}
	if entries[0].ChartOfAccountCode != "1001" {
		t.Errorf("entries[0] chart code: got %q, want 1001", entries[0].ChartOfAccountCode)
	}
	if entries[0].CreditCents != amount || entries[0].DebitCents != 0 {
		t.Errorf("source entry: expected credit=%d debit=0, got credit=%d debit=%d",
			amount, entries[0].CreditCents, entries[0].DebitCents)
	}
	// entries[1]: receivable — debit only (asset +).
	if entries[1].AccountID != rcv.ID {
		t.Errorf("entries[1] account: got %s, want receivable %s", entries[1].AccountID, rcv.ID)
	}
	if entries[1].ChartOfAccountCode != "1122" {
		t.Errorf("entries[1] chart code: got %q, want 1122", entries[1].ChartOfAccountCode)
	}
	if entries[1].DebitCents != amount || entries[1].CreditCents != 0 {
		t.Errorf("receivable entry: expected debit=%d credit=0, got debit=%d credit=%d",
			amount, entries[1].DebitCents, entries[1].CreditCents)
	}
	// Balanced: source credit == receivable debit.
	if entries[0].CreditCents != entries[1].DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", entries[0].CreditCents, entries[1].DebitCents)
	}
}

// ---------------------------------------------------------------------------
// CreateDebt validation fail-fast tests (create-debt-dual-write)
//
// Validation runs BEFORE service.CreateDebt, so an invalid source fails fast
// and no debt is persisted. Each test asserts the gRPC error code AND that no
// debt was saved AND no transaction was recorded.
// ---------------------------------------------------------------------------

// borrowedOut base request builder (valid except the field under test).
func newBorrowedOutCreateReq(debtAccID, sourceAccID string) *pb.CreateDebtRequest {
	return &pb.CreateDebtRequest{
		AccountId:           debtAccID,
		SourceAccountId:     sourceAccID,
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: 1_000_00,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
	}
}

// requireNoDebtAndNoTxn asserts the fail-fast invariant: nothing persisted.
func requireNoDebtAndNoTxn(t *testing.T, resp *pb.DebtResponse, err error, debtRepo *fakeDebtRepo, txnRepo *recordingTxnRepo) {
	t.Helper()
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
	if resp != nil {
		t.Errorf("expected nil response on validation failure, got %+v", resp)
	}
	if len(debtRepo.byID) != 0 {
		t.Errorf("fail-fast: no debt should be persisted, got %d", len(debtRepo.byID))
	}
	if txnRepo.saved != nil {
		t.Error("fail-fast: no transaction should be recorded")
	}
}

// TestCreateDebt_MissingSource_Rejects: borrowedOut with empty source is
// rejected with InvalidArgument (source is required for borrowedOut).
func TestCreateDebt_MissingSource_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	req := newBorrowedOutCreateReq(debtAccID.String(), "")
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_NonAssetSource_Rejects: a source whose AccountType is not
// asset is rejected with InvalidArgument before the debt is created.
func TestCreateDebt_NonAssetSource_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	liabAcc, err := accountdomain.NewAccount(tenantID, "liability source", accountdomain.AccountTypeLiability, "CNY")
	if err != nil {
		t.Fatalf("seed liability account: %v", err)
	}
	liabAcc.ChartCode = "2202"
	liabAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(liabAcc)

	req := newBorrowedOutCreateReq(debtAccID.String(), liabAcc.ID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_InsufficientBalance_Rejects: a source whose balance is below
// the lent principal is rejected with FailedPrecondition before the debt is
// created.
func TestCreateDebt_InsufficientBalance_Rejects(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	// Drop source balance below the 1000.00 principal.
	accLookup.byID[sourceAccID].CurrentBalanceCents = 500_00

	req := newBorrowedOutCreateReq(debtAccID.String(), sourceAccID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.FailedPrecondition {
		t.Errorf("error code: got %v, want FailedPrecondition", err)
	}
}

// TestCreateDebt_CrossCurrency_Rejects: a source whose currency differs from
// the receivable account is rejected with InvalidArgument.
func TestCreateDebt_CrossCurrency_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, accLookup, debtRepo :=
		setupCreateDebtHarness(t)

	usdAcc, err := accountdomain.NewAccount(tenantID, "usd cash", accountdomain.AccountTypeAsset, "USD")
	if err != nil {
		t.Fatalf("seed usd account: %v", err)
	}
	usdAcc.ChartCode = "1001"
	usdAcc.CurrentBalanceCents = 1_000_000_00
	accLookup.seed(usdAcc)

	req := newBorrowedOutCreateReq(debtAccID.String(), usdAcc.ID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_SelfTransfer_Rejects: source == receivable account is
// rejected with InvalidArgument (no self-transfer).
func TestCreateDebt_SelfTransfer_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	// Point source at the receivable account itself.
	req := newBorrowedOutCreateReq(debtAccID.String(), debtAccID.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// TestCreateDebt_SourceNotFound_Rejects: a source account id that the lookup
// has no account for is rejected with NotFound before the debt is created.
func TestCreateDebt_SourceNotFound_Rejects(t *testing.T) {
	h, tenantID, _, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	// A valid UUID the lookup has no account for.
	missing := uuid.New()
	req := newBorrowedOutCreateReq(debtAccID.String(), missing.String())
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.NotFound {
		t.Errorf("error code: got %v, want NotFound", err)
	}
}

// TestCreateDebt_BorrowedOut_CollectionDefaultsToSource: spec B6 — when the
// request omits collection_account_id, the handler defaults the collection
// account to the cash source (source_account_id), so a direct RPC caller
// matches the create-debt form's behavior.
func TestCreateDebt_BorrowedOut_CollectionDefaultsToSource(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, _, _, debtRepo :=
		setupCreateDebtHarness(t)

	req := newBorrowedOutCreateReq(debtAccID.String(), sourceAccID.String())
	// collection_account_id intentionally left empty → must default to source.
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil {
		t.Fatal("CreateDebt returned empty debt")
	}

	d, ok := debtRepo.byID[uuid.MustParse(resp.Debt.Id)]
	if !ok {
		t.Fatalf("created debt not found in repo: id=%s", resp.Debt.Id)
	}
	if d.CollectionAccountID == nil {
		t.Fatal("CollectionAccountID is nil; expected default = source")
	}
	if *d.CollectionAccountID != sourceAccID {
		t.Errorf("CollectionAccountID default: got %s, want source %s",
			*d.CollectionAccountID, sourceAccID)
	}
}

// TestCreateDebt_BorrowedOut_MalformedCollection_Rejects: a non-empty, non-UUID
// collection_account_id must NOT silently fall back to the source — it is
// rejected with InvalidArgument, mirroring UpdateDebt's parse handling.
func TestCreateDebt_BorrowedOut_MalformedCollection_Rejects(t *testing.T) {
	h, tenantID, sourceAccID, debtAccID, txnRepo, _, debtRepo :=
		setupCreateDebtHarness(t)

	req := newBorrowedOutCreateReq(debtAccID.String(), sourceAccID.String())
	req.CollectionAccountId = "not-a-uuid"
	resp, err := h.CreateDebt(ctxWithTenant(tenantID), req)

	requireNoDebtAndNoTxn(t, resp, err, debtRepo, txnRepo)
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.InvalidArgument {
		t.Errorf("error code: got %v, want InvalidArgument", err)
	}
}

// ---------------------------------------------------------------------------
// GetReceivablesSummary handler tests (Task 7)
//
// Drives the real application Service + a fake snapshot repo end-to-end through
// the handler, asserting (1) borrowed_in debts are excluded, (2) totals +
// overdue + next_payment are aggregated correctly, and (3) the month-pair
// snapshot trend flows through summaryToProto into the response DTO.
// ---------------------------------------------------------------------------

// setupReceivablesSummaryHarness wires a DebtHandler backed by a fake debt repo
// (two borrowed_out receivables + one borrowed_in that must be excluded) and a
// fake snapshot repo seeded with this-month + last-month snapshots per debt.
// Returns the handler + tenant so the test can call GetReceivablesSummary.
func setupReceivablesSummaryHarness(t *testing.T) (h *DebtHandler, tenantID uuid.UUID) {
	t.Helper()
	tenantID = uuid.New()
	debtRepo := newFakeDebtRepo()

	// Debt A: principal 1_000_00, entry 1 (Jan) paid principal 200_00, entry 2
	// (Feb, unpaid, overdue as of now=Jun). Remaining = 800_00. Global next
	// payment is debtA's Feb entry (earlier than debtB's Jul).
	now := time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC)
	debtA, err := domain.NewDebtDetails(tenantID, uuid.New(), "Alice", 0,
		domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		1_000_00, domain.BorrowedOut, "", "AliceContact", "", nil)
	if err != nil {
		t.Fatalf("seed debtA: %v", err)
	}
	debtA.Schedule = []domain.PaymentScheduleEntry{
		{ID: uuid.New(), PaymentDate: time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC), PrincipalCents: 200_00, InterestCents: 50_00, TotalCents: 250_00, Paid: true, PaidCents: 250_00},
		// Index 1 → NextPaymentPeriodNo = 2 (1-based schedule index).
		{ID: uuid.New(), PaymentDate: time.Date(2026, 2, 28, 0, 0, 0, 0, time.UTC), PrincipalCents: 200_00, InterestCents: 40_00, TotalCents: 240_00, Paid: false},
		{ID: uuid.New(), PaymentDate: time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), PrincipalCents: 200_00, InterestCents: 30_00, TotalCents: 230_00, Paid: false},
	}
	debtA.Version = 1
	debtRepo.byID[debtA.ID] = debtA

	// Debt B: principal 500_00, all unpaid, next entry in Jul. Remaining = 500_00.
	debtB, err := domain.NewDebtDetails(tenantID, uuid.New(), "Bob", 0,
		domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		500_00, domain.BorrowedOut, "", "", "", nil)
	if err != nil {
		t.Fatalf("seed debtB: %v", err)
	}
	debtB.Schedule = []domain.PaymentScheduleEntry{
		// Index 0 → NextPaymentPeriodNo = 1 (not the global next, so not asserted).
		{ID: uuid.New(), PaymentDate: time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), PrincipalCents: 250_00, InterestCents: 10_00, TotalCents: 260_00, Paid: false},
	}
	debtB.Version = 1
	debtRepo.byID[debtB.ID] = debtB

	// Debt C: borrowed_in — must be excluded from the receivables summary.
	debtC, err := domain.NewDebtDetails(tenantID, uuid.New(), "Bank", 0,
		domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		9_000_00, domain.BorrowedIn, "", "", "", nil)
	if err != nil {
		t.Fatalf("seed debtC: %v", err)
	}
	debtC.Version = 1
	debtRepo.byID[debtC.ID] = debtC

	// Snapshots: this month + last month for both receivables (so the trend Σ
	// has a valid baseline for each debt).
	snapRepo := newFakeDebtSnapshotRepo()
	monthStart := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	lastMonthStart := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	snapRepo.rangeOut[debtA.ID] = []domain.DebtProgressSnapshot{
		{DebtID: debtA.ID, SnapshotDate: lastMonthStart, TotalPrincipalCents: 1_000_00, RemainingCents: 1_000_00},
		{DebtID: debtA.ID, SnapshotDate: monthStart, TotalPrincipalCents: 1_000_00, RemainingCents: 800_00},
	}
	snapRepo.rangeOut[debtB.ID] = []domain.DebtProgressSnapshot{
		{DebtID: debtB.ID, SnapshotDate: lastMonthStart, TotalPrincipalCents: 500_00, RemainingCents: 500_00},
		{DebtID: debtB.ID, SnapshotDate: monthStart, TotalPrincipalCents: 500_00, RemainingCents: 500_00},
	}

	svc := application.NewService(debtRepo)
	svc.SetSnapshotRepo(snapRepo)
	svc.SetNow(func() time.Time { return now })
	h = NewDebtHandler(svc, nil, nil)
	return
}

// TestGetReceivablesSummary_ReturnsSummary drives the real service end-to-end
// and asserts the response carries the aggregated totals, the excluded
// borrowed_in debt, the overdue entry, and the snapshot-driven trend.
func TestGetReceivablesSummary_ReturnsSummary(t *testing.T) {
	h, tenantID := setupReceivablesSummaryHarness(t)

	resp, err := h.GetReceivablesSummary(ctxWithTenant(tenantID), &pb.GetReceivablesSummaryRequest{})
	if err != nil {
		t.Fatalf("GetReceivablesSummary: %v", err)
	}
	if resp == nil || resp.Summary == nil {
		t.Fatal("expected non-nil response.Summary")
	}
	s := resp.Summary

	// Count: only the two borrowed_out receivables; debtC (borrowed_in) excluded.
	if s.Count != 2 {
		t.Errorf("Count: got %d, want 2 (borrowed_in excluded)", s.Count)
	}
	// Total principal = 1_000_00 + 500_00 = 1_500_00.
	if s.TotalPrincipalCents != 1_500_00 {
		t.Errorf("TotalPrincipalCents: got %d, want 150000", s.TotalPrincipalCents)
	}
	// Total remaining = 800_00 (debtA) + 500_00 (debtB) = 1_300_00.
	if s.TotalRemainingCents != 1_300_00 {
		t.Errorf("TotalRemainingCents: got %d, want 130000", s.TotalRemainingCents)
	}
	// Collected = 200_00 (debtA's paid entry principal).
	if s.TotalCollectedCents != 200_00 {
		t.Errorf("TotalCollectedCents: got %d, want 20000", s.TotalCollectedCents)
	}
	// Overdue: debtA's Feb entry (unpaid, due before now=Jun). One entry, total 240_00.
	if s.OverdueCount != 1 {
		t.Errorf("OverdueCount: got %d, want 1", s.OverdueCount)
	}
	if s.OverdueAmountCents != 240_00 {
		t.Errorf("OverdueAmountCents: got %d, want 24000", s.OverdueAmountCents)
	}
	// Next payment = debtA's Feb entry (earliest unpaid globally).
	if s.NextPaymentDate != "2026-02-28" {
		t.Errorf("NextPaymentDate: got %q, want 2026-02-28", s.NextPaymentDate)
	}
	if s.NextPaymentAmountCents != 240_00 {
		t.Errorf("NextPaymentAmountCents: got %d, want 24000", s.NextPaymentAmountCents)
	}
	if s.NextPaymentCounterparty != "Alice" {
		t.Errorf("NextPaymentCounterparty: got %q, want Alice", s.NextPaymentCounterparty)
	}
	if s.NextPaymentPeriodNo != 2 {
		t.Errorf("NextPaymentPeriodNo: got %d, want 2", s.NextPaymentPeriodNo)
	}
	// Principal trend = 0 (both debts: this month total == last month total).
	if s.PrincipalTrendCents != 0 {
		t.Errorf("PrincipalTrendCents: got %d, want 0", s.PrincipalTrendCents)
	}
	// Remaining trend = (800_00 - 1000_00) + (500_00 - 500_00) = -200_00.
	if s.RemainingTrendCents != -200_00 {
		t.Errorf("RemainingTrendCents: got %d, want -20000", s.RemainingTrendCents)
	}
}

// TestGetReceivablesSummary_Unauthenticated asserts the handler rejects a
// context without a tenant_id with Unauthenticated, mirroring every other
// per-tenant RPC in this handler.
func TestGetReceivablesSummary_Unauthenticated(t *testing.T) {
	h, _ := setupReceivablesSummaryHarness(t)

	// Plain background context carries no tenant_id.
	resp, err := h.GetReceivablesSummary(context.Background(), &pb.GetReceivablesSummaryRequest{})

	if err == nil {
		t.Fatal("expected Unauthenticated error, got nil")
	}
	if resp != nil {
		t.Errorf("expected nil response on auth failure, got %+v", resp)
	}
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.Unauthenticated {
		t.Errorf("error code: got %v, want Unauthenticated", err)
	}
}
