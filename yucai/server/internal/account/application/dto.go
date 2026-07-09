package application

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// CreateAccountRequest holds input for creating an account.
type CreateAccountRequest struct {
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

// UpdateAccountRequest holds input for updating an account.
type UpdateAccountRequest struct {
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
	SortOrder                *int // nil = 不更新；分类重排时由 ReorderCategories 设置
	ParentID                 *uuid.UUID // nil = 不更新；分类编辑改父分类走 UpdateAccount 路径
	Version                  int64
}

// CreateCategoryRequest creates a category account (AccountType=Expense/Income).
// Categories are accounts under the account-as-category model.
type CreateCategoryRequest struct {
	TenantID    uuid.UUID
	Name        string
	Icon        string
	Color       string
	AccountType domain.AccountType // must be Expense or Income
	ParentID    *uuid.UUID         // optional sub-category parent
}

// UpdateCategoryRequest edits a category account. System categories may change
// icon/color/name but not type. All optional fields use pointers (nil = unchanged).
type UpdateCategoryRequest struct {
	TenantID   uuid.UUID
	CategoryID uuid.UUID
	Name       *string
	Icon       *string
	Color      *string
	ParentID   *uuid.UUID
	Version    int64
}

// ReorderCategoriesRequest sets sort_order for the given category IDs within a
// tenant + account-type group. The slice order defines the new sort order
// (1-indexed).
type ReorderCategoriesRequest struct {
	TenantID    uuid.UUID
	AccountType domain.AccountType
	OrderedIDs  []uuid.UUID
}

// DeleteAccountRequest holds input for soft-deleting an account.
type DeleteAccountRequest struct {
	TenantID  uuid.UUID
	AccountID uuid.UUID
}

// ListAccountsRequest holds input for listing accounts with filters.
type ListAccountsRequest struct {
	TenantID    uuid.UUID
	Filter      domain.AccountFilter
	PageRequest domain.PageRequest
}

// AccountDTO is the data transfer object for accounts.
type AccountDTO struct {
	ID                       uuid.UUID
	TenantID                 uuid.UUID
	Name                     string
	AccountType              domain.AccountType
	Category                 domain.AccountCategory
	CurrencyCode             string
	InitialBalanceCents      int64
	CurrentBalanceCents      int64
	Ownership                domain.Ownership
	Icon                     string
	Color                    string
	ChartCode                string
	ParentID                 *uuid.UUID
	IsSystem                 bool
	SortOrder                int
	Institution              string
	CreditLimitCents         int64
	CardNumberTail           string
	Notes                    string
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
	GoldProductType          string
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
	Status                   domain.AccountStatus
	Version                  int64
	CreatedAt                time.Time
	UpdatedAt                time.Time
}

// ListAccountsResult wraps paginated account DTOs.
type ListAccountsResult struct {
	Accounts      []AccountDTO
	NextPageToken string
	TotalCount    int32
}

// AccountToDTO converts a domain Account to AccountDTO.
func AccountToDTO(a *domain.Account) AccountDTO {
	return AccountDTO{
		ID:                       a.ID,
		TenantID:                 a.TenantID,
		Name:                     a.Name,
		AccountType:              a.AccountType,
		Category:                 a.Category,
		CurrencyCode:             a.CurrencyCode,
		InitialBalanceCents:      a.InitialBalanceCents,
		CurrentBalanceCents:      a.CurrentBalanceCents,
		Ownership:                a.Ownership,
		Icon:                     a.Icon,
		Color:                    a.Color,
		ChartCode:                a.ChartCode,
		ParentID:                 a.ParentID,
		IsSystem:                 a.IsSystem,
		SortOrder:                a.SortOrder,
		Institution:              a.Institution,
		CreditLimitCents:         a.CreditLimitCents,
		CardNumberTail:           a.CardNumberTail,
		Notes:                    a.Notes,
		OpeningDate:              a.OpeningDate,
		InterestRate:             a.InterestRate,
		CreditBillingDay:         a.CreditBillingDay,
		CreditRepaymentDay:       a.CreditRepaymentDay,
		CreditAnnualFeeCents:     a.CreditAnnualFeeCents,
		InvestCostCents:          a.InvestCostCents,
		InvestMarketValueCents:   a.InvestMarketValueCents,
		InvestReturnYtd:          a.InvestReturnYtd,
		FixedPrincipalCents:      a.FixedPrincipalCents,
		FixedStartDate:           a.FixedStartDate,
		FixedMaturityDate:        a.FixedMaturityDate,
		FixedTermMonths:          a.FixedTermMonths,
		GoldProductType:          a.GoldProductType,
		GoldQuantity:             a.GoldQuantity,
		GoldBuyPriceCents:        a.GoldBuyPriceCents,
		GoldCurrentPriceCents:    a.GoldCurrentPriceCents,
		EstatePurchasePriceCents: a.EstatePurchasePriceCents,
		EstateCurrentValueCents:  a.EstateCurrentValueCents,
		EstatePurchaseDate:       a.EstatePurchaseDate,
		EstateDepreciationRate:   a.EstateDepreciationRate,
		LoanOriginalCents:        a.LoanOriginalCents,
		LoanRemainingCents:       a.LoanRemainingCents,
		LoanMonthlyCents:         a.LoanMonthlyCents,
		LoanNextPaymentDate:      a.LoanNextPaymentDate,
		Status:                   a.Status,
		Version:                  a.Version,
		CreatedAt:                a.CreatedAt,
		UpdatedAt:                a.UpdatedAt,
	}
}

// CreateRequestToProfile 把 CreateAccountRequest 的可编辑字段映射到 domain AccountProfile。
func CreateRequestToProfile(req CreateAccountRequest) *domain.AccountProfile {
	return &domain.AccountProfile{
		Name: strPtr(req.Name), Icon: strPtr(req.Icon), Color: strPtr(req.Color),
		ChartCode: strPtr(req.ChartCode), Institution: strPtr(req.Institution),
		CreditLimitCents: &req.CreditLimitCents,
		CardNumberTail:   req.CardNumberTail, Notes: req.Notes, OpeningDate: req.OpeningDate,
		InterestRate: req.InterestRate, CreditBillingDay: req.CreditBillingDay,
		CreditRepaymentDay: req.CreditRepaymentDay, CreditAnnualFeeCents: req.CreditAnnualFeeCents,
		InvestCostCents: req.InvestCostCents, InvestMarketValueCents: req.InvestMarketValueCents,
		InvestReturnYtd: req.InvestReturnYtd, FixedPrincipalCents: req.FixedPrincipalCents,
		FixedStartDate: req.FixedStartDate, FixedMaturityDate: req.FixedMaturityDate,
		FixedTermMonths: req.FixedTermMonths, GoldProductType: req.GoldProductType,
		GoldQuantity: req.GoldQuantity, GoldBuyPriceCents: req.GoldBuyPriceCents,
		GoldCurrentPriceCents:    req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents:  req.EstateCurrentValueCents,
		EstatePurchaseDate:       req.EstatePurchaseDate, EstateDepreciationRate: req.EstateDepreciationRate,
		LoanOriginalCents: req.LoanOriginalCents, LoanRemainingCents: req.LoanRemainingCents,
		LoanMonthlyCents: req.LoanMonthlyCents, LoanNextPaymentDate: req.LoanNextPaymentDate,
	}
}

// UpdateRequestToProfile 把 UpdateAccountRequest 映射到 domain AccountProfile。
func UpdateRequestToProfile(req UpdateAccountRequest) *domain.AccountProfile {
	return &domain.AccountProfile{
		Name: strPtr(req.Name), Icon: strPtr(req.Icon), Color: strPtr(req.Color),
		ChartCode: strPtr(req.ChartCode), Institution: strPtr(req.Institution),
		CreditLimitCents: &req.CreditLimitCents, Status: req.Status,
		CardNumberTail: req.CardNumberTail, Notes: req.Notes, OpeningDate: req.OpeningDate,
		InterestRate: req.InterestRate, CreditBillingDay: req.CreditBillingDay,
		CreditRepaymentDay: req.CreditRepaymentDay, CreditAnnualFeeCents: req.CreditAnnualFeeCents,
		InvestCostCents: req.InvestCostCents, InvestMarketValueCents: req.InvestMarketValueCents,
		InvestReturnYtd: req.InvestReturnYtd, FixedPrincipalCents: req.FixedPrincipalCents,
		FixedStartDate: req.FixedStartDate, FixedMaturityDate: req.FixedMaturityDate,
		FixedTermMonths: req.FixedTermMonths, GoldProductType: req.GoldProductType,
		GoldQuantity: req.GoldQuantity, GoldBuyPriceCents: req.GoldBuyPriceCents,
		GoldCurrentPriceCents:    req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents:  req.EstateCurrentValueCents,
		EstatePurchaseDate:       req.EstatePurchaseDate, EstateDepreciationRate: req.EstateDepreciationRate,
		LoanOriginalCents: req.LoanOriginalCents, LoanRemainingCents: req.LoanRemainingCents,
		LoanMonthlyCents: req.LoanMonthlyCents, LoanNextPaymentDate: req.LoanNextPaymentDate,
	}
}

func strPtr(s string) *string { return &s }

// ApplyCreateDefaults applies optional fields from the request to the account entity.
func ApplyCreateDefaults(a *domain.Account, req CreateAccountRequest) {
	a.InitialBalanceCents = req.InitialBalanceCents
	a.CurrentBalanceCents = req.InitialBalanceCents
	a.Ownership = req.Ownership
	a.Icon = req.Icon
	a.Color = req.Color
	a.ChartCode = req.ChartCode
	a.ParentID = req.ParentID
	a.Institution = req.Institution
	a.CreditLimitCents = req.CreditLimitCents
	if a.Ownership == 0 {
		a.Ownership = domain.OwnershipPersonal
	}
	if a.CurrencyCode == "" {
		a.CurrencyCode = "CNY"
	}
}

// ValidateUpdateVersion checks optimistic locking.
func ValidateUpdateVersion(current, expected int64) error {
	if current != expected {
		return fmt.Errorf("optimistic lock conflict: current version %d, expected %d", current, expected)
	}
	return nil
}
