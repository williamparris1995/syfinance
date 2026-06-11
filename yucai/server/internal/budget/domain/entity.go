package domain

import (
	"fmt"
	"regexp"
	"time"

	"github.com/google/uuid"
)

var monthRegex = regexp.MustCompile(`^\d{4}-(0[1-9]|1[0-2])$`)

// Budget is the aggregate root for monthly budgeting.
type Budget struct {
	ID               uuid.UUID
	TenantID         uuid.UUID
	Name             string
	Month            string
	TotalAmountCents int64
	CurrencyCode     string
	IsActive         bool
	Items            []BudgetItem
	Version          int64
	CreatedAt        time.Time
	UpdatedAt        time.Time
	DeletedAt        *time.Time
}

// BudgetItem is a value object within a Budget.
type BudgetItem struct {
	ID                 uuid.UUID
	BudgetID           uuid.UUID
	AccountID          uuid.UUID
	PlannedAmountCents int64
	ActualAmountCents  int64
	Notes              string
}

// NewBudget creates a validated Budget with initial items.
func NewBudget(tenantID uuid.UUID, name, month, currencyCode string, items []BudgetItem) (*Budget, error) {
	name = trimAndCheck(name)
	if name == "" {
		return nil, fmt.Errorf("budget name must not be empty")
	}
	if !monthRegex.MatchString(month) {
		return nil, fmt.Errorf("invalid month format, expected YYYY-MM")
	}
	if len(items) == 0 {
		return nil, fmt.Errorf("budget must have at least 1 item")
	}

	id := uuid.New()
	var total int64
	for i := range items {
		if items[i].ID == uuid.Nil {
			items[i].ID = uuid.New()
		}
		items[i].BudgetID = id
		total += items[i].PlannedAmountCents
	}

	now := time.Now()
	return &Budget{
		ID:               id,
		TenantID:         tenantID,
		Name:             name,
		Month:            month,
		TotalAmountCents: total,
		CurrencyCode:     currencyCode,
		IsActive:         true,
		Items:            items,
		Version:          1,
		CreatedAt:        now,
		UpdatedAt:        now,
	}, nil
}

// AddItem appends a new item and updates total.
func (b *Budget) AddItem(item BudgetItem) {
	item.ID = uuid.New()
	item.BudgetID = b.ID
	b.Items = append(b.Items, item)
	b.TotalAmountCents += item.PlannedAmountCents
	b.touch()
}

// RemoveItem removes an item by ID and updates total.
func (b *Budget) RemoveItem(itemID uuid.UUID) error {
	for i, item := range b.Items {
		if item.ID == itemID {
			b.TotalAmountCents -= item.PlannedAmountCents
			b.Items = append(b.Items[:i], b.Items[i+1:]...)
			b.touch()
			return nil
		}
	}
	return fmt.Errorf("budget item %s not found", itemID)
}

// UpdateItemAmount adjusts a specific item's planned amount.
func (b *Budget) UpdateItemAmount(itemID uuid.UUID, newAmount int64) error {
	for i, item := range b.Items {
		if item.ID == itemID {
			delta := newAmount - item.PlannedAmountCents
			b.Items[i].PlannedAmountCents = newAmount
			b.TotalAmountCents += delta
			b.touch()
			return nil
		}
	}
	return fmt.Errorf("budget item %s not found", itemID)
}

// TotalActual returns the sum of all items' actual amounts.
func (b *Budget) TotalActual() int64 {
	var total int64
	for _, item := range b.Items {
		total += item.ActualAmountCents
	}
	return total
}

// TotalRemaining returns total planned minus actual.
func (b *Budget) TotalRemaining() int64 {
	return b.TotalAmountCents - b.TotalActual()
}

// UsagePct returns the percentage of budget used.
func (b *Budget) UsagePct() float64 {
	if b.TotalAmountCents == 0 {
		return 0
	}
	return float64(b.TotalActual()) / float64(b.TotalAmountCents) * 100
}

// IsOverBudget returns true if actual spending exceeds the plan.
func (b *Budget) IsOverBudget() bool {
	return b.TotalActual() > b.TotalAmountCents
}

// Deactivate marks the budget as inactive.
func (b *Budget) Deactivate() {
	b.IsActive = false
	b.touch()
}

// Activate marks the budget as active.
func (b *Budget) Activate() {
	b.IsActive = true
	b.touch()
}

// CloneToMonth creates a deep copy for a different month.
func (b *Budget) CloneToMonth(targetMonth, name string) (*Budget, error) {
	clonedItems := make([]BudgetItem, len(b.Items))
	for i, item := range b.Items {
		clonedItems[i] = BudgetItem{
			AccountID:          item.AccountID,
			PlannedAmountCents: item.PlannedAmountCents,
			ActualAmountCents:  0, // reset actuals
			Notes:              item.Notes,
		}
	}
	cloneName := name
	if cloneName == "" {
		cloneName = b.Name
	}
	return NewBudget(b.TenantID, cloneName, targetMonth, b.CurrencyCode, clonedItems)
}

// IncrementVersion bumps the optimistic lock version.
func (b *Budget) IncrementVersion() {
	b.Version++
	b.UpdatedAt = time.Now()
}

func (b *Budget) touch() {
	b.UpdatedAt = time.Now()
}

func trimAndCheck(s string) string {
	return trim(s)
}

func trim(s string) string {
	return trimSpace(s)
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
