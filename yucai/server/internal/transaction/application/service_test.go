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
