package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewBudget_Valid(t *testing.T) {
	items := []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
	}
	b, err := NewBudget(uuid.New(), "5月预算", "2026-05", "CNY", items)
	if err != nil {
		t.Fatalf("NewBudget failed: %v", err)
	}
	if b.Version != 1 {
		t.Errorf("expected version 1, got %d", b.Version)
	}
	if b.TotalAmountCents != 80000 {
		t.Errorf("expected total 80000, got %d", b.TotalAmountCents)
	}
	if !b.IsActive {
		t.Error("expected active")
	}
	if len(b.Items) != 2 {
		t.Errorf("expected 2 items, got %d", len(b.Items))
	}
}

func TestNewBudget_InvalidMonth(t *testing.T) {
	_, err := NewBudget(uuid.New(), "Test", "2026-13", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}})
	if err == nil {
		t.Error("expected error for invalid month")
	}
}

func TestNewBudget_EmptyName(t *testing.T) {
	_, err := NewBudget(uuid.New(), "  ", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}})
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestNewBudget_NoItems(t *testing.T) {
	_, err := NewBudget(uuid.New(), "Test", "2026-05", "CNY", nil)
	if err == nil {
		t.Error("expected error for no items")
	}
}

func TestBudget_AddRemoveItem(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 10000}})
	initial := b.TotalAmountCents

	b.AddItem(BudgetItem{AccountID: uuid.New(), PlannedAmountCents: 5000})
	if b.TotalAmountCents != initial+5000 {
		t.Errorf("expected total %d, got %d", initial+5000, b.TotalAmountCents)
	}
	if len(b.Items) != 2 {
		t.Errorf("expected 2 items, got %d", len(b.Items))
	}

	err := b.RemoveItem(b.Items[1].ID)
	if err != nil {
		t.Fatalf("RemoveItem failed: %v", err)
	}
	if b.TotalAmountCents != initial {
		t.Errorf("expected total %d after remove, got %d", initial, b.TotalAmountCents)
	}
}

func TestBudget_UsagePct(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}})
	b.Items[0].ActualAmountCents = 75000
	if pct := b.UsagePct(); pct != 75.0 {
		t.Errorf("expected 75%%, got %f", pct)
	}
}

func TestBudget_IsOverBudget(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}})
	b.Items[0].ActualAmountCents = 150000
	if !b.IsOverBudget() {
		t.Error("expected over budget")
	}
}

func TestBudget_CloneToMonth(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
	})
	b.Items[0].ActualAmountCents = 25000

	clone, err := b.CloneToMonth("2026-06", "6月预算")
	if err != nil {
		t.Fatalf("CloneToMonth failed: %v", err)
	}
	if clone.Month != "2026-06" {
		t.Errorf("expected month 2026-06, got %s", clone.Month)
	}
	if clone.Name != "6月预算" {
		t.Errorf("expected name, got %s", clone.Name)
	}
	if clone.TotalAmountCents != b.TotalAmountCents {
		t.Errorf("total should match, got %d", clone.TotalAmountCents)
	}
	// Actuals should be reset
	if clone.TotalActual() != 0 {
		t.Errorf("cloned actuals should be 0, got %d", clone.TotalActual())
	}
	// IDs should differ
	if clone.ID == b.ID {
		t.Error("clone should have different ID")
	}
}

func TestBudget_DeactivateActivate(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}})
	b.Deactivate()
	if b.IsActive {
		t.Error("expected inactive")
	}
	b.Activate()
	if !b.IsActive {
		t.Error("expected active")
	}
}

func TestBudget_IncrementVersion(t *testing.T) {
	b, _ := NewBudget(uuid.New(), "Test", "2026-05", "CNY", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}})
	before := b.Version
	time.Sleep(time.Millisecond)
	b.IncrementVersion()
	if b.Version != before+1 {
		t.Errorf("expected version %d, got %d", before+1, b.Version)
	}
}

func TestBudget_Update(t *testing.T) {
	b, err := NewBudget(uuid.New(), "原预算", "2026-05", "CNY", []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 50000},
	})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	origID := b.ID
	origMonth := b.Month
	origVersion := b.Version

	err = b.Update("改名", "USD", []BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 30000},
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if b.Name != "改名" {
		t.Errorf("name: got %q, want 改名", b.Name)
	}
	if b.CurrencyCode != "USD" {
		t.Errorf("currency: got %q, want USD", b.CurrencyCode)
	}
	if len(b.Items) != 2 {
		t.Fatalf("items: got %d, want 2 (full replace)", len(b.Items))
	}
	for _, it := range b.Items {
		if it.BudgetID != origID {
			t.Errorf("item BudgetID: got %s, want %s", it.BudgetID, origID)
		}
		if it.ID == uuid.Nil {
			t.Error("item ID not assigned")
		}
	}
	if b.TotalAmountCents != 50000 {
		t.Errorf("total: got %d, want 50000 (30000+20000)", b.TotalAmountCents)
	}
	if b.Version != origVersion+1 {
		t.Errorf("version: got %d, want %d (bumped)", b.Version, origVersion+1)
	}
	if b.Month != origMonth {
		t.Errorf("month mutated: got %s, want %s (immutable)", b.Month, origMonth)
	}
	if b.ID != origID {
		t.Errorf("ID mutated: got %s, want %s (stable)", b.ID, origID)
	}

	// Validation: empty name → err
	if err := b.Update("   ", "USD", []BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100}}); err == nil {
		t.Error("empty name: expected error, got nil")
	}
	// Validation: empty items → err
	if err := b.Update("ok", "USD", []BudgetItem{}); err == nil {
		t.Error("empty items: expected error, got nil")
	}
}

func TestMonthRange(t *testing.T) {
	from, to := monthRange("2026-02")
	if from.Day() != 1 {
		t.Errorf("expected day 1, got %d", from.Day())
	}
	if to.Day() != 28 {
		t.Errorf("expected day 28 for Feb, got %d", to.Day())
	}
}
