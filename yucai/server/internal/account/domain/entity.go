package domain

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Account is the aggregate root for the accounting system.
type Account struct {
	ID                       uuid.UUID
	TenantID                 uuid.UUID
	Name                     string
	AccountType              AccountType
	Category                 AccountCategory
	CurrencyCode             string
	InitialBalanceCents      int64
	CurrentBalanceCents      int64
	Ownership                Ownership
	Icon                     string
	Color                    string
	ChartCode                string
	ParentID                 *uuid.UUID // 父分类账户（二级分类，如"咖啡"归属"餐饮"）
	IsSystem                 bool       // 系统预置分类（不可删；category-as-account 重构）
	SortOrder                int        // 分类排序（升序，默认 0）
	Institution              string
	CreditLimitCents         int64
	CardNumberTail           string     // 卡号/账号尾号（金融类）
	Notes                    string     // 备注
	OpeningDate              *time.Time // 开户日期
	InterestRate             *float64   // 年化利率(%)：储蓄/定期/贷款利率、信用卡APR
	CreditBillingDay         *int       // 信用卡账单日（1-31）
	CreditRepaymentDay       *int       // 信用卡还款日（1-31）
	CreditAnnualFeeCents     *int64     // 信用卡年费
	InvestCostCents          *int64     // 投资投入成本
	InvestMarketValueCents   *int64     // 投资当前市值
	InvestReturnYtd          *float64   // 投资今年收益率(%)
	FixedPrincipalCents      *int64     // 定期本金
	FixedStartDate           *time.Time // 定期起息日
	FixedMaturityDate        *time.Time // 定期到期日
	FixedTermMonths          *int       // 定期期限（月）
	GoldProductType          string     // 黄金外汇品种（如实物黄金/USD）
	GoldQuantity             *float64   // 黄金外汇持有数量
	GoldBuyPriceCents        *int64     // 黄金外汇买入价
	GoldCurrentPriceCents    *int64     // 黄金外汇现价
	EstatePurchasePriceCents *int64     // 固定资产买入价
	EstateCurrentValueCents  *int64     // 固定资产现估值
	EstatePurchaseDate       *time.Time // 固定资产买入日期
	EstateDepreciationRate   *float64   // 固定资产折旧率(%)
	LoanOriginalCents        *int64     // 贷款原始本金
	LoanRemainingCents       *int64     // 贷款剩余本金
	LoanMonthlyCents         *int64     // 贷款月供
	LoanNextPaymentDate      *time.Time // 贷款下次还款日
	Status                   AccountStatus
	Version                  int64
	DeletedAt                *time.Time
	CreatedAt                time.Time
	UpdatedAt                time.Time
}

// NewAccount creates a validated Account entity.
func NewAccount(tenantID uuid.UUID, name string, accountType AccountType, currencyCode string) (*Account, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("account name must not be empty")
	}
	if accountType < AccountTypeAsset || accountType > AccountTypeExpense {
		return nil, fmt.Errorf("invalid account type")
	}
	currencyCode = strings.TrimSpace(strings.ToUpper(currencyCode))
	if currencyCode == "" {
		currencyCode = "CNY"
	}
	return &Account{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		AccountType:  accountType,
		CurrencyCode: currencyCode,
		Status:       AccountStatusActive,
		Version:      1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}, nil
}

// NewAccountWithCategory 按 category 创建账户，account_type 由 category 派生。
// 用户创建的账户走此构造函数；系统/科目表账户仍用 NewAccount（直接指定 account_type）。
func NewAccountWithCategory(tenantID uuid.UUID, name string, category AccountCategory, currencyCode string) (*Account, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("account name must not be empty")
	}
	if category < AccountCategorySavings || category > AccountCategoryOtherLiability {
		return nil, fmt.Errorf("invalid account category")
	}
	currencyCode = strings.TrimSpace(strings.ToUpper(currencyCode))
	if currencyCode == "" {
		currencyCode = "CNY"
	}
	return &Account{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		AccountType:  category.ToAccountType(),
		Category:     category,
		CurrencyCode: currencyCode,
		Status:       AccountStatusActive,
		Version:      1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}, nil
}

// NewCategoryAccount creates an Expense/Income category account under the
// account-as-category model. Categories have no balance, currency CNY, and
// IsSystem=false by default (preset seeds flip it to true).
func NewCategoryAccount(tenantID uuid.UUID, name string, accountType AccountType) (*Account, error) {
	if accountType != AccountTypeExpense && accountType != AccountTypeIncome {
		return nil, fmt.Errorf("category account type must be expense or income, got %s", accountType)
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("account name must not be empty")
	}
	return &Account{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		AccountType:  accountType,
		CurrencyCode: "CNY",
		Status:       AccountStatusActive,
		Version:      1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}, nil
}

// SetSortOrder updates the category sort order.
func (a *Account) SetSortOrder(order int) {
	a.SortOrder = order
	a.UpdatedAt = time.Now()
}

// MarkSystem flags the account as a system preset (non-deletable).
func (a *Account) MarkSystem() {
	a.IsSystem = true
	a.UpdatedAt = time.Now()
}

// UpdateName changes the account display name.
func (a *Account) UpdateName(name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("account name must not be empty")
	}
	a.Name = name
	a.UpdatedAt = time.Now()
	return nil
}

// Archive marks the account as archived.
func (a *Account) Archive() {
	a.Status = AccountStatusArchived
	a.UpdatedAt = time.Now()
}

// SoftDelete marks the account as deleted.
func (a *Account) SoftDelete() {
	now := time.Now()
	a.DeletedAt = &now
	a.Status = AccountStatusArchived
	a.UpdatedAt = now
}

// IncrementVersion bumps the optimistic lock version.
func (a *Account) IncrementVersion() {
	a.Version++
	a.UpdatedAt = time.Now()
}

// IsDeleted returns true if the account has been soft-deleted.
func (a *Account) IsDeleted() bool {
	return a.DeletedAt != nil
}

// AccountProfile 是账户可编辑字段的值对象（全指针，nil=不提供/不更新）。
// 用于统一 create 灌入 + update 应用，避免大参数列表。
type AccountProfile struct {
	Name                     *string
	Icon                     *string
	Color                    *string
	ChartCode                *string
	Institution              *string
	CreditLimitCents         *int64
	Status                   *AccountStatus
	CardNumberTail           *string
	Notes                    *string
	OpeningDate              *time.Time
	InterestRate             *float64
	CreditBillingDay         *int
	CreditRepaymentDay       *int
	CreditAnnualFeeCents     *int64
	InvestCostCents          *int64
	InvestMarketValueCents   *int64
	InvestReturnYtd          *float64
	FixedPrincipalCents      *int64
	FixedStartDate           *time.Time
	FixedMaturityDate        *time.Time
	FixedTermMonths          *int
	GoldProductType          *string
	GoldQuantity             *float64
	GoldBuyPriceCents        *int64
	GoldCurrentPriceCents    *int64
	EstatePurchasePriceCents *int64
	EstateCurrentValueCents  *int64
	EstatePurchaseDate       *time.Time
	EstateDepreciationRate   *float64
	LoanOriginalCents        *int64
	LoanRemainingCents       *int64
	LoanMonthlyCents         *int64
	LoanNextPaymentDate      *time.Time
}

// ApplyProfile 把非 nil 字段应用到账户。create 时全量灌入；update 时部分更新。
func (a *Account) ApplyProfile(p *AccountProfile) {
	if p == nil {
		return
	}
	if p.Name != nil {
		a.Name = strings.TrimSpace(*p.Name)
	}
	if p.Icon != nil {
		a.Icon = *p.Icon
	}
	if p.Color != nil {
		a.Color = *p.Color
	}
	if p.ChartCode != nil {
		a.ChartCode = *p.ChartCode
	}
	if p.Institution != nil {
		a.Institution = *p.Institution
	}
	if p.CreditLimitCents != nil {
		a.CreditLimitCents = *p.CreditLimitCents
	}
	if p.Status != nil {
		a.Status = *p.Status
	}
	if p.CardNumberTail != nil {
		a.CardNumberTail = *p.CardNumberTail
	}
	if p.Notes != nil {
		a.Notes = *p.Notes
	}
	if p.OpeningDate != nil {
		a.OpeningDate = p.OpeningDate
	}
	if p.InterestRate != nil {
		a.InterestRate = p.InterestRate
	}
	if p.CreditBillingDay != nil {
		a.CreditBillingDay = p.CreditBillingDay
	}
	if p.CreditRepaymentDay != nil {
		a.CreditRepaymentDay = p.CreditRepaymentDay
	}
	if p.CreditAnnualFeeCents != nil {
		a.CreditAnnualFeeCents = p.CreditAnnualFeeCents
	}
	if p.InvestCostCents != nil {
		a.InvestCostCents = p.InvestCostCents
	}
	if p.InvestMarketValueCents != nil {
		a.InvestMarketValueCents = p.InvestMarketValueCents
	}
	if p.InvestReturnYtd != nil {
		a.InvestReturnYtd = p.InvestReturnYtd
	}
	if p.FixedPrincipalCents != nil {
		a.FixedPrincipalCents = p.FixedPrincipalCents
	}
	if p.FixedStartDate != nil {
		a.FixedStartDate = p.FixedStartDate
	}
	if p.FixedMaturityDate != nil {
		a.FixedMaturityDate = p.FixedMaturityDate
	}
	if p.FixedTermMonths != nil {
		a.FixedTermMonths = p.FixedTermMonths
	}
	if p.GoldProductType != nil {
		a.GoldProductType = *p.GoldProductType
	}
	if p.GoldQuantity != nil {
		a.GoldQuantity = p.GoldQuantity
	}
	if p.GoldBuyPriceCents != nil {
		a.GoldBuyPriceCents = p.GoldBuyPriceCents
	}
	if p.GoldCurrentPriceCents != nil {
		a.GoldCurrentPriceCents = p.GoldCurrentPriceCents
	}
	if p.EstatePurchasePriceCents != nil {
		a.EstatePurchasePriceCents = p.EstatePurchasePriceCents
	}
	if p.EstateCurrentValueCents != nil {
		a.EstateCurrentValueCents = p.EstateCurrentValueCents
	}
	if p.EstatePurchaseDate != nil {
		a.EstatePurchaseDate = p.EstatePurchaseDate
	}
	if p.EstateDepreciationRate != nil {
		a.EstateDepreciationRate = p.EstateDepreciationRate
	}
	if p.LoanOriginalCents != nil {
		a.LoanOriginalCents = p.LoanOriginalCents
	}
	if p.LoanRemainingCents != nil {
		a.LoanRemainingCents = p.LoanRemainingCents
	}
	if p.LoanMonthlyCents != nil {
		a.LoanMonthlyCents = p.LoanMonthlyCents
	}
	if p.LoanNextPaymentDate != nil {
		a.LoanNextPaymentDate = p.LoanNextPaymentDate
	}
	a.UpdatedAt = time.Now()
}

// ChartOfAccount represents an entry in the tenant's chart of accounts.
type ChartOfAccount struct {
	ID               uuid.UUID
	TenantID         uuid.UUID
	Code             string
	Name             string
	Level            int
	AccountType      AccountType
	ParentCode       string
	BalanceDirection BalanceDirection
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// NewChartOfAccount creates a validated ChartOfAccount entity.
func NewChartOfAccount(tenantID uuid.UUID, code, name string, accountType AccountType, balanceDir BalanceDirection) (*ChartOfAccount, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, fmt.Errorf("chart code must not be empty")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("chart name must not be empty")
	}
	return &ChartOfAccount{
		ID:               uuid.New(),
		TenantID:         tenantID,
		Code:             code,
		Name:             name,
		Level:            1,
		AccountType:      accountType,
		BalanceDirection: balanceDir,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}, nil
}
