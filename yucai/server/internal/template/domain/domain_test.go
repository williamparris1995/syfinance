package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/shared/domain/recurrence"
)

func TestNewTemplate_Valid(t *testing.T) {
	tmpl, err := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 1},
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
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 1},
		time.Now(),
	)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestTemplate_IsDue(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 1},
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
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 1},
		time.Now(),
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

func TestNewTemplate_NextDateUsesRule(t *testing.T) {
	// Every 2nd Tuesday: first occurrence after 2026-01-01 is 2026-01-13.
	tmpl, err := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{
			Cycle:       recurrence.CycleMonthly,
			MonthlyMode: recurrence.MonthlyByNthWeekday,
			Nth:         2,
			WeekdayMask: 1 << 1,
		},
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("NewTransactionTemplate failed: %v", err)
	}
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-01-13" {
		t.Errorf("expected next date 2026-01-13, got %s", got)
	}
}

func TestNewTemplate_InvalidRule(t *testing.T) {
	_, err := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleWeekly, WeekdayMask: 0x80},
		time.Now(),
	)
	if err == nil {
		t.Error("expected error for invalid weekday mask")
	}
}

func TestTemplate_AdvanceToNext(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 15},
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
