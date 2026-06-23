package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yucai/server/internal/transaction/domain"
)

// seedCrossMonthFixture seeds transactions spread across multiple days AND
// months within 2026 so DAY/MONTH/YEAR scope queries can verify grouping:
//   - Jan 5:  income salary 10000
//   - Jan 20: expense food   500
//   - Feb 8:  expense food   300
//   - Mar 1:  income salary  8000
//
// All seeded against the summaryFixture's tenant + accounts.
func seedCrossMonthFixture(t *testing.T, f summaryFixture) {
	t.Helper()
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 5, 12, 0, 0, 0, time.UTC),
		"jan salary", incomeEntries(f.cash.ID, f.salary.ID, 10000_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 20, 12, 0, 0, 0, time.UTC),
		"jan food", expenseEntries(f.food.ID, f.cash.ID, 500_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 2, 8, 12, 0, 0, 0, time.UTC),
		"feb food", expenseEntries(f.food.ID, f.cash.ID, 300_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 3, 1, 12, 0, 0, 0, time.UTC),
		"mar salary", incomeEntries(f.cash.ID, f.salary.ID, 8000_00))
}

// TestTransactionSummary_DayScope verifies DAY scope aggregates only that one
// day into a SINGLE bucket. The day's transactions must be summed together and
// no per-day breakdown beyond a single entry should appear in ByDay.
func TestTransactionSummary_DayScope(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)
	seedCrossMonthFixture(t, f)

	// Day scope Jan 20 (food expense 500). Only that day's txn survives.
	day20 := 20
	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026, Month: 1, Day: &day20,
		Scope: domain.ScopeDay,
	})
	require.NoError(t, err)

	// Only the Jan 20 food txn lives in [Jan 20 00:00, Jan 21 00:00).
	assert.Equal(t, int64(500_00), summary.ExpenseCents, "day scope: only Jan 20 expense")
	assert.Equal(t, int64(0), summary.IncomeCents, "day scope: no income on Jan 20")
	assert.Equal(t, int64(-500_00), summary.NetCents)

	// DAY scope produces a single bucket: one ByDay entry for the whole day.
	require.Len(t, summary.ByDay, 1, "DAY scope must aggregate into a single bucket")
	dayBucket := summary.ByDay[0]
	// The bucket date is normalized; verify it's the requested day.
	gotDay := dayBucket.Date.Truncate(24 * time.Hour)
	wantDay := time.Date(2026, 1, 20, 0, 0, 0, 0, time.UTC).Truncate(24 * time.Hour)
	assert.True(t, gotDay.Equal(wantDay), "bucket date: got %v want %v", dayBucket.Date, wantDay)
	// Category breakdown still works within the day bucket.
	require.Len(t, dayBucket.ByCategory, 1)
	assert.Equal(t, f.food.ID, dayBucket.ByCategory[0].AccountID)
	assert.Equal(t, int64(500_00), dayBucket.ByCategory[0].Amount)
}

// TestTransactionSummary_DayScope_MultipleTxnsSameDay verifies DAY scope
// aggregates multiple transactions on the same day into one bucket.
func TestTransactionSummary_DayScope_MultipleTxnsSameDay(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	// Two transactions on Jan 15: salary (income 7000) + food (expense 200).
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 15, 9, 0, 0, 0, time.UTC),
		"salary", incomeEntries(f.cash.ID, f.salary.ID, 7000_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 15, 14, 0, 0, 0, time.UTC),
		"lunch", expenseEntries(f.food.ID, f.cash.ID, 200_00))
	// A different day must NOT leak in.
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 16, 9, 0, 0, 0, time.UTC),
		"next day", expenseEntries(f.food.ID, f.cash.ID, 999_00))

	day15 := 15
	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026, Month: 1, Day: &day15,
		Scope: domain.ScopeDay,
	})
	require.NoError(t, err)

	assert.Equal(t, int64(7000_00), summary.IncomeCents)
	assert.Equal(t, int64(200_00), summary.ExpenseCents, "next-day txn must be excluded")
	require.Len(t, summary.ByDay, 1, "DAY scope must produce a single bucket")
	// Two categories: salary (income) + food (expense).
	assert.Len(t, summary.ByDay[0].ByCategory, 2)
}

// TestTransactionSummary_DayScope_NilDayErrors verifies the repo errors when
// scope is DAY but Day is nil (rather than silently producing a wrong window).
func TestTransactionSummary_DayScope_NilDayErrors(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	_, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026, Month: 1, Day: nil,
		Scope: domain.ScopeDay,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "day")
}

// TestTransactionSummary_MonthScopeGroupsByDay verifies MONTH scope still groups
// by day (no regression — existing behavior preserved). It selects Jan only and
// checks the per-day breakdown is intact.
func TestTransactionSummary_MonthScopeGroupsByDay(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)
	seedCrossMonthFixture(t, f)

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026, Month: 1,
		Scope: domain.ScopeMonth,
	})
	require.NoError(t, err)

	// Jan only: salary 10000 income, food 500 expense. Feb/Mar must be excluded.
	assert.Equal(t, int64(10000_00), summary.IncomeCents)
	assert.Equal(t, int64(500_00), summary.ExpenseCents)

	// MONTH groups by day: two active days (Jan 5 salary, Jan 20 food).
	require.Len(t, summary.ByDay, 2, "MONTH scope must group by day")
	wantDays := []int{5, 20}
	for i, d := range summary.ByDay {
		gotDay := d.Date.Truncate(24 * time.Hour)
		wantDay := time.Date(2026, 1, wantDays[i], 0, 0, 0, 0, time.UTC).Truncate(24 * time.Hour)
		assert.True(t, gotDay.Equal(wantDay), "day %d: got %v want %v", i, d.Date, wantDay)
	}
}

// TestTransactionSummary_MonthScopeDefault verifies that omitting Scope (zero
// value) still defaults to MONTH grouping (backward compatibility).
func TestTransactionSummary_MonthScopeDefault(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 5, 12, 0, 0, 0, time.UTC),
		"salary", incomeEntries(f.cash.ID, f.salary.ID, 1000_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 1, 10, 12, 0, 0, 0, time.UTC),
		"more salary", incomeEntries(f.cash.ID, f.salary.ID, 2000_00))

	// Scope omitted — defaults to MONTH grouping by day.
	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID, Year: 2026, Month: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(3000_00), summary.IncomeCents)
	require.Len(t, summary.ByDay, 2, "default scope = MONTH = group by day")
}

// TestTransactionSummary_YearScopeGroupsByMonth verifies YEAR scope groups by
// MONTH: Jan/Feb/Mar 2026 transactions appear as 3 buckets, with each bucket's
// date being the first of that month.
func TestTransactionSummary_YearScopeGroupsByMonth(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)
	seedCrossMonthFixture(t, f)

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026,
		Scope:    domain.ScopeYear,
	})
	require.NoError(t, err)

	// Year totals: income = 10000 (jan) + 8000 (mar) = 18000;
	//              expense = 500 (jan) + 300 (feb) = 800.
	assert.Equal(t, int64(18000_00), summary.IncomeCents)
	assert.Equal(t, int64(800_00), summary.ExpenseCents)

	// YEAR groups by month. Active months: Jan, Feb, Mar (3 buckets).
	require.Len(t, summary.ByDay, 3, "YEAR scope must group by month (3 active months)")
	wantMonths := []time.Month{time.January, time.February, time.March}
	for i, d := range summary.ByDay {
		// Each bucket's date is the first day of its month.
		assert.Equal(t, wantMonths[i], d.Date.Month(), "bucket %d month", i)
		assert.Equal(t, 1, d.Date.Day(), "bucket %d day-of-month", i)
		assert.Equal(t, 2026, d.Date.Year(), "bucket %d year", i)
	}

	// Jan bucket: salary 10000 (income), food 500 (expense).
	janBucket := summary.ByDay[0]
	assert.Equal(t, int64(10000_00), janBucket.TotalIncome)
	require.Len(t, janBucket.ByCategory, 2, "Jan: 2 categories (salary + food)")

	// Feb bucket: food 300 (expense), no income.
	febBucket := summary.ByDay[1]
	assert.Equal(t, int64(0), febBucket.TotalIncome)
	require.Len(t, febBucket.ByCategory, 1)
	assert.Equal(t, f.food.ID, febBucket.ByCategory[0].AccountID)
	assert.Equal(t, int64(300_00), febBucket.ByCategory[0].Amount)

	// Mar bucket: salary 8000 (income).
	marBucket := summary.ByDay[2]
	assert.Equal(t, int64(8000_00), marBucket.TotalIncome)
	require.Len(t, marBucket.ByCategory, 1)
	assert.Equal(t, f.salary.ID, marBucket.ByCategory[0].AccountID)
	assert.Equal(t, int64(8000_00), marBucket.ByCategory[0].Amount)
}

// TestTransactionSummary_YearScope_ExcludesOtherYears verifies YEAR scope only
// picks up the requested year.
func TestTransactionSummary_YearScope_ExcludesOtherYears(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	// 2026 income and 2025 income.
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC),
		"2026 salary", incomeEntries(f.cash.ID, f.salary.ID, 6000_00))
	recordTxn(t, f.txnRepo, f.tenantID, time.Date(2025, 6, 15, 12, 0, 0, 0, time.UTC),
		"2025 salary", incomeEntries(f.cash.ID, f.salary.ID, 4000_00))

	summary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID: f.tenantID,
		Year:     2026,
		Scope:    domain.ScopeYear,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(6000_00), summary.IncomeCents, "2025 must be excluded")
	require.Len(t, summary.ByDay, 1, "only 2026 month should appear")
}
