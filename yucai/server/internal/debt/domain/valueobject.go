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

// DebtType distinguishes money the user borrowed (a liability, borrowed_in)
// from money the user lent out (a receivable, borrowed_out).
//
// Mapping across layers is NAME-BASED, never by numeric coincidence:
//   - ent (string column): "borrowed_in" / "borrowed_out"
//   - domain (this enum):  BorrowedIn / BorrowedOut
//   - proto enum:          DEBT_TYPE_BORROWED_IN / DEBT_TYPE_BORROWED_OUT
//
// Unknown / unspecified values resolve to BorrowedIn, matching the ent column
// default ("borrowed_in") so existing rows map correctly.
type DebtType int

const (
	// DebtTypeUnspecified is the zero value; treated as BorrowedIn at boundaries.
	DebtTypeUnspecified DebtType = iota
	// BorrowedIn means the user borrowed money (a liability).
	BorrowedIn
	// BorrowedOut means the user lent money out (a receivable).
	BorrowedOut
)

// String returns the string representation stored in the ent debt_type column.
func (t DebtType) String() string {
	switch t {
	case BorrowedIn, DebtTypeUnspecified:
		return "borrowed_in"
	case BorrowedOut:
		return "borrowed_out"
	default:
		return "borrowed_in"
	}
}

// ParseDebtType converts an ent debt_type string to the domain enum.
// Unknown values default to BorrowedIn (matches the ent column default).
func ParseDebtType(s string) DebtType {
	switch s {
	case "borrowed_out":
		return BorrowedOut
	case "borrowed_in":
		return BorrowedIn
	default:
		return BorrowedIn
	}
}

// Debt subtype keys for borrowedIn (money the user borrowed).
// Use these consts everywhere instead of bare strings — no enum mapping is
// performed; the value is persisted and returned verbatim at every layer.
const (
	DebtSubtypeMortgage   = "mortgage"
	DebtSubtypeAutoLoan   = "auto_loan"
	DebtSubtypeCreditCard = "credit_card"
	DebtSubtypeFamily     = "family"
	DebtSubtypeOther      = "other"
)

// Receivable subtype keys for borrowedOut (money the user lent out).
// Note: "family" and "other" are shared with borrowedIn — since subtype is a
// plain string (no enum), reuse DebtSubtypeFamily / DebtSubtypeOther for those;
// only the distinct keys are declared here.
const (
	ReceivableSubtypePersonal = "personal"
	ReceivableSubtypeBusiness = "business"
)
