package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/account/ent"
	accountent "github.com/yucai/server/internal/account/ent/account"
	"github.com/yucai/server/internal/sqltx"
)

// AccountRepository implements domain.AccountRepository using entGo.
type AccountRepository struct {
	client *ent.Client
}

// NewAccountRepository creates a new AccountRepository.
func NewAccountRepository(client *ent.Client) *AccountRepository {
	return &AccountRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose writes
// join the outer transaction; otherwise it returns the default r.client (the
// non-transactional path, preserving backward compatibility for callers that
// do not wrap in a tx).
func (r *AccountRepository) clientFor(ctx context.Context) *ent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return ent.NewClient(ent.Driver(d))
	}
	return r.client
}

// Save persists a new account.
func (r *AccountRepository) Save(ctx context.Context, a *domain.Account) error {
	builder := r.clientFor(ctx).Account.Create().
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
		SetIsSystem(a.IsSystem).
		SetSortOrder(a.SortOrder).
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
	a, err := r.clientFor(ctx).Account.Query().
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
	query := r.clientFor(ctx).Account.Query().
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
		// 默认放大:交易分录/分类 chip 需解析所有账户(含 expense/income 分类账户),
		// 若分页太小(default 20)会漏分类账户 → client 显示 #id。200 容纳常规租户全量。
		pageSize = 200
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

// FindByAccountType returns all non-deleted accounts of a given type within a tenant,
// ordered by sort_order then name for stable category-dropdown display.
func (r *AccountRepository) FindByAccountType(ctx context.Context, tenantID uuid.UUID, accountType domain.AccountType) ([]domain.Account, error) {
	results, err := r.clientFor(ctx).Account.Query().
		Where(
			accountent.TenantID(tenantID),
			accountent.AccountTypeEQ(accountent.AccountType(accountType.String())),
			accountent.DeletedAtIsNil(),
		).
		Order(
			ent.Asc(accountent.FieldSortOrder),
			ent.Asc(accountent.FieldName),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find accounts by type: %w", err)
	}

	accounts := make([]domain.Account, len(results))
	for i, a := range results {
		accounts[i] = *toDomainAccount(a)
	}
	return accounts, nil
}

// Update persists changes to an existing account (optimistic lock via version).
func (r *AccountRepository) Update(ctx context.Context, a *domain.Account) error {
	n, err := r.clientFor(ctx).Account.UpdateOneID(a.ID).
		Where(accountent.Version(a.Version - 1)).
		SetName(a.Name).
		SetCurrentBalanceCents(a.CurrentBalanceCents).
		SetIcon(a.Icon).
		SetColor(a.Color).
		SetSortOrder(a.SortOrder).
		SetChartCode(a.ChartCode).
		SetInstitution(a.Institution).
		SetCreditLimitCents(a.CreditLimitCents).
		SetStatus(accountent.Status(a.Status.String())). // 关闭/归档状态须持久化（否则 status 变更不落库）
		SetNillableParentID(a.ParentID). // 二级分类父级须持久化（否则编辑改父分类不落库；service 已加载现有值，nil=保持/清除）
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
	_, err := r.clientFor(ctx).Account.UpdateOneID(id).
		Where(accountent.TenantID(tenantID)).
		SetStatus(accountent.StatusArchived).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete account: %w", err)
	}
	return nil
}

// FindAllForBackup returns all non-deleted accounts for a tenant (no pagination,
// includes category accounts) for backup export.
func (r *AccountRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Account, error) {
	results, err := r.clientFor(ctx).Account.Query().
		Where(
			accountent.TenantID(tenantID),
			accountent.DeletedAtIsNil(),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup find accounts: %w", err)
	}
	out := make([]domain.Account, len(results))
	for i, a := range results {
		out[i] = *toDomainAccount(a)
	}
	return out, nil
}

// DeleteByTenant hard-deletes all accounts (including categories) for a tenant.
// Used by backup Import's purge step to clear before re-import.
func (r *AccountRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	_, err := r.clientFor(ctx).Account.Delete().
		Where(accountent.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("backup purge accounts: %w", err)
	}
	return nil
}

// UpsertForSync applies one offline-sync push for a single account: find by
// id+tenant (soft-deleted rows included — an upsert from the client, which is
// the single-device source of truth, resurrects them), then either a
// full-field update trusting the client-supplied version (no optimistic lock:
// sync owns the row, v1 semantics per F11 spec) or a create with the
// client-supplied id (the Save path). Tx-aware via clientFor so the whole sync
// batch joins one sqltx transaction.
func (r *AccountRepository) UpsertForSync(ctx context.Context, a *domain.Account) error {
	c := r.clientFor(ctx)
	_, err := c.Account.Query().
		Where(accountent.ID(a.ID), accountent.TenantID(a.TenantID)).
		First(ctx)
	switch {
	case err == nil:
		update := c.Account.UpdateOneID(a.ID).
			SetName(a.Name).
			SetAccountType(accountent.AccountType(a.AccountType.String())).
			SetCategory(accountent.Category(a.Category.String())).
			SetCurrencyCode(a.CurrencyCode).
			SetInitialBalanceCents(a.InitialBalanceCents).
			SetCurrentBalanceCents(a.CurrentBalanceCents).
			SetOwnership(accountent.Ownership(a.Ownership.String())).
			SetIcon(a.Icon).
			SetColor(a.Color).
			SetIsSystem(a.IsSystem).
			SetSortOrder(a.SortOrder).
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
			SetNillableParentID(a.ParentID).
			SetVersion(a.Version).
			SetUpdatedAt(a.UpdatedAt).
			ClearDeletedAt() // client truth says the row is alive
		if _, err := update.Save(ctx); err != nil {
			return fmt.Errorf("sync upsert account %s: %w", a.ID, err)
		}
		return nil
	case ent.IsNotFound(err):
		return r.Save(ctx, a) // create with the client-supplied id
	default:
		return fmt.Errorf("sync find account %s: %w", a.ID, err)
	}
}

// HardDeleteForSync physically removes one account on the offline-sync DELETE
// path (single-device hard-delete semantics; the soft-delete column is a
// server-only concept and is deliberately not used here). Idempotent by
// design: deleting an already-absent row is a no-op so a re-delivered
// tombstone never fails the batch (FR-3). Accounts have no in-module child
// rows (categories are peer account rows), so no cascade is needed.
// Cross-module referencers are cleaned by their own writers following the
// dependents-first delete order in the sync service.
func (r *AccountRepository) HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error {
	if _, err := r.clientFor(ctx).Account.Delete().
		Where(accountent.ID(id), accountent.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync hard delete account %s: %w", id, err)
	}
	return nil
}

// FindForSync returns the tenant's current row for the offline-sync conflict
// check (F16 ADR-4) — the read dual of UpsertForSync: soft-deleted rows are
// INCLUDED (they own their version until a push resurrects or hard-deletes
// them). found=false means the tenant holds no row for the id; every other
// failure is an error. Tx-aware via clientFor so the check reads inside the
// push batch transaction.
func (r *AccountRepository) FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*domain.Account, bool, error) {
	a, err := r.clientFor(ctx).Account.Query().
		Where(accountent.ID(id), accountent.TenantID(tenantID)).
		First(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("sync find account %s: %w", id, err)
	}
	return toDomainAccount(a), true, nil
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
		IsSystem:                 a.IsSystem,
		SortOrder:                a.SortOrder,
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
