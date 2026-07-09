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

// TestFindByAccountType_OrdersBySortOrder verifies that accounts are returned
// ordered by sort_order ASC (name ASC as tiebreaker). This guards the
// "deterministic dropdown order" contract and is only meaningful once Save
// persists sort_order (fixed alongside this test).
func TestFindByAccountType_OrdersBySortOrder(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()

	// Save three Expense accounts with deliberately out-of-alphabetical sort_order.
	// Without sort_order persistence, all would default to 0 and only name
	// tiebreak would apply (alphabetical: A, B, C) — masking the bug.
	c := newAccountWithSortOrder(tenantID, "C-first", domain.AccountTypeExpense, 1)
	b := newAccountWithSortOrder(tenantID, "B-second", domain.AccountTypeExpense, 2)
	a := newAccountWithSortOrder(tenantID, "A-third", domain.AccountTypeExpense, 3)
	for _, acc := range []*domain.Account{c, b, a} {
		if err := repo.Save(context.Background(), acc); err != nil {
			t.Fatalf("save account %q: %v", acc.Name, err)
		}
	}

	got, err := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	if err != nil {
		t.Fatalf("FindByAccountType: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 expense accounts, got %d", len(got))
	}

	// Expected order: sort_order 1, 2, 3 (i.e. names "C-first", "B-second", "A-third").
	wantNames := []string{"C-first", "B-second", "A-third"}
	for i, want := range wantNames {
		if got[i].Name != want {
			t.Errorf("position %d: got %q (sort_order=%d), want %q — order should be sort_order ASC",
				i, got[i].Name, got[i].SortOrder, want)
		}
	}

	// Sanity: confirm sort_order round-tripped non-zero (verifies Save fix).
	for _, acc := range got {
		if acc.SortOrder == 0 {
			t.Errorf("account %q has SortOrder=0; Save did not persist sort_order", acc.Name)
		}
	}
}

// newAccountWithSortOrder builds a minimal account with an explicit sort_order.
func newAccountWithSortOrder(tenantID uuid.UUID, name string, at domain.AccountType, sortOrder int) *domain.Account {
	a, err := domain.NewAccount(tenantID, name, at, "CNY")
	if err != nil {
		panic(err)
	}
	a.SortOrder = sortOrder
	return a
}

// TestUpdate_PersistsParentID verifies the Update method writes ParentID to the
// DB. Previously Update omitted SetParentID, so the service's in-memory
// assignment (account.ParentID = req.ParentID) was lost on persist — the RPC
// response showed the new parent (in-memory) but the DB stayed empty.
func TestUpdate_PersistsParentID(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()

	parent := saveAccount(t, repo, tenantID, "餐饮", domain.AccountTypeExpense)
	child := saveAccount(t, repo, tenantID, "咖啡", domain.AccountTypeExpense)

	// Simulate the service flow: load → set ParentID → increment version → update.
	child.ParentID = &parent.ID
	child.IncrementVersion()
	if err := repo.Update(context.Background(), child); err != nil {
		t.Fatalf("Update: %v", err)
	}

	reloaded, err := repo.FindByID(context.Background(), tenantID, child.ID)
	if err != nil {
		t.Fatalf("FindByID: %v", err)
	}
	if reloaded.ParentID == nil {
		t.Fatal("ParentID is nil after Update; Update did not persist parent_id")
	}
	if *reloaded.ParentID != parent.ID {
		t.Errorf("ParentID = %v, want %v", *reloaded.ParentID, parent.ID)
	}
}

// TestUpdate_PreservesParentIDWhenUnchanged verifies Update does not clobber an
// existing ParentID when the field is left untouched (service keeps the loaded
// value; repo must re-write it, not drop it).
func TestUpdate_PreservesParentIDWhenUnchanged(t *testing.T) {
	client := setupAccountTestDB(t)
	repo := repository.NewAccountRepository(client)
	tenantID := uuid.New()

	parent := saveAccount(t, repo, tenantID, "餐饮", domain.AccountTypeExpense)
	child := saveAccount(t, repo, tenantID, "咖啡", domain.AccountTypeExpense)

	// First update: set the parent.
	child.ParentID = &parent.ID
	child.IncrementVersion()
	if err := repo.Update(context.Background(), child); err != nil {
		t.Fatalf("Update (set parent): %v", err)
	}

	// Second update: rename only, ParentID untouched (service would keep it).
	child.Name = "拿铁"
	child.IncrementVersion()
	if err := repo.Update(context.Background(), child); err != nil {
		t.Fatalf("Update (rename): %v", err)
	}

	reloaded, err := repo.FindByID(context.Background(), tenantID, child.ID)
	if err != nil {
		t.Fatalf("FindByID: %v", err)
	}
	if reloaded.ParentID == nil || *reloaded.ParentID != parent.ID {
		t.Errorf("ParentID lost after rename update; got %v, want %v", reloaded.ParentID, parent.ID)
	}
	if reloaded.Name != "拿铁" {
		t.Errorf("Name = %q, want 拿铁", reloaded.Name)
	}
}
