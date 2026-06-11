package domain

// GoalType defines the type of financial goal.
type GoalType int

const (
	GoalTypeSavings GoalType = iota + 1
	GoalTypeDebtPayoff
	GoalTypeInvestment
)

// String returns the string representation stored in the database.
func (t GoalType) String() string {
	switch t {
	case GoalTypeSavings:
		return "savings"
	case GoalTypeDebtPayoff:
		return "debt_payoff"
	case GoalTypeInvestment:
		return "investment"
	default:
		return "unknown"
	}
}

// ParseGoalType converts a database string to the enum.
func ParseGoalType(s string) GoalType {
	switch s {
	case "savings":
		return GoalTypeSavings
	case "debt_payoff":
		return GoalTypeDebtPayoff
	case "investment":
		return GoalTypeInvestment
	default:
		return 0
	}
}
