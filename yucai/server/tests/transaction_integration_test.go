package tests

import (
	"context"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"database/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txndomain "github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

func setupTransactionTestDB(t *testing.T) (*accountent.Client, *txnent.Client) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:txn_ent?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)

	acctClient := accountent.NewClient(accountent.Driver(drv))
	txnClient := txnent.NewClient(txnent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := txnClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create transaction schema: %v", err)
	}

	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { txnClient.Close() })
	return acctClient, txnClient
}

func setupTransactionTestService(t *testing.T) (accountapp.Service, *txnapp.Service) {
	t.Helper()
	acctClient, txnClient := setupTransactionTestDB(t)
	ar := accountrepo.NewAccountRepository(acctClient)
	cr := accountrepo.NewChartRepository(acctClient)
	acctSvc := *accountapp.NewService(ar, cr)

	txnRepo := txnrepo.NewTransactionRepository(txnClient, nil)
	bu := txnbalance.NewBalanceUpdater(ar)
	txnSvc := txnapp.NewService(txnRepo, ar, bu, nil)
	return acctSvc, txnSvc
}

func createTestAccounts(t *testing.T, ctx context.Context, acctSvc accountapp.Service, tenantID uuid.UUID) (assetID, expenseID, incomeID uuid.UUID) {
	t.Helper()
	asset, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Cash",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create asset account: %v", err)
	}
	expense, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Food",
		AccountType:  accountdomain.AccountTypeExpense,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create expense account: %v", err)
	}
	income, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Salary",
		AccountType:  accountdomain.AccountTypeIncome,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create income account: %v", err)
	}
	return asset.ID, expense.ID, income.ID
}

func TestRecordTransaction(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	txn, err := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Monthly salary",
		Entries: []txnapp.EntryInput{
			{AccountID: assetID, DebitCents: 100000},
			{AccountID: incomeID, CreditCents: 100000},
		},
	})
	if err != nil {
		t.Fatalf("RecordTransaction failed: %v", err)
	}
	if txn.Version != 1 {
		t.Errorf("expected version 1, got %d", txn.Version)
	}
	if len(txn.Entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(txn.Entries))
	}

	// Verify balance updated: asset account increased by 100000 cents (1000.00)
	asset, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 100000 {
		t.Errorf("expected asset balance 100000, got %d", asset.CurrentBalanceCents)
	}
}

func TestDoubleEntryValidation(t *testing.T) {
	_, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	_, err := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Unbalanced",
		Entries: []txnapp.EntryInput{
			{AccountID: uuid.New(), DebitCents: 1000},
			{AccountID: uuid.New(), CreditCents: 500},
		},
	})
	if err == nil {
		t.Error("expected error for unbalanced entries")
	}
}

func TestSimpleIncome(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	txn, err := txnSvc.SimpleIncome(ctx, txnapp.SimpleIncomeRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Salary deposit",
		AssetAccountID:  assetID,
		IncomeAccountID: incomeID,
		AmountCents:     50000,
	})
	if err != nil {
		t.Fatalf("SimpleIncome failed: %v", err)
	}
	if len(txn.Entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(txn.Entries))
	}
	// Verify: debit asset, credit income
	var foundDebit, foundCredit bool
	for _, e := range txn.Entries {
		if e.AccountID == assetID && e.DebitCents == 50000 {
			foundDebit = true
		}
		if e.AccountID == incomeID && e.CreditCents == 50000 {
			foundCredit = true
		}
	}
	if !foundDebit {
		t.Error("expected debit entry on asset account")
	}
	if !foundCredit {
		t.Error("expected credit entry on income account")
	}

	// Balance: asset increases by 50000
	asset, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 50000 {
		t.Errorf("expected asset balance 50000, got %d", asset.CurrentBalanceCents)
	}
}

func TestSimpleExpense(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, expenseID, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	// First add some money to the asset
	_, err := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Initial deposit",
		Entries:         txnapp.BuildSimpleEntries(100000, assetID, incomeID, ""),
	})
	if err != nil {
		t.Fatalf("initial deposit: %v", err)
	}

	txn, err := txnSvc.SimpleExpense(ctx, txnapp.SimpleExpenseRequest{
		TenantID:         tenantID,
		TransactionDate:  time.Now(),
		Description:      "Lunch",
		ExpenseAccountID: expenseID,
		AssetAccountID:   assetID,
		AmountCents:      3000,
	})
	if err != nil {
		t.Fatalf("SimpleExpense failed: %v", err)
	}
	if len(txn.Entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(txn.Entries))
	}

	// Balance: asset decreased by 3000 → 100000 - 3000 = 97000
	asset, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 97000 {
		t.Errorf("expected asset balance 97000, got %d", asset.CurrentBalanceCents)
	}
}

func TestSimpleTransfer(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	// Create second asset account (bank)
	bank, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Bank",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create bank account: %v", err)
	}

	// Deposit into cash first (incomeID grounds the credit leg — required by the
	// entry ownership check; a random uuid would now be rejected as cross-tenant).
	_, err = txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantID, TransactionDate: time.Now(), Description: "Initial",
		Entries: txnapp.BuildSimpleEntries(200000, assetID, incomeID, ""),
	})
	if err != nil {
		t.Fatalf("initial deposit: %v", err)
	}

	// Transfer cash → bank
	_, err = txnSvc.SimpleTransfer(ctx, txnapp.SimpleTransferRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Cash to bank",
		FromAccountID:   assetID,
		ToAccountID:     bank.ID,
		AmountCents:     50000,
	})
	if err != nil {
		t.Fatalf("SimpleTransfer failed: %v", err)
	}

	// Verify: cash decreased, bank increased
	cash, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	bankAcct, _ := acctSvc.GetAccount(ctx, tenantID, bank.ID)
	if cash.CurrentBalanceCents != 150000 {
		t.Errorf("expected cash balance 150000, got %d", cash.CurrentBalanceCents)
	}
	if bankAcct.CurrentBalanceCents != 50000 {
		t.Errorf("expected bank balance 50000, got %d", bankAcct.CurrentBalanceCents)
	}
}

func TestDeleteReversesBalance(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	// Record income
	txn, _ := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantID, TransactionDate: time.Now(), Description: "Salary",
		Entries: txnapp.BuildSimpleEntries(100000, assetID, incomeID, ""),
	})

	// Verify balance is 100000
	asset, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 100000 {
		t.Fatalf("pre-delete: expected 100000, got %d", asset.CurrentBalanceCents)
	}

	// Delete
	err := txnSvc.DeleteTransaction(ctx, tenantID, txn.ID)
	if err != nil {
		t.Fatalf("DeleteTransaction failed: %v", err)
	}

	// Verify balance reversed to 0
	asset, _ = acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 0 {
		t.Errorf("post-delete: expected 0, got %d", asset.CurrentBalanceCents)
	}

	// Verify transaction is gone
	_, err = txnSvc.GetTransaction(ctx, tenantID, txn.ID)
	if err == nil {
		t.Error("expected error for deleted transaction")
	}
}

func TestUpdateTransaction(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	// Record initial
	txn, _ := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantID, TransactionDate: time.Now(), Description: "Salary",
		Entries: txnapp.BuildSimpleEntries(100000, assetID, incomeID, ""),
	})

	// Update with new amount
	updated, err := txnSvc.UpdateTransaction(ctx, txnapp.UpdateTransactionRequest{
		TenantID:        tenantID,
		TransactionID:   txn.ID,
		TransactionDate: time.Now(),
		Description:     "Salary corrected",
		Entries:         txnapp.BuildSimpleEntries(80000, assetID, incomeID, ""),
		Version:         1,
	})
	if err != nil {
		t.Fatalf("UpdateTransaction failed: %v", err)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}
	if updated.Description != "Salary corrected" {
		t.Errorf("expected updated description, got %s", updated.Description)
	}

	// Balance should be 80000 (was reversed from 100000, then applied 80000)
	asset, _ := acctSvc.GetAccount(ctx, tenantID, assetID)
	if asset.CurrentBalanceCents != 80000 {
		t.Errorf("expected asset balance 80000, got %d", asset.CurrentBalanceCents)
	}
}

func TestUpdateOptimisticLock(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	txn, _ := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantID, TransactionDate: time.Now(), Description: "Salary",
		Entries: txnapp.BuildSimpleEntries(100000, assetID, incomeID, ""),
	})

	// Update with wrong version
	_, err := txnSvc.UpdateTransaction(ctx, txnapp.UpdateTransactionRequest{
		TenantID:      tenantID,
		TransactionID: txn.ID,
		Version:       999,
	})
	if err == nil {
		t.Error("expected optimistic lock error")
	}
}

func TestDateRangeFilter(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()
	assetID, _, incomeID := createTestAccounts(t, ctx, acctSvc, tenantID)

	// Create transactions on different dates
	dates := []time.Time{
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 3, 15, 0, 0, 0, 0, time.UTC),
	}
	for _, d := range dates {
		txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
			TenantID: tenantID, TransactionDate: d, Description: "Income",
			Entries: txnapp.BuildSimpleEntries(10000, assetID, incomeID, ""),
		})
	}

	// Filter: only February
	from := time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 2, 28, 0, 0, 0, 0, time.UTC)
	result, err := txnSvc.ListTransactions(ctx, txnapp.ListTransactionsRequest{
		TenantID: tenantID,
		Filter:   txndomain.TransactionFilter{DateFrom: &from, DateTo: &to},
		PageRequest: txndomain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListTransactions with filter failed: %v", err)
	}
	if result.TotalCount != 1 {
		t.Errorf("expected 1 transaction in Feb, got %d", result.TotalCount)
	}
}

func TestTenantIsolation(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	// Create accounts for tenant A
	assetA, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantA, Name: "Cash A", AccountType: accountdomain.AccountTypeAsset,
		Category: accountdomain.AccountCategorySavings,
	})
	incomeA, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantA, Name: "Salary A", AccountType: accountdomain.AccountTypeIncome,
	})

	// Record transaction for tenant A
	txn, _ := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantA, TransactionDate: time.Now(), Description: "A's salary",
		Entries: txnapp.BuildSimpleEntries(50000, assetA.ID, incomeA.ID, ""),
	})

	// Tenant B cannot see A's transaction
	_, err := txnSvc.GetTransaction(ctx, tenantB, txn.ID)
	if err == nil {
		t.Error("tenant B should not see tenant A's transaction")
	}

	// Tenant B list should be empty
	result, _ := txnSvc.ListTransactions(ctx, txnapp.ListTransactionsRequest{
		TenantID: tenantB,
		PageRequest: txndomain.PageRequest{PageSize: 10},
	})
	if result.TotalCount != 0 {
		t.Errorf("tenant B should see 0 transactions, got %d", result.TotalCount)
	}
}

// TestRecordTransaction_RejectsCrossTenantEntry verifies the cross-tenant guard
// in RecordTransaction: tenant A cannot attach tenant B's account_id as one of
// its transaction's entries. Without this guard the entry would write through
// (no FK from transaction_entries.account_id to account.tenant_id) and pollute
// tenant B's balances + SumEntryTotalsByAccount budget actuals.
func TestRecordTransaction_RejectsCrossTenantEntry(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	// Tenant A owns the asset account; tenant B owns the income account.
	assetA, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantA, Name: "Cash A", AccountType: accountdomain.AccountTypeAsset,
		Category: accountdomain.AccountCategorySavings,
	})
	incomeB, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantB, Name: "Salary B", AccountType: accountdomain.AccountTypeIncome,
	})

	// Tenant A attempts to credit tenant B's income account.
	_, err := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantA, TransactionDate: time.Now(), Description: "steal B's income",
		Entries: txnapp.BuildSimpleEntries(50000, assetA.ID, incomeB.ID, ""),
	})
	if err == nil {
		t.Fatal("expected cross-tenant entry rejection, got nil")
	}
}

// TestUpdateTransaction_RejectsCrossTenantEntry verifies the same cross-tenant
// guard applies on update: an existing in-tenant transaction cannot be edited
// to swap in another tenant's account_id.
func TestUpdateTransaction_RejectsCrossTenantEntry(t *testing.T) {
	acctSvc, txnSvc := setupTransactionTestService(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	assetA, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantA, Name: "Cash A", AccountType: accountdomain.AccountTypeAsset,
		Category: accountdomain.AccountCategorySavings,
	})
	incomeA, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantA, Name: "Salary A", AccountType: accountdomain.AccountTypeIncome,
	})
	// Tenant B's income account — must not be attachable to A's transaction.
	incomeB, _ := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantB, Name: "Salary B", AccountType: accountdomain.AccountTypeIncome,
	})

	// Record a legitimate transaction under tenant A.
	txn, err := txnSvc.RecordTransaction(ctx, txnapp.RecordTransactionRequest{
		TenantID: tenantA, TransactionDate: time.Now(), Description: "A's salary",
		Entries: txnapp.BuildSimpleEntries(50000, assetA.ID, incomeA.ID, ""),
	})
	if err != nil {
		t.Fatalf("seed transaction: %v", err)
	}

	// Attempt to swap the income leg to tenant B's account on update.
	_, err = txnSvc.UpdateTransaction(ctx, txnapp.UpdateTransactionRequest{
		TenantID:        tenantA,
		TransactionID:   txn.ID,
		TransactionDate: time.Now(),
		Description:     "rewrite to B's income",
		Entries:         txnapp.BuildSimpleEntries(50000, assetA.ID, incomeB.ID, ""),
		Version:         txn.Version,
	})
	if err == nil {
		t.Fatal("expected cross-tenant entry rejection on update, got nil")
	}
}
