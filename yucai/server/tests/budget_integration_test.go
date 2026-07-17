package tests

import (
	"context"
	"strings"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"database/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	"github.com/yucai/server/internal/budget/application"
	budgetdomain "github.com/yucai/server/internal/budget/domain"
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
	return application.NewService(repo, nil, nil)
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

// TestBudgetRepoUpdate verifies the repo persists CurrencyCode on Update
// (M1 fix: previously dropped) and fully replaces items + honors the
// optimistic-lock version predicate. Exercises repo.Update directly (no
// service.UpdateBudget yet — added in Task 2).
func TestBudgetRepoUpdate(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, err := budgetdomain.NewBudget(tenantID, "原预算", "2026-05", "CNY", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
	})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}
	versionBefore := b.Version

	// Edit in place: change currency + replace items (1 → 2).
	if err := b.Update("改名", "USD", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	}); err != nil {
		t.Fatalf("Update: %v", err)
	}
	if err := repo.Update(ctx, b); err != nil {
		t.Fatalf("repo.Update: %v", err)
	}

	got, err := repo.FindByID(ctx, tenantID, b.ID)
	if err != nil {
		t.Fatalf("FindByID: %v", err)
	}
	if got.CurrencyCode != "USD" {
		t.Errorf("currency persisted: got %q, want USD (M1 fix)", got.CurrencyCode)
	}
	if got.Name != "改名" {
		t.Errorf("name: got %q, want 改名", got.Name)
	}
	if len(got.Items) != 2 {
		t.Errorf("items replaced: got %d, want 2", len(got.Items))
	}
	if got.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000", got.TotalAmountCents)
	}
	if got.Version != versionBefore+1 {
		t.Errorf("version bumped: got %d, want %d", got.Version, versionBefore+1)
	}
	if got.Month != "2026-05" {
		t.Errorf("month mutated: got %s, want 2026-05 (immutable)", got.Month)
	}
}

// TestBudgetUpdate verifies the full UpdateBudget service path: edits a
// budget in place (name + currency + items full replace), budget ID stable,
// month immutable, version bumped + persisted. Replaces the client form's
// old delete+recreate (which changed the ID).
func TestBudgetUpdate(t *testing.T) {
	svc := setupBudgetTestService(t)
	ctx := context.Background()
	tenantID := uuid.New()

	created, err := svc.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID: tenantID, Name: "原预算", Month: "2026-05", CurrencyCode: "CNY",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 50000},
		},
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}
	id := created.ID
	versionBefore := created.Version

	updated, err := svc.UpdateBudget(ctx, application.UpdateBudgetRequest{
		TenantID: tenantID, BudgetID: id,
		Name: "改名", CurrencyCode: "USD",
		Items: []application.BudgetItemInput{
			{AccountID: uuid.New(), PlannedAmountCents: 30000},
			{AccountID: uuid.New(), PlannedAmountCents: 20000},
		},
	})
	if err != nil {
		t.Fatalf("UpdateBudget: %v", err)
	}
	if updated.ID != id {
		t.Errorf("ID changed: got %s, want %s (delete+recreate regression)", updated.ID, id)
	}
	if updated.Name != "改名" {
		t.Errorf("name: got %s, want 改名", updated.Name)
	}
	if updated.CurrencyCode != "USD" {
		t.Errorf("currency: got %s, want USD", updated.CurrencyCode)
	}
	if len(updated.Items) != 2 {
		t.Errorf("items: got %d, want 2", len(updated.Items))
	}
	if updated.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000", updated.TotalAmountCents)
	}
	if updated.Version != versionBefore+1 {
		t.Errorf("version: got %d, want %d", updated.Version, versionBefore+1)
	}

	// Persisted (re-fetch by the same ID — would fail under delete+recreate).
	got, err := svc.GetBudget(ctx, tenantID, id)
	if err != nil {
		t.Fatalf("GetBudget after update: %v", err)
	}
	if got.Budget.CurrencyCode != "USD" {
		t.Errorf("persisted currency: got %s, want USD", got.Budget.CurrencyCode)
	}
	if got.Budget.Month != "2026-05" {
		t.Errorf("month mutated: got %s, want 2026-05 (immutable)", got.Budget.Month)
	}
}

// TestBudgetRepoUpdate_OptimisticLock verifies a stale version is rejected:
// a second Update built from the pre-bump version must fail to match the
// WHERE version predicate.
func TestBudgetRepoUpdate_OptimisticLock(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, _ := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 10000}})
	repo.Save(ctx, b)

	// Stale snapshot: simulate a concurrent edit by bumping version once more
	// than the predicate expects. domain.Update sets Version = v+1; repo WHERE
	// matches v. If we manually set Version = v+2 without a real intervening
	// write, WHERE v+1 finds no row → error.
	stale := *b
	stale.Update("B2", "CNY", []budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 20000}})
	// Now corrupt: pretend version is one ahead of what DB has.
	stale.Version = b.Version + 2 // repo WHERE Version(stale.Version-1) = v+1, DB still v → no match
	err := repo.Update(ctx, &stale)
	if err == nil {
		t.Fatal("optimistic lock: expected error on stale version, got nil")
	}
}

// TestBudgetRepoUpdate_TxAtomicOnOptimisticLock verifies that when the budget
// UPDATE fails the optimistic lock (WHERE version mismatch), the preceding
// items delete+insert are rolled back — the whole Update is atomic. Under the
// pre-fix non-transactional repo, items would be left in the new state while
// the budget row stayed old.
func TestBudgetRepoUpdate_TxAtomicOnOptimisticLock(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	origAcc := uuid.New()
	b, err := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: origAcc, PlannedAmountCents: 10000}})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}

	// Force optimistic-lock failure: bump version past what the DB has so the
	// WHERE Version(stale.Version-1) predicate matches 0 rows.
	stale := *b
	stale.Update("B2", "USD", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	})
	stale.Version = b.Version + 2 // WHERE Version(b.Version+1) != DB b.Version -> NotFound
	if err := repo.Update(ctx, &stale); err == nil {
		t.Fatal("expected optimistic lock error, got nil")
	}

	// TX atomicity: the items delete+insert must have rolled back — FindByID
	// should still see the ORIGINAL single item, not the replacement.
	got, err := repo.FindByID(ctx, tenantID, b.ID)
	if err != nil {
		t.Fatalf("FindByID after failed update: %v", err)
	}
	if len(got.Items) != 1 {
		t.Fatalf("tx did not roll back items: got %d items, want 1 (original)", len(got.Items))
	}
	if got.Items[0].AccountID != origAcc {
		t.Errorf("item account after rollback: got %s, want %s (original)", got.Items[0].AccountID, origAcc)
	}
	if got.TotalAmountCents != 10000 {
		t.Errorf("total after rollback: got %d, want 10000 (original)", got.TotalAmountCents)
	}
	if got.Name != "B" || got.CurrencyCode != "CNY" {
		t.Errorf("budget fields changed despite rollback: name=%q currency=%q", got.Name, got.CurrencyCode)
	}
}

// TestBudgetRepoUpdate_OptimisticLockErrMapping verifies the optimistic-lock
// error is phrased so budget mapError routes it to codes.Aborted (not
// codes.NotFound): the message MUST contain "optimistic lock" and MUST NOT
// contain "not found" (mapError checks "not found" before "optimistic lock").
func TestBudgetRepoUpdate_OptimisticLockErrMapping(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, err := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 10000}})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}

	stale := *b
	stale.Update("B2", "CNY", []budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 20000}})
	stale.Version = b.Version + 2
	err = repo.Update(ctx, &stale)
	if err == nil {
		t.Fatal("expected optimistic lock error, got nil")
	}
	if !strings.Contains(err.Error(), "optimistic lock") {
		t.Errorf("err missing 'optimistic lock' phrase (mapError needs it for Aborted): %q", err.Error())
	}
	if strings.Contains(err.Error(), "not found") {
		t.Errorf("err leaks 'not found' (mapError would route to codes.NotFound, not Aborted): %q", err.Error())
	}
}
