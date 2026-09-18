package domain

import (
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/shared/domain/recurrence"
)

// AmortizationCalculator generates payment schedules for different amortization methods.
type AmortizationCalculator struct{}

// ScheduleDatesFrom resolves the installment dates for a rule:
//   - termPeriods > 0 (by-periods mode): exactly that many occurrences after
//     anchor; due is ignored (the caller derives it from the last date);
//   - monthly (by-due-date mode): ceil(month-diff / interval) occurrences —
//     interval 1 keeps the legacy month-diff count (byte-exact parity,
//     including odd pairs like Jan 31 → Jul 15);
//   - other cycles (by-due-date mode): every occurrence in (anchor, due],
//     at least one.
func ScheduleDatesFrom(rule recurrence.Rule, anchor, due time.Time, termPeriods int32) []time.Time {
	if termPeriods > 0 {
		return rule.Occurrences(anchor, int(termPeriods))
	}
	if rule.Cycle == recurrence.CycleMonthly {
		interval := rule.Interval
		if interval < 1 {
			interval = 1
		}
		n := (monthsBetween(anchor, due) + int(interval) - 1) / int(interval)
		if n < 1 {
			n = 1
		}
		if rule.UsesNthWeekday() {
			// 第 N 个星期几:链式推进(每月第 N 个周 X 无漂移问题)。
			return rule.Occurrences(anchor, n)
		}
		// MonthlyDates re-anchors every date at the anchor's own day — the
		// legacy addMonths(start, k) semantics (no drift after month-end
		// clamps: Jan 31 → Feb 28 → Mar 31).
		return rule.MonthlyDates(anchor, n)
	}
	return rule.OccurrencesBetween(anchor, due, true)
}

// monthsBetween is the legacy month-diff term (>= 1) used by TermInMonths.
func monthsBetween(from, to time.Time) int {
	months := (to.Year()-from.Year())*12 + int(to.Month()) - int(from.Month())
	if months <= 0 {
		return 1
	}
	return months
}

// GenerateSchedule creates payment entries based on the debt's amortization method.
func (c *AmortizationCalculator) GenerateSchedule(debt *DebtDetails) []PaymentScheduleEntry {
	return c.generate(debt.AmortizationMethod, debt.StartDate, debt.ScheduleDates(),
		debt.TotalPrincipalCents, debt.InterestRate, debt.Rule())
}

// RegenerateFutureSchedule builds the future (post-frozen) entries for a rule
// edit: same math as GenerateSchedule but over the remaining principal and a
// caller-resolved date series anchored after the last frozen entry.
func (c *AmortizationCalculator) RegenerateFutureSchedule(debt *DebtDetails, anchor time.Time, dates []time.Time, remainingPrincipalCents int64) []PaymentScheduleEntry {
	return c.generate(debt.AmortizationMethod, anchor, dates,
		remainingPrincipalCents, debt.InterestRate, debt.Rule())
}

func (c *AmortizationCalculator) generate(method AmortizationMethod, anchor time.Time, dates []time.Time, principalCents int64, annualRate float64, rule recurrence.Rule) []PaymentScheduleEntry {
	switch method {
	case AmortizationLumpSum:
		return c.lumpSum(anchor, dates, principalCents, annualRate, rule)
	case AmortizationEqualPrincipal:
		return c.equalPrincipal(dates, principalCents, annualRate, rule)
	case AmortizationEqualPrincipalInterest:
		return c.annuity(dates, principalCents, annualRate, rule)
	case AmortizationInterestFirst:
		return c.interestFirst(dates, principalCents, annualRate, rule)
	default:
		return c.annuity(dates, principalCents, annualRate, rule)
	}
}

// lumpSum: single entry at the last date. Interest = principal * rate *
// termYears — monthly rules keep the legacy months/12 arithmetic over the
// anchor→last month diff; other cycles use elapsed days / 365.
func (c *AmortizationCalculator) lumpSum(anchor time.Time, dates []time.Time, principalCents int64, annualRate float64, rule recurrence.Rule) []PaymentScheduleEntry {
	last := dates[len(dates)-1]
	var years float64
	if rule.Cycle == recurrence.CycleMonthly {
		years = float64(monthsBetween(anchor, last)) / 12.0
	} else {
		years = last.Sub(anchor).Hours() / 24 / 365
		if years <= 0 {
			years = rule.PeriodYears() * float64(len(dates))
		}
	}
	interestCents := roundToInt64(float64(principalCents) * annualRate * years)
	return []PaymentScheduleEntry{
		{
			ID:             uuid.New(),
			PaymentDate:    last,
			PrincipalCents: principalCents,
			InterestCents:  interestCents,
			TotalCents:     principalCents + interestCents,
		},
	}
}

// equalPrincipal: per-period principal = principal/n (rounded); last period
// absorbs the remainder (total conservation); interest = remaining × period
// rate computed on the true (unrounded) remaining (F7).
func (c *AmortizationCalculator) equalPrincipal(dates []time.Time, principalCents int64, annualRate float64, rule recurrence.Rule) []PaymentScheduleEntry {
	n := len(dates)
	periodRate := annualRate * rule.PeriodYears()
	perPeriod := float64(principalCents) / float64(n)
	remaining := float64(principalCents)

	entries := make([]PaymentScheduleEntry, n)
	for i := 0; i < n; i++ {
		interestCents := roundToInt64(remaining * periodRate)

		var principalPart int64
		if i == n-1 {
			principalPart = roundToInt64(remaining)
		} else {
			principalPart = roundToInt64(perPeriod)
		}

		entries[i] = PaymentScheduleEntry{
			ID:             uuid.New(),
			PaymentDate:    dates[i],
			PrincipalCents: principalPart,
			InterestCents:  interestCents,
			TotalCents:     principalPart + interestCents,
		}
		remaining -= float64(principalPart)
	}
	return entries
}

// annuity (equal principal + interest): fixed payment =
// P * r * (1+r)^n / ((1+r)^n - 1) with r = per-period rate; last entry
// absorbs the rounding remainder.
func (c *AmortizationCalculator) annuity(dates []time.Time, principalCents int64, annualRate float64, rule recurrence.Rule) []PaymentScheduleEntry {
	n := len(dates)
	periodRate := annualRate * rule.PeriodYears()
	principal := float64(principalCents)

	var payment float64
	if periodRate == 0 {
		payment = principal / float64(n)
	} else {
		factor := math.Pow(1+periodRate, float64(n))
		payment = principal * periodRate * factor / (factor - 1)
	}

	entries := make([]PaymentScheduleEntry, n)
	remaining := principal
	for i := 0; i < n; i++ {
		interestCents := roundToInt64(remaining * periodRate)
		var principalPart int64
		if i == n-1 {
			principalPart = roundToInt64(remaining)
		} else {
			principalPart = roundToInt64(payment) - interestCents
		}
		entries[i] = PaymentScheduleEntry{
			ID:             uuid.New(),
			PaymentDate:    dates[i],
			PrincipalCents: principalPart,
			InterestCents:  interestCents,
			TotalCents:     principalPart + interestCents,
		}
		remaining -= float64(principalPart)
	}
	return entries
}

// interestFirst (先息后本): every period pays interest on the FULL
// principal; the last period additionally repays the entire principal.
func (c *AmortizationCalculator) interestFirst(dates []time.Time, principalCents int64, annualRate float64, rule recurrence.Rule) []PaymentScheduleEntry {
	n := len(dates)
	periodRate := annualRate * rule.PeriodYears()
	perPeriodInterest := roundToInt64(float64(principalCents) * periodRate)

	entries := make([]PaymentScheduleEntry, n)
	for i := 0; i < n; i++ {
		principalPart := int64(0)
		if i == n-1 {
			principalPart = principalCents
		}
		entries[i] = PaymentScheduleEntry{
			ID:             uuid.New(),
			PaymentDate:    dates[i],
			PrincipalCents: principalPart,
			InterestCents:  perPeriodInterest,
			TotalCents:     principalPart + perPeriodInterest,
		}
	}
	return entries
}

// roundToInt64 rounds a float64 to int64 (cents).
func roundToInt64(f float64) int64 {
	return int64(math.Round(f))
}
