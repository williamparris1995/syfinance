package repository_test

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	"github.com/yucai/server/internal/goal/adapter/driven/repository"
	"github.com/yucai/server/internal/goal/domain"
	goalent "github.com/yucai/server/internal/goal/ent"
)

// setupGoalTestDB opens an in-memory SQLite database and runs ent auto-migration
// for the goal schema. Mirrors the holding test pattern (file:<name>?mode=memory,
// MaxOpenConns(1) to keep the same in-memory DB alive across connections).
func setupGoalTestDB(t *testing.T) *goalent.Client {
	t.Helper()
	dbName := "goal_ent_" + sanitize(t.Name())
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
	client := goalent.NewClient(goalent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// sanitize strips characters illegal in sqlite file names from a test name.
func sanitize(s string) string {
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

// seedGoal creates and persists a goal of the given type for the given tenant.
// Investment/Savings goals get one linked account; DebtPayoff gets one linked
// debt (so the new type-based validator is satisfied). Returns the persisted
// *domain.Goal so tests can assert on it.
func seedGoal(t *testing.T, ctx context.Context, repo domain.GoalRepository, tenantID uuid.UUID, gt domain.GoalType, name string) *domain.Goal {
	t.Helper()
	var accs, debts []uuid.UUID
	switch gt {
	case domain.GoalTypeInvestment, domain.GoalTypeSavings:
		accs = []uuid.UUID{uuid.New()}
	case domain.GoalTypeDebtPayoff:
		debts = []uuid.UUID{uuid.New()}
	}
	g, err := domain.NewGoal(tenantID, name, gt, 100000, "CNY", nil, accs, debts, "")
	if err != nil {
		t.Fatalf("NewGoal: %v", err)
	}
	if err := repo.Save(ctx, g); err != nil {
		t.Fatalf("Save goal: %v", err)
	}
	return g
}

// TestGoalRepoFindAllFiltersByType verifies FindAll narrows by goalType when
// provided (Task 4 / Task 1 ent filter) and returns all goals when goalType is nil.
func TestGoalRepoFindAllFiltersByType(t *testing.T) {
	client := setupGoalTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()

	repo := repository.NewGoalRepository(client)
	page := domain.PageRequest{PageSize: 50}

	// Seed 2 investment + 1 savings goal.
	seedGoal(t, ctx, repo, tenant, domain.GoalTypeInvestment, "buy-stocks")
	seedGoal(t, ctx, repo, tenant, domain.GoalTypeInvestment, "buy-bonds")
	seedGoal(t, ctx, repo, tenant, domain.GoalTypeSavings, "emergency-fund")

	// Filter by investment → only the 2 investment goals.
	investment := domain.GoalTypeInvestment
	got, err := repo.FindAll(ctx, tenant, nil, &investment, page)
	if err != nil {
		t.Fatalf("FindAll(investment): %v", err)
	}
	if len(got.Items) != 2 {
		t.Fatalf("expected 2 investment goals, got %d", len(got.Items))
	}
	for _, g := range got.Items {
		if g.GoalType != domain.GoalTypeInvestment {
			t.Errorf("type leakage: got %v, want investment", g.GoalType)
		}
		if g.TenantID != tenant {
			t.Errorf("tenant leakage: %s != %s", g.TenantID, tenant)
		}
	}
	if got.TotalCount != 2 {
		t.Errorf("TotalCount = %d, want 2", got.TotalCount)
	}

	// nil goalType → all 3 goals.
	all, err := repo.FindAll(ctx, tenant, nil, nil, page)
	if err != nil {
		t.Fatalf("FindAll(nil type): %v", err)
	}
	if len(all.Items) != 3 {
		t.Fatalf("expected 3 goals (nil filter), got %d", len(all.Items))
	}
	if all.TotalCount != 3 {
		t.Errorf("TotalCount = %d, want 3", all.TotalCount)
	}

	// Filter by savings → exactly 1 savings goal (sanity check on a different type).
	savings := domain.GoalTypeSavings
	gotSavings, err := repo.FindAll(ctx, tenant, nil, &savings, page)
	if err != nil {
		t.Fatalf("FindAll(savings): %v", err)
	}
	if len(gotSavings.Items) != 1 {
		t.Fatalf("expected 1 savings goal, got %d", len(gotSavings.Items))
	}

	// Filter by a type with no seeded goals → empty.
	debt := domain.GoalTypeDebtPayoff
	gotDebt, err := repo.FindAll(ctx, tenant, nil, &debt, page)
	if err != nil {
		t.Fatalf("FindAll(debt): %v", err)
	}
	if len(gotDebt.Items) != 0 {
		t.Fatalf("expected 0 debt goals, got %d", len(gotDebt.Items))
	}
	if gotDebt.TotalCount != 0 {
		t.Errorf("TotalCount = %d, want 0", gotDebt.TotalCount)
	}

	// Tenant isolation: a different tenant sees none.
	otherTenant := uuid.New()
	gotOther, err := repo.FindAll(ctx, otherTenant, nil, &investment, page)
	if err != nil {
		t.Fatalf("FindAll(other tenant): %v", err)
	}
	if len(gotOther.Items) != 0 {
		t.Fatalf("tenant leakage: other tenant saw %d goals", len(gotOther.Items))
	}
}
