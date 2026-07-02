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
	LinkedAccountIDs   []uuid.UUID // Investment + Savings goals link 1+ accounts
	LinkedDebtIDs      []uuid.UUID // DebtPayoff goals link 1+ debts
	Notes              string
	IsCompleted        bool
	CompletedAt        *time.Time
	Version            int64
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// ProgressPoint is one point in a goal's progress history (a daily snapshot).
// Returned by GoalRepository.FindSnapshotRange for the trend-curve data source
// (Phase 2 GetGoalProgressHistory RPC). Date is the snapshot_date (UTC midnight).
type ProgressPoint struct {
	Date               time.Time
	CurrentAmountCents int64
}

// NewGoal creates a validated Goal.
//
// linkedAccountIDs is required (≥1) for Investment/Savings goals; linkedDebtIDs
// is required (≥1) for DebtPayoff goals. The corresponding unused slice may be nil.
func NewGoal(
	tenantID uuid.UUID,
	name string,
	goalType GoalType,
	targetAmountCents int64,
	currencyCode string,
	deadline *time.Time,
	linkedAccountIDs []uuid.UUID,
	linkedDebtIDs []uuid.UUID,
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
	// 按 type 校验关联
	switch goalType {
	case GoalTypeInvestment, GoalTypeSavings:
		if len(linkedAccountIDs) == 0 {
			return nil, fmt.Errorf("%s goal requires at least 1 linked account", goalType)
		}
	case GoalTypeDebtPayoff:
		if len(linkedDebtIDs) == 0 {
			return nil, fmt.Errorf("debtpayoff goal requires at least 1 linked debt")
		}
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
		LinkedAccountIDs:   linkedAccountIDs,
		LinkedDebtIDs:      linkedDebtIDs,
		Notes:              notes,
		IsCompleted:        false,
		Version:            1,
		CreatedAt:          now,
		UpdatedAt:          now,
	}, nil
}

// Clone duplicates the goal into a new tenant (or the same tenant) with a fresh
// ID and reset progress. Caller may override targetAmountCents (≤0 → keep src),
// deadline (nil → drop), and name ("" → keep src). Linked account/debt IDs are
// deep-copied so the clone shares no slice header with the source.
func (g *Goal) Clone(newTenantID uuid.UUID, targetAmountCents int64, deadline *time.Time, name string) (*Goal, error) {
	if name == "" {
		name = g.Name
	}
	if targetAmountCents <= 0 {
		targetAmountCents = g.TargetAmountCents
	}
	accs := append([]uuid.UUID(nil), g.LinkedAccountIDs...)
	debts := append([]uuid.UUID(nil), g.LinkedDebtIDs...)
	return NewGoal(newTenantID, name, g.GoalType, targetAmountCents, g.CurrencyCode, deadline, accs, debts, g.Notes)
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

// SetCurrentAmount sets the current progress from a market-value snapshot
// (used by investment goals whose progress = Σ holdings mv). Auto-completes
// when reaching target; never un-completes a completed goal (mv may fluctuate).
func (g *Goal) SetCurrentAmount(amtCents int64) {
	g.CurrentAmountCents = amtCents
	if g.CurrentAmountCents < 0 {
		g.CurrentAmountCents = 0
	}
	g.UpdatedAt = time.Now()
	if g.CurrentAmountCents >= g.TargetAmountCents && !g.IsCompleted {
		g.MarkCompleted()
	}
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

// LinkAccount associates the goal with an additional account for progress
// syncing (idempotent: a repeated id is not appended twice).
func (g *Goal) LinkAccount(accountID uuid.UUID) {
	for _, id := range g.LinkedAccountIDs {
		if id == accountID {
			return
		}
	}
	g.LinkedAccountIDs = append(g.LinkedAccountIDs, accountID)
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
