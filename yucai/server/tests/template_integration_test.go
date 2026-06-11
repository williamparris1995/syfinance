package tests

import (
	"context"
	"testing"
	"time"

	"database/sql"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
	tmplrepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	"github.com/yucai/server/internal/template/application"
	tmplent "github.com/yucai/server/internal/template/ent"
)

func setupTemplateTestDB(t *testing.T) *tmplent.Client {
	t.Helper()
	dbName := "tmpl_ent_" + t.Name()
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
	client := tmplent.NewClient(tmplent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestTemplateCRUD(t *testing.T) {
	client := setupTemplateTestDB(t)
	repo := tmplrepo.NewTemplateRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create
	resp, err := svc.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:       tenantID,
		Name:           "Rent",
		AmountCents:    500000,
		Direction:      domain.DirectionExpense,
		SourceAccountID: uuid.New(),
		Cycle:          domain.CycleMonthly,
		BillingDay:     1,
		StartDate:      time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("CreateTemplate failed: %v", err)
	}
	if resp.Version != 1 {
		t.Errorf("expected version 1, got %d", resp.Version)
	}
	tmplID := resp.ID

	// Get
	_, err = svc.GetTemplate(ctx, tenantID, tmplID)
	if err != nil {
		t.Fatalf("GetTemplate failed: %v", err)
	}

	// Update
	updated, err := svc.UpdateTemplate(ctx, application.UpdateTemplateRequest{
		TenantID:    tenantID,
		ID:          tmplID,
		Name:        "Rent (Updated)",
		AmountCents: 550000,
		Version:     1,
	})
	if err != nil {
		t.Fatalf("UpdateTemplate failed: %v", err)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}

	// List
	result, err := svc.ListTemplates(ctx, application.ListTemplatesRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListTemplates failed: %v", err)
	}
	if len(result.Templates) != 1 {
		t.Errorf("expected 1 template, got %d", len(result.Templates))
	}

	// Delete
	err = svc.DeleteTemplate(ctx, tenantID, tmplID)
	if err != nil {
		t.Fatalf("DeleteTemplate failed: %v", err)
	}
	_, err = svc.GetTemplate(ctx, tenantID, tmplID)
	if err == nil {
		t.Error("expected error after delete")
	}
}

func TestTemplatePauseResume(t *testing.T) {
	client := setupTemplateTestDB(t)
	repo := tmplrepo.NewTemplateRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	resp, _ := svc.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:       tenantID,
		Name:           "Salary",
		AmountCents:    1500000,
		Direction:      domain.DirectionIncome,
		SourceAccountID: uuid.New(),
		Cycle:          domain.CycleMonthly,
		BillingDay:     15,
		StartDate:      time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	})

	// Pause
	paused, err := svc.PauseTemplate(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("PauseTemplate failed: %v", err)
	}
	if !paused.Paused {
		t.Error("expected paused")
	}

	// List paused
	pausedBool := true
	result, _ := svc.ListTemplates(ctx, application.ListTemplatesRequest{
		TenantID: tenantID,
		Paused:   &pausedBool,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if len(result.Templates) != 1 {
		t.Errorf("expected 1 paused template, got %d", len(result.Templates))
	}

	// Resume
	resumed, err := svc.ResumeTemplate(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("ResumeTemplate failed: %v", err)
	}
	if resumed.Paused {
		t.Error("expected not paused after resume")
	}
}

func TestTemplateIsDue(t *testing.T) {
	client := setupTemplateTestDB(t)
	repo := tmplrepo.NewTemplateRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, _ := svc.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:       uuid.New(),
		Name:           "Old Rent",
		AmountCents:    500000,
		Direction:      domain.DirectionExpense,
		SourceAccountID: uuid.New(),
		Cycle:          domain.CycleMonthly,
		BillingDay:     1,
		StartDate:      time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
	})

	tmpl, _ := repo.FindByID(ctx, resp.TenantID, resp.ID)
	if !tmpl.IsDue() {
		t.Error("template with past next_date should be due")
	}
}

func TestTemplateAdvanceToNext(t *testing.T) {
	client := setupTemplateTestDB(t)
	repo := tmplrepo.NewTemplateRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, _ := svc.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:       uuid.New(),
		Name:           "Monthly",
		AmountCents:    100000,
		Direction:      domain.DirectionExpense,
		SourceAccountID: uuid.New(),
		Cycle:          domain.CycleMonthly,
		BillingDay:     15,
		StartDate:      time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	})

	tmpl, _ := repo.FindByID(ctx, resp.TenantID, resp.ID)
	before := tmpl.NextDate
	tmpl.AdvanceToNext()
	tmpl.IncrementVersion()
	repo.Update(ctx, tmpl)

	updated, _ := repo.FindByID(ctx, resp.TenantID, resp.ID)
	if !updated.NextDate.After(before) {
		t.Error("next_date should have advanced")
	}
}

func TestTemplateMonthEndClamping(t *testing.T) {
	base := time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC)
	next := domain.CalculateNextDate(base, domain.CycleMonthly, 31, 1)
	if next.Month() != time.February {
		t.Errorf("expected February, got %v", next.Month())
	}
	if next.Day() != 28 {
		t.Errorf("expected day 28 for Feb, got %d", next.Day())
	}

	next2 := domain.CalculateNextDate(base, domain.CycleMonthly, 31, 2)
	if next2.Month() != time.March {
		t.Errorf("expected March, got %v", next2.Month())
	}
	if next2.Day() != 31 {
		t.Errorf("expected day 31 for March, got %d", next2.Day())
	}
}

func TestTemplateTenantIsolation(t *testing.T) {
	client := setupTemplateTestDB(t)
	repo := tmplrepo.NewTemplateRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	svc.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:       tenantA,
		Name:           "Rent A",
		AmountCents:    500000,
		Direction:      domain.DirectionExpense,
		SourceAccountID: uuid.New(),
		Cycle:          domain.CycleMonthly,
		BillingDay:     1,
		StartDate:      time.Now(),
	})

	result, _ := svc.ListTemplates(ctx, application.ListTemplatesRequest{
		TenantID: tenantB,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if len(result.Templates) != 0 {
		t.Errorf("tenant B should see 0 templates, got %d", len(result.Templates))
	}
}
