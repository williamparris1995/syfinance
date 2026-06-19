package repository_test

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/adapter/driven/repository"
	"github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
)

// setupAccountTestDB opens an in-memory SQLite database and runs ent auto-migration
// for the account schema. Mirrors the pattern in tests/holding_integration_test.go.
func setupAccountTestDB(t *testing.T) *accountent.Client {
	t.Helper()
	dbName := "account_ent_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client := accountent.NewClient(accountent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// saveAccount persists a minimal account of the given type for the tenant.
func saveAccount(t *testing.T, repo *repository.AccountRepository, tenantID uuid.UUID, name string, at domain.AccountType) *domain.Account {
	t.Helper()
	a, err := domain.NewAccount(tenantID, name, at, "CNY")
	if err != nil {
		t.Fatalf("new account: %v", err)
	}
	if err := repo.Save(context.Background(), a); err != nil {
		t.Fatalf("save account: %v", err)
	}
	return a
}

func TestFindByAccountType_ReturnsOnlyMatchingType(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()
	otherTenant := uuid.New()

	saveAccount(t, repo, tenantID, "Cash", domain.AccountTypeAsset)
	saveAccount(t, repo, tenantID, "Salary", domain.AccountTypeIncome)
	saveAccount(t, repo, tenantID, "Food", domain.AccountTypeExpense)
	saveAccount(t, repo, tenantID, "Rent", domain.AccountTypeExpense)
	saveAccount(t, repo, otherTenant, "Other tenant expense", domain.AccountTypeExpense)

	got, err := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	if err != nil {
		t.Fatalf("FindByAccountType: %v", err)
	}

	if len(got) != 2 {
		t.Fatalf("expected 2 expense accounts, got %d", len(got))
	}
	for _, a := range got {
		if a.AccountType != domain.AccountTypeExpense {
			t.Errorf("returned account %q has type %v, want expense", a.Name, a.AccountType)
		}
		if a.TenantID != tenantID {
			t.Errorf("returned account %q has tenant %v, want %v (tenant isolation broken)", a.Name, a.TenantID, tenantID)
		}
	}
}

func TestFindByAccountType_ExcludesSoftDeleted(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()

	active := saveAccount(t, repo, tenantID, "Food", domain.AccountTypeExpense)
	deleted := saveAccount(t, repo, tenantID, "Old Food", domain.AccountTypeExpense)

	if err := repo.SoftDelete(context.Background(), tenantID, deleted.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	got, err := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	if err != nil {
		t.Fatalf("FindByAccountType: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 active expense account, got %d", len(got))
	}
	if got[0].ID != active.ID {
		t.Errorf("expected active account %s, got %s", active.ID, got[0].ID)
	}
}

func TestFindByAccountType_EmptyResult(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()

	got, err := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeLiability)
	if err != nil {
		t.Fatalf("FindByAccountType: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil empty slice, got nil")
	}
	if len(got) != 0 {
		t.Errorf("expected 0 accounts, got %d", len(got))
	}
}
