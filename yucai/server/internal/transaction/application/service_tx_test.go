package application

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/account/ent/account"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	"github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// txTestDialect is the ent dialect string for SQLite
// (== entgo.io/ent/dialect.SQLite). Forwarded to the service's WithTx call so
// ent's mutation builders emit "?" placeholders instead of PostgreSQL's "$1".
const txTestDialect = "sqlite3"

// setupTxTestDB opens ONE shared in-memory SQLite database, runs BOTH the
// account and transaction ent auto-migrations against it, and returns the
// underlying *sql.DB plus ready account + transaction ent clients. The shared
// *sql.DB is what the service's WithTx opens its transaction on (mirroring the
// production cross-module pattern from Task 1's provideDB).
//
// SetMaxOpenConns(1) is mandatory for shared in-memory SQLite — it pins the
// pool to a single physical connection so the *sql.Tx grabbed by WithTx and
// the subsequent read-through-default-client hit the same database.
func setupTxTestDB(t *testing.T) (*sql.DB, *txnent.Client, *accountent.Client) {
	t.Helper()
	dbName := "txn_app_shared_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB(txTestDialect, db)

	txnClient := txnent.NewClient(txnent.Driver(drv))
	if err := txnClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	accountClient := accountent.NewClient(accountent.Driver(drv))
	if err := accountClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() {
		_ = txnClient.Close()
		_ = accountClient.Close()
	})
	return db, txnClient, accountClient
}

// inlineBalanceUpdater mirrors balance.BalanceUpdaterImpl's applyEntries path
// (accountRepo.FindByID → BalanceCalculator.ApplyEntryDelta →
// accountRepo.Update). It is duplicated inline here because importing the real
// balance package would form an import cycle (balance imports application for
// the BalanceUpdater interface). Keeping the path identical ensures the test
// exercises the same write sequence the production balance updater performs
// inside the WithTx wrapper.
type inlineBalanceUpdater struct {
	accountRepo accountdomain.AccountRepository
}

func (u *inlineBalanceUpdater) UpdateBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, 1)
}
func (u *inlineBalanceUpdater) ReverseBalances(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, -1)
}
func (u *inlineBalanceUpdater) applyEntries(ctx context.Context, tenantID uuid.UUID, entries []domain.TransactionEntry, sign int64) error {
	calc := accountdomain.BalanceCalculator{}
	for _, e := range entries {
		acc, err := u.accountRepo.FindByID(ctx, tenantID, e.AccountID)
		if err != nil {
			return fmt.Errorf("find account %s: %w", e.AccountID, err)
		}
		delta := calc.ApplyEntryDelta(acc.AccountType, e.DebitCents, e.CreditCents) * sign
		acc.CurrentBalanceCents += delta
		acc.IncrementVersion()
		if err := u.accountRepo.Update(ctx, acc); err != nil {
			return fmt.Errorf("update account balance: %w", err)
		}
	}
	return nil
}

// failingUpdateAccountRepo wraps an accountdomain.AccountRepository, delegating
// every method to the inner repo EXCEPT Update, which returns the injected
// error. This simulates a mid-flow persistence failure on the balance-update
// path (the second write phase of SimpleExpense) so the rollback test can
// assert the earlier transaction header + entries writes were rolled back.
//
// Embedding the interface promotes all methods; shadowing just Update keeps
// the wrapper resilient to future AccountRepository growth (a new method is
// auto-delegated, not silently dropped).
type failingUpdateAccountRepo struct {
	accountdomain.AccountRepository
	failUpdate error
}

func (r *failingUpdateAccountRepo) Update(_ context.Context, _ *accountdomain.Account) error {
	return r.failUpdate
}

// seedAccountForTx inserts one account row directly via the ent client (not the
// service path) so the test starts from a known state without invoking the
// method under test. Uses the minimum required field set; the rest get ent
// defaults.
func seedAccountForTx(t *testing.T, ctx context.Context, c *accountent.Client, id, tenantID uuid.UUID, name string, accountType account.AccountType, balanceCents int64) {
	t.Helper()
	if _, err := c.Account.Create().
		SetID(id).
		SetTenantID(tenantID).
		SetName(name).
		SetAccountType(accountType).
		SetCurrentBalanceCents(balanceCents).
		SetInitialBalanceCents(balanceCents).
		Save(ctx); err != nil {
		t.Fatalf("seed account %s: %v", name, err)
	}
}

// TestCreateTransaction_RollbackOnBalanceFailure is the headline transactional
// guarantee for Task 4 (audit D1): when SimpleExpense's balance-update phase
// fails AFTER the transaction header + entries have been written, the entire
// operation must roll back — leaving zero transaction rows and zero entry rows
// in the database. Pre-Task-4 (no sqltx.WithTx wrapping, repos writing through
// their default auto-commit clients), the header+entries persist and the
// assertion fails; post-Task-4 the WithTx wrapper rolls them back with the
// failed balance update.
func TestCreateTransaction_RollbackOnBalanceFailure(t *testing.T) {
	db, txnClient, accountClient := setupTxTestDB(t)

	tenantID := uuid.New()
	assetID := uuid.New()
	expenseID := uuid.New()
	ctx := context.Background()

	seedAccountForTx(t, ctx, accountClient, assetID, tenantID, "Cash", account.AccountTypeAsset, 1000_00)
	seedAccountForTx(t, ctx, accountClient, expenseID, tenantID, "Food", account.AccountTypeExpense, 0)

	// Real repos wired over the shared db. The transaction repo's SetDialect
	// selects the placeholder style for its raw SQL reads — not exercised on
	// this path but set for correctness.
	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectSQLite3)
	realAccountRepo := accountrepo.NewAccountRepository(accountClient)

	// Wrap the real account repo so Update (the balance-persistence step inside
	// inlineBalanceUpdater.applyEntries) returns errFake. FindByID and every
	// other method keep working, so validation + the txn Save complete normally
	// before the balance update trips.
	errFake := errors.New("simulated balance update failure")
	failingRepo := &failingUpdateAccountRepo{AccountRepository: realAccountRepo, failUpdate: errFake}

	bu := &inlineBalanceUpdater{accountRepo: failingRepo}
	svc := NewService(txnRepo, failingRepo, bu, db)

	_, err := svc.SimpleExpense(ctx, SimpleExpenseRequest{
		TenantID:         tenantID,
		Description:      "lunch",
		ExpenseAccountID: expenseID,
		AssetAccountID:   assetID,
		AmountCents:      50_00,
	})
	if err == nil {
		t.Fatal("expected SimpleExpense to surface the balance-update error, got nil")
	}
	if !errors.Is(err, errFake) {
		t.Fatalf("expected error to wrap errFake, got %v", err)
	}

	// Headline assertion: the transaction header and every entry must have been
	// rolled back. Pre-Task-4 the Save writes through the default (auto-commit)
	// client, so the header persists and these counts are 1 / 2.
	headerCount, err := txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if headerCount != 0 {
		t.Errorf("transaction header should have rolled back, got %d row(s)", headerCount)
	}
	entryCount, err := txnClient.TransactionEntry.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count entries: %v", err)
	}
	if entryCount != 0 {
		t.Errorf("transaction entries should have rolled back, got %d row(s)", entryCount)
	}

	// Sanity: the asset account's balance must be unchanged (the increment was
	// inside the rolled-back tx).
	asset, err := accountClient.Account.Get(ctx, assetID)
	if err != nil {
		t.Fatalf("reload asset account: %v", err)
	}
	if asset.CurrentBalanceCents != 1000_00 {
		t.Errorf("asset balance should be unchanged at 100000, got %d", asset.CurrentBalanceCents)
	}
}

// TestCreateTransaction_CommitsOnSuccess is the paired control for the rollback
// test: when every step succeeds, the WithTx wrapper commits and the
// transaction header + entries + balance update are all durable. Without this
// control a bug where WithTx always rolled back would pass the rollback test
// silently.
func TestCreateTransaction_CommitsOnSuccess(t *testing.T) {
	db, txnClient, accountClient := setupTxTestDB(t)

	tenantID := uuid.New()
	assetID := uuid.New()
	expenseID := uuid.New()
	ctx := context.Background()

	seedAccountForTx(t, ctx, accountClient, assetID, tenantID, "Cash", account.AccountTypeAsset, 1000_00)
	seedAccountForTx(t, ctx, accountClient, expenseID, tenantID, "Food", account.AccountTypeExpense, 0)

	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectSQLite3)
	accountRepo := accountrepo.NewAccountRepository(accountClient)
	bu := &inlineBalanceUpdater{accountRepo: accountRepo}
	svc := NewService(txnRepo, accountRepo, bu, db)

	dto, err := svc.SimpleExpense(ctx, SimpleExpenseRequest{
		TenantID:         tenantID,
		Description:      "lunch",
		ExpenseAccountID: expenseID,
		AssetAccountID:   assetID,
		AmountCents:      50_00,
	})
	if err != nil {
		t.Fatalf("SimpleExpense succeeded-path: %v", err)
	}
	if dto == nil {
		t.Fatal("expected non-nil DTO on success")
	}

	headerCount, err := txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if headerCount != 1 {
		t.Errorf("transaction header should have committed, got %d row(s)", headerCount)
	}
	entryCount, err := txnClient.TransactionEntry.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count entries: %v", err)
	}
	if entryCount != 2 {
		t.Errorf("expected 2 entries committed, got %d row(s)", entryCount)
	}

	// Balance update also committed: asset balance dropped by 50.00.
	asset, err := accountClient.Account.Get(ctx, assetID)
	if err != nil {
		t.Fatalf("reload asset account: %v", err)
	}
	if asset.CurrentBalanceCents != 950_00 {
		t.Errorf("asset balance should be 95000 after 50.00 expense, got %d", asset.CurrentBalanceCents)
	}
}

// ensure dialect import is used even if the helper signatures change later.
var _ = dialect.SQLite
