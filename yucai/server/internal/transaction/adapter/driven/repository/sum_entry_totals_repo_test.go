package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	"github.com/yucai/server/internal/transaction/adapter/driven/repository"
	"github.com/yucai/server/internal/transaction/domain"
)

// newSumRepoFixture wires the shared in-memory DB (with raw *sql.DB so the
// aggregation query can run), seeds the standard account fixture, and returns
// the ready-to-use repos plus the fixture accounts.
func newSumRepoFixture(t *testing.T) (fixture, *repository.TransactionRepository) {
	t.Helper()
	txnClient, accClient, db := setupSummaryTestDB(t)
	txnRepo := repository.NewTransactionRepository(txnClient, db)
	accRepo := accountrepo.NewAccountRepository(accClient)
	f := seedFixture(t, accRepo, txnRepo)
	return f, txnRepo
}

// TestSumEntryTotalsByAccount_SumsDebitAndCredit verifies the repo aggregation
// returns the period's debit total (spend) and credit total (refunds) for the
// given account, scoped by transaction_date in [from, to] and excluding
// out-of-window rows. Budget actuals consume this: budget items track Expense
// accounts (= categories), so an item's spend is the debit total.
func TestSumEntryTotalsByAccount_SumsDebitAndCredit(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	jan1 := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	jan15 := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	feb1 := time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)

	// Two January expenses on the Food account: ¥500 + ¥300 debit legs.
	recordTxn(t, txnRepo, f.tenantID, jan1, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	recordTxn(t, txnRepo, f.tenantID, jan15, "groceries",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 30000))
	// A February expense that must be EXCLUDED by the date window.
	recordTxn(t, txnRepo, f.tenantID, feb1, "next-month lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 99999))

	// Window covers January only.
	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	debit, credit, err := txnRepo.SumEntryTotalsByAccount(context.Background(), f.expenseAcc.ID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByAccount: %v", err)
	}
	if debit != 80000 {
		t.Errorf("debit total: got %d, want 80000", debit)
	}
	if credit != 0 {
		t.Errorf("credit total: got %d, want 0", credit)
	}
}

// TestSumEntryTotalsByAccount_IncludesRefundAsCredit verifies that a refund
// (credit leg on an Expense account) is returned as the credit total, separate
// from the debit spend. Budget actuals subtract refunds from spend.
func TestSumEntryTotalsByAccount_IncludesRefundAsCredit(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	date := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	// Spend ¥500 on Food (debit on expense).
	recordTxn(t, txnRepo, f.tenantID, date, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	// Refund ¥50 to Food: reverse-style entry (credit on expense, debit on asset).
	recordTxn(t, txnRepo, f.tenantID, date, "refund",
		[]domain.TransactionEntry{
			{AccountID: f.expenseAcc.ID, CreditCents: 5000},
			{AccountID: f.assetAcc.ID, DebitCents: 5000},
		})

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	debit, credit, err := txnRepo.SumEntryTotalsByAccount(context.Background(), f.expenseAcc.ID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByAccount: %v", err)
	}
	if debit != 50000 {
		t.Errorf("debit total: got %d, want 50000", debit)
	}
	if credit != 5000 {
		t.Errorf("credit total: got %d, want 5000", credit)
	}
}

// TestSumEntryTotalsByAccount_ExcludesSoftDeleted verifies that soft-deleted
// transactions do not contribute to the totals.
func TestSumEntryTotalsByAccount_ExcludesSoftDeleted(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	date := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, date, "live",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	deleted := recordTxn(t, txnRepo, f.tenantID, date, "deleted",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 30000))
	if err := txnRepo.SoftDelete(context.Background(), f.tenantID, deleted.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	debit, _, err := txnRepo.SumEntryTotalsByAccount(context.Background(), f.expenseAcc.ID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByAccount: %v", err)
	}
	if debit != 50000 {
		t.Errorf("debit total: got %d, want 50000 (soft-deleted leaked)", debit)
	}
}

// TestSumEntryTotalsByAccount_TransfersExcludedAutomatically verifies the
// account-as-category invariant: a transfer (asset→asset) never touches the
// Expense account, so it contributes 0 to the Expense account's totals without
// any explicit TransactionType filter. This is why the repo applies no type
// filter (it would be redundant).
func TestSumEntryTotalsByAccount_TransfersExcludedAutomatically(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	date := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	// A transfer between two asset accounts — no entry touches expenseAcc.
	recordTxn(t, txnRepo, f.tenantID, date, "move",
		transferEntries(f.assetAcc.ID, f.assetAcc2.ID, 20000))

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	debit, credit, err := txnRepo.SumEntryTotalsByAccount(context.Background(), f.expenseAcc.ID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByAccount: %v", err)
	}
	if debit != 0 || credit != 0 {
		t.Errorf("transfer leaked into expense totals: debit=%d credit=%d, want 0/0", debit, credit)
	}
}

// TestSumEntryTotalsByAccount_EmptyReturnsZero verifies that an account with no
// matching entries returns (0, 0, nil) rather than erroring (COALESCE in the
// SQL keeps NULL aggregates as 0).
func TestSumEntryTotalsByAccount_EmptyReturnsZero(t *testing.T) {
	_, txnRepo := newSumRepoFixture(t)

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	debit, credit, err := txnRepo.SumEntryTotalsByAccount(context.Background(), uuid.New(), from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByAccount empty: %v", err)
	}
	if debit != 0 || credit != 0 {
		t.Errorf("empty account: got debit=%d credit=%d, want 0/0", debit, credit)
	}
}

// TestSumEntryTotalsByMonth_GroupsByAccount verifies the repo returns one
// debit/credit total per account for entries in [from, to]. Budget batch
// actuals consume this: one query per month fills every item (replaces N×M
// per-item SumEntryTotalsByAccount calls).
func TestSumEntryTotalsByMonth_GroupsByAccount(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	jan10 := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	// Food expense ¥500 (debit on expense, credit on asset).
	recordTxn(t, txnRepo, f.tenantID, jan10, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	// Salary income ¥10000 (debit on asset, credit on income).
	recordTxn(t, txnRepo, f.tenantID, jan10, "salary",
		incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 1000000))

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	// Expense account: debit 50000 (spend), credit 0.
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 || got.CreditCents != 0 {
		t.Errorf("expense account: got debit=%d credit=%d, want 50000/0", got.DebitCents, got.CreditCents)
	}
	// Income account: credit 1000000 (salary), debit 0.
	if got := totals[f.incomeAcc.ID]; got.DebitCents != 0 || got.CreditCents != 1000000 {
		t.Errorf("income account: got debit=%d credit=%d, want 0/1000000", got.DebitCents, got.CreditCents)
	}
	// Asset account legs: debit=salary leg 1000000, credit=lunch leg 50000.
	if got := totals[f.assetAcc.ID]; got.DebitCents != 1000000 || got.CreditCents != 50000 {
		t.Errorf("asset account: got debit=%d credit=%d, want 1000000/50000", got.DebitCents, got.CreditCents)
	}
}

// TestSumEntryTotalsByMonth_TenantScopedAndDateFiltered verifies both the
// tenant_id WHERE and the date window: a February entry and another tenant's
// January entry do not contribute (even when the entry's account_id matches).
func TestSumEntryTotalsByMonth_TenantScopedAndDateFiltered(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	jan10 := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	feb10 := time.Date(2026, 2, 10, 0, 0, 0, 0, time.UTC)
	// In-window January spend by the fixture tenant.
	recordTxn(t, txnRepo, f.tenantID, jan10, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	// Out-of-window February spend by the fixture tenant (date filter excludes).
	recordTxn(t, txnRepo, f.tenantID, feb10, "feb lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 99999))
	// January spend by ANOTHER tenant on the same expense account (tenant filter
	// excludes — the whole txn is dropped despite matching account_id).
	recordTxn(t, txnRepo, uuid.New(), jan10, "other-tenant lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 77777))

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 {
		t.Errorf("expense debit: got %d, want 50000 (feb/other-tenant leaked)", got.DebitCents)
	}
}

// TestSumEntryTotalsByMonth_ExcludesSoftDeleted verifies that soft-deleted
// transactions do not contribute (same deleted_at IS NULL guard as
// SumEntryTotalsByAccount).
func TestSumEntryTotalsByMonth_ExcludesSoftDeleted(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	date := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, date, "live",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	deleted := recordTxn(t, txnRepo, f.tenantID, date, "deleted",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 30000))
	if err := txnRepo.SoftDelete(context.Background(), f.tenantID, deleted.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 {
		t.Errorf("expense debit: got %d, want 50000 (soft-deleted leaked)", got.DebitCents)
	}
}

// TestSumEntryTotalsByMonth_EmptyReturnsEmptyMap verifies that a tenant/month
// with no activity returns an empty (non-nil) map, not an error.
func TestSumEntryTotalsByMonth_EmptyReturnsEmptyMap(t *testing.T) {
	_, txnRepo := newSumRepoFixture(t)

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), uuid.New(), from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth empty: %v", err)
	}
	if totals == nil {
		t.Fatal("empty result: got nil map, want non-nil empty map")
	}
	if len(totals) != 0 {
		t.Errorf("empty tenant: got %d accounts, want 0", len(totals))
	}
}
