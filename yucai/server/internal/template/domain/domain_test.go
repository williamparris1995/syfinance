package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewTemplate_Valid(t *testing.T) {
	tmpl, err := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		CycleMonthly, 1,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("NewTransactionTemplate failed: %v", err)
	}
	if tmpl.Version != 1 {
		t.Errorf("expected version 1, got %d", tmpl.Version)
	}
	if tmpl.Paused {
		t.Error("should not be paused initially")
	}
}

func TestNewTemplate_EmptyName(t *testing.T) {
	_, err := NewTransactionTemplate(
		uuid.New(), "  ", 500000,
		DirectionExpense, uuid.New(),
		CycleMonthly, 1, time.Now(),
	)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestTemplate_IsDue(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		CycleMonthly, 1,
		time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if !tmpl.IsDue() {
		t.Error("template with past next_date should be due")
	}
}

func TestTemplate_PauseResume(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		CycleMonthly, 1, time.Now(),
	)
	tmpl.Pause()
	if !tmpl.Paused {
		t.Error("should be paused")
	}
	tmpl.Resume()
	if tmpl.Paused {
		t.Error("should be resumed")
	}
}

func TestCalculateNextDate_Monthly(t *testing.T) {
	base := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	next := CalculateNextDate(base, CycleMonthly, 15, 1)
	if next.Month() != time.February {
		t.Errorf("expected February, got %v", next.Month())
	}
	if next.Day() != 15 {
		t.Errorf("expected day 15, got %d", next.Day())
	}
}

func TestCalculateNextDate_MonthEndClamping(t *testing.T) {
	base := time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC)
	next := CalculateNextDate(base, CycleMonthly, 31, 1)
	if next.Month() != time.February {
		t.Errorf("expected February, got %v", next.Month())
	}
	if next.Day() != 28 {
		t.Errorf("expected day 28 (Feb), got %d", next.Day())
	}
}

func TestCalculateNextDate_Weekly(t *testing.T) {
	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC) // Thursday
	next := CalculateNextDate(base, CycleWeekly, 0, 1)
	if next.Day() != 8 {
		t.Errorf("expected day 8, got %d", next.Day())
	}
}

func TestTemplate_AdvanceToNext(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		CycleMonthly, 15,
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	)
	before := tmpl.NextDate
	tmpl.AdvanceToNext()
	if !tmpl.NextDate.After(before) {
		t.Error("next_date should advance")
	}
}

func TestTemplateDirection_RoundTrip(t *testing.T) {
	dirs := []TemplateDirection{DirectionExpense, DirectionIncome, DirectionTransfer}
	for _, d := range dirs {
		if ParseTemplateDirection(d.String()) != d {
			t.Errorf("round-trip failed for %v", d)
		}
	}
}

func TestTemplateCycle_RoundTrip(t *testing.T) {
	cycles := []TemplateCycle{CycleWeekly, CycleMonthly, CycleYearly, CycleCustom}
	for _, c := range cycles {
		if ParseTemplateCycle(c.String()) != c {
			t.Errorf("round-trip failed for %v", c)
		}
	}
}
