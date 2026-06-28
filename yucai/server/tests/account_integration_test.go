package tests

import (
	"context"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"
	"database/sql"

	"github.com/yucai/server/internal/account/adapter/driven/repository"
	"github.com/yucai/server/internal/account/application"
	"github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/google/uuid"
)

func setupAccountTestDB(t *testing.T) *accountent.Client {
	t.Helper()
	db, err := sql.Open("sqlite", "file:account_ent?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))

	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("create schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func setupAccountTestService(t *testing.T) *application.Service {
	t.Helper()
	client := setupAccountTestDB(t)
	accountRepo := repository.NewAccountRepository(client)
	chartRepo := repository.NewChartRepository(client)
	return application.NewService(accountRepo, chartRepo)
}

func TestAccountCRUD(t *testing.T) {
	svc := setupAccountTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create
	created, err := svc.CreateAccount(ctx, application.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Cash",
		AccountType:  domain.AccountTypeAsset,
		Category:     domain.AccountCategorySavings,
		CurrencyCode: "CNY",
		Ownership:    domain.OwnershipPersonal,
	})
	if err != nil {
		t.Fatalf("CreateAccount failed: %v", err)
	}
	if created.Name != "Cash" {
		t.Errorf("expected Cash, got %s", created.Name)
	}
	if created.AccountType != domain.AccountTypeAsset {
		t.Error("expected asset type")
	}
	if created.Status != domain.AccountStatusActive {
		t.Error("expected active status")
	}
	if created.Version != 1 {
		t.Errorf("expected version 1, got %d", created.Version)
	}

	// Get
	got, err := svc.GetAccount(ctx, tenantID, created.ID)
	if err != nil {
		t.Fatalf("GetAccount failed: %v", err)
	}
	if got.Name != "Cash" {
		t.Errorf("expected Cash, got %s", got.Name)
	}

	// Update
	updated, err := svc.UpdateAccount(ctx, application.UpdateAccountRequest{
		TenantID:    tenantID,
		AccountID:   created.ID,
		Name:        "Cash Updated",
		Icon:        "wallet",
		Version:     1,
	})
	if err != nil {
		t.Fatalf("UpdateAccount failed: %v", err)
	}
	if updated.Name != "Cash Updated" {
		t.Errorf("expected Cash Updated, got %s", updated.Name)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}

	// Delete (balance is 0)
	if err := svc.DeleteAccount(ctx, tenantID, created.ID); err != nil {
		t.Fatalf("DeleteAccount failed: %v", err)
	}

	// Verify gone
	_, err = svc.GetAccount(ctx, tenantID, created.ID)
	if err == nil {
		t.Error("expected error for deleted account")
	}
}

func TestAccountList(t *testing.T) {
	svc := setupAccountTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create 3 accounts
	for _, name := range []string{"Cash", "Bank", "Food"} {
		at := domain.AccountTypeAsset
		if name == "Food" {
			at = domain.AccountTypeExpense
		}
		req := application.CreateAccountRequest{
			TenantID: tenantID, Name: name, AccountType: at, CurrencyCode: "CNY",
		}
		if at == domain.AccountTypeAsset {
			req.Category = domain.AccountCategorySavings
		}
		_, err := svc.CreateAccount(ctx, req)
		if err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
	}

	// List all
	result, err := svc.ListAccounts(ctx, application.ListAccountsRequest{
		TenantID:    tenantID,
		PageRequest: domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListAccounts failed: %v", err)
	}
	if result.TotalCount != 3 {
		t.Errorf("expected 3 accounts, got %d", result.TotalCount)
	}

	// Filter by type
	expenseType := domain.AccountTypeExpense
	filtered, err := svc.ListAccounts(ctx, application.ListAccountsRequest{
		TenantID:    tenantID,
		Filter:      domain.AccountFilter{AccountType: &expenseType},
		PageRequest: domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("filtered ListAccounts failed: %v", err)
	}
	if filtered.TotalCount != 1 {
		t.Errorf("expected 1 expense account, got %d", filtered.TotalCount)
	}
}

func TestAccountTenantIsolation(t *testing.T) {
	svc := setupAccountTestService(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	_, err := svc.CreateAccount(ctx, application.CreateAccountRequest{
		TenantID: tenantA, Name: "A Cash", AccountType: domain.AccountTypeAsset,
		Category: domain.AccountCategorySavings,
	})
	if err != nil {
		t.Fatalf("create for A: %v", err)
	}

	result, err := svc.ListAccounts(ctx, application.ListAccountsRequest{
		TenantID:    tenantB,
		PageRequest: domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("list for B: %v", err)
	}
	if result.TotalCount != 0 {
		t.Errorf("tenant B should see 0 accounts, got %d", result.TotalCount)
	}
}

func TestAccountOptimisticLock(t *testing.T) {
	svc := setupAccountTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	created, err := svc.CreateAccount(ctx, application.CreateAccountRequest{
		TenantID: tenantID, Name: "Cash", AccountType: domain.AccountTypeAsset,
		Category: domain.AccountCategorySavings,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	// Update with wrong version should fail
	_, err = svc.UpdateAccount(ctx, application.UpdateAccountRequest{
		TenantID:  tenantID,
		AccountID: created.ID,
		Name:      "Stale",
		Version:   999, // wrong version
	})
	if err == nil {
		t.Error("expected optimistic lock error")
	}
}

func TestDeleteNonZeroBalance(t *testing.T) {
	svc := setupAccountTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	created, err := svc.CreateAccount(ctx, application.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "Bank",
		AccountType:         domain.AccountTypeAsset,
		Category:            domain.AccountCategorySavings,
		InitialBalanceCents: 50000,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	err = svc.DeleteAccount(ctx, tenantID, created.ID)
	if err == nil {
		t.Error("expected error for non-zero balance delete")
	}
}
