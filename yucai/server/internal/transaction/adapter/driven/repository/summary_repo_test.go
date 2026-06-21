package repository_test

import (
	"context"
	"database/sql"
	"strings"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/transaction/adapter/driven/repository"
	"github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// setupSummaryTestDB opens a shared in-memory SQLite DB and migrates both the
// transaction and account schemas against it (same shared-DB pattern as
// setupTestDB), but additionally returns the raw *sql.DB so the repo's
// TransactionSummary aggregation query can run.
func setupSummaryTestDB(t *testing.T) (*txnent.Client, *accountent.Client, *sql.DB) {
	t.Helper()
	dbName := "txn_summary_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	require.NoError(t, err)
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB("sqlite3", db)
	txnClient := txnent.NewClient(txnent.Driver(drv))
	require.NoError(t, txnClient.Schema.Create(context.Background()))
	accountClient := accountent.NewClient(accountent.Driver(drv))
	require.NoError(t, accountClient.Schema.Create(context.Background()))
	t.Cleanup(func() {
		_ = txnClient.Close()
		_ = accountClient.Close()
	})
	return txnClient, accountClient, db
}

// summaryFixture seeds a richer account set for summary aggregation: two income
// accounts (Salary, Interest), two expense accounts (Food, Transport), and an
// asset account (Cash) that acts as the counterpart leg.
type summaryFixture struct {
	tenantID  uuid.UUID
	cash      *accountdomain.Account
	salary    *accountdomain.Account
	interest  *accountdomain.Account
	food      *accountdomain.Account
	transport *accountdomain.Account
	bank      *accountdomain.Account
	accRepo   *accountrepo.AccountRepository
	txnRepo   *repository.TransactionRepository
}

func seedSummaryFixture(t *testing.T, txnClient *txnent.Client, accClient *accountent.Client, db *sql.DB) summaryFixture {
	t.Helper()
	txnRepo := repository.NewTransactionRepository(txnClient, db)
	accRepo := accountrepo.NewAccountRepository(accClient)
	tenantID := uuid.New()

	mk := func(name string, at accountdomain.AccountType) *accountdomain.Account {
		return saveAccount(t, accRepo, tenantID, name, at)
	}

	return summaryFixture{
		tenantID:  tenantID,
		cash:      mk("Cash", accountdomain.AccountTypeAsset),
		bank:      mk("Bank", accountdomain.AccountTypeAsset),
		salary:    mk("Salary", accountdomain.AccountTypeIncome),
		interest:  mk("Interest", accountdomain.AccountTypeIncome),
		food:      mk("Food", accountdomain.AccountTypeExpense),
		transport: mk("Transport", accountdomain.AccountTypeExpense),
		accRepo:   accRepo,
		txnRepo:   txnRepo,
	}
}

// TestTransactionSummary_AggregatesIncomeExpenseByDayAndCategory is the core
// TDD test: given several transactions across a month (salary, interest, food,
// transport, and an asset→asset transfer that must contribute zero), the
// summary must report correct month totals, per-day totals, and per-category
// breakdown. It also verifies DailyAvg = total / distinct active days.
func TestTransactionSummary_AggregatesIncomeExpenseByDayAndCategory(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	jan := func(day int) time.Time { return time.Date(2026, 1, day, 12, 0, 0, 0, time.UTC) }
	// Day 1: salary 10000 (income), food 50 (expense)
	recordTxn(t, f.txnRepo, f.tenantID, jan(1), "salary", incomeEntries(f.cash.ID, f.salary.ID, 10000_00))
	recordTxn(t, f.txnRepo, f.tenantID, jan(1), "food", expenseEntries(f.food.ID, f.cash.ID, 50_00))
	// Day 1: interest 200 (income, different income account)
	recordTxn(t, f.txnRepo, f.tenantID, jan(1), "interest", incomeEntries(f.cash.ID, f.interest.ID, 200_00))
	// Day 5: transport 120 (expense)
	recordTxn(t, f.txnRepo, f.tenantID, jan(5), "transport", expenseEntries(f.transport.ID, f.cash.ID, 120_00))
	// Day 10: a transfer cash→bank 5000 — must NOT count as income or expense.
	recordTxn(t, f.txnRepo, f.tenantID, jan(10), "move", transferEntries(f.cash.ID, f.bank.ID, 5000_00))

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1,
	})
	require.NoError(t, err)

	// Month totals: income = 10000 + 200 = 10200; expense = 50 + 120 = 170.
	assert.Equal(t, int64(10200_00), summary.IncomeCents)
	assert.Equal(t, int64(170_00), summary.ExpenseCents)
	assert.Equal(t, int64(10200_00-170_00), summary.NetCents)
	// 3 active days (1, 5, 10). DailyAvg of NET = (10200 - 170) / 3.
	assert.Equal(t, int64((10200_00-170_00)/3), summary.DailyAvgCents)

	// ByDay: days present, ordered ascending; transfer day has zero income/expense.
	require.Len(t, summary.ByDay, 3, "expected 3 active days (transfer day counts as activity)")
	wantDates := []time.Time{jan(1), jan(5), jan(10)}
	for i, d := range summary.ByDay {
		// Days are normalized to midnight UTC by substr extraction.
		gotDay := d.Date.Truncate(24 * time.Hour)
		wantDay := wantDates[i].Truncate(24 * time.Hour)
		assert.True(t, gotDay.Equal(wantDay), "day %d: got %v want %v", i, d.Date, wantDates[i])
	}

	// Day 1 breakdown: 2 income categories (salary 10000, interest 200), 1 expense (food 50).
	day1 := summary.ByDay[0]
	assert.Equal(t, int64(10200_00), day1.TotalIncome)
	// categories: salary, interest (income) + food (expense) = 3 items
	assert.Len(t, day1.ByCategory, 3)

	byAcc := map[uuid.UUID]int64{}
	for _, c := range day1.ByCategory {
		byAcc[c.AccountID] = c.Amount
	}
	assert.Equal(t, int64(10000_00), byAcc[f.salary.ID], "salary category amount")
	assert.Equal(t, int64(200_00), byAcc[f.interest.ID], "interest category amount")
	assert.Equal(t, int64(50_00), byAcc[f.food.ID], "food category amount")

	// Day 5: transport only.
	day5 := summary.ByDay[1]
	assert.Equal(t, int64(0), day5.TotalIncome)
	require.Len(t, day5.ByCategory, 1)
	assert.Equal(t, f.transport.ID, day5.ByCategory[0].AccountID)
	assert.Equal(t, int64(120_00), day5.ByCategory[0].Amount)
	assert.Equal(t, "expense", day5.ByCategory[0].AccountType)
	assert.Equal(t, "Transport", day5.ByCategory[0].Name)

	// Day 10: transfer contributes 0 income and 0 expense but still appears as a
	// day with activity (it had entries in the month). ByCategory is empty.
	day10 := summary.ByDay[2]
	assert.Equal(t, int64(0), day10.TotalIncome)
	assert.Empty(t, day10.ByCategory)
}

// TestTransactionSummary_AccountScope narrows to a single account and verifies
// only that account's income/expense legs are counted.
func TestTransactionSummary_AccountScope(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	jan := func(day int) time.Time { return time.Date(2026, 1, day, 12, 0, 0, 0, time.UTC) }
	recordTxn(t, f.txnRepo, f.tenantID, jan(1), "salary", incomeEntries(f.cash.ID, f.salary.ID, 1000_00))
	recordTxn(t, f.txnRepo, f.tenantID, jan(2), "food", expenseEntries(f.food.ID, f.cash.ID, 50_00))

	// Scope to salary account: only the salary leg is counted (1000 income).
	salaryID := f.salary.ID
	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1, AccountID: &salaryID,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(1000_00), summary.IncomeCents)
	assert.Equal(t, int64(0), summary.ExpenseCents)
}

// TestTransactionSummary_AccountScopeAggregatesCounterpartyLegs guards the
// A1 subquery fix: when scope.AccountID points at an asset account, the
// aggregation must cover the counterparty income/expense legs of every
// transaction that touches that asset. The pre-fix clause
// "(? IS NULL OR e.account_id = ?)" filtered entry rows directly, so only the
// asset's own leg survived — and since the CASE returns 0 for asset accounts,
// the account-detail page's "this month income/expense" was dead-data 0.
//
// Scenario: 1 asset (Cash) + 1 expense (Food) + one 100.00 food txn
// (Food debit 10000 / Cash credit 10000). Scope to Cash → the fix preserves
// the Food leg, so ExpenseCents = 10000 and NetCents = -10000.
func TestTransactionSummary_AccountScopeAggregatesCounterpartyLegs(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	now := time.Now()
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(now.Year(), now.Month(), 15, 12, 0, 0, 0, time.UTC),
		"lunch", expenseEntries(f.food.ID, f.cash.ID, 10000))

	cashID := f.cash.ID
	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID:  f.tenantID,
		Year:      now.Year(),
		Month:     int(now.Month()),
		AccountID: &cashID,
	})
	require.NoError(t, err)

	// Counterparty Food leg (expense debit 10000) must survive the asset-scope filter.
	assert.Equal(t, int64(10000), summary.ExpenseCents,
		"scope to asset: expense must aggregate counterparty Food leg, not 0")
	assert.Equal(t, int64(-10000), summary.NetCents,
		"scope to asset: net = income - expense = 0 - 10000")
}

// TestTransactionSummary_MonthIsolation verifies only the queried month is
// included (a transaction in a different month is excluded).
func TestTransactionSummary_MonthIsolation(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC),
		"jan salary", incomeEntries(f.cash.ID, f.salary.ID, 5000_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 2, 15, 12, 0, 0, 0, time.UTC),
		"feb salary", incomeEntries(f.cash.ID, f.salary.ID, 7000_00))

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(5000_00), summary.IncomeCents, "feb salary must be excluded from Jan summary")
}

// TestTransactionSummary_TenantIsolation verifies cross-tenant rows are excluded.
func TestTransactionSummary_TenantIsolation(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	other := uuid.New()
	recordTxn(t, f.txnRepo, other, time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC),
		"theirs", incomeEntries(f.cash.ID, f.salary.ID, 9999_00))

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(0), summary.IncomeCents)
	assert.Empty(t, summary.ByDay)
}

// TestTransactionSummary_ExcludesSoftDeleted verifies soft-deleted transactions
// do not contribute to the summary.
func TestTransactionSummary_ExcludesSoftDeleted(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	live := recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC),
		"live", incomeEntries(f.cash.ID, f.salary.ID, 1000_00))
	deleted := recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 2, 12, 0, 0, 0, time.UTC),
		"deleted", incomeEntries(f.cash.ID, f.salary.ID, 4000_00))
	require.NoError(t, f.txnRepo.SoftDelete(context.Background(), f.tenantID, deleted.ID))

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(1000_00), summary.IncomeCents)
	require.Len(t, summary.ByDay, 1)
	assert.Equal(t, live.Entries[0].AccountID, f.cash.ID) // sanity: live txn's cash leg
}
