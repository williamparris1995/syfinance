package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/account/ent"
	accountent "github.com/yucai/server/internal/account/ent/account"
)

// AccountRepository implements domain.AccountRepository using entGo.
type AccountRepository struct {
	client *ent.Client
}

// NewAccountRepository creates a new AccountRepository.
func NewAccountRepository(client *ent.Client) *AccountRepository {
	return &AccountRepository{client: client}
}

// Save persists a new account.
func (r *AccountRepository) Save(ctx context.Context, a *domain.Account) error {
	builder := r.client.Account.Create().
		SetID(a.ID).
		SetTenantID(a.TenantID).
		SetName(a.Name).
		SetAccountType(accountent.AccountType(a.AccountType.String())).
		SetCategory(accountent.Category(a.Category.String())).
		SetCurrencyCode(a.CurrencyCode).
		SetInitialBalanceCents(a.InitialBalanceCents).
		SetCurrentBalanceCents(a.CurrentBalanceCents).
		SetOwnership(accountent.Ownership(a.Ownership.String())).
		SetIcon(a.Icon).
		SetColor(a.Color).
		SetChartCode(a.ChartCode).
		SetInstitution(a.Institution).
		SetCreditLimitCents(a.CreditLimitCents).
		SetCardNumberTail(a.CardNumberTail).
		SetNotes(a.Notes).
		SetNillableOpeningDate(a.OpeningDate).
		SetNillableInterestRate(a.InterestRate).
		SetNillableCreditBillingDay(a.CreditBillingDay).
		SetNillableCreditRepaymentDay(a.CreditRepaymentDay).
		SetNillableCreditAnnualFeeCents(a.CreditAnnualFeeCents).
		SetNillableInvestCostCents(a.InvestCostCents).
		SetNillableInvestMarketValueCents(a.InvestMarketValueCents).
		SetNillableInvestReturnYtd(a.InvestReturnYtd).
		SetNillableFixedPrincipalCents(a.FixedPrincipalCents).
		SetNillableFixedStartDate(a.FixedStartDate).
		SetNillableFixedMaturityDate(a.FixedMaturityDate).
		SetNillableFixedTermMonths(a.FixedTermMonths).
		SetGoldProductType(a.GoldProductType).
		SetNillableGoldQuantity(a.GoldQuantity).
		SetNillableGoldBuyPriceCents(a.GoldBuyPriceCents).
		SetNillableGoldCurrentPriceCents(a.GoldCurrentPriceCents).
		SetNillableEstatePurchasePriceCents(a.EstatePurchasePriceCents).
		SetNillableEstateCurrentValueCents(a.EstateCurrentValueCents).
		SetNillableEstatePurchaseDate(a.EstatePurchaseDate).
		SetNillableEstateDepreciationRate(a.EstateDepreciationRate).
		SetNillableLoanOriginalCents(a.LoanOriginalCents).
		SetNillableLoanRemainingCents(a.LoanRemainingCents).
		SetNillableLoanMonthlyCents(a.LoanMonthlyCents).
		SetNillableLoanNextPaymentDate(a.LoanNextPaymentDate).
		SetStatus(accountent.Status(a.Status.String())).
		SetVersion(a.Version).
		SetCreatedAt(a.CreatedAt).
		SetUpdatedAt(a.UpdatedAt)

	if a.ParentID != nil {
		builder.SetParentID(*a.ParentID)
	}

	_, err := builder.Save(ctx)
	if err != nil {
		return fmt.Errorf("save account: %w", err)
	}
	return nil
}

// FindByID retrieves an account by ID within a tenant, excluding soft-deleted.
func (r *AccountRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Account, error) {
	a, err := r.client.Account.Query().
		Where(
			accountent.ID(id),
			accountent.TenantID(tenantID),
			accountent.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find account by id: %w", err)
	}
	return toDomainAccount(a), nil
}

// FindAll returns a paginated, filtered list of accounts.
func (r *AccountRepository) FindAll(ctx context.Context, tenantID uuid.UUID, filter domain.AccountFilter, page domain.PageRequest) (*domain.PaginatedResult[domain.Account], error) {
	query := r.client.Account.Query().
		Where(
			accountent.TenantID(tenantID),
			accountent.DeletedAtIsNil(),
		)

	if filter.AccountType != nil {
		query.Where(accountent.AccountTypeEQ(accountent.AccountType(filter.AccountType.String())))
	}
	if filter.Status != nil {
		query.Where(accountent.StatusEQ(accountent.Status(filter.Status.String())))
	}

	// Get total count
	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count accounts: %w", err)
	}

	// Apply pagination
	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1) // +1 to detect next page

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(accountent.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query accounts: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	accounts := make([]domain.Account, len(results))
	for i, a := range results {
		accounts[i] = *toDomainAccount(a)
	}

	return &domain.PaginatedResult[domain.Account]{
		Items:         accounts,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to an existing account (optimistic lock via version).
func (r *AccountRepository) Update(ctx context.Context, a *domain.Account) error {
	n, err := r.client.Account.UpdateOneID(a.ID).
		Where(accountent.Version(a.Version - 1)).
		SetName(a.Name).
		SetCurrentBalanceCents(a.CurrentBalanceCents).
		SetIcon(a.Icon).
		SetColor(a.Color).
		SetChartCode(a.ChartCode).
		SetInstitution(a.Institution).
		SetCreditLimitCents(a.CreditLimitCents).
		SetStatus(accountent.Status(a.Status.String())). // 关闭/归档状态须持久化（否则 status 变更不落库）
		SetCardNumberTail(a.CardNumberTail).
		SetNotes(a.Notes).
		SetNillableOpeningDate(a.OpeningDate).
		SetNillableInterestRate(a.InterestRate).
		SetNillableCreditBillingDay(a.CreditBillingDay).
		SetNillableCreditRepaymentDay(a.CreditRepaymentDay).
		SetNillableCreditAnnualFeeCents(a.CreditAnnualFeeCents).
		SetNillableInvestCostCents(a.InvestCostCents).
		SetNillableInvestMarketValueCents(a.InvestMarketValueCents).
		SetNillableInvestReturnYtd(a.InvestReturnYtd).
		SetNillableFixedPrincipalCents(a.FixedPrincipalCents).
		SetNillableFixedStartDate(a.FixedStartDate).
		SetNillableFixedMaturityDate(a.FixedMaturityDate).
		SetNillableFixedTermMonths(a.FixedTermMonths).
		SetGoldProductType(a.GoldProductType).
		SetNillableGoldQuantity(a.GoldQuantity).
		SetNillableGoldBuyPriceCents(a.GoldBuyPriceCents).
		SetNillableGoldCurrentPriceCents(a.GoldCurrentPriceCents).
		SetNillableEstatePurchasePriceCents(a.EstatePurchasePriceCents).
		SetNillableEstateCurrentValueCents(a.EstateCurrentValueCents).
		SetNillableEstatePurchaseDate(a.EstatePurchaseDate).
		SetNillableEstateDepreciationRate(a.EstateDepreciationRate).
		SetNillableLoanOriginalCents(a.LoanOriginalCents).
		SetNillableLoanRemainingCents(a.LoanRemainingCents).
		SetNillableLoanMonthlyCents(a.LoanMonthlyCents).
		SetNillableLoanNextPaymentDate(a.LoanNextPaymentDate).
		SetVersion(a.Version).
		SetUpdatedAt(a.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update account: %w", err)
	}
	if n.Version != a.Version {
		return fmt.Errorf("optimistic lock: version mismatch after update")
	}
	return nil
}

// SoftDelete sets deleted_at and archives the account.
func (r *AccountRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Account.UpdateOneID(id).
		Where(accountent.TenantID(tenantID)).
		SetStatus(accountent.StatusArchived).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete account: %w", err)
	}
	return nil
}

func toDomainAccount(a *ent.Account) *domain.Account {
	result := &domain.Account{
		ID:                       a.ID,
		TenantID:                 a.TenantID,
		Name:                     a.Name,
		AccountType:              domain.ParseAccountType(string(a.AccountType)),
		Category:                 domain.ParseAccountCategory(string(a.Category)),
		CurrencyCode:             a.CurrencyCode,
		InitialBalanceCents:      a.InitialBalanceCents,
		CurrentBalanceCents:      a.CurrentBalanceCents,
		Ownership:                domain.ParseOwnership(string(a.Ownership)),
		Icon:                     a.Icon,
		Color:                    a.Color,
		ChartCode:                a.ChartCode,
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
		Status:                   domain.ParseAccountStatus(string(a.Status)),
		Version:                  a.Version,
		DeletedAt:                a.DeletedAt,
		CreatedAt:                a.CreatedAt,
		UpdatedAt:                a.UpdatedAt,
	}
	if a.ParentID != nil {
		pid := *a.ParentID
		result.ParentID = &pid
	}
	return result
}

// Compile-time check.
var _ domain.AccountRepository = (*AccountRepository)(nil)
