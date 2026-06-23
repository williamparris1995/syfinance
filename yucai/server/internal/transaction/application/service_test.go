package application

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/transaction/domain"
)

// --- Mocks ---

// mockAccountRepo implements the account lookup port used by the service.
// We only need FindByID for validation; other methods panic to surface misuse.
type mockAccountRepo struct {
	mu    sync.Mutex
	byID  map[uuid.UUID]*accountdomain.Account
	errFn func(uuid.UUID) error // optional per-id error injection
}

func newMockAccountRepo() *mockAccountRepo {
	return &mockAccountRepo{byID: make(map[uuid.UUID]*accountdomain.Account)}
}

func (m *mockAccountRepo) seed(a *accountdomain.Account) {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *a
	m.byID[a.ID] = &c
}

func (m *mockAccountRepo) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*accountdomain.Account, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.errFn != nil {
		if err := m.errFn(id); err != nil {
			return nil, err
		}
	}
	a, ok := m.byID[id]
	if !ok {
		return nil, fmt.Errorf("account %s not found", id)
	}
	c := *a
	return &c, nil
}

// Unused repository methods — panic if invoked (not needed by validation).
func (m *mockAccountRepo) Save(context.Context, *accountdomain.Account) error {
	panic("unexpected Save call")
}
func (m *mockAccountRepo) FindAll(context.Context, uuid.UUID, accountdomain.AccountFilter, accountdomain.PageRequest) (*accountdomain.PaginatedResult[accountdomain.Account], error) {
	panic("unexpected FindAll call")
}
func (m *mockAccountRepo) FindByAccountType(context.Context, uuid.UUID, accountdomain.AccountType) ([]accountdomain.Account, error) {
	panic("unexpected FindByAccountType call")
}
func (m *mockAccountRepo) Update(context.Context, *accountdomain.Account) error {
	panic("unexpected Update call")
}
func (m *mockAccountRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}

// noopBalanceUpdater satisfies BalanceUpdater without touching accounts.
type noopBalanceUpdater struct{}

func (noopBalanceUpdater) UpdateBalances(context.Context, uuid.UUID, []domain.TransactionEntry) error {
	return nil
}
func (noopBalanceUpdater) ReverseBalances(context.Context, uuid.UUID, []domain.TransactionEntry) error {
	return nil
}

// recordingTxnRepo is a minimal TransactionRepository that records Save calls
// so the "happy path" tests can confirm validation passed and the transaction
// was built. Other methods panic if misused.
type recordingTxnRepo struct {
	saved *domain.Transaction
}

func (r *recordingTxnRepo) Save(_ context.Context, t *domain.Transaction) error {
	r.saved = t
	return nil
}
func (r *recordingTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*domain.Transaction, error) {
	panic("unexpected FindByID call")
}
func (r *recordingTxnRepo) FindAll(context.Context, uuid.UUID, domain.TransactionFilter, domain.PageRequest) (*domain.PaginatedResult[domain.Transaction], error) {
	panic("unexpected FindAll call")
}
func (r *recordingTxnRepo) Update(context.Context, *domain.Transaction) error {
	panic("unexpected Update call")
}
func (r *recordingTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}
func (r *recordingTxnRepo) FindRecentByAccount(context.Context, uuid.UUID, uuid.UUID, int) ([]domain.Transaction, error) {
	panic("unexpected FindRecentByAccount call")
}
func (r *recordingTxnRepo) TransactionSummary(context.Context, domain.SummaryScope) (*domain.MonthlySummary, error) {
	panic("unexpected TransactionSummary call")
}

// recentTxnRepo is a TransactionRepository whose FindRecentByAccount returns a
// canned result (and records its args) so the service-level thin-wrapper test
// can assert delegation. All other methods panic.
type recentTxnRepo struct {
	gotTenantID  uuid.UUID
	gotAccountID uuid.UUID
	gotLimit     int
	result       []domain.Transaction
	err          error
}

func (r *recentTxnRepo) Save(context.Context, *domain.Transaction) error {
	panic("unexpected Save call")
}
func (r *recentTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*domain.Transaction, error) {
	panic("unexpected FindByID call")
}
func (r *recentTxnRepo) FindAll(context.Context, uuid.UUID, domain.TransactionFilter, domain.PageRequest) (*domain.PaginatedResult[domain.Transaction], error) {
	panic("unexpected FindAll call")
}
func (r *recentTxnRepo) Update(context.Context, *domain.Transaction) error {
	panic("unexpected Update call")
}
func (r *recentTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}
func (r *recentTxnRepo) FindRecentByAccount(_ context.Context, tenantID, accountID uuid.UUID, limit int) ([]domain.Transaction, error) {
	r.gotTenantID = tenantID
	r.gotAccountID = accountID
	r.gotLimit = limit
	return r.result, r.err
}
func (r *recentTxnRepo) TransactionSummary(context.Context, domain.SummaryScope) (*domain.MonthlySummary, error) {
	panic("unexpected TransactionSummary call")
}

// --- Helpers ---

func newTestAccount(t *testing.T, accountType accountdomain.AccountType, currency string, balanceCents int64) *accountdomain.Account {
	t.Helper()
	a, err := accountdomain.NewAccount(uuid.New(), "test-account", accountType, currency)
	if err != nil {
		t.Fatalf("create test account: %v", err)
	}
	a.CurrentBalanceCents = balanceCents
	return a
}

// --- Tests ---

func TestSimpleTransfer_RejectsMismatchedCurrency(t *testing.T) {
	tenantID := uuid.New()
	fromAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 1000_00)
	toAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "USD", 0)

	repo := newMockAccountRepo()
	repo.seed(fromAcc)
	repo.seed(toAcc)

	svc := NewService(nil, repo, noopBalanceUpdater{})

	_, err := svc.SimpleTransfer(context.Background(), SimpleTransferRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "cross-currency transfer",
		FromAccountID:   fromAcc.ID,
		ToAccountID:     toAcc.ID,
		AmountCents:     100_00,
	})
	if err == nil {
		t.Fatal("expected currency mismatch error, got nil")
	}
}

func TestSimpleTransfer_AcceptsSameCurrency(t *testing.T) {
	// Boundary: same currency must NOT be rejected at the validation step.
	tenantID := uuid.New()
	fromAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 1000_00)
	toAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(fromAcc)
	repo.seed(toAcc)
	txnRepo := &recordingTxnRepo{}

	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	dto, err := svc.SimpleTransfer(context.Background(), SimpleTransferRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "same-currency transfer",
		FromAccountID:   fromAcc.ID,
		ToAccountID:     toAcc.ID,
		AmountCents:     100_00,
	})
	if err != nil {
		t.Fatalf("expected validation to pass, got error: %v", err)
	}
	if dto == nil || txnRepo.saved == nil {
		t.Fatal("expected transaction to be saved after passing validation")
	}
}

func TestSimpleExpense_RejectsInsufficientBalance(t *testing.T) {
	tenantID := uuid.New()
	assetAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 100_00)
	expenseAcc := newTestAccount(t, accountdomain.AccountTypeExpense, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(assetAcc)
	repo.seed(expenseAcc)

	svc := NewService(nil, repo, noopBalanceUpdater{})

	_, err := svc.SimpleExpense(context.Background(), SimpleExpenseRequest{
		TenantID:         tenantID,
		TransactionDate:  time.Now(),
		Description:      "overdraft expense",
		ExpenseAccountID: expenseAcc.ID,
		AssetAccountID:   assetAcc.ID,
		AmountCents:      200_00, // balance 100 < 200
	})
	if err == nil {
		t.Fatal("expected insufficient balance error, got nil")
	}
}

func TestSimpleExpense_AcceptsExactBalance(t *testing.T) {
	// Boundary: balance == amount must NOT be rejected.
	tenantID := uuid.New()
	assetAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 200_00)
	expenseAcc := newTestAccount(t, accountdomain.AccountTypeExpense, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(assetAcc)
	repo.seed(expenseAcc)
	txnRepo := &recordingTxnRepo{}

	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	dto, err := svc.SimpleExpense(context.Background(), SimpleExpenseRequest{
		TenantID:         tenantID,
		TransactionDate:  time.Now(),
		Description:      "exact-balance expense",
		ExpenseAccountID: expenseAcc.ID,
		AssetAccountID:   assetAcc.ID,
		AmountCents:      200_00, // balance 200 == 200 → allowed
	})
	if err != nil {
		t.Fatalf("expected validation to pass, got error: %v", err)
	}
	if dto == nil || txnRepo.saved == nil {
		t.Fatal("expected transaction to be saved after passing validation")
	}
}

// TestSimpleExpense_ForwardsTransactionTime verifies that SimpleExpense forwards
// its optional TransactionTime to the underlying RecordTransaction so the saved
// domain.Transaction carries it. Set → saved; nil → saved as nil (no default).
func TestSimpleExpense_ForwardsTransactionTime(t *testing.T) {
	tenantID := uuid.New()
	assetAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 1000_00)
	expenseAcc := newTestAccount(t, accountdomain.AccountTypeExpense, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(assetAcc)
	repo.seed(expenseAcc)
	txnRepo := &recordingTxnRepo{}
	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	want := time.Date(2026, 6, 5, 19, 20, 0, 0, time.UTC)
	if _, err := svc.SimpleExpense(context.Background(), SimpleExpenseRequest{
		TenantID:         tenantID,
		TransactionDate:  time.Now(),
		Description:      "lunch",
		ExpenseAccountID: expenseAcc.ID,
		AssetAccountID:   assetAcc.ID,
		AmountCents:      50_00,
		TransactionTime:  &want,
	}); err != nil {
		t.Fatalf("SimpleExpense with TransactionTime: %v", err)
	}
	if txnRepo.saved == nil {
		t.Fatal("expected transaction to be saved")
	}
	if txnRepo.saved.TransactionTime == nil {
		t.Fatal("expected saved TransactionTime to be set, got nil")
	}
	if !txnRepo.saved.TransactionTime.Equal(want) {
		t.Errorf("saved TransactionTime = %v, want %v", *txnRepo.saved.TransactionTime, want)
	}
}

// TestSimpleExpense_NoTransactionTimeDefaultsToNil verifies that omitting
// TransactionTime leaves the saved domain.Transaction's TransactionTime as nil
// (RecordTransaction does not synthesize a default now-time).
func TestSimpleExpense_NoTransactionTimeDefaultsToNil(t *testing.T) {
	tenantID := uuid.New()
	assetAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 1000_00)
	expenseAcc := newTestAccount(t, accountdomain.AccountTypeExpense, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(assetAcc)
	repo.seed(expenseAcc)
	txnRepo := &recordingTxnRepo{}
	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	if _, err := svc.SimpleExpense(context.Background(), SimpleExpenseRequest{
		TenantID:         tenantID,
		TransactionDate:  time.Now(),
		Description:      "lunch",
		ExpenseAccountID: expenseAcc.ID,
		AssetAccountID:   assetAcc.ID,
		AmountCents:      50_00,
		// TransactionTime intentionally nil
	}); err != nil {
		t.Fatalf("SimpleExpense without TransactionTime: %v", err)
	}
	if txnRepo.saved == nil {
		t.Fatal("expected transaction to be saved")
	}
	if txnRepo.saved.TransactionTime != nil {
		t.Errorf("expected saved TransactionTime nil, got %v", *txnRepo.saved.TransactionTime)
	}
}

// TestSimpleIncome_ForwardsTransactionTime verifies SimpleIncome forwards its
// TransactionTime into the saved domain transaction.
func TestSimpleIncome_ForwardsTransactionTime(t *testing.T) {
	tenantID := uuid.New()
	assetAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 0)
	incomeAcc := newTestAccount(t, accountdomain.AccountTypeIncome, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(assetAcc)
	repo.seed(incomeAcc)
	txnRepo := &recordingTxnRepo{}
	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	want := time.Date(2026, 6, 5, 8, 0, 0, 0, time.UTC)
	if _, err := svc.SimpleIncome(context.Background(), SimpleIncomeRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "salary",
		AssetAccountID:  assetAcc.ID,
		IncomeAccountID: incomeAcc.ID,
		AmountCents:     1000_00,
		TransactionTime: &want,
	}); err != nil {
		t.Fatalf("SimpleIncome with TransactionTime: %v", err)
	}
	if txnRepo.saved == nil || txnRepo.saved.TransactionTime == nil {
		t.Fatalf("expected saved TransactionTime set, got: saved=%v", txnRepo.saved)
	}
	if !txnRepo.saved.TransactionTime.Equal(want) {
		t.Errorf("saved TransactionTime = %v, want %v", *txnRepo.saved.TransactionTime, want)
	}
}

// TestSimpleTransfer_ForwardsTransactionTime verifies SimpleTransfer forwards
// its TransactionTime into the saved domain transaction.
func TestSimpleTransfer_ForwardsTransactionTime(t *testing.T) {
	tenantID := uuid.New()
	fromAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 1000_00)
	toAcc := newTestAccount(t, accountdomain.AccountTypeAsset, "CNY", 0)

	repo := newMockAccountRepo()
	repo.seed(fromAcc)
	repo.seed(toAcc)
	txnRepo := &recordingTxnRepo{}
	svc := NewService(txnRepo, repo, noopBalanceUpdater{})

	want := time.Date(2026, 6, 5, 12, 30, 0, 0, time.UTC)
	if _, err := svc.SimpleTransfer(context.Background(), SimpleTransferRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "move",
		FromAccountID:   fromAcc.ID,
		ToAccountID:     toAcc.ID,
		AmountCents:     100_00,
		TransactionTime: &want,
	}); err != nil {
		t.Fatalf("SimpleTransfer with TransactionTime: %v", err)
	}
	if txnRepo.saved == nil || txnRepo.saved.TransactionTime == nil {
		t.Fatalf("expected saved TransactionTime set, got: saved=%v", txnRepo.saved)
	}
	if !txnRepo.saved.TransactionTime.Equal(want) {
		t.Errorf("saved TransactionTime = %v, want %v", *txnRepo.saved.TransactionTime, want)
	}
}

// TestListRecentByAccount_DelegatesToRepo verifies the service method is a thin
// wrapper: it passes tenant/account/limit straight through and converts domain
// entities to DTOs.
func TestListRecentByAccount_DelegatesToRepo(t *testing.T) {
	tenantID := uuid.New()
	accountID := uuid.New()
	seeded := []domain.Transaction{
		{ID: uuid.New(), TenantID: tenantID, Description: "recent-a"},
		{ID: uuid.New(), TenantID: tenantID, Description: "recent-b"},
	}
	repo := &recentTxnRepo{result: seeded}
	svc := NewService(repo, newMockAccountRepo(), noopBalanceUpdater{})

	got, err := svc.ListRecentByAccount(context.Background(), tenantID, accountID, 5)
	if err != nil {
		t.Fatalf("ListRecentByAccount: %v", err)
	}
	if repo.gotTenantID != tenantID || repo.gotAccountID != accountID || repo.gotLimit != 5 {
		t.Errorf("delegation args: tenant=%v account=%v limit=%d; want %v %v 5",
			repo.gotTenantID, repo.gotAccountID, repo.gotLimit, tenantID, accountID)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 DTOs, got %d", len(got))
	}
	if got[0].Description != "recent-a" || got[1].Description != "recent-b" {
		t.Errorf("DTO order/content: got %q, %q", got[0].Description, got[1].Description)
	}
}

// TestListRecentByAccount_PropagatesRepoError verifies the service surfaces
// repository errors instead of swallowing them.
func TestListRecentByAccount_PropagatesRepoError(t *testing.T) {
	repo := &recentTxnRepo{err: fmt.Errorf("boom")}
	svc := NewService(repo, newMockAccountRepo(), noopBalanceUpdater{})

	if _, err := svc.ListRecentByAccount(context.Background(), uuid.New(), uuid.New(), 5); err == nil {
		t.Fatal("expected error to propagate, got nil")
	}
}
