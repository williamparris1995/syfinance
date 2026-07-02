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
	"github.com/yucai/server/internal/goal/domain"
	goalrepo "github.com/yucai/server/internal/goal/adapter/driven/repository"
	"github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
)

func setupGoalTestDB(t *testing.T) *goalent.Client {
	t.Helper()
	dbName := "goal_ent_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := goalent.NewClient(goalent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestGoalCRUD(t *testing.T) {
	client := setupGoalTestDB(t)
	repo := goalrepo.NewGoalRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create
	resp, err := svc.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          tenantID,
		Name:              "Emergency Fund",
		GoalType:          domain.GoalTypeSavings,
		TargetAmountCents: 10000000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{uuid.New()},
		Notes:             "6 months expenses",
	})
	if err != nil {
		t.Fatalf("CreateGoal failed: %v", err)
	}
	if resp.Version != 1 {
		t.Errorf("expected version 1, got %d", resp.Version)
	}
	goalID := resp.ID

	// Get
	detail, err := svc.GetGoal(ctx, tenantID, goalID)
	if err != nil {
		t.Fatalf("GetGoal failed: %v", err)
	}
	if detail.ProgressPct != 0 {
		t.Errorf("expected 0%% progress, got %f", detail.ProgressPct)
	}

	// Update
	updated, err := svc.UpdateGoal(ctx, application.UpdateGoalRequest{
		TenantID:          tenantID,
		ID:                goalID,
		Name:              "Emergency Fund (Revised)",
		TargetAmountCents: 12000000,
		Notes:             "9 months expenses",
		Version:           1,
	})
	if err != nil {
		t.Fatalf("UpdateGoal failed: %v", err)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}
	if updated.TargetAmountCents != 12000000 {
		t.Errorf("expected 12000000, got %d", updated.TargetAmountCents)
	}

	// List
	result, err := svc.ListGoals(ctx, application.ListGoalsRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListGoals failed: %v", err)
	}
	if len(result.Goals) != 1 {
		t.Errorf("expected 1 goal, got %d", len(result.Goals))
	}

	// Delete
	err = svc.DeleteGoal(ctx, tenantID, goalID)
	if err != nil {
		t.Fatalf("DeleteGoal failed: %v", err)
	}
	_, err = svc.GetGoal(ctx, tenantID, goalID)
	if err == nil {
		t.Error("expected error after delete")
	}
}

func TestGoalProgress(t *testing.T) {
	client := setupGoalTestDB(t)
	repo := goalrepo.NewGoalRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, _ := svc.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          uuid.New(),
		Name:              "Vacation",
		GoalType:          domain.GoalTypeSavings,
		TargetAmountCents: 1000000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{uuid.New()},
	})

	// Add progress
	progress, err := svc.UpdateGoalProgress(ctx, application.UpdateProgressRequest{
		TenantID:    resp.TenantID,
		ID:          resp.ID,
		AmountCents: 750000,
	})
	if err != nil {
		t.Fatalf("UpdateGoalProgress failed: %v", err)
	}
	if progress.CurrentAmountCents != 750000 {
		t.Errorf("expected 750000, got %d", progress.CurrentAmountCents)
	}
	if progress.ProgressPct != 75.0 {
		t.Errorf("expected 75%%, got %f", progress.ProgressPct)
	}
	if progress.IsCompleted {
		t.Error("should not be completed yet")
	}

	// Complete by exceeding target
	completed, err := svc.UpdateGoalProgress(ctx, application.UpdateProgressRequest{
		TenantID:    resp.TenantID,
		ID:          resp.ID,
		AmountCents: 500000,
	})
	if err != nil {
		t.Fatalf("UpdateGoalProgress (complete) failed: %v", err)
	}
	if !completed.IsCompleted {
		t.Error("should be auto-completed when target exceeded")
	}
	if completed.CompletedAt == nil {
		t.Error("completed_at should be set")
	}
}

func TestGoalSyncFromAccount(t *testing.T) {
	client := setupGoalTestDB(t)
	repo := goalrepo.NewGoalRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	linkedAccountID := uuid.New()
	resp, _ := svc.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          uuid.New(),
		Name:              "New Car",
		GoalType:          domain.GoalTypeSavings,
		TargetAmountCents: 20000000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{linkedAccountID},
	})

	// Sync with account balance of 15,000,000 cents
	synced, err := svc.SyncGoalProgress(ctx, resp.TenantID, resp.ID, 15000000)
	if err != nil {
		t.Fatalf("SyncGoalProgress failed: %v", err)
	}
	if synced.CurrentAmountCents != 15000000 {
		t.Errorf("expected 15000000, got %d", synced.CurrentAmountCents)
	}
	if synced.IsCompleted {
		t.Error("should not be completed")
	}
}

func TestGoalOverdue(t *testing.T) {
	client := setupGoalTestDB(t)
	repo := goalrepo.NewGoalRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	past := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	resp, err := svc.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          uuid.New(),
		Name:              "Old Goal",
		GoalType:          domain.GoalTypeSavings,
		TargetAmountCents: 1000000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{uuid.New()},
		Deadline:          &past,
	})
	if err != nil {
		t.Fatalf("CreateGoal failed: %v", err)
	}

	// Get and check overdue status via domain
	goal, _ := repo.FindByID(ctx, resp.TenantID, resp.ID)
	if !goal.IsOverdue() {
		t.Error("goal with past deadline should be overdue")
	}

	// Complete it — should no longer be overdue
	svc.CompleteGoal(ctx, resp.TenantID, resp.ID)
	goal2, _ := repo.FindByID(ctx, resp.TenantID, resp.ID)
	if goal2.IsOverdue() {
		t.Error("completed goal should not be overdue")
	}
}

func TestGoalTenantIsolation(t *testing.T) {
	client := setupGoalTestDB(t)
	repo := goalrepo.NewGoalRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	svc.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          tenantA,
		Name:              "Savings A",
		GoalType:          domain.GoalTypeSavings,
		TargetAmountCents: 500000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{uuid.New()},
	})

	result, _ := svc.ListGoals(ctx, application.ListGoalsRequest{
		TenantID: tenantB,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if len(result.Goals) != 0 {
		t.Errorf("tenant B should see 0 goals, got %d", len(result.Goals))
	}
}
