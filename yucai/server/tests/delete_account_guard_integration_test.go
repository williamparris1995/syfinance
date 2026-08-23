package tests

import (
	"context"
	"database/sql"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"entgo.io/ent/dialect/sql/schema"
	_ "modernc.org/sqlite"
	"github.com/google/uuid"

	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	budgetent "github.com/yucai/server/internal/budget/ent"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtent "github.com/yucai/server/internal/debt/ent"
	goalrepo "github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalent "github.com/yucai/server/internal/goal/ent"
	holdingrepo "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingent "github.com/yucai/server/internal/holding/ent"
	tmplrepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	tmplent "github.com/yucai/server/internal/template/ent"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// setupDeleteGuardDB opens one in-memory SQLite DB and migrates every module
// that references accounts, then wires accountService with the six real
// repos as AccountReferenceSource implementations — the same shape as
// wire_gen's wireAccountReferenceSources, exercised against real rows.
func setupDeleteGuardDB(t *testing.T) (*accountapp.Service, *accountent.Client, guardSeeders) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:del_guard_"+strings.ReplaceAll(t.Name(), "/", "_")+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	drv := entsql.OpenDB(dialect.SQLite, db)

	acctClient := accountent.NewClient(accountent.Driver(drv))
	txnClient := txnent.NewClient(txnent.Driver(drv))
	budgetClient := budgetent.NewClient(budgetent.Driver(drv))
	debtClient := debtent.NewClient(debtent.Driver(drv))
	holdingClient := holdingent.NewClient(holdingent.Driver(drv))
	goalClient := goalent.NewClient(goalent.Driver(drv))
	tmplClient := tmplent.NewClient(tmplent.Driver(drv))

	ctx := context.Background()
	migrators := []func(context.Context, ...schema.MigrateOption) error{
		acctClient.Schema.Create, txnClient.Schema.Create, budgetClient.Schema.Create,
		debtClient.Schema.Create, holdingClient.Schema.Create, goalClient.Schema.Create,
		tmplClient.Schema.Create,
	}
	for _, migrate := range migrators {
		if err := migrate(ctx); err != nil {
			t.Fatalf("migrate schema: %v", err)
		}
	}
	for _, closer := range []func() error{
		acctClient.Close, txnClient.Close, budgetClient.Close, debtClient.Close,
		holdingClient.Close, goalClient.Close, tmplClient.Close,
	} {
		t.Cleanup(func() { _ = closer() })
	}

	acctRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	svc := accountapp.NewService(acctRepo, chartRepo)

	txnRefs := txnrepo.NewTransactionRepository(txnClient, db)
	budgetRefs := budgetrepo.NewBudgetRepository(budgetClient)
	debtRefs := debtrepo.NewDebtRepository(debtClient)
	holdingRefs := holdingrepo.NewHoldingRepository(holdingClient)
	goalRefs := goalrepo.NewGoalRepository(goalClient)
	tmplRefs := tmplrepo.NewTemplateRepository(tmplClient)

	svc.SetAccountReferenceSources([]accountdomain.AccountReferenceSource{
		txnRefs, budgetRefs, debtRefs, holdingRefs, goalRefs, tmplRefs,
	})

	return svc, acctClient, guardSeeders{
		txn: txnClient, budget: budgetClient, debt: debtClient,
		holding: holdingClient, goal: goalClient, tmpl: tmplClient,
	}
}

// guardSeeders holds the raw ent clients for planting references.
type guardSeeders struct {
	txn     *txnent.Client
	budget  *budgetent.Client
	debt    *debtent.Client
	holding *holdingent.Client
	goal    *goalent.Client
	tmpl    *tmplent.Client
}

func seedGuardAccount(t *testing.T, client *accountent.Client, tenant uuid.UUID) uuid.UUID {
	t.Helper()
	a, err := client.Account.Create().
		SetTenantID(tenant).
		SetName("guard target").
		SetAccountType("asset").
		Save(context.Background())
	if err != nil {
		t.Fatalf("seed account: %v", err)
	}
	return a.ID
}

// A zero-reference account deletes cleanly through the full wiring.
func TestDeleteGuard_NoReferencesDeletes(t *testing.T) {
	svc, acctClient, _ := setupDeleteGuardDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	id := seedGuardAccount(t, acctClient, tenant)

	if err := svc.DeleteAccount(ctx, tenant, id); err != nil {
		t.Fatalf("delete unreferenced account: %v", err)
	}
	if _, err := svc.GetAccount(ctx, tenant, id); err == nil {
		t.Error("account should be gone after delete")
	}
}

// Each module's reference blocks deletion with that module named in the
// error. Soft-deleted parents (transaction, budget) do not block.
func TestDeleteGuard_EachModuleBlocks(t *testing.T) {
	ctx := context.Background()

	cases := []struct {
		name string
		seed func(t *testing.T, s guardSeeders, tenant, account uuid.UUID)
	}{
		{"transaction", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			txn, err := s.txn.Transaction.Create().
				SetTenantID(tenant).SetTransactionDate(time.Now()).SetDescription("ref").
				Save(ctx)
			if err != nil {
				t.Fatalf("seed txn: %v", err)
			}
			if _, err := s.txn.TransactionEntry.Create().
				SetTransactionID(txn.ID).SetAccountID(acct).
				SetDebitCents(100).SetChartOfAccountCode("1001").
				Save(ctx); err != nil {
				t.Fatalf("seed entry: %v", err)
			}
		}},
		{"budget", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			b, err := s.budget.Budget.Create().
				SetTenantID(tenant).SetName("ref").SetMonth("2026-08").
				Save(ctx)
			if err != nil {
				t.Fatalf("seed budget: %v", err)
			}
			if _, err := s.budget.BudgetItem.Create().
				SetBudgetID(b.ID).SetAccountID(acct).
				Save(ctx); err != nil {
				t.Fatalf("seed item: %v", err)
			}
		}},
		{"debt", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			// via collection_account_id (account_id is a random other account)
			if _, err := s.debt.DebtDetails.Create().
				SetTenantID(tenant).SetAccountID(uuid.New()).SetCollectionAccountID(acct).
				SetCounterparty("bank").SetInterestRate(3).
				SetAmortizationMethod("equal_principal_interest").
				SetStartDate(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)).
				SetDueDate(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)).
				SetTotalPrincipalCents(1000_00).SetDebtType("borrowed_in").SetVersion(1).
				Save(ctx); err != nil {
				t.Fatalf("seed debt: %v", err)
			}
		}},
		{"holding", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			// via a bare holding_transactions row (holdings stay on other accounts)
			if _, err := s.holding.HoldingTransaction.Create().
				SetTenantID(tenant).SetAccountID(acct).SetSecurityID(uuid.New()).
				SetTradeType("buy").SetQuantity(10).SetPriceCents(100).
				SetTradeDate(time.Now()).
				Save(ctx); err != nil {
				t.Fatalf("seed trade: %v", err)
			}
		}},
		{"goal", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			// via goals.linked_account_id directly (no link rows)
			if _, err := s.goal.Goal.Create().
				SetTenantID(tenant).SetName("ref").SetGoalType("savings").
				SetTargetAmountCents(100_00).SetCurrencyCode("CNY").
				SetLinkedAccountID(acct).
				Save(ctx); err != nil {
				t.Fatalf("seed goal: %v", err)
			}
		}},
		{"template", func(t *testing.T, s guardSeeders, tenant, acct uuid.UUID) {
			if _, err := s.tmpl.TransactionTemplate.Create().
				SetTenantID(tenant).SetName("ref").SetAmountCents(100).
				SetDirection("expense").SetCycle("monthly").SetSourceAccountID(uuid.New()).
				SetDestinationAccountID(acct).SetNextDate(time.Now()).SetStartDate(time.Now()).
				Save(ctx); err != nil {
				t.Fatalf("seed template: %v", err)
			}
		}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			svc, acctClient, seeders := setupDeleteGuardDB(t)
			tenant := uuid.New()
			id := seedGuardAccount(t, acctClient, tenant)
			tc.seed(t, seeders, tenant, id)

			err := svc.DeleteAccount(ctx, tenant, id)
			if err == nil {
				t.Fatal("expected rejection")
			}
			if !strings.Contains(err.Error(), tc.name) {
				t.Errorf("error should name %s, got: %v", tc.name, err)
			}
			// Account still present.
			if _, err := svc.GetAccount(ctx, tenant, id); err != nil {
				t.Errorf("referenced account must survive: %v", err)
			}
		})
	}
}

// Soft-deleted transactions must NOT block: their entries are invisible to
// users and cannot resurrect into a ghost-account view.
func TestDeleteGuard_SoftDeletedTransactionDoesNotBlock(t *testing.T) {
	svc, acctClient, seeders := setupDeleteGuardDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	id := seedGuardAccount(t, acctClient, tenant)

	txn, err := seeders.txn.Transaction.Create().
		SetTenantID(tenant).SetTransactionDate(time.Now()).SetDescription("old").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed txn: %v", err)
	}
	if _, err := seeders.txn.TransactionEntry.Create().
		SetTransactionID(txn.ID).SetAccountID(id).
		SetDebitCents(100).SetChartOfAccountCode("1001").
		Save(ctx); err != nil {
		t.Fatalf("seed entry: %v", err)
	}
	if err := seeders.txn.Transaction.UpdateOneID(txn.ID).
		SetDeletedAt(time.Now()).Exec(ctx); err != nil {
		t.Fatalf("soft delete txn: %v", err)
	}

	if err := svc.DeleteAccount(ctx, tenant, id); err != nil {
		t.Fatalf("soft-deleted transaction must not block deletion: %v", err)
	}
}

// Cross-tenant isolation: another tenant's reference does not block.
func TestDeleteGuard_OtherTenantReferenceDoesNotBlock(t *testing.T) {
	svc, acctClient, seeders := setupDeleteGuardDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	id := seedGuardAccount(t, acctClient, tenant)

	// A budget of a DIFFERENT tenant budgeting THE SAME account: the row
	// exists and matches account_id, so only the tenant filter can keep the
	// count at zero.
	b, err := seeders.budget.Budget.Create().
		SetTenantID(uuid.New()).SetName("other").SetMonth("2026-08").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed other-tenant budget: %v", err)
	}
	if _, err := seeders.budget.BudgetItem.Create().
		SetBudgetID(b.ID).SetAccountID(id).
		Save(ctx); err != nil {
		t.Fatalf("seed other-tenant item: %v", err)
	}

	if err := svc.DeleteAccount(ctx, tenant, id); err != nil {
		t.Fatalf("other tenant's references must not block: %v", err)
	}
}

// Soft-deleted budgets must NOT block (live items under a dead parent are
// invisible to users, same semantics as soft-deleted transactions).
func TestDeleteGuard_SoftDeletedBudgetDoesNotBlock(t *testing.T) {
	svc, acctClient, seeders := setupDeleteGuardDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	id := seedGuardAccount(t, acctClient, tenant)

	b, err := seeders.budget.Budget.Create().
		SetTenantID(tenant).SetName("dead").SetMonth("2026-08").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed budget: %v", err)
	}
	if _, err := seeders.budget.BudgetItem.Create().
		SetBudgetID(b.ID).SetAccountID(id).
		Save(ctx); err != nil {
		t.Fatalf("seed item: %v", err)
	}
	if err := seeders.budget.Budget.UpdateOneID(b.ID).
		SetDeletedAt(time.Now()).Exec(ctx); err != nil {
		t.Fatalf("soft delete budget: %v", err)
	}

	if err := svc.DeleteAccount(ctx, tenant, id); err != nil {
		t.Fatalf("soft-deleted budget must not block deletion: %v", err)
	}
}

// DeleteByTenant (disaster-cleanup path) must keep working untouched by the
// guard — ticket 05 decision 5 keeps it for purge/restore flows.
func TestDeleteGuard_DeleteByTenantUnchanged(t *testing.T) {
	_, acctClient, _ := setupDeleteGuardDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	id := seedGuardAccount(t, acctClient, tenant)

	// The repo-level path (what D6's purge uses), not the guarded service.
	repo := accountrepo.NewAccountRepository(acctClient)
	if err := repo.DeleteByTenant(ctx, tenant); err != nil {
		t.Fatalf("DeleteByTenant: %v", err)
	}
	exists, err := acctClient.Account.Query().Where().IDs(ctx)
	if err != nil {
		t.Fatalf("query accounts: %v", err)
	}
	for _, got := range exists {
		if got == id {
			t.Error("account should be purged by DeleteByTenant")
		}
	}
}
