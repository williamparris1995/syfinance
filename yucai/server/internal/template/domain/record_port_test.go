package domain

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAdvanceNextDate_Weekly(t *testing.T) {
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, CycleWeekly, 0)
	want := time.Date(2026, 1, 22, 0, 0, 0, 0, time.UTC)
	if !got.Equal(want) {
		t.Errorf("weekly: expected %v, got %v", want, got)
	}
}

func TestAdvanceNextDate_Monthly(t *testing.T) {
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, CycleMonthly, 0)
	want := time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC)
	if !got.Equal(want) {
		t.Errorf("monthly: expected %v, got %v", want, got)
	}
}

func TestAdvanceNextDate_Yearly(t *testing.T) {
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, CycleYearly, 0)
	want := time.Date(2027, 1, 15, 0, 0, 0, 0, time.UTC)
	if !got.Equal(want) {
		t.Errorf("yearly: expected %v, got %v", want, got)
	}
}

func TestAdvanceNextDate_Custom(t *testing.T) {
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, CycleCustom, 10)
	want := time.Date(2026, 1, 25, 0, 0, 0, 0, time.UTC)
	if !got.Equal(want) {
		t.Errorf("custom: expected %v, got %v", want, got)
	}
}

func TestAdvanceNextDate_CustomZeroDays(t *testing.T) {
	// custom with cycleDays=0 → no advance (+0 days)
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, CycleCustom, 0)
	if !got.Equal(current) {
		t.Errorf("custom zero days: expected unchanged %v, got %v", current, got)
	}
}

func TestAdvanceNextDate_Unspecified(t *testing.T) {
	// unspecified / zero cycle → unchanged (no advance)
	current := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	got := advanceNextDate(current, 0, 0)
	if !got.Equal(current) {
		t.Errorf("unspecified: expected unchanged %v, got %v", current, got)
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
