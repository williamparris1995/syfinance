package repository_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"
	"github.com/google/uuid"

	budgetent "github.com/yucai/server/internal/budget/ent"
	budgetitem "github.com/yucai/server/internal/budget/ent/budgetitem"
)

// setupBudgetSchemaDB opens an in-memory SQLite database (foreign keys ON)
// and migrates the budget schema. Mirrors the debt test-db helper: a named
// memory DB plus MaxOpenConns(1) keeps the connection shared.
func setupBudgetSchemaDB(t *testing.T) *budgetent.Client {
	t.Helper()
	dbName := "budget_schema_" + sanitizeBudgetSchema(t.Name())
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
	client := budgetent.NewClient(budgetent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// sanitizeBudgetSchema strips characters illegal in sqlite file names.
func sanitizeBudgetSchema(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ' ' || c == ':' {
			out = append(out, '_')
			continue
		}
		out = append(out, c)
	}
	return string(out)
}

// TestSchemaCompositeUnique_RejectsDuplicateBudgetItem verifies the DB-level
// composite unique index (budget_id, account_id): budgeting the same account
// twice under one budget is rejected by the database, not just app logic.
func TestSchemaCompositeUnique_RejectsDuplicateBudgetItem(t *testing.T) {
	client := setupBudgetSchemaDB(t)
	ctx := context.Background()

	b, err := client.Budget.Create().
		SetTenantID(uuid.New()).
		SetName("monthly").
		SetMonth("2026-01").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed budget: %v", err)
	}
	acct := uuid.New()

	if _, err := client.BudgetItem.Create().
		SetBudgetID(b.ID).SetAccountID(acct).
		Save(ctx); err != nil {
		t.Fatalf("first item: %v", err)
	}
	if _, err := client.BudgetItem.Create().
		SetBudgetID(b.ID).SetAccountID(acct).
		Save(ctx); err == nil {
		t.Fatal("expected composite unique (budget_id, account_id) violation, got nil")
	}
	// A different account under the same budget stays legal.
	if _, err := client.BudgetItem.Create().
		SetBudgetID(b.ID).SetAccountID(uuid.New()).
		Save(ctx); err != nil {
		t.Fatalf("second distinct account: %v", err)
	}
}

// TestSchemaPartialUnique_SoftDeletedBudgetRebuild verifies the partial
// unique index (tenant_id, month) WHERE deleted_at IS NULL: a soft-deleted
// budget no longer occupies its month slot, so recreating the same month
// succeeds while two live budgets for one month are still rejected.
func TestSchemaPartialUnique_SoftDeletedBudgetRebuild(t *testing.T) {
	client := setupBudgetSchemaDB(t)
	ctx := context.Background()
	tenant := uuid.New()

	first, err := client.Budget.Create().
		SetTenantID(tenant).SetName("jan").SetMonth("2026-01").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed budget: %v", err)
	}

	// A second live budget for the same month must fail.
	if _, err := client.Budget.Create().
		SetTenantID(tenant).SetName("jan again").SetMonth("2026-01").
		Save(ctx); err == nil {
		t.Fatal("expected live duplicate (tenant_id, month) rejection, got nil")
	}

	// Soft-delete frees the slot.
	if err := client.Budget.UpdateOneID(first.ID).
		SetDeletedAt(time.Now()).Exec(ctx); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	if _, err := client.Budget.Create().
		SetTenantID(tenant).SetName("jan rebuilt").SetMonth("2026-01").
		Save(ctx); err != nil {
		t.Fatalf("recreate after soft delete: %v", err)
	}
}

// TestSchemaCascade_DeleteBudgetRemovesItems verifies the OnDelete(Cascade)
// edge: hard-deleting a budget takes its budget_items with it (with FK
// enforcement ON, the alternative — orphan rows — is exactly what R5-E
// exists to prevent).
func TestSchemaCascade_DeleteBudgetRemovesItems(t *testing.T) {
	client := setupBudgetSchemaDB(t)
	ctx := context.Background()

	b, err := client.Budget.Create().
		SetTenantID(uuid.New()).SetName("cascade").SetMonth("2026-02").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed budget: %v", err)
	}
	for i := 0; i < 2; i++ {
		if _, err := client.BudgetItem.Create().
			SetBudgetID(b.ID).SetAccountID(uuid.New()).
			Save(ctx); err != nil {
			t.Fatalf("seed item %d: %v", i, err)
		}
	}

	if err := client.Budget.DeleteOneID(b.ID).Exec(ctx); err != nil {
		t.Fatalf("delete budget: %v", err)
	}

	n, err := client.BudgetItem.Query().
		Where(budgetitem.BudgetID(b.ID)).
		Count(ctx)
	if err != nil {
		t.Fatalf("count items after cascade: %v", err)
	}
	if n != 0 {
		t.Errorf("expected 0 budget_items after parent delete, got %d", n)
	}
}
