package domain

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/shared/domain/recurrence"
)

// 推进算法本体(NextAfter)的用例在 internal/shared/domain/recurrence;
// 此处覆盖 template 实体经 Rule() 视图推进的集成语义。
func TestRule_AdvanceWeekly(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleWeekly},
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	)
	before := tmpl.NextDate
	tmpl.AdvanceToNext()
	want := before.AddDate(0, 0, 7)
	if !tmpl.NextDate.Equal(want) {
		t.Errorf("weekly: expected %v, got %v", want, tmpl.NextDate)
	}
}

func TestRule_AdvanceMonthlyClampsMonthEnd(t *testing.T) {
	// billingDay=0(legacy 未设账单日)锚定发生日自身:1/31 → 2/28(月末钳制,
	// 不再滚到 3/3);此后按 28 日漂移 —— 与旧 client/server 推进语义一致。
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleMonthly},
		time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC),
	)
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-02-28" {
		t.Errorf("monthly clamp first: expected 2026-02-28, got %s", got)
	}
	tmpl.AdvanceToNext()
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-03-28" {
		t.Errorf("monthly clamp next: expected 2026-03-28, got %s", got)
	}
}

func TestRule_AdvanceMonthlyBilling31IsMonthEnd(t *testing.T) {
	// billingDay=31 + 钳制 = 「每月末」语义:2 月 → 2/28,3 月 → 3/31,不漂移。
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleMonthly, BillingDay: 31},
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	)
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-02-28" {
		t.Errorf("month-end feb: expected 2026-02-28, got %s", got)
	}
	tmpl.AdvanceToNext()
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-03-31" {
		t.Errorf("month-end mar: expected 2026-03-31, got %s", got)
	}
}

func TestRule_AdvanceCustomUsesCycleDays(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{Cycle: recurrence.CycleCustom, CycleDays: 10},
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
	)
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-01-25" {
		t.Errorf("custom first: expected 2026-01-25, got %s", got)
	}
	tmpl.AdvanceToNext()
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-02-04" {
		t.Errorf("custom next: expected 2026-02-04, got %s", got)
	}
}

func TestRule_AdvanceEvery2WeeksOnMonday(t *testing.T) {
	tmpl, _ := NewTransactionTemplate(
		uuid.New(), "Rent", 500000,
		DirectionExpense, uuid.New(),
		recurrence.Rule{
			Cycle:       recurrence.CycleWeekly,
			Interval:    2,
			WeekdayMask: 1 << 0,
		},
		time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC), // Monday
	)
	// 创建即得首个发生日(严格晚于起始日),再推进一个周期。
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-01-19" {
		t.Errorf("biweekly monday first: expected 2026-01-19, got %s", got)
	}
	tmpl.AdvanceToNext()
	if got := tmpl.NextDate.Format("2006-01-02"); got != "2026-02-02" {
		t.Errorf("biweekly monday next: expected 2026-02-02, got %s", got)
	}
}

// fakeRecorder is a test double for TransactionRecorder.
type fakeRecorder struct {
	called bool
}

func (f *fakeRecorder) Record(ctx context.Context, tenantID uuid.UUID, req RecordRequest) (uuid.UUID, error) {
	f.called = true
	return uuid.New(), nil
}

// Compile-time check that fakeRecorder satisfies TransactionRecorder.
var _ TransactionRecorder = (*fakeRecorder)(nil)

func TestRecordRequest_Fields(t *testing.T) {
	src := uuid.New()
	dst := uuid.New()
	req := RecordRequest{
		Direction:          DirectionTransfer,
		AmountCents:        12345,
		SourceAccountID:    src,
		DestinationAccount: &dst,
		Category:           "groceries",
		Date:               time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC),
	}
	if req.Direction != DirectionTransfer {
		t.Errorf("expected DirectionTransfer, got %v", req.Direction)
	}
	if req.AmountCents != 12345 {
		t.Errorf("expected 12345 cents, got %d", req.AmountCents)
	}
	if req.SourceAccountID != src {
		t.Error("source account mismatch")
	}
	if req.DestinationAccount == nil || *req.DestinationAccount != dst {
		t.Error("destination account mismatch")
	}
	if req.Category != "groceries" {
		t.Errorf("expected category groceries, got %s", req.Category)
	}
	if !req.Date.Equal(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("date mismatch: %v", req.Date)
	}
}
