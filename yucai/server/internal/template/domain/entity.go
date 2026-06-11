package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

// TransactionTemplate is a recurring transaction template.
type TransactionTemplate struct {
	ID                 uuid.UUID
	TenantID           uuid.UUID
	Name               string
	Description        string
	AmountCents        int64
	Direction          TemplateDirection
	SourceAccountID     uuid.UUID
	DestinationAccountID *uuid.UUID
	Cycle              TemplateCycle
	CycleDays          int32
	BillingDay         int32
	NextDate           time.Time
	StartDate          time.Time
	EndDate            *time.Time
	AutoRecord         bool
	Paused             bool
	LastTransactionID  *uuid.UUID
	Category           string
	Version            int64
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// NewTransactionTemplate creates a validated template.
func NewTransactionTemplate(
	tenantID uuid.UUID,
	name string,
	amountCents int64,
	direction TemplateDirection,
	sourceAccountID uuid.UUID,
	cycle TemplateCycle,
	billingDay int32,
	startDate time.Time,
) (*TransactionTemplate, error) {
	name = trimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("template name must not be empty")
	}
	if amountCents <= 0 {
		return nil, fmt.Errorf("amount must be positive")
	}
	if direction == 0 {
		return nil, fmt.Errorf("direction must be specified")
	}
	if cycle == 0 {
		return nil, fmt.Errorf("cycle must be specified")
	}

	nextDate := CalculateNextDate(startDate, cycle, billingDay, 1)

	now := time.Now()
	return &TransactionTemplate{
		ID:              uuid.New(),
		TenantID:        tenantID,
		Name:            name,
		AmountCents:     amountCents,
		Direction:       direction,
		SourceAccountID: sourceAccountID,
		Cycle:           cycle,
		BillingDay:      billingDay,
		NextDate:        nextDate,
		StartDate:       startDate,
		Version:         1,
		CreatedAt:       now,
		UpdatedAt:       now,
	}, nil
}

// IsDue returns true if the template's next_date is today or earlier.
func (t *TransactionTemplate) IsDue() bool {
	return !t.NextDate.After(time.Now().Truncate(24 * time.Hour).Add(24 * time.Hour))
}

// CalculateNextDate computes the next occurrence based on cycle.
func CalculateNextDate(base time.Time, cycle TemplateCycle, billingDay int32, occurrence int) time.Time {
	switch cycle {
	case CycleWeekly:
		return base.AddDate(0, 0, 7*occurrence)
	case CycleMonthly:
		return addMonthsClamped(base, occurrence, billingDay)
	case CycleYearly:
		return base.AddDate(occurrence, 0, 0)
	case CycleCustom:
		return base.AddDate(0, 0, 1) // default daily for custom
	default:
		return base.AddDate(0, 1, 0)
	}
}

// AdvanceToNext moves the template to the next occurrence.
func (t *TransactionTemplate) AdvanceToNext() {
	t.NextDate = CalculateNextDate(t.NextDate, t.Cycle, t.BillingDay, 1)
	t.UpdatedAt = time.Now()
}

// Pause marks the template as paused.
func (t *TransactionTemplate) Pause() {
	t.Paused = true
	t.UpdatedAt = time.Now()
}

// Resume marks the template as active.
func (t *TransactionTemplate) Resume() {
	t.Paused = false
	t.UpdatedAt = time.Now()
}

// IncrementVersion bumps the optimistic lock version.
func (t *TransactionTemplate) IncrementVersion() {
	t.Version++
	t.UpdatedAt = time.Now()
}

// addMonthsClamped adds months and clamps the day to the last day of the month.
func addMonthsClamped(base time.Time, months int, billingDay int32) time.Time {
	targetMonth := int(base.Month()) + months
	targetYear := base.Year() + (targetMonth-1)/12
	targetMonth = (targetMonth-1)%12 + 1

	day := int(billingDay)
	if day <= 0 {
		day = base.Day()
	}

	// Clamp to last day of target month
	lastDay := time.Date(targetYear, time.Month(targetMonth+1), 0, 0, 0, 0, 0, time.UTC).Day()
	if day > lastDay {
		day = lastDay
	}

	return time.Date(targetYear, time.Month(targetMonth), day, 0, 0, 0, 0, time.UTC)
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
