package command

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// CreateAccountCommand creates a new account.
type CreateAccountCommand struct {
	TenantID                 uuid.UUID
	Name                     string
	AccountType              domain.AccountType
	Category                 domain.AccountCategory
	CurrencyCode             string
	InitialBalanceCents      int64
	Ownership                domain.Ownership
	Icon                     string
	Color                    string
	ChartCode                string
	ParentID                 *uuid.UUID
	Institution              string
	CreditLimitCents         int64
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

// UpdateAccountCommand updates an existing account.
type UpdateAccountCommand struct {
	TenantID                 uuid.UUID
	AccountID                uuid.UUID
	Name                     string
	Icon                     string
	Color                    string
	ChartCode                string
	Institution              string
	CreditLimitCents         int64
	Status                   *domain.AccountStatus
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
	Version                  int64
}

// DeleteAccountCommand soft-deletes an account.
type DeleteAccountCommand struct {
	TenantID  uuid.UUID
	AccountID uuid.UUID
}
