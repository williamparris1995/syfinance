package repository_test

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/transaction/adapter/driven/repository"
	"github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// --- Test DB setup -------------------------------------------------------

// setupTestDB opens ONE shared in-memory SQLite database, runs BOTH the
// account and transaction ent auto-migrations against it, and returns a
// transaction client plus an account client. Both modules share the same
// underlying *sql.DB so a transaction's entries can JOIN the accounts table
// (the production deployment pattern).
func setupTestDB(t *testing.T) (*txnent.Client, *accountent.Client) {
	t.Helper()
	dbName := "txn_shared_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Enable FK enforcement at the driver level (matches tests/account_integration_test.go).
	// modernc/sqlite otherwise rejects FK creation with "missing _fk=1".
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1) // required for shared in-memory sqlite across conns

	drv := entsql.OpenDB("sqlite3", db)

	txnClient := txnent.NewClient(txnent.Driver(drv))
	if err := txnClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	// Account client shares the same driver (same physical DB).
	accountClient := accountent.NewClient(accountent.Driver(drv))
	if err := accountClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() {
		_ = txnClient.Close()
		_ = accountClient.Close()
	})
	return txnClient, accountClient
}

// queryCountingDriver wraps an entsql.Driver, atomically counting SELECT
// Query calls so the N+1 test can assert a bounded number of reads.
type queryCountingDriver struct {
	inner   *entsql.Driver
	queries *atomic.Int64
}

func (d *queryCountingDriver) Query(ctx context.Context, query string, args, v any) error {
	if strings.HasPrefix(strings.TrimSpace(strings.ToLower(query)), "select") {
		d.queries.Add(1)
	}
	return d.inner.Query(ctx, query, args, v)
}

func (d *queryCountingDriver) Exec(ctx context.Context, query string, args, v any) error {
	return d.inner.Exec(ctx, query, args, v)
}

func (d *queryCountingDriver) Tx(ctx context.Context) (dialect.Tx, error) {
	return d.inner.Tx(ctx)
}

func (d *queryCountingDriver) Close() error    { return d.inner.Close() }
func (d *queryCountingDriver) Dialect() string { return d.inner.Dialect() }
func (d *queryCountingDriver) DB() *sql.DB     { return d.inner.DB() }

// setupCountingDB is like setupTestDB but the transaction client is wired to
// a driver that counts SELECT queries. Returns the client, the counter, and
// the raw (non-counting) driver — useful for seeding accounts via the account
// client without inflating the counter.
func setupCountingDB(t *testing.T) (*txnent.Client, *atomic.Int64, *entsql.Driver) {
	t.Helper()
	dbName := "txn_count_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB("sqlite3", db)
	counting := &queryCountingDriver{inner: drv, queries: &atomic.Int64{}}

	// Migrate account schema on the raw driver first (so accounts table exists).
	accountClient := accountent.NewClient(accountent.Driver(drv))
	if err := accountClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	txnClient := txnent.NewClient(txnent.Driver(counting))
	if err := txnClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	t.Cleanup(func() {
		_ = txnClient.Close()
		_ = accountClient.Close()
	})
	return txnClient, counting.queries, drv
}

// --- Fixtures ------------------------------------------------------------

type fixture struct {
	assetAcc   *accountdomain.Account
	incomeAcc  *accountdomain.Account
	expenseAcc *accountdomain.Account
	assetAcc2  *accountdomain.Account
	tenantID   uuid.UUID
}

func seedFixture(t *testing.T, accRepo *accountrepo.AccountRepository, txnRepo *repository.TransactionRepository) fixture {
	t.Helper()
	tenantID := uuid.New()
	asset := saveAccount(t, accRepo, tenantID, "Cash", accountdomain.AccountTypeAsset)
	income := saveAccount(t, accRepo, tenantID, "Salary", accountdomain.AccountTypeIncome)
	expense := saveAccount(t, accRepo, tenantID, "Food", accountdomain.AccountTypeExpense)
	asset2 := saveAccount(t, accRepo, tenantID, "Bank", accountdomain.AccountTypeAsset)
	return fixture{asset, income, expense, asset2, tenantID}
}

// saveAccount persists a minimal account via the account repo (ent) so it
// exists in the shared DB for transaction entry JOINs.
func saveAccount(t *testing.T, repo *accountrepo.AccountRepository, tenantID uuid.UUID, name string, at accountdomain.AccountType) *accountdomain.Account {
	t.Helper()
	a, err := accountdomain.NewAccount(tenantID, name, at, "CNY")
	if err != nil {
		t.Fatalf("new account: %v", err)
	}
	if err := repo.Save(context.Background(), a); err != nil {
		t.Fatalf("save account: %v", err)
	}
	return a
}

// recordTxn saves a domain.Transaction directly via the repo.
func recordTxn(t *testing.T, repo *repository.TransactionRepository, tenantID uuid.UUID, date time.Time, desc string, entries []domain.TransactionEntry) *domain.Transaction {
	t.Helper()
	txn, err := domain.NewTransaction(tenantID, date, desc, entries)
	if err != nil {
		t.Fatalf("new transaction: %v", err)
	}
	if err := repo.Save(context.Background(), txn); err != nil {
		t.Fatalf("save transaction: %v", err)
	}
	return txn
}

// incomeEntries builds a SimpleIncome pair (debit asset, credit income).
func incomeEntries(assetID, incomeID uuid.UUID, amount int64) []domain.TransactionEntry {
	return []domain.TransactionEntry{
		{AccountID: assetID, DebitCents: amount},
		{AccountID: incomeID, CreditCents: amount},
	}
}

// expenseEntries builds a SimpleExpense pair (debit expense, credit asset).
func expenseEntries(expenseID, assetID uuid.UUID, amount int64) []domain.TransactionEntry {
	return []domain.TransactionEntry{
		{AccountID: expenseID, DebitCents: amount},
		{AccountID: assetID, CreditCents: amount},
	}
}

// transferEntries builds a SimpleTransfer pair (debit toAsset, credit fromAsset).
func transferEntries(fromAssetID, toAssetID uuid.UUID, amount int64) []domain.TransactionEntry {
	return []domain.TransactionEntry{
		{AccountID: toAssetID, DebitCents: amount},
		{AccountID: fromAssetID, CreditCents: amount},
	}
}

// --- N+1 test ------------------------------------------------------------

// TestFindAll_NoNPlusOne_LoadsEntriesInConstantQueries asserts that FindAll
// issues a bounded number of SELECTs regardless of how many transactions are
// returned. Before the fix, each transaction triggered a separate entry query
// (1 + N). After the fix, entries are loaded in a single batched query.
func TestFindAll_NoNPlusOne_LoadsEntriesInConstantQueries(t *testing.T) {
	txnClient, queryCount, accDrv := setupCountingDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	// Account schema was migrated inside setupCountingDB on the raw driver.
	// Reuse that same physical DB (via the raw driver) for the account repo.
	accDrvClient := accountent.NewClient(accountent.Driver(accDrv))
	accRepo := accountrepo.NewAccountRepository(accDrvClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	// Seed 5 transactions, each with 2 entries.
	for i := 0; i < 5; i++ {
		recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, i), fmt.Sprintf("income %d", i),
			incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 1000))
	}

	// Reset counter, then run FindAll and measure SELECTs.
	queryCount.Store(0)
	res, err := txnRepo.FindAll(context.Background(), f.tenantID, domain.TransactionFilter{}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll: %v", err)
	}
	selects := queryCount.Load()

	if len(res.Items) != 5 {
		t.Fatalf("expected 5 transactions, got %d", len(res.Items))
	}
	// Every transaction must carry its entries (the point of eager loading).
	for i, tx := range res.Items {
		if len(tx.Entries) != 2 {
			t.Fatalf("transaction %d has %d entries, want 2 (eager load broken)", i, len(tx.Entries))
		}
	}

	// Contract: at most 3 SELECTs total (transactions list + entry batch +
	// optional count). The pre-fix N+1 code would issue 1 + len(items) = 6.
	const maxSelects = 3
	if selects > maxSelects {
		t.Errorf("N+1 regression: FindAll issued %d SELECTs for %d transactions, expected <= %d",
			selects, len(res.Items), maxSelects)
	}
	t.Logf("FindAll issued %d SELECTs for %d transactions", selects, len(res.Items))
}

// --- Type filter tests ---------------------------------------------------

func TestFindAll_TypeFilter_Income(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "salary", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 5000))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 1), "lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 2), "move", transferEntries(f.assetAcc.ID, f.assetAcc2.ID, 200))

	tp := domain.TransactionTypeIncome
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{Type: &tp}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll income: %v", err)
	}
	if len(res.Items) != 1 {
		t.Fatalf("expected 1 income transaction, got %d", len(res.Items))
	}
	if res.Items[0].Description != "salary" {
		t.Errorf("got %q, want salary", res.Items[0].Description)
	}
}

func TestFindAll_TypeFilter_Expense(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "salary", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 5000))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 1), "lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 2), "dinner", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 80))

	tp := domain.TransactionTypeExpense
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{Type: &tp}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll expense: %v", err)
	}
	if len(res.Items) != 2 {
		t.Fatalf("expected 2 expense transactions, got %d", len(res.Items))
	}
	got := []string{res.Items[0].Description, res.Items[1].Description}
	sort.Strings(got)
	if got[0] != "dinner" || got[1] != "lunch" {
		t.Errorf("got %v, want [dinner lunch]", got)
	}
}

func TestFindAll_TypeFilter_Transfer(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "salary", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 5000))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 1), "move", transferEntries(f.assetAcc.ID, f.assetAcc2.ID, 200))

	tp := domain.TransactionTypeTransfer
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{Type: &tp}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll transfer: %v", err)
	}
	if len(res.Items) != 1 {
		t.Fatalf("expected 1 transfer transaction, got %d", len(res.Items))
	}
	if res.Items[0].Description != "move" {
		t.Errorf("got %q, want move", res.Items[0].Description)
	}
}

// TestFindAll_TypeFilter_ExcludesIncomeWhenOnlyAssetTouched guards the
// transfer-vs-income boundary: a transaction whose entries only touch Asset
// accounts must NOT match the income filter (income requires an Income account).
func TestFindAll_TypeFilter_TransferNotIncome(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "move", transferEntries(f.assetAcc.ID, f.assetAcc2.ID, 200))

	income := domain.TransactionTypeIncome
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{Type: &income}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll income (should be empty): %v", err)
	}
	if len(res.Items) != 0 {
		t.Errorf("transfer leaked into income filter: got %d items", len(res.Items))
	}
}

// --- Regression tests (existing ListTransactions behavior) ---------------

func TestFindAll_AccountIDFilter_StillWorks(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "salary", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 5000))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 1), "lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	// incomeAcc only participates in the salary txn.
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{AccountID: &f.incomeAcc.ID}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll by account: %v", err)
	}
	if len(res.Items) != 1 || res.Items[0].Description != "salary" {
		t.Fatalf("expected only salary, got %+v", res.Items)
	}
}

func TestFindAll_DateFilter_StillWorks(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	jan1 := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	jan5 := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	jan10 := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, jan1, "a", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))
	recordTxn(t, txnRepo, f.tenantID, jan5, "b", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))
	recordTxn(t, txnRepo, f.tenantID, jan10, "c", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))

	from, to := jan1.AddDate(0, 0, 2), jan1.AddDate(0, 0, 6)
	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{DateFrom: &from, DateTo: &to}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll by date: %v", err)
	}
	if len(res.Items) != 1 || res.Items[0].Description != "b" {
		t.Fatalf("expected only 'b' in [jan3,jan7], got %+v", res.Items)
	}
}

func TestFindAll_Pagination_StillWorks(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 3; i++ {
		recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, i), fmt.Sprintf("t%d", i),
			incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))
	}

	page1, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{}, domain.PageRequest{PageSize: 2})
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if len(page1.Items) != 2 {
		t.Fatalf("expected 2 on page1, got %d", len(page1.Items))
	}
	if page1.NextPageToken == "" {
		t.Fatal("expected a next page token")
	}
	if page1.TotalCount != 3 {
		t.Errorf("total count: got %d, want 3", page1.TotalCount)
	}

	page2, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{}, domain.PageRequest{PageSize: 2, PageToken: page1.NextPageToken})
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(page2.Items) != 1 {
		t.Fatalf("expected 1 on page2, got %d", len(page2.Items))
	}
}

func TestFindAll_TenantIsolation_StillWorks(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	otherTenant := uuid.New()
	recordTxn(t, txnRepo, f.tenantID, time.Now(), "mine", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))
	recordTxn(t, txnRepo, otherTenant, time.Now(), "theirs", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 100))

	res, err := txnRepo.FindAll(context.Background(), f.tenantID,
		domain.TransactionFilter{}, domain.PageRequest{PageSize: 50})
	if err != nil {
		t.Fatalf("FindAll: %v", err)
	}
	if len(res.Items) != 1 || res.Items[0].Description != "mine" {
		t.Fatalf("tenant isolation broken: got %+v", res.Items)
	}
}

// --- FindRecentByAccount tests ------------------------------------------

// TestFindRecentByAccount_ReturnsSameAccountTransactions_OrderedDesc verifies
// that FindRecentByAccount returns transactions touching the given account,
// ordered by transaction_date DESC, and that entries are eager-loaded.
func TestFindRecentByAccount_ReturnsSameAccountTransactions_OrderedDesc(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	// Three expense txns (touching expenseAcc) at different dates...
	recordTxn(t, txnRepo, f.tenantID, base, "jan1 lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 5), "jan6 lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 60))
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 10), "jan11 lunch", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 70))
	// ...and one income txn that does NOT touch expenseAcc — must be excluded.
	recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 20), "salary", incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 5000))

	got, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 10)
	if err != nil {
		t.Fatalf("FindRecentByAccount: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 expense txns, got %d", len(got))
	}
	// DESC order: jan11, jan6, jan1.
	want := []string{"jan11 lunch", "jan6 lunch", "jan1 lunch"}
	for i, w := range want {
		if got[i].Description != w {
			t.Errorf("position %d: got %q, want %q", i, got[i].Description, w)
		}
	}
	// Entries must be eager-loaded (the point of the FindAll pattern).
	for i, tx := range got {
		if len(tx.Entries) != 2 {
			t.Fatalf("transaction %d (%q) has %d entries, want 2 (eager load broken)",
				i, tx.Description, len(tx.Entries))
		}
	}
}

// TestFindRecentByAccount_RespectsLimit verifies the limit parameter is honored.
func TestFindRecentByAccount_RespectsLimit(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 5; i++ {
		recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, i), fmt.Sprintf("lunch %d", i),
			expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	}

	got, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 2)
	if err != nil {
		t.Fatalf("FindRecentByAccount: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 txns (limit), got %d", len(got))
	}
	// The two newest: lunch 4 then lunch 3.
	if got[0].Description != "lunch 4" || got[1].Description != "lunch 3" {
		t.Errorf("limit+order: got %q, %q; want lunch 4, lunch 3",
			got[0].Description, got[1].Description)
	}
}

// TestFindRecentByAccount_TenantIsolation verifies cross-tenant rows are excluded.
func TestFindRecentByAccount_TenantIsolation(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	otherTenant := uuid.New()
	recordTxn(t, txnRepo, f.tenantID, time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		"mine", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	recordTxn(t, txnRepo, otherTenant, time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC),
		"theirs", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))

	got, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 10)
	if err != nil {
		t.Fatalf("FindRecentByAccount: %v", err)
	}
	if len(got) != 1 || got[0].Description != "mine" {
		t.Fatalf("tenant isolation broken: got %+v", got)
	}
}

// TestFindRecentByAccount_ExcludesSoftDeleted verifies soft-deleted transactions
// do not appear in the recent list.
func TestFindRecentByAccount_ExcludesSoftDeleted(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	live := recordTxn(t, txnRepo, f.tenantID, base, "live", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))
	deleted := recordTxn(t, txnRepo, f.tenantID, base.AddDate(0, 0, 1), "deleted",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 60))
	if err := txnRepo.SoftDelete(context.Background(), f.tenantID, deleted.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	got, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 10)
	if err != nil {
		t.Fatalf("FindRecentByAccount: %v", err)
	}
	if len(got) != 1 || got[0].ID != live.ID {
		t.Fatalf("soft-deleted leaked: got %+v", got)
	}
}

// TestFindRecentByAccount_LimitClamping verifies that limit <= 0 falls back to
// a sane default and that an oversized limit is capped.
func TestFindRecentByAccount_LimitClamping(t *testing.T) {
	txnClient, accClient := setupTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, nil)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)

	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, base, "a", expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50))

	// limit <= 0 → default (must return the one seeded txn, not error/empty).
	got, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 0)
	if err != nil {
		t.Fatalf("FindRecentByAccount limit=0: %v", err)
	}
	if len(got) != 1 {
		t.Errorf("limit=0 default: got %d, want 1", len(got))
	}

	// limit oversized (10000) → capped, still returns the one seeded txn cleanly.
	gotBig, err := txnRepo.FindRecentByAccount(context.Background(), f.tenantID, f.expenseAcc.ID, 10000)
	if err != nil {
		t.Fatalf("FindRecentByAccount limit=10000: %v", err)
	}
	if len(gotBig) != 1 {
		t.Errorf("limit=10000 capped: got %d, want 1", len(gotBig))
	}
}
