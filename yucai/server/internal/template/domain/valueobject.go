package domain

// TemplateDirection defines the direction of a recurring transaction.
type TemplateDirection int

const (
	DirectionExpense TemplateDirection = iota + 1
	DirectionIncome
	DirectionTransfer
)

func (d TemplateDirection) String() string {
	switch d {
	case DirectionExpense:
		return "expense"
	case DirectionIncome:
		return "income"
	case DirectionTransfer:
		return "transfer"
	default:
		return "unknown"
	}
}

func ParseTemplateDirection(s string) TemplateDirection {
	switch s {
	case "expense":
		return DirectionExpense
	case "income":
		return DirectionIncome
	case "transfer":
		return DirectionTransfer
	default:
		return 0
	}
}

// TemplateCycle defines how often a template repeats.
type TemplateCycle int

const (
	CycleWeekly TemplateCycle = iota + 1
	CycleMonthly
	CycleYearly
	CycleCustom
)

func (c TemplateCycle) String() string {
	switch c {
	case CycleWeekly:
		return "weekly"
	case CycleMonthly:
		return "monthly"
	case CycleYearly:
		return "yearly"
	case CycleCustom:
		return "custom"
	default:
		return "unknown"
	}
}

func ParseTemplateCycle(s string) TemplateCycle {
	switch s {
	case "weekly":
		return CycleWeekly
	case "monthly":
		return CycleMonthly
	case "yearly":
		return CycleYearly
	case "custom":
		return CycleCustom
	default:
		return 0
	}
}
