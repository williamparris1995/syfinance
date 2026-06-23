package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yucai/server/internal/transaction/domain"
)

// TestTransactionSummary_AccountScope_DayAndYearNonzero reproduces the
// account_detail page regression: under DAY and YEAR scope the pie chart
// disappears (total=0) even though the seeded transactions touch the scoped
// account within the period. MONTH scope already works (covered separately);
// this test pins DAY and YEAR so a regression that zeros either is caught.
//
// Data shape mirrors production: transaction_date is stored at UTC midnight
// (the gRPC handler parses "YYYY-MM-DD" via time.Parse which yields UTC), and
// the scope targets a Cash asset account whose counterparty legs carry the
// income/expense.
func TestTransactionSummary_AccountScope_DayAndYearNonzero(t *testing.T) {
	txnClient, accClient, db := setupSummaryTestDB(t)
	f := seedSummaryFixture(t, txnClient, accClient, db)

	// Seed spanning 2026: one day in June (expense) + one day in March (income),
	// both touching Cash. transaction_date = UTC midnight of that calendar day,
	// matching what the gRPC RecordExpense/Income handlers persist.
	jun23 := time.Date(2026, 6, 23, 0, 0, 0, 0, time.UTC)
	mar5 := time.Date(2026, 3, 5, 0, 0, 0, 0, time.UTC)
	recordTxn(t, f.txnRepo, f.tenantID, jun23, "lunch",
		expenseEntries(f.food.ID, f.cash.ID, 286_00))
	recordTxn(t, f.txnRepo, f.tenantID, mar5, "salary",
		incomeEntries(f.cash.ID, f.salary.ID, 15000_00))

	cashID := f.cash.ID

	// DAY scope (Jun 23) — account-scoped to Cash. The expense counterparty
	// (Food) leg must aggregate: ExpenseCents = 286, IncomeCents = 0.
	day23 := 23
	daySummary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID:  f.tenantID,
		Year:      2026, Month: 6, Day: &day23,
		Scope:     domain.ScopeDay,
		AccountID: &cashID,
	})
	require.NoError(t, err)
	assert.NotZero(t, daySummary.ExpenseCents,
		"account-scope DAY: expense must aggregate counterparty Food leg (got %d)", daySummary.ExpenseCents)
	assert.Equal(t, int64(286_00), daySummary.ExpenseCents,
		"account-scope DAY expense = 286")
	assert.Zero(t, daySummary.IncomeCents, "no income on Jun 23")

	// YEAR scope (2026) — account-scoped to Cash. Both legs aggregate:
	// income 15000 (Mar salary) + expense 286 (Jun food).
	yearSummary, err := f.txnRepo.TransactionSummary(context.Background(), domain.SummaryScope{
		TenantID:  f.tenantID,
		Year:      2026,
		Scope:     domain.ScopeYear,
		AccountID: &cashID,
	})
	require.NoError(t, err)
	assert.NotZero(t, yearSummary.IncomeCents,
		"account-scope YEAR: income must aggregate counterparty Salary leg (got %d)", yearSummary.IncomeCents)
	assert.Equal(t, int64(15000_00), yearSummary.IncomeCents, "account-scope YEAR income = 15000")
	assert.NotZero(t, yearSummary.ExpenseCents,
		"account-scope YEAR: expense must aggregate counterparty Food leg (got %d)", yearSummary.ExpenseCents)
	assert.Equal(t, int64(286_00), yearSummary.ExpenseCents, "account-scope YEAR expense = 286")
}
