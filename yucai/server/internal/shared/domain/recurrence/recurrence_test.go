package recurrence

import (
	"testing"
	"time"
)

func d(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic(err)
	}
	return t
}

func TestNextAfter(t *testing.T) {
	const (
		mon = 1 << 0
		tue = 1 << 1
		wed = 1 << 2
		fri = 1 << 4
	)
	monToFri := int32(mon | tue | 1<<2 | 1<<3 | fri)

	tests := []struct {
		name string
		rule Rule
		from string
		want string
	}{
		// Weekly.
		{"weekly legacy mask0 keeps weekday", Rule{Cycle: CycleWeekly}, "2026-01-07", "2026-01-14"},
		{"weekly monday mask", Rule{Cycle: CycleWeekly, WeekdayMask: mon}, "2026-01-05", "2026-01-12"},
		{"weekly multi weekday next hit", Rule{Cycle: CycleWeekly, WeekdayMask: mon | fri}, "2026-01-05", "2026-01-09"},
		{"weekly multi weekday same week wrap", Rule{Cycle: CycleWeekly, WeekdayMask: mon | fri}, "2026-01-09", "2026-01-12"},
		{"weekly interval 2 skips week", Rule{Cycle: CycleWeekly, Interval: 2, WeekdayMask: mon}, "2026-01-05", "2026-01-19"},
		{"weekly interval 2 mask0 anchors own weekday", Rule{Cycle: CycleWeekly, Interval: 2}, "2026-01-07", "2026-01-21"},
		{"weekly weekdays only", Rule{Cycle: CycleWeekly, WeekdayMask: monToFri}, "2026-01-09", "2026-01-12"},
		{"weekly sunday bit6", Rule{Cycle: CycleWeekly, WeekdayMask: 1 << 6}, "2026-01-04", "2026-01-11"},

		// Monthly by date.
		{"monthly legacy billing0 keeps day", Rule{Cycle: CycleMonthly}, "2026-01-15", "2026-02-15"},
		{"monthly billing day", Rule{Cycle: CycleMonthly, BillingDay: 10}, "2026-01-15", "2026-02-10"},
		{"monthly month-end clamp from jan31", Rule{Cycle: CycleMonthly}, "2026-01-31", "2026-02-28"},
		{"monthly leap year clamp", Rule{Cycle: CycleMonthly}, "2028-01-31", "2028-02-29"},
		{"monthly billing 31 means month end", Rule{Cycle: CycleMonthly, BillingDay: 31}, "2026-01-15", "2026-02-28"},
		{"monthly billing 31 april", Rule{Cycle: CycleMonthly, BillingDay: 31}, "2026-03-31", "2026-04-30"},
		{"monthly interval 3 quarterly", Rule{Cycle: CycleMonthly, Interval: 3, BillingDay: 15}, "2026-01-15", "2026-04-15"},
		{"monthly cross year", Rule{Cycle: CycleMonthly, BillingDay: 15}, "2025-12-15", "2026-01-15"},

		// Monthly nth weekday.
		{"monthly nth 2nd tuesday", Rule{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 2, WeekdayMask: tue}, "2026-01-01", "2026-01-13"},
		{"monthly nth skips current when passed", Rule{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 2, WeekdayMask: tue}, "2026-01-13", "2026-02-10"},
		{"monthly nth 5 last friday", Rule{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 5, WeekdayMask: fri}, "2026-01-01", "2026-01-30"},
		{"monthly nth last wednesday of month", Rule{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 5, WeekdayMask: wed}, "2026-01-01", "2026-01-28"},
		{"monthly nth interval 2", Rule{Cycle: CycleMonthly, Interval: 2, MonthlyMode: MonthlyByNthWeekday, Nth: 1, WeekdayMask: mon}, "2026-01-05", "2026-03-02"},
		{"monthly nth invalid mask falls back to date", Rule{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 2, WeekdayMask: mon | tue}, "2026-01-15", "2026-02-15"},

		// Yearly.
		{"yearly keeps date", Rule{Cycle: CycleYearly}, "2026-05-20", "2027-05-20"},
		{"yearly feb29 clamps to feb28", Rule{Cycle: CycleYearly}, "2024-02-29", "2025-02-28"},
		{"yearly interval 2", Rule{Cycle: CycleYearly, Interval: 2}, "2026-05-20", "2028-05-20"},

		// Custom (every N days).
		{"custom uses cycle days", Rule{Cycle: CycleCustom, CycleDays: 30}, "2026-01-01", "2026-01-31"},
		{"custom daily", Rule{Cycle: CycleCustom, CycleDays: 1}, "2026-01-01", "2026-01-02"},
		{"custom zero days treated as daily", Rule{Cycle: CycleCustom}, "2026-01-01", "2026-01-02"},

		// Unknown falls back to +1 month (legacy default).
		{"unknown cycle defaults to monthly", Rule{Cycle: 99}, "2026-01-15", "2026-02-15"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.rule.NextAfter(d(tt.from))
			if got.Format("2006-01-02") != tt.want {
				t.Errorf("NextAfter(%s) = %s, want %s", tt.from, got.Format("2006-01-02"), tt.want)
			}
		})
	}
}

func TestOccurrences(t *testing.T) {
	rule := Rule{Cycle: CycleWeekly, WeekdayMask: 1 << 0} // every Monday
	got := rule.Occurrences(d("2026-01-05"), 3)
	want := []string{"2026-01-12", "2026-01-19", "2026-01-26"}
	if len(got) != len(want) {
		t.Fatalf("got %d occurrences, want %d", len(got), len(want))
	}
	for i := range want {
		if got[i].Format("2006-01-02") != want[i] {
			t.Errorf("occurrence[%d] = %s, want %s", i, got[i].Format("2006-01-02"), want[i])
		}
	}
}

func TestOccurrencesBetween(t *testing.T) {
	// 12 weekly occurrences between Jan 1 and Mar 26 (exclusive of Mar 30).
	rule := Rule{Cycle: CycleWeekly, WeekdayMask: 1 << 0}
	got := rule.OccurrencesBetween(d("2026-01-01"), d("2026-03-26"), false)
	if len(got) != 12 {
		t.Fatalf("got %d occurrences, want 12", len(got))
	}
	// atLeastOne returns one occurrence even past the end.
	got = rule.OccurrencesBetween(d("2026-01-05"), d("2026-01-06"), true)
	if len(got) != 1 || got[0].Format("2006-01-02") != "2026-01-12" {
		t.Fatalf("atLeastOne = %v, want [2026-01-12]", got)
	}
}

func TestPeriodYears(t *testing.T) {
	tests := []struct {
		rule Rule
		want float64
	}{
		{Rule{Cycle: CycleMonthly}, 1.0 / 12.0},
		{Rule{Cycle: CycleMonthly, Interval: 3}, 3.0 / 12.0},
		{Rule{Cycle: CycleWeekly}, 7.0 / 365.0},
		{Rule{Cycle: CycleWeekly, Interval: 2}, 14.0 / 365.0},
		{Rule{Cycle: CycleYearly}, 1.0},
		{Rule{Cycle: CycleCustom, CycleDays: 30}, 30.0 / 365.0},
	}
	for _, tt := range tests {
		if got := tt.rule.PeriodYears(); got != tt.want {
			t.Errorf("PeriodYears(%+v) = %v, want %v", tt.rule, got, tt.want)
		}
	}
}

func TestValidate(t *testing.T) {
	valid := []Rule{
		{Cycle: CycleWeekly},
		{Cycle: CycleWeekly, Interval: 2, WeekdayMask: 0x7F},
		{Cycle: CycleMonthly, BillingDay: 31, MonthlyMode: MonthlyByNthWeekday, Nth: 5, WeekdayMask: 1 << 3},
		{Cycle: CycleCustom, CycleDays: 3650},
	}
	for i, r := range valid {
		if err := r.Validate(); err != nil {
			t.Errorf("valid[%d] returned error: %v", i, err)
		}
	}
	invalid := []Rule{
		{Cycle: 5},
		{Cycle: CycleWeekly, Interval: -1},
		{Cycle: CycleWeekly, Interval: 101},
		{Cycle: CycleCustom, CycleDays: -7},
		{Cycle: CycleCustom, CycleDays: 3651},
		{Cycle: CycleMonthly, BillingDay: 32},
		{Cycle: CycleMonthly, BillingDay: -1},
		{Cycle: CycleWeekly, WeekdayMask: 0x80},
		{Cycle: CycleMonthly, MonthlyMode: MonthlyMode(7)},
		{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: 6},
		{Cycle: CycleMonthly, MonthlyMode: MonthlyByNthWeekday, Nth: -2},
	}
	for i, r := range invalid {
		if err := r.Validate(); err == nil {
			t.Errorf("invalid[%d] %+v: expected error", i, r)
		}
	}
}
