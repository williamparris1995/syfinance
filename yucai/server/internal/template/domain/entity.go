package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/shared/domain/recurrence"
)

// TransactionTemplate is a recurring transaction template.
type TransactionTemplate struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	Name                string
	Description         string
	AmountCents         int64
	Direction           TemplateDirection
	SourceAccountID     uuid.UUID
	DestinationAccountID *uuid.UUID
	Cycle               TemplateCycle
	CycleDays           int32
	BillingDay          int32
	// Recurrence rule extensions (zero values = legacy behavior).
	Interval    int32
	WeekdayMask int32
	MonthlyMode recurrence.MonthlyMode
	Nth         int32
	NextDate    time.Time
	StartDate   time.Time
	EndDate     *time.Time
	AutoRecord  bool
	Paused      bool
	LastTransactionID  *uuid.UUID
	Category    string
	Version     int64
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Rule returns the recurrence.Rule view of the template's cycle fields.
// Cycle values 1-4 align between TemplateCycle and recurrence.Cycle.
func (t *TransactionTemplate) Rule() recurrence.Rule {
	return recurrence.Rule{
		Cycle:       recurrence.Cycle(t.Cycle),
		Interval:    t.Interval,
		CycleDays:   t.CycleDays,
		BillingDay:  t.BillingDay,
		WeekdayMask: t.WeekdayMask,
		MonthlyMode: t.MonthlyMode,
		Nth:         t.Nth,
	}
}

// NewTransactionTemplate creates a validated template. The recurrence rule
// (cycle + extensions) drives NextDate = first occurrence after startDate.
func NewTransactionTemplate(
	tenantID uuid.UUID,
	name string,
	amountCents int64,
	direction TemplateDirection,
	sourceAccountID uuid.UUID,
	rule recurrence.Rule,
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
	cycle := TemplateCycle(rule.Cycle)
	if cycle == 0 {
		return nil, fmt.Errorf("cycle must be specified")
	}
	if err := rule.Validate(); err != nil {
		return nil, err
	}

	nextDate := rule.NextAfter(startDate)

	now := time.Now()
	return &TransactionTemplate{
		ID:              uuid.New(),
		TenantID:        tenantID,
		Name:            name,
		AmountCents:     amountCents,
		Direction:       direction,
		SourceAccountID: sourceAccountID,
		Cycle:           cycle,
		CycleDays:       rule.CycleDays,
		BillingDay:      rule.BillingDay,
		Interval:        rule.Interval,
		WeekdayMask:     rule.WeekdayMask,
		MonthlyMode:     rule.MonthlyMode,
		Nth:             rule.Nth,
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

// AdvanceToNext moves the template to the next occurrence.
func (t *TransactionTemplate) AdvanceToNext() {
	t.NextDate = t.Rule().NextAfter(t.NextDate)
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

func trimSpace(s string) string {
	result := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] != ' ' && s[i] != '\t' && s[i] != '\n' && s[i] != '\r' {
			result = append(result, s[i])
		}
	}
	return string(result)
}
