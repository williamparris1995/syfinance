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

// AccountCategory 是用户面向的账户分类（区别于会计 AccountType）。
// 固定 9 类，匹配原型 + 行业惯例（Mint/YNAB/Quicken）。
type AccountCategory int

const (
	AccountCategorySavings AccountCategory = iota + 1
	AccountCategoryCreditCard
	AccountCategoryInvestment
	AccountCategoryFixedDeposit
	AccountCategoryGoldFx
	AccountCategoryRealEstate
	AccountCategoryLoan
	AccountCategoryOtherAsset
	AccountCategoryOtherLiability
)

func (c AccountCategory) String() string {
	switch c {
	case AccountCategorySavings:
		return "savings"
	case AccountCategoryCreditCard:
		return "credit_card"
	case AccountCategoryInvestment:
		return "investment"
	case AccountCategoryFixedDeposit:
		return "fixed_deposit"
	case AccountCategoryGoldFx:
		return "gold_fx"
	case AccountCategoryRealEstate:
		return "real_estate"
	case AccountCategoryLoan:
		return "loan"
	case AccountCategoryOtherAsset:
		return "other_asset"
	case AccountCategoryOtherLiability:
		return "other_liability"
	default:
		return "savings"
	}
}

func ParseAccountCategory(s string) AccountCategory {
	switch s {
	case "credit_card":
		return AccountCategoryCreditCard
	case "investment":
		return AccountCategoryInvestment
	case "fixed_deposit":
		return AccountCategoryFixedDeposit
	case "gold_fx":
		return AccountCategoryGoldFx
	case "real_estate":
		return AccountCategoryRealEstate
	case "loan":
		return AccountCategoryLoan
	case "other_asset":
		return AccountCategoryOtherAsset
	case "other_liability":
		return AccountCategoryOtherLiability
	default:
		return AccountCategorySavings
	}
}

// ToAccountType 按 9 类映射表派生会计类型（复式记账用）。
func (c AccountCategory) ToAccountType() AccountType {
	switch c {
	case AccountCategoryCreditCard, AccountCategoryLoan, AccountCategoryOtherLiability:
		return AccountTypeLiability
	default:
		return AccountTypeAsset
	}
}

// Description 返回创建表单显示的示例文案。
func (c AccountCategory) Description() string {
	switch c {
	case AccountCategorySavings:
		return "活期/定期、现金、数字钱包余额"
	case AccountCategoryCreditCard:
		return "信用卡、花呗、免息分期"
	case AccountCategoryInvestment:
		return "证券、基金、理财、数字货币"
	case AccountCategoryFixedDeposit:
		return "大额存单、结构性存款"
	case AccountCategoryGoldFx:
		return "实物黄金、外币"
	case AccountCategoryRealEstate:
		return "房产、车辆"
	case AccountCategoryLoan:
		return "房贷、车贷、消费贷"
	case AccountCategoryOtherAsset:
		return "古董、字画、收藏品、保险现金价值"
	case AccountCategoryOtherLiability:
		return "其他欠款、应付款"
	default:
		return ""
	}
}
