package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

// TestSchemaCompositeUnique_RejectsDuplicateSchedule verifies the DB-level
// composite unique index (debt_id, payment_date): two installments of one
// debt on the same day are rejected by the database.
func TestSchemaCompositeUnique_RejectsDuplicateSchedule(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	debt := uuid.New()
	seedDebtParent(t, client, tenant, debt)
	day := dayDebt("2026-03-01")

	if _, err := client.PaymentSchedule.Create().
		SetDebtID(debt).SetPaymentDate(day).
		SetPrincipalCents(100_00).SetInterestCents(10_00).SetTotalCents(110_00).
		Save(ctx); err != nil {
		t.Fatalf("first schedule: %v", err)
	}
	if _, err := client.PaymentSchedule.Create().
		SetDebtID(debt).SetPaymentDate(day).
		SetPrincipalCents(200_00).SetInterestCents(20_00).SetTotalCents(220_00).
		Save(ctx); err == nil {
		t.Fatal("expected composite unique (debt_id, payment_date) violation, got nil")
	}
}

// TestSchemaCascade_DeleteDebtRemovesChildren verifies both OnDelete(Cascade)
// edges from debt_details: hard-deleting the parent removes its
// payment_schedules and debt_progress_snapshots in the same statement.
func TestSchemaCascade_DeleteDebtRemovesChildren(t *testing.T) {
	client := setupDebtTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()
	debt := uuid.New()
	seedDebtParent(t, client, tenant, debt)

	days := []time.Time{dayDebt("2026-04-01"), dayDebt("2026-05-01")}
	for i, day := range days {
		if _, err := client.PaymentSchedule.Create().
			SetDebtID(debt).SetPaymentDate(day).
			SetPrincipalCents(50_00).SetInterestCents(5_00).SetTotalCents(55_00).
			Save(ctx); err != nil {
			t.Fatalf("seed schedule %d: %v", i, err)
		}
	}
	if _, err := client.DebtProgressSnapshot.Create().
		SetTenantID(tenant).SetDebtID(debt).
		SetSnapshotDate(time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC)).
		SetTotalPrincipalCents(1_000_00).
		SetRemainingPrincipalCents(900_00).
		SetPaidTotalCents(100_00).
		Save(ctx); err != nil {
		t.Fatalf("seed snapshot: %v", err)
	}

	if err := client.DebtDetails.DeleteOneID(debt).Exec(ctx); err != nil {
		t.Fatalf("delete debt: %v", err)
	}

	schedules, err := client.PaymentSchedule.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count schedules: %v", err)
	}
	snapshots, err := client.DebtProgressSnapshot.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count snapshots: %v", err)
	}
	if schedules != 0 || snapshots != 0 {
		t.Errorf("expected cascade to remove all children, got %d schedules / %d snapshots",
			schedules, snapshots)
	}
}
