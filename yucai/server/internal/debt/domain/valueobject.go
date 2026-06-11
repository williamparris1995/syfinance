package domain

// AmortizationMethod defines how loan payments are structured.
type AmortizationMethod int

const (
	AmortizationEqualPrincipalInterest AmortizationMethod = iota + 1
	AmortizationEqualPrincipal
	AmortizationLumpSum
)

// String returns the string representation stored in the database.
func (m AmortizationMethod) String() string {
	switch m {
	case AmortizationEqualPrincipalInterest:
		return "equal_principal_interest"
	case AmortizationEqualPrincipal:
		return "equal_principal"
	case AmortizationLumpSum:
		return "lump_sum"
	default:
		return "unknown"
	}
}

// ParseAmortizationMethod converts a database string to the enum.
func ParseAmortizationMethod(s string) AmortizationMethod {
	switch s {
	case "equal_principal_interest":
		return AmortizationEqualPrincipalInterest
	case "equal_principal":
		return AmortizationEqualPrincipal
	case "lump_sum":
		return AmortizationLumpSum
	default:
		return 0
	}
}
