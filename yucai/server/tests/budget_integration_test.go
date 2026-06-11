package tests

import (
	"context"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"database/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	"github.com/yucai/server/internal/budget/application"
	budgetent "github.com/yucai/server/internal/budget/ent"
)

func setupBudgetTestDB(t *testing.T) *budgetent.Client {
	t.Helper()
	db, err := sql.Open("sqlite", "file:budget_ent?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := budgetent.NewClient(budgetent.Driver(drv))

	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("create budget schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func setupBudgetTestService(t *testing.T) *application.Service {
	t.Helper()
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	return application.NewService(repo, nil)
}

func TestBudgetCRUD(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create
	created, err := svc.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID:     tenantID,
		Name:         "5月预算",
		Month:        "2026-05",
		CurrencyCode: "CNY",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 50000},
			{AccountID: uuid.New(), PlannedAmountCents: 30000},
		},
	})
	if err != nil {
		t.Fatalf("CreateBudget failed: %v", err)
	}
	if created.Name != "5月预算" {
		t.Errorf("expected 5月预算, got %s", created.Name)
	}
	if created.TotalAmountCents != 80000 {
		t.Errorf("expected total 80000, got %d", created.TotalAmountCents)
	}
	if created.Version != 1 {
		t.Errorf("expected version 1, got %d", created.Version)
	}
	if !created.IsActive {
		t.Error("expected active")
	}

	// GetByMonth
	byMonth, err := svc.GetBudgetByMonth(ctx, tenantID, "2026-05")
	if err != nil {
		t.Fatalf("GetBudgetByMonth failed: %v", err)
	}
	if byMonth.Budget.Month != "2026-05" {
		t.Errorf("expected month 2026-05, got %s", byMonth.Budget.Month)
	}

	// Get
	got, err := svc.GetBudget(ctx, tenantID, created.ID)
	if err != nil {
		t.Fatalf("GetBudget failed: %v", err)
	}
	if got.Budget.Name != "5月预算" {
		t.Errorf("expected 5月预算, got %s", got.Budget.Name)
	}

	// AddItem
	updated, err := svc.AddBudgetItem(ctx, application.AddBudgetItemRequest{
		TenantID:           tenantID,
		BudgetID:           created.ID,
		AccountID:          uuid.New(),
		PlannedAmountCents: 20000,
	})
	if err != nil {
		t.Fatalf("AddBudgetItem failed: %v", err)
	}
	if updated.TotalAmountCents != 100000 {
		t.Errorf("expected total 100000, got %d", updated.TotalAmountCents)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}

	// RemoveItem
	updated2, err := svc.RemoveBudgetItem(ctx, application.RemoveBudgetItemRequest{
		TenantID: tenantID,
		BudgetID: created.ID,
		ItemID:   updated.Items[len(updated.Items)-1].ID,
	})
	if err != nil {
		t.Fatalf("RemoveBudgetItem failed: %v", err)
	}
	if updated2.TotalAmountCents != 80000 {
		t.Errorf("expected total 80000 after remove, got %d", updated2.TotalAmountCents)
	}

	// Delete
	if err := svc.DeleteBudget(ctx, tenantID, created.ID); err != nil {
		t.Fatalf("DeleteBudget failed: %v", err)
	}

	// Verify gone
	_, err = svc.GetBudget(ctx, tenantID, created.ID)
	if err == nil {
		t.Error("expected error for deleted budget")
	}
}

func TestBudgetList(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	for _, month := range []string{"2026-01", "2026-02", "2026-03"} {
		_, err := svc.CreateBudget(ctx, application.CreateBudgetRequest{
			TenantID: tenantID, Name: month, Month: month, CurrencyCode: "CNY",
			Items: []application.BudgetItemInput{{AccountID: uuid.New(), PlannedAmountCents: 10000}},
		})
		if err != nil {
			t.Fatalf("create budget %s: %v", month, err)
		}
	}

	result, err := svc.ListBudgets(ctx, application.ListBudgetsRequest{
		TenantID: tenantID,
	})
	if err != nil {
		t.Fatalf("ListBudgets failed: %v", err)
	}
	if result.TotalCount != 3 {
		t.Errorf("expected 3 budgets, got %d", result.TotalCount)
	}
}

func TestBudgetCloneToMonth(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	original, _ := svc.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID: tenantID, Name: "Original", Month: "2026-05", CurrencyCode: "CNY",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 50000},
			{AccountID: uuid.New(), PlannedAmountCents: 30000},
		},
	})

	cloned, err := svc.CloneBudgetToMonth(ctx, application.CloneBudgetRequest{
		TenantID:       tenantID,
		SourceBudgetID: original.ID,
		TargetMonth:    "2026-06",
		Name:           "6月预算",
	})
	if err != nil {
		t.Fatalf("CloneBudgetToMonth failed: %v", err)
	}
	if cloned.Month != "2026-06" {
		t.Errorf("expected month 2026-06, got %s", cloned.Month)
	}
	if cloned.Name != "6月预算" {
		t.Errorf("expected name, got %s", cloned.Name)
	}
	if cloned.TotalAmountCents != original.TotalAmountCents {
		t.Errorf("total should match: %d vs %d", cloned.TotalAmountCents, original.TotalAmountCents)
	}
	if cloned.ID == original.ID {
		t.Error("clone should have different ID")
	}
}

func TestBudgetTenantIsolation(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	_, err := svc.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID: tenantA, Name: "A Budget", Month: "2026-05", CurrencyCode: "CNY",
		Items: []application.BudgetItemInput{{AccountID: uuid.New(), PlannedAmountCents: 10000}},
	})
	if err != nil {
		t.Fatalf("create for A: %v", err)
	}

	result, err := svc.ListBudgets(ctx, application.ListBudgetsRequest{
		TenantID: tenantB,
	})
	if err != nil {
		t.Fatalf("list for B: %v", err)
	}
	if result.TotalCount != 0 {
		t.Errorf("tenant B should see 0 budgets, got %d", result.TotalCount)
	}
}
