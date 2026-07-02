package domain

import (
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewGoalMultiAccountValidation(t *testing.T) {
	tid := uuid.New()
	dl := time.Now().Add(30 * 24 * time.Hour)
	acc1, acc2 := uuid.New(), uuid.New()

	// Savings 多账户 OK
	g, err := NewGoal(tid, "应急基金", GoalTypeSavings, 1000000, "CNY", &dl, []uuid.UUID{acc1, acc2}, nil, "")
	if err != nil || len(g.LinkedAccountIDs) != 2 {
		t.Fatalf("savings multi-account: err=%v links=%v", err, g)
	}

	// DebtPayoff 无 debt → error
	_, err = NewGoal(tid, "还房贷", GoalTypeDebtPayoff, 5000000, "CNY", &dl, nil, nil, "")
	if err == nil || !strings.Contains(err.Error(), "debt") {
		t.Fatalf("debtpayoff no debt: err=%v", err)
	}

	// Investment 无 account → error
	_, err = NewGoal(tid, "投资", GoalTypeInvestment, 1000000, "CNY", &dl, nil, nil, "")
	if err == nil || !strings.Contains(err.Error(), "account") {
		t.Fatalf("investment no account: err=%v", err)
	}
}

func TestGoalClone(t *testing.T) {
	src := &Goal{ID: uuid.New(), Name: "原目标", GoalType: GoalTypeSavings, TargetAmountCents: 1000000, CurrencyCode: "CNY", LinkedAccountIDs: []uuid.UUID{uuid.New()}}
	cloned, err := src.Clone(uuid.New(), 2000000, nil, "复制目标") // 改 target,reset current
	if err != nil || cloned.ID == src.ID || cloned.CurrentAmountCents != 0 || cloned.TargetAmountCents != 2000000 || len(cloned.LinkedAccountIDs) != 1 {
		t.Fatalf("clone: err=%v cloned=%+v", err, cloned)
	}
}
