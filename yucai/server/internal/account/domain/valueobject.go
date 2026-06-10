package domain

// AccountType classifies accounts per Chinese accounting standards.
type AccountType int

const (
	AccountTypeAsset      AccountType = iota + 1
	AccountTypeLiability
	AccountTypeEquity
	AccountTypeIncome
	AccountTypeExpense
)

func (t AccountType) String() string {
	switch t {
	case AccountTypeAsset:
		return "asset"
	case AccountTypeLiability:
		return "liability"
	case AccountTypeEquity:
		return "equity"
	case AccountTypeIncome:
		return "income"
	case AccountTypeExpense:
		return "expense"
	default:
		return "unknown"
	}
}

func ParseAccountType(s string) AccountType {
	switch s {
	case "asset":
		return AccountTypeAsset
	case "liability":
		return AccountTypeLiability
	case "equity":
		return AccountTypeEquity
	case "income":
		return AccountTypeIncome
	case "expense":
		return AccountTypeExpense
	default:
		return AccountTypeAsset
	}
}

// Ownership indicates whether an account is personal or joint.
type Ownership int

const (
	OwnershipPersonal Ownership = iota + 1
	OwnershipJoint
)

func (o Ownership) String() string {
	switch o {
	case OwnershipPersonal:
		return "personal"
	case OwnershipJoint:
		return "joint"
	default:
		return "personal"
	}
}

func ParseOwnership(s string) Ownership {
	switch s {
	case "joint":
		return OwnershipJoint
	default:
		return OwnershipPersonal
	}
}

// AccountStatus represents the lifecycle state of an account.
type AccountStatus int

const (
	AccountStatusActive AccountStatus = iota + 1
	AccountStatusArchived
)

func (s AccountStatus) String() string {
	switch s {
	case AccountStatusActive:
		return "active"
	case AccountStatusArchived:
		return "archived"
	default:
		return "active"
	}
}

func ParseAccountStatus(s string) AccountStatus {
	switch s {
	case "archived":
		return AccountStatusArchived
	default:
		return AccountStatusActive
	}
}

// BalanceDirection indicates which side increases the account balance.
type BalanceDirection int

const (
	BalanceDirectionDebit  BalanceDirection = iota + 1
	BalanceDirectionCredit
)

func (d BalanceDirection) String() string {
	switch d {
	case BalanceDirectionDebit:
		return "debit"
	case BalanceDirectionCredit:
		return "credit"
	default:
		return "debit"
	}
}

func ParseBalanceDirection(s string) BalanceDirection {
	switch s {
	case "credit":
		return BalanceDirectionCredit
	default:
		return BalanceDirectionDebit
	}
}
