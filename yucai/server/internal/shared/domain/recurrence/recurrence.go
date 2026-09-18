// Package recurrence provides the calendar-style recurrence rule shared by
// the template (subscription) and debt (installment schedule) modules.
// All date math is date-granular and normalized to UTC midnight.
package recurrence

import (
	"fmt"
	"time"
)

// Cycle is the unit of a recurrence rule. Values 1-4 align with proto
// TemplateCycle / RecurrenceCycle so adapters can cast directly.
type Cycle int

const (
	CycleWeekly Cycle = iota + 1
	CycleMonthly
	CycleYearly
	CycleCustom // every CycleDays days
)

// String returns the persistence string for the cycle (legacy default
// "monthly" for the zero value).
func (c Cycle) String() string {
	switch c {
	case CycleWeekly:
		return "weekly"
	case CycleMonthly:
		return "monthly"
	case CycleYearly:
		return "yearly"
	case CycleCustom:
		return "custom"
	default:
		return "monthly"
	}
}

// ParseCycle decodes a persisted cycle string (unknown/empty → monthly).
func ParseCycle(s string) Cycle {
	switch s {
	case "weekly":
		return CycleWeekly
	case "monthly":
		return CycleMonthly
	case "yearly":
		return CycleYearly
	case "custom":
		return CycleCustom
	default:
		return CycleMonthly
	}
}

// MonthlyMode selects how a monthly rule picks its day of the month.
type MonthlyMode int32

const (
	// MonthlyByDate anchors a fixed day (BillingDay, or the occurrence's own
	// day when BillingDay <= 0), clamped to the target month's last day.
	MonthlyByDate MonthlyMode = iota
	// MonthlyByNthWeekday anchors the Nth weekday of the month (Nth=5 means
	// the last such weekday). Requires exactly one WeekdayMask bit.
	MonthlyByNthWeekday
)

// Rule is a calendar-style recurrence rule. Zero values keep legacy
// behavior: Interval<=1 means 1, WeekdayMask==0 derives the weekday from
// the anchor date, CycleDays<=1 means 1, MonthlyByDate with BillingDay<=0
// anchors the from-date's day.
type Rule struct {
	Cycle       Cycle
	Interval    int32  // every N weeks/months/years
	CycleDays   int32  // CycleCustom: every N days
	BillingDay  int32  // monthly-by-date anchor 1-31 (31 clamps to month end)
	WeekdayMask int32  // bit0=Monday ... bit6=Sunday
	MonthlyMode MonthlyMode
	Nth         int32 // 1-4 = the Nth, 5 = the last (MonthlyByNthWeekday)
}

// Validate checks the rule's value ranges. Zero values are valid (legacy).
func (r Rule) Validate() error {
	if r.Cycle < CycleWeekly || r.Cycle > CycleCustom {
		return fmt.Errorf("invalid recurrence cycle: %d", r.Cycle)
	}
	if r.Interval < 0 || r.Interval > 100 {
		return fmt.Errorf("recurrence interval must be 1-100")
	}
	if r.CycleDays < 0 || r.CycleDays > 3650 {
		return fmt.Errorf("recurrence cycle_days must be 1-3650")
	}
	if r.BillingDay < 0 || r.BillingDay > 31 {
		return fmt.Errorf("recurrence billing_day must be 1-31")
	}
	if r.WeekdayMask < 0 || r.WeekdayMask > 0x7F {
		return fmt.Errorf("invalid recurrence weekday mask: %#x", r.WeekdayMask)
	}
	if r.MonthlyMode != MonthlyByDate && r.MonthlyMode != MonthlyByNthWeekday {
		return fmt.Errorf("invalid recurrence monthly mode: %d", r.MonthlyMode)
	}
	if r.Nth < 0 || r.Nth > 5 {
		return fmt.Errorf("recurrence nth must be 1-5")
	}
	return nil
}

// interval returns the sanitized interval (<=0 treated as 1).
func (r Rule) interval() int {
	if r.Interval < 1 {
		return 1
	}
	return int(r.Interval)
}

// cycleDays returns the sanitized custom-day count (<=0 treated as 1).
func (r Rule) cycleDays() int {
	if r.CycleDays < 1 {
		return 1
	}
	return int(r.CycleDays)
}

// NextAfter returns the first occurrence strictly after `from`.
// Unknown/invalid input falls back to the legacy default of +1 month.
func (r Rule) NextAfter(from time.Time) time.Time {
	from = midnight(from)
	switch r.Cycle {
	case CycleWeekly:
		return r.nextWeekly(from)
	case CycleMonthly:
		if w, ok := maskWeekday(r.WeekdayMask); r.MonthlyMode == MonthlyByNthWeekday && ok && r.Nth >= 1 && r.Nth <= 5 {
			return r.nextNthWeekday(from, w)
		}
		return addMonthsClamped(from, r.interval(), int(r.BillingDay))
	case CycleYearly:
		return addYearsClamped(from, r.interval())
	case CycleCustom:
		return from.AddDate(0, 0, r.cycleDays())
	default:
		return addMonthsClamped(from, 1, int(r.BillingDay))
	}
}

// Occurrences returns the next n occurrences strictly after `start`.
func (r Rule) Occurrences(start time.Time, n int) []time.Time {
	if n <= 0 {
		return nil
	}
	out := make([]time.Time, 0, n)
	d := midnight(start)
	for i := 0; i < n; i++ {
		d = r.NextAfter(d)
		out = append(out, d)
	}
	return out
}

// MonthlyDates returns n monthly occurrence dates anchored at start's own day
// (start + k*interval months, clamped to each target month's end). Unlike
// Occurrences — which chains from the previous occurrence and drifts after a
// clamp (Jan 31 → Feb 28 → Mar 28) — every date re-anchors at start, so
// Jan 31 yields Feb 28, Mar 31, Apr 30... This is the no-drift semantics of
// debt installment schedules (legacy addMonths(start, k) parity) and of
// Google-Calendar monthly rules without an explicit day.
func (r Rule) MonthlyDates(start time.Time, n int) []time.Time {
	if n <= 0 {
		return nil
	}
	interval := r.interval()
	out := make([]time.Time, 0, n)
	for k := 1; k <= n; k++ {
		out = append(out, addMonthsClamped(midnight(start), k*interval, 0))
	}
	return out
}

// OccurrencesBetween returns all occurrences in the half-open span
// (start, end]. With atLeastOne it always returns at least one occurrence
// (even past end) so callers never build an empty schedule.
func (r Rule) OccurrencesBetween(start, end time.Time, atLeastOne bool) []time.Time {
	d := midnight(start)
	end = midnight(end)
	var out []time.Time
	for {
		d = r.NextAfter(d)
		if !d.After(end) {
			out = append(out, d)
			continue
		}
		if atLeastOne && len(out) == 0 {
			out = append(out, d)
		}
		return out
	}
}

// UsesNthWeekday reports whether the rule resolves to the Nth-weekday-of-
// month monthly mode with a usable single-bit mask (NextAfter falls back to
// by-date otherwise).
func (r Rule) UsesNthWeekday() bool {
	if r.MonthlyMode != MonthlyByNthWeekday || r.Nth < 1 || r.Nth > 5 {
		return false
	}
	_, ok := maskWeekday(r.WeekdayMask)
	return ok
}

// PeriodYears returns the length of one period expressed in years, used to
// derive the per-period interest rate from an annual rate.
func (r Rule) PeriodYears() float64 {
	switch r.Cycle {
	case CycleWeekly:
		return float64(r.interval()) * 7.0 / 365.0
	case CycleMonthly:
		return float64(r.interval()) / 12.0
	case CycleYearly:
		return float64(r.interval())
	case CycleCustom:
		return float64(r.cycleDays()) / 365.0
	default:
		return 1.0 / 12.0
	}
}

// nextWeekly scans forward for the next date whose weekday is in the mask
// and whose week is an interval multiple away from `from`'s week.
func (r Rule) nextWeekly(from time.Time) time.Time {
	mask := r.WeekdayMask
	if mask == 0 {
		mask = weekdayBit(from)
	}
	anchor := weekStart(from)
	limit := 7*r.interval() + 7
	d := from
	for i := 0; i < limit; i++ {
		d = d.AddDate(0, 0, 1)
		if mask&weekdayBit(d) == 0 {
			continue
		}
		weeks := int(weekStart(d).Sub(anchor).Hours() / 24 / 7)
		if weeks%r.interval() == 0 {
			return d
		}
	}
	// Unreachable: the from-weekday recurs within interval weeks.
	return d
}

// nextNthWeekday finds the next Nth-weekday-of-month occurrence.
func (r Rule) nextNthWeekday(from time.Time, w time.Weekday) time.Time {
	for k := 0; k < 3; k++ {
		year, month := addMonths(from, r.interval()*k)
		target := nthWeekdayOfMonth(year, month, int(r.Nth), w)
		if target.After(from) {
			return target
		}
	}
	// Unreachable: the next interval month always yields a later date.
	return from
}

// maskWeekday decodes a single-bit weekday mask. bit0=Monday ... bit6=Sunday
// (time.Weekday: Sunday=0, Monday=1, ...).
func maskWeekday(mask int32) (time.Weekday, bool) {
	if mask == 0 || mask&(mask-1) != 0 {
		return 0, false
	}
	return time.Weekday((bitsTrailing(mask) + 1) % 7), true
}

// bitsTrailing returns the index of the lowest set bit (mask != 0).
func bitsTrailing(mask int32) int {
	i := 0
	for mask&1 == 0 {
		mask >>= 1
		i++
	}
	return i
}

// weekdayBit maps Monday to bit0 ... Sunday to bit6.
func weekdayBit(t time.Time) int32 {
	return int32(1) << uint((int(t.Weekday())+6)%7)
}

// midnight truncates to UTC midnight.
func midnight(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// weekStart returns the Monday of t's week (UTC midnight).
func weekStart(t time.Time) time.Time {
	t = midnight(t)
	return t.AddDate(0, 0, -((int(t.Weekday()) + 6) % 7))
}

// addMonths returns the year/month that is n months after t's month.
func addMonths(t time.Time, n int) (int, time.Month) {
	m := int(t.Month()) - 1 + n
	return t.Year() + m/12, time.Month(m%12 + 1)
}

// addMonthsClamped adds n months keeping the anchor day (billingDay <= 0
// keeps base's day), clamped to the target month's last day.
func addMonthsClamped(base time.Time, n int, billingDay int) time.Time {
	year, month := addMonths(base, n)
	day := base.Day()
	if billingDay > 0 {
		day = billingDay
	}
	if last := lastDayOfMonth(year, month); day > last {
		day = last
	}
	return time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
}

// addYearsClamped adds n years keeping month/day, clamping Feb 29 to Feb 28.
func addYearsClamped(base time.Time, n int) time.Time {
	year := base.Year() + n
	month := base.Month()
	day := base.Day()
	if last := lastDayOfMonth(year, month); day > last {
		day = last
	}
	return time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
}

// nthWeekdayOfMonth returns the nth (5=last) given weekday of the month.
func nthWeekdayOfMonth(year int, month time.Month, nth int, weekday time.Weekday) time.Time {
	if nth == 5 {
		last := lastDayOfMonth(year, month)
		d := time.Date(year, month, last, 0, 0, 0, 0, time.UTC)
		for d.Weekday() != weekday {
			d = d.AddDate(0, 0, -1)
		}
		return d
	}
	d := time.Date(year, month, 1, 0, 0, 0, 0, time.UTC)
	for d.Weekday() != weekday {
		d = d.AddDate(0, 0, 1)
	}
	return d.AddDate(0, 0, 7*(nth-1))
}

// lastDayOfMonth returns the last day (28-31) of the given month.
func lastDayOfMonth(year int, month time.Month) int {
	return time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC).Day()
}
