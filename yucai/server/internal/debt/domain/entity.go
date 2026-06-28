package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

// DebtDetails is the aggregate root for debt/loan tracking.
type DebtDetails struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	AccountID           uuid.UUID
	Counterparty        string
	InterestRate        float64
	AmortizationMethod  AmortizationMethod
	StartDate           time.Time
	DueDate             time.Time
	TotalPrincipalCents int64
	DebtType            DebtType
	Subtype             string
	Schedule            []PaymentScheduleEntry
	Version             int64
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// PaymentScheduleEntry represents a single payment in the amortization schedule.
type PaymentScheduleEntry struct {
	ID              uuid.UUID
	DebtID          uuid.UUID
	PaymentDate     time.Time
	PrincipalCents  int64
	InterestCents   int64
	TotalCents      int64
	Paid            bool
	PaidCents       int64
	TransactionID   *uuid.UUID
}

// NewDebtDetails creates a validated DebtDetails aggregate.
// subtype is a plain string persisted verbatim (no enum mapping); pass "" when
// unspecified. Use the DebtSubtype* / ReceivableSubtype* consts for known keys.
func NewDebtDetails(
	tenantID, accountID uuid.UUID,
	counterparty string,
	interestRate float64,
	method AmortizationMethod,
	startDate, dueDate time.Time,
	totalPrincipalCents int64,
	debtType DebtType,
	subtype string,
) (*DebtDetails, error) {
	counterparty = trimSpace(counterparty)
	if counterparty == "" {
		return nil, fmt.Errorf("counterparty must not be empty")
	}
	if totalPrincipalCents <= 0 {
		return nil, fmt.Errorf("total principal must be positive")
	}
	if interestRate < 0 {
		return nil, fmt.Errorf("interest rate must not be negative")
	}
	if !dueDate.After(startDate) {
		return nil, fmt.Errorf("due date must be after start date")
	}

	// Normalize zero/unspecified debt type to BorrowedIn (matches ent default).
	if debtType == DebtTypeUnspecified {
		debtType = BorrowedIn
	}

	now := time.Now()
	return &DebtDetails{
		ID:                  uuid.New(),
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        counterparty,
		InterestRate:        interestRate,
		AmortizationMethod:  method,
		StartDate:           startDate,
		DueDate:             dueDate,
		TotalPrincipalCents: totalPrincipalCents,
		DebtType:            debtType,
		Subtype:             subtype,
		Version:             1,
		CreatedAt:           now,
		UpdatedAt:           now,
	}, nil
}

// GenerateSchedule creates payment schedule entries using the AmortizationCalculator.
func (d *DebtDetails) GenerateSchedule() []PaymentScheduleEntry {
	calc := AmortizationCalculator{}
	entries := calc.GenerateSchedule(d)
	for i := range entries {
		entries[i].DebtID = d.ID
	}
	d.Schedule = entries
	return entries
}

// MarkPaid marks a schedule entry as paid with the given transaction ID.
func (d *DebtDetails) MarkPaid(entryID uuid.UUID, transactionID uuid.UUID) error {
	for i, entry := range d.Schedule {
		if entry.ID == entryID {
			d.Schedule[i].Paid = true
			d.Schedule[i].TransactionID = &transactionID
			d.Schedule[i].PaidCents = entry.TotalCents
			d.Version++
			d.UpdatedAt = time.Now()
			return nil
		}
	}
	return fmt.Errorf("schedule entry %s not found", entryID)
}

// RemainingPrincipal calculates how much principal is still unpaid.
func (d *DebtDetails) RemainingPrincipal() int64 {
	var paidCents int64
	for _, entry := range d.Schedule {
		if entry.Paid {
			paidCents += entry.PrincipalCents
		}
	}
	return d.TotalPrincipalCents - paidCents
}

// TermInMonths returns the loan term in months.
func (d *DebtDetails) TermInMonths() int {
	months := (d.DueDate.Year()-d.StartDate.Year())*12 + int(d.DueDate.Month()) - int(d.StartDate.Month())
	if months <= 0 {
		return 1
	}
	return months
}

// IncrementVersion bumps the optimistic lock version.
func (d *DebtDetails) IncrementVersion() {
	d.Version++
	d.UpdatedAt = time.Now()
}

func trimSpace(s string) string {
	result := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] != ' ' && s[i] != '\t' && s[i] != '\n' && s[i] != '\r' {
			result = append(result, s[i])
		}
	}
	return string(result)
}
