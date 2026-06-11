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
	"github.com/yucai/server/internal/debt/domain"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	"github.com/yucai/server/internal/debt/application"
	debtent "github.com/yucai/server/internal/debt/ent"
)

func setupDebtTestDB(t *testing.T) *debtent.Client {
	t.Helper()
	dbName := "debt_ent_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := debtent.NewClient(debtent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestDebtCRUD(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()
	accountID := uuid.New()

	// Create
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 12000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}
	if resp.Version != 1 {
		t.Errorf("expected version 1, got %d", resp.Version)
	}
	debtID := resp.ID

	// Get
	detail, err := svc.GetDebt(ctx, tenantID, debtID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}
	if len(detail.Schedule) != 6 {
		t.Errorf("expected 6 schedule entries, got %d", len(detail.Schedule))
	}

	// Update
	updated, err := svc.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           debtID,
		Counterparty: "Bank of China",
		InterestRate: 0.045,
		Version:      1,
	})
	if err != nil {
		t.Fatalf("UpdateDebt failed: %v", err)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}
	if updated.InterestRate != 0.045 {
		t.Errorf("expected rate 0.045, got %f", updated.InterestRate)
	}

	// List
	result, err := svc.ListDebts(ctx, application.ListDebtsRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListDebts failed: %v", err)
	}
	if len(result.Debts) != 1 {
		t.Errorf("expected 1 debt, got %d", len(result.Debts))
	}

	// Delete
	err = svc.DeleteDebt(ctx, tenantID, debtID)
	if err != nil {
		t.Fatalf("DeleteDebt failed: %v", err)
	}

	// Verify deleted
	_, err = svc.GetDebt(ctx, tenantID, debtID)
	if err == nil {
		t.Error("expected error after delete")
	}
}

func TestEqualPrincipalInterestSchedule(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "CMB",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipalInterest,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 12000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, err := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}

	// Verify schedule has 6 entries
	if len(detail.Schedule) != 6 {
		t.Fatalf("expected 6 entries, got %d", len(detail.Schedule))
	}

	// Verify total principal sums correctly
	var totalPrincipal int64
	for _, e := range detail.Schedule {
		totalPrincipal += e.PrincipalCents
	}
	if totalPrincipal != 12000000 {
		t.Errorf("total principal should be 12000000, got %d", totalPrincipal)
	}

	// All payments should be roughly equal (within a few cents)
	firstTotal := detail.Schedule[0].TotalCents
	for i, e := range detail.Schedule {
		diff := e.TotalCents - firstTotal
		if diff > 10 || diff < -10 {
			t.Errorf("entry %d total %d differs from first %d by %d", i, e.TotalCents, firstTotal, diff)
		}
	}
}

func TestLumpSumSchedule(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "Friend",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 1000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, err := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}

	if len(detail.Schedule) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(detail.Schedule))
	}
	// Interest = 1000000 * 0.05 * 6/12 = 25000
	if detail.Schedule[0].InterestCents != 25000 {
		t.Errorf("expected interest 25000, got %d", detail.Schedule[0].InterestCents)
	}
}

func TestRecordPayment(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 900000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, _ := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	entryID := detail.Schedule[0].ID
	fromAccountID := uuid.New()

	// Record payment
	payResult, err := svc.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        resp.TenantID,
		DebtID:          resp.ID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccountID,
	})
	if err != nil {
		t.Fatalf("RecordPayment failed: %v", err)
	}
	if payResult.TransactionID == uuid.Nil {
		t.Error("expected non-nil transaction ID")
	}
	if !payResult.Entry.Paid {
		t.Error("expected entry to be paid")
	}

	// Verify remaining principal decreased
	updated, _ := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if updated.Debt.RemainingPrincipal >= 900000 {
		t.Errorf("remaining should have decreased, got %d", updated.Debt.RemainingPrincipal)
	}
}

func TestDebtTenantIsolation(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	// Create for tenant A
	_, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantA,
		AccountID:           uuid.New(),
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 500000,
	})
	if err != nil {
		t.Fatalf("CreateDebt for A failed: %v", err)
	}

	// Tenant B should see no debts
	result, err := svc.ListDebts(ctx, application.ListDebtsRequest{
		TenantID: tenantB,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListDebts for B failed: %v", err)
	}
	if len(result.Debts) != 0 {
		t.Errorf("tenant B should see 0 debts, got %d", len(result.Debts))
	}
}
