package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewGoal_Valid(t *testing.T) {
	g, err := NewGoal(uuid.New(), "Emergency Fund", GoalTypeSavings, 10000000, "CNY", nil, nil, "")
	if err != nil {
		t.Fatalf("NewGoal failed: %v", err)
	}
	if g.Version != 1 {
		t.Errorf("expected version 1, got %d", g.Version)
	}
	if g.IsCompleted {
		t.Error("should not be completed initially")
	}
	if g.CurrencyCode != "CNY" {
		t.Errorf("expected CNY, got %s", g.CurrencyCode)
	}
}

func TestNewGoal_EmptyName(t *testing.T) {
	_, err := NewGoal(uuid.New(), "  ", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestNewGoal_NonPositiveTarget(t *testing.T) {
	_, err := NewGoal(uuid.New(), "Test", GoalTypeSavings, 0, "CNY", nil, nil, "")
	if err == nil {
		t.Error("expected error for zero target")
	}
}

func TestNewGoal_UnspecifiedType(t *testing.T) {
	_, err := NewGoal(uuid.New(), "Test", GoalType(0), 100000, "CNY", nil, nil, "")
	if err == nil {
		t.Error("expected error for unspecified type")
	}
}

func TestGoal_AddProgress(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")

	completed := g.AddProgress(60000)
	if completed {
		t.Error("should not be completed yet")
	}
	if g.CurrentAmountCents != 60000 {
		t.Errorf("expected 60000, got %d", g.CurrentAmountCents)
	}
}

func TestGoal_AutoComplete(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")

	completed := g.AddProgress(100000)
	if !completed {
		t.Error("should be auto-completed")
	}
	if !g.IsCompleted {
		t.Error("expected completed")
	}
	if g.CompletedAt == nil {
		t.Error("expected completed_at to be set")
	}
}

func TestGoal_AutoCompleteExceedTarget(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")

	completed := g.AddProgress(150000)
	if !completed {
		t.Error("should be auto-completed when exceeding target")
	}
	if g.CurrentAmountCents != 150000 {
		t.Errorf("expected 150000, got %d", g.CurrentAmountCents)
	}
}

func TestGoal_ProgressPct(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	g.CurrentAmountCents = 75000
	if pct := g.ProgressPct(); pct != 75.0 {
		t.Errorf("expected 75%%, got %f", pct)
	}
}

func TestGoal_RemainingAmount(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	g.CurrentAmountCents = 30000
	if rem := g.RemainingAmount(); rem != 70000 {
		t.Errorf("expected 70000, got %d", rem)
	}
}

func TestGoal_RemainingAmount_Negative(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	g.CurrentAmountCents = 150000
	if rem := g.RemainingAmount(); rem != 0 {
		t.Errorf("expected 0 when over target, got %d", rem)
	}
}

func TestGoal_IsOverdue(t *testing.T) {
	past := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", &past, nil, "")
	if !g.IsOverdue() {
		t.Error("should be overdue")
	}
}

func TestGoal_IsOverdue_Completed(t *testing.T) {
	past := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", &past, nil, "")
	g.MarkCompleted()
	if g.IsOverdue() {
		t.Error("completed goal should not be overdue")
	}
}

func TestGoal_IsOverdue_NoDeadline(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	if g.IsOverdue() {
		t.Error("no deadline should not be overdue")
	}
}

func TestGoal_LinkAccount(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	accountID := uuid.New()
	g.LinkAccount(accountID)
	if g.LinkedAccountID == nil || *g.LinkedAccountID != accountID {
		t.Error("account not linked correctly")
	}
}

func TestGoal_IncrementVersion(t *testing.T) {
	g, _ := NewGoal(uuid.New(), "Savings", GoalTypeSavings, 100000, "CNY", nil, nil, "")
	before := g.Version
	g.IncrementVersion()
	if g.Version != before+1 {
		t.Errorf("expected version %d, got %d", before+1, g.Version)
	}
}

func TestGoalType_StringRoundTrip(t *testing.T) {
	types := []GoalType{GoalTypeSavings, GoalTypeDebtPayoff, GoalTypeInvestment}
	for _, gt := range types {
		parsed := ParseGoalType(gt.String())
		if parsed != gt {
			t.Errorf("round-trip failed: %v -> %s -> %v", gt, gt.String(), parsed)
		}
	}
}
