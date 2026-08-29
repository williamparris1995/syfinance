package domain

import (
	"math"
	"time"

	"github.com/google/uuid"
)

// AmortizationCalculator generates payment schedules for different amortization methods.
type AmortizationCalculator struct{}

// GenerateSchedule creates payment entries based on the debt's amortization method.
func (c *AmortizationCalculator) GenerateSchedule(debt *DebtDetails) []PaymentScheduleEntry {
	switch debt.AmortizationMethod {
	case AmortizationLumpSum:
		return c.lumpSum(debt)
	case AmortizationEqualPrincipal:
		return c.equalPrincipal(debt)
	case AmortizationEqualPrincipalInterest:
		return c.equalPrincipalInterest(debt)
	default:
		return c.equalPrincipalInterest(debt)
	}
}

// lumpSum: single entry at due date. Interest = principal * rate * (months/12).
func (c *AmortizationCalculator) lumpSum(debt *DebtDetails) []PaymentScheduleEntry {
	months := debt.TermInMonths()
	interest := float64(debt.TotalPrincipalCents) * debt.InterestRate * float64(months) / 12.0
	interestCents := roundToInt64(interest)
	totalCents := debt.TotalPrincipalCents + interestCents

	return []PaymentScheduleEntry{
		{
			ID:             uuid.New(),
			DebtID:         debt.ID,
			PaymentDate:    debt.DueDate,
			PrincipalCents: debt.TotalPrincipalCents,
			InterestCents:  interestCents,
			TotalCents:     totalCents,
		},
	}
}

// equalPrincipal: monthly principal = total/months(float 均摊,每月四舍五入);
// last month absorbs the remainder(总额守恒);interest = remaining × monthly_rate
// 按真实(未截断)remaining 复算(F7:旧实现整除截断 + 按截断 remaining 复息,
// 系统性偏差;与 equalPrincipalInterest 的 round+float 模式对齐)。
// 存量已生成 schedule 不受影响(仅新生成走本路径)。
func (c *AmortizationCalculator) equalPrincipal(debt *DebtDetails) []PaymentScheduleEntry {
	months := debt.TermInMonths()
	monthlyRate := debt.InterestRate / 12.0
	monthlyPrincipal := float64(debt.TotalPrincipalCents) / float64(months)
	remainingPrincipal := float64(debt.TotalPrincipalCents)

	entries := make([]PaymentScheduleEntry, months)
	for i := 0; i < months; i++ {
		interestCents := roundToInt64(remainingPrincipal * monthlyRate)

		var principalCents int64
		if i == months-1 {
			// Last entry gets the remainder to avoid rounding gaps
			principalCents = roundToInt64(remainingPrincipal)
		} else {
			principalCents = roundToInt64(monthlyPrincipal)
		}

		entries[i] = PaymentScheduleEntry{
			ID:             uuid.New(),
			DebtID:         debt.ID,
			PaymentDate:    addMonths(debt.StartDate, i+1),
			PrincipalCents: principalCents,
			InterestCents:  interestCents,
			TotalCents:     principalCents + interestCents,
		}
		remainingPrincipal -= float64(principalCents)
	}
	return entries
}

// equalPrincipalInterest: fixed monthly payment = P * r * (1+r)^n / ((1+r)^n - 1).
func (c *AmortizationCalculator) equalPrincipalInterest(debt *DebtDetails) []PaymentScheduleEntry {
	months := debt.TermInMonths()
	monthlyRate := debt.InterestRate / 12.0
	principal := float64(debt.TotalPrincipalCents)

	var monthlyPayment float64
	if monthlyRate == 0 {
		monthlyPayment = principal / float64(months)
	} else {
		factor := math.Pow(1+monthlyRate, float64(months))
		monthlyPayment = principal * monthlyRate * factor / (factor - 1)
	}

	entries := make([]PaymentScheduleEntry, months)
	remainingPrincipal := principal

	for i := 0; i < months; i++ {
		interestCents := roundToInt64(remainingPrincipal * monthlyRate)
		var principalCents int64
		if i == months-1 {
			// Last entry: use remaining principal to avoid rounding gaps
			principalCents = roundToInt64(remainingPrincipal)
		} else {
			principalCents = roundToInt64(monthlyPayment) - interestCents
		}
		totalCents := principalCents + interestCents

		entries[i] = PaymentScheduleEntry{
			ID:             uuid.New(),
			DebtID:         debt.ID,
			PaymentDate:    addMonths(debt.StartDate, i+1),
			PrincipalCents: principalCents,
			InterestCents:  interestCents,
			TotalCents:     totalCents,
		}
		remainingPrincipal -= float64(principalCents)
	}
	return entries
}

// addMonths adds months to a date, clamping to the last day of month.
func addMonths(t time.Time, months int) time.Time {
	year := t.Year()
	month := int(t.Month()) + months
	day := t.Day()

	year += (month - 1) / 12
	month = (month-1)%12 + 1

	// Clamp day to last day of target month
	lastDay := time.Date(year, time.Month(month+1), 0, 0, 0, 0, 0, t.Location()).Day()
	if day > lastDay {
		day = lastDay
	}

	return time.Date(year, time.Month(month), day, 0, 0, 0, 0, t.Location())
}

// roundToInt64 rounds a float64 to int64 (cents).
func roundToInt64(f float64) int64 {
	return int64(math.Round(f))
}
