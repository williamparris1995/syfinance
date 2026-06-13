package domain

// CategoryType classifies a category as income or expense.
type CategoryType int

const (
	CategoryTypeIncome CategoryType = iota + 1
	CategoryTypeExpense
)

func (t CategoryType) String() string {
	switch t {
	case CategoryTypeIncome:
		return "income"
	case CategoryTypeExpense:
		return "expense"
	default:
		return "unknown"
	}
}

func ParseCategoryType(s string) CategoryType {
	switch s {
	case "income":
		return CategoryTypeIncome
	case "expense":
		return CategoryTypeExpense
	default:
		return 0
	}
}

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
