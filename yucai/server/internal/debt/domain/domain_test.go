package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewDebtDetails_Valid(t *testing.T) {
	d, err := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Bank of China",
		0.05,
		AmortizationEqualPrincipalInterest,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		10000000, // 100,000 yuan in cents
		DebtTypeUnspecified,
	)
	if err != nil {
		t.Fatalf("NewDebtDetails failed: %v", err)
	}
	if d.Version != 1 {
		t.Errorf("expected version 1, got %d", d.Version)
	}
	if d.Counterparty != "BankofChina" {
		t.Errorf("expected trimmed counterparty, got %q", d.Counterparty)
	}
	if d.TotalPrincipalCents != 10000000 {
		t.Errorf("expected 10000000, got %d", d.TotalPrincipalCents)
	}
}

func TestNewDebtDetails_EmptyCounterparty(t *testing.T) {
	_, err := NewDebtDetails(
		uuid.New(), uuid.New(),
		"  ",
		0.05, AmortizationEqualPrincipalInterest,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		100000,
		DebtTypeUnspecified,
	)
	if err == nil {
		t.Error("expected error for empty counterparty")
	}
}

func TestNewDebtDetails_NonPositivePrincipal(t *testing.T) {
	_, err := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		0,
		DebtTypeUnspecified,
	)
	if err == nil {
		t.Error("expected error for zero principal")
	}
}

func TestNewDebtDetails_NegativeInterestRate(t *testing.T) {
	_, err := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", -0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		100000,
		DebtTypeUnspecified,
	)
	if err == nil {
		t.Error("expected error for negative interest rate")
	}
}

func TestNewDebtDetails_DueDateBeforeStartDate(t *testing.T) {
	_, err := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		100000,
		DebtTypeUnspecified,
	)
	if err == nil {
		t.Error("expected error for due date before start date")
	}
}

func TestLumpSumSchedule(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		12000000, // 120,000 yuan
		DebtTypeUnspecified,
	)
	entries := d.GenerateSchedule()
	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}
	e := entries[0]
	// Interest = 12000000 * 0.05 * 6/12 = 300000
	if e.InterestCents != 300000 {
		t.Errorf("expected interest 300000, got %d", e.InterestCents)
	}
	// Total = 12000000 + 300000 = 12300000
	if e.TotalCents != 12300000 {
		t.Errorf("expected total 12300000, got %d", e.TotalCents)
	}
	if e.PrincipalCents != 12000000 {
		t.Errorf("expected principal 12000000, got %d", e.PrincipalCents)
	}
}

func TestEqualPrincipalSchedule(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationEqualPrincipal,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		12000000, // 120,000 yuan, 6 months
		DebtTypeUnspecified,
	)
	entries := d.GenerateSchedule()
	if len(entries) != 6 {
		t.Fatalf("expected 6 entries, got %d", len(entries))
	}
	// Monthly principal = 12000000 / 6 = 2000000
	for i, e := range entries {
		if e.PrincipalCents != 2000000 {
			t.Errorf("entry %d: expected principal 2000000, got %d", i, e.PrincipalCents)
		}
	}
	// First entry interest = 12000000 * (0.05/12) = 50000
	if entries[0].InterestCents != 50000 {
		t.Errorf("first entry: expected interest 50000, got %d", entries[0].InterestCents)
	}
	// Verify total principal sums correctly
	var totalPrincipal int64
	for _, e := range entries {
		totalPrincipal += e.PrincipalCents
	}
	if totalPrincipal != 12000000 {
		t.Errorf("total principal should be 12000000, got %d", totalPrincipal)
	}
}

func TestEqualPrincipalInterestSchedule(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationEqualPrincipalInterest,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		12000000, // 120,000 yuan, 6 months
		DebtTypeUnspecified,
	)
	entries := d.GenerateSchedule()
	if len(entries) != 6 {
		t.Fatalf("expected 6 entries, got %d", len(entries))
	}

	// Monthly payment = P * r * (1+r)^n / ((1+r)^n - 1)
	// P = 12000000, r = 0.05/12, n = 6
	// Each payment should be roughly the same
	for i := 1; i < len(entries); i++ {
		diff := entries[i].TotalCents - entries[0].TotalCents
		if diff > 10 || diff < -10 {
			t.Errorf("entry %d total %d differs from first %d by %d",
				i, entries[i].TotalCents, entries[0].TotalCents, diff)
		}
	}

	// Verify total principal sums correctly
	var totalPrincipal int64
	for _, e := range entries {
		totalPrincipal += e.PrincipalCents
	}
	if totalPrincipal != 12000000 {
		t.Errorf("total principal should be 12000000, got %d", totalPrincipal)
	}
}

func TestZeroInterestRate(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Friend", 0.0, AmortizationEqualPrincipalInterest,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		900000, // 9,000 yuan, 3 months
		DebtTypeUnspecified,
	)
	entries := d.GenerateSchedule()
	if len(entries) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(entries))
	}
	for i, e := range entries {
		if e.InterestCents != 0 {
			t.Errorf("entry %d: expected 0 interest, got %d", i, e.InterestCents)
		}
		if e.PrincipalCents != 300000 {
			t.Errorf("entry %d: expected 300000 principal, got %d", i, e.PrincipalCents)
		}
	}
}

func TestMarkPaid(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		1000000,
		DebtTypeUnspecified,
	)
	d.GenerateSchedule()
	entryID := d.Schedule[0].ID
	txnID := uuid.New()

	err := d.MarkPaid(entryID, txnID)
	if err != nil {
		t.Fatalf("MarkPaid failed: %v", err)
	}
	if !d.Schedule[0].Paid {
		t.Error("expected entry to be paid")
	}
	if d.Schedule[0].TransactionID == nil || *d.Schedule[0].TransactionID != txnID {
		t.Error("transaction ID not set correctly")
	}
	if d.Version != 2 {
		t.Errorf("expected version 2, got %d", d.Version)
	}
}

func TestMarkPaid_EntryNotFound(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		1000000,
		DebtTypeUnspecified,
	)
	err := d.MarkPaid(uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error for non-existent entry")
	}
}

func TestRemainingPrincipal(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationEqualPrincipal,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		900000, // 3 months
		DebtTypeUnspecified,
	)
	d.GenerateSchedule()

	// Before any payment
	if rem := d.RemainingPrincipal(); rem != 900000 {
		t.Errorf("expected remaining 900000, got %d", rem)
	}

	// Pay first entry
	d.MarkPaid(d.Schedule[0].ID, uuid.New())
	if rem := d.RemainingPrincipal(); rem != 600000 {
		t.Errorf("expected remaining 600000, got %d", rem)
	}
}

func TestTermInMonths(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC),
		1000000,
		DebtTypeUnspecified,
	)
	if months := d.TermInMonths(); months != 6 {
		t.Errorf("expected 6 months, got %d", months)
	}
}

func TestIncrementVersion(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		1000000,
		DebtTypeUnspecified,
	)
	before := d.Version
	d.IncrementVersion()
	if d.Version != before+1 {
		t.Errorf("expected version %d, got %d", before+1, d.Version)
	}
}

func TestAmortizationMethod_StringRoundTrip(t *testing.T) {
	methods := []AmortizationMethod{
		AmortizationEqualPrincipalInterest,
		AmortizationEqualPrincipal,
		AmortizationLumpSum,
	}
	for _, m := range methods {
		parsed := ParseAmortizationMethod(m.String())
		if parsed != m {
			t.Errorf("round-trip failed: %v -> %s -> %v", m, m.String(), parsed)
		}
	}
}

func TestDebtType_StringRoundTrip(t *testing.T) {
	types := []DebtType{BorrowedIn, BorrowedOut}
	for _, dt := range types {
		parsed := ParseDebtType(dt.String())
		if parsed != dt {
			t.Errorf("round-trip failed: %v -> %q -> %v", dt, dt.String(), parsed)
		}
	}
}

func TestDebtType_StringValues(t *testing.T) {
	// ent column stores exact strings; verify them explicitly (name-based mapping).
	if BorrowedIn.String() != "borrowed_in" {
		t.Errorf("BorrowedIn.String() = %q, want %q", BorrowedIn.String(), "borrowed_in")
	}
	if BorrowedOut.String() != "borrowed_out" {
		t.Errorf("BorrowedOut.String() = %q, want %q", BorrowedOut.String(), "borrowed_out")
	}
	// Unspecified normalizes to borrowed_in (matches ent default).
	if DebtTypeUnspecified.String() != "borrowed_in" {
		t.Errorf("DebtTypeUnspecified.String() = %q, want %q", DebtTypeUnspecified.String(), "borrowed_in")
	}
}

func TestParseDebtType_UnknownDefaultsToBorrowedIn(t *testing.T) {
	for _, s := range []string{"", "unknown", "INVALID", "BorrowedIn"} {
		if got := ParseDebtType(s); got != BorrowedIn {
			t.Errorf("ParseDebtType(%q) = %v, want BorrowedIn", s, got)
		}
	}
}

func TestAddMonths_Clamping(t *testing.T) {
	// Jan 31 + 1 month = Feb 28
	result := addMonths(time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC), 1)
	if result.Month() != time.February {
		t.Errorf("expected February, got %v", result.Month())
	}
	if result.Day() != 28 {
		t.Errorf("expected day 28, got %d", result.Day())
	}
}
