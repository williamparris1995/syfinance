package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Goal is the aggregate root for financial goals.
type Goal struct {
	ID                 uuid.UUID
	TenantID           uuid.UUID
	Name               string
	GoalType           GoalType
	TargetAmountCents  int64
	CurrentAmountCents int64
	CurrencyCode       string
	Deadline           *time.Time
	LinkedAccountID    *uuid.UUID
	Notes              string
	IsCompleted        bool
	CompletedAt        *time.Time
	Version            int64
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// NewGoal creates a validated Goal.
func NewGoal(
	tenantID uuid.UUID,
	name string,
	goalType GoalType,
	targetAmountCents int64,
	currencyCode string,
	deadline *time.Time,
	linkedAccountID *uuid.UUID,
	notes string,
) (*Goal, error) {
	name = trimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("goal name must not be empty")
	}
	if targetAmountCents <= 0 {
		return nil, fmt.Errorf("target amount must be positive")
	}
	if goalType == 0 {
		return nil, fmt.Errorf("goal type must be specified")
	}
	if currencyCode == "" {
		currencyCode = "CNY"
	}

	now := time.Now()
	return &Goal{
		ID:                 uuid.New(),
		TenantID:           tenantID,
		Name:               name,
		GoalType:           goalType,
		TargetAmountCents:  targetAmountCents,
		CurrentAmountCents: 0,
		CurrencyCode:       currencyCode,
		Deadline:           deadline,
		LinkedAccountID:    linkedAccountID,
		Notes:              notes,
		IsCompleted:        false,
		Version:            1,
		CreatedAt:          now,
		UpdatedAt:          now,
	}, nil
}

// AddProgress adds amount to the current progress.
// Returns true if the goal is auto-completed.
func (g *Goal) AddProgress(amountCents int64) bool {
	g.CurrentAmountCents += amountCents
	if g.CurrentAmountCents < 0 {
		g.CurrentAmountCents = 0
	}
	g.UpdatedAt = time.Now()
	if g.CurrentAmountCents >= g.TargetAmountCents && !g.IsCompleted {
		g.MarkCompleted()
		return true
	}
	return false
}

// MarkCompleted marks the goal as completed now.
func (g *Goal) MarkCompleted() {
	now := time.Now()
	g.IsCompleted = true
	g.CompletedAt = &now
	g.UpdatedAt = now
}

// ProgressPct returns the percentage of goal achieved (0-100+).
func (g *Goal) ProgressPct() float64 {
	if g.TargetAmountCents == 0 {
		return 0
	}
	return float64(g.CurrentAmountCents) / float64(g.TargetAmountCents) * 100
}

// RemainingAmount returns how much more is needed to reach the target.
func (g *Goal) RemainingAmount() int64 {
	rem := g.TargetAmountCents - g.CurrentAmountCents
	if rem < 0 {
		return 0
	}
	return rem
}

// IsOverdue returns true if the deadline has passed and the goal is not completed.
func (g *Goal) IsOverdue() bool {
	if g.IsCompleted || g.Deadline == nil {
		return false
	}
	return time.Now().After(*g.Deadline)
}

// LinkAccount associates the goal with an account for progress syncing.
func (g *Goal) LinkAccount(accountID uuid.UUID) {
	g.LinkedAccountID = &accountID
	g.UpdatedAt = time.Now()
}

// IncrementVersion bumps the optimistic lock version.
func (g *Goal) IncrementVersion() {
	g.Version++
	g.UpdatedAt = time.Now()
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
