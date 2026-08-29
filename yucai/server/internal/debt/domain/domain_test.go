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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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

// F7:不可整除本金——月供本金浮点均摊 + 每月四舍五入,末月吸收余差;
// 利息按真实(未截断)remaining 复算。旧实现整除截断(333333)系统性偏差。
//
//	本金 1000001 / 3 月:月供 = round(333333.67) = 333334,末月余 333333;
//	利息:round(1000001×0.05/12)=4167 → round(666667×r)=2778 → round(333333×r)=1389。
func TestEqualPrincipalNonDivisibleRoundsMonthly(t *testing.T) {
	d, _ := NewDebtDetails(
		uuid.New(), uuid.New(),
		"Lender", 0.05, AmortizationEqualPrincipal,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		1000001, // 3 个月,不可整除
		DebtTypeUnspecified,
		"",
		"", "", nil,
	)
	entries := d.GenerateSchedule()
	if len(entries) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(entries))
	}
	wantPrincipal := []int64{333334, 333334, 333333}
	wantInterest := []int64{4167, 2778, 1389}
	for i, e := range entries {
		if e.PrincipalCents != wantPrincipal[i] {
			t.Errorf("entry %d: principal %d, want %d (float amortization + round)", i, e.PrincipalCents, wantPrincipal[i])
		}
		if e.InterestCents != wantInterest[i] {
			t.Errorf("entry %d: interest %d, want %d (interest on true remaining)", i, e.InterestCents, wantInterest[i])
		}
		if e.TotalCents != e.PrincipalCents+e.InterestCents {
			t.Errorf("entry %d: total %d != principal+interest", i, e.TotalCents)
		}
	}
	var total int64
	for _, e := range entries {
		total += e.PrincipalCents
	}
	if total != 1000001 {
		t.Errorf("total principal = %d, want 1000001 (conservation)", total)
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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
		"",
		"", "", nil,
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

func TestNewDebtDetails_SubtypeRoundTrips(t *testing.T) {
	// subtype is a plain string passed through verbatim (no normalization).
	for _, tc := range []struct {
		name    string
		subtype string
	}{
		{"empty", ""},
		{"mortgage_const", DebtSubtypeMortgage},
		{"auto_loan_const", DebtSubtypeAutoLoan},
		{"credit_card_const", DebtSubtypeCreditCard},
		{"receivable_personal", ReceivableSubtypePersonal},
		{"arbitrary_unknown_value", "custom_value"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d, err := NewDebtDetails(
				uuid.New(), uuid.New(),
				"Lender", 0.05, AmortizationLumpSum,
				time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
				time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
				1000000, DebtTypeUnspecified,
				tc.subtype,
				"", "", nil,
			)
			if err != nil {
				t.Fatalf("NewDebtDetails failed: %v", err)
			}
			if d.Subtype != tc.subtype {
				t.Errorf("Subtype = %q, want %q", d.Subtype, tc.subtype)
			}
		})
	}
}

func TestSubtypeConstValues(t *testing.T) {
	// Consts hold the exact string keys persisted/returned verbatim — verify
	// them explicitly so renames surface here rather than at the client.
	want := map[string]string{
		"DebtSubtypeMortgage":      DebtSubtypeMortgage,
		"DebtSubtypeAutoLoan":      DebtSubtypeAutoLoan,
		"DebtSubtypeCreditCard":    DebtSubtypeCreditCard,
		"DebtSubtypeFamily":        DebtSubtypeFamily,
		"DebtSubtypeOther":         DebtSubtypeOther,
		"ReceivableSubtypePersonal": ReceivableSubtypePersonal,
		"ReceivableSubtypeBusiness": ReceivableSubtypeBusiness,
	}
	expected := map[string]string{
		"DebtSubtypeMortgage":      "mortgage",
		"DebtSubtypeAutoLoan":      "auto_loan",
		"DebtSubtypeCreditCard":    "credit_card",
		"DebtSubtypeFamily":        "family",
		"DebtSubtypeOther":         "other",
		"ReceivableSubtypePersonal": "personal",
		"ReceivableSubtypeBusiness": "business",
	}
	for name, v := range want {
		if v != expected[name] {
			t.Errorf("%s = %q, want %q", name, v, expected[name])
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
