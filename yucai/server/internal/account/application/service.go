package application

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/application/command"
	"github.com/yucai/server/internal/account/application/query"
	"github.com/yucai/server/internal/account/domain"
)

// Service orchestrates account operations.
type Service struct {
	accountRepo domain.AccountRepository
	chartRepo   domain.ChartRepository
	refSources  []domain.AccountReferenceSource
}

// NewService creates a new account application service.
func NewService(accountRepo domain.AccountRepository, chartRepo domain.ChartRepository) *Service {
	return &Service{accountRepo: accountRepo, chartRepo: chartRepo}
}

// SetAccountReferenceSources injects the cross-module reference counters used
// by DeleteAccount / DeleteCategory (R5-E ticket 05 decision 5: cross-module
// orphans are prevented by rejecting deletion of referenced accounts, since
// cross-module FKs are deliberately not modeled). The slice is built at the
// composition root from the consumer-module repositories, which implement the
// port structurally.
func (s *Service) SetAccountReferenceSources(sources []domain.AccountReferenceSource) {
	s.refSources = sources
}

// rejectIfReferenced fails-closed on every configured source: any count > 0
// blocks deletion with a caller-presentable reason; a counting error or a
// missing wiring (empty sources) also refuses, never silently reverting to
// the orphan-leaving behavior this guard exists to prevent.
func (s *Service) rejectIfReferenced(ctx context.Context, tenantID, accountID uuid.UUID) error {
	if len(s.refSources) == 0 {
		return fmt.Errorf("account reference sources not configured")
	}
	for _, src := range s.refSources {
		n, err := src.CountAccountReferences(ctx, tenantID, accountID)
		if err != nil {
			return fmt.Errorf("check %s references: %w", src.AccountReferenceSourceName(), err)
		}
		if n > 0 {
			return fmt.Errorf("cannot delete account: referenced by %d %s record(s)",
				n, src.AccountReferenceSourceName())
		}
	}
	return nil
}

// CreateAccount creates a new account and returns its DTO.
//
// Construction is split by account_type:
//   - Expense/Income (account-as-category): built via [domain.NewCategoryAccount],
//     which sets AccountType from the request and leaves Category at its zero
//     value (categories carry no financial category). The request's Category
//     field is ignored for these types — it is meaningless for a category
//     account and previously caused expense/income categories to be silently
//     stored as asset/other_asset (see task: 分类创建存成了 asset 类型).
//   - Asset/Liability/Equity: built via [domain.NewAccountWithCategory], which
//     derives AccountType from Category (the documented user-facing path).
func (s *Service) CreateAccount(ctx context.Context, req CreateAccountRequest) (*AccountDTO, error) {
	var account *domain.Account
	var err error
	if req.AccountType == domain.AccountTypeExpense || req.AccountType == domain.AccountTypeIncome {
		account, err = domain.NewCategoryAccount(req.TenantID, req.Name, req.AccountType)
	} else {
		account, err = domain.NewAccountWithCategory(req.TenantID, req.Name, req.Category, req.CurrencyCode)
	}
	if err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}
	account.ApplyProfile(CreateRequestToProfile(req))
	// ApplyCreateDefaults 处理 create-only 字段（InitialBalance/CurrentBalance/Ownership/
	// CurrencyCode/ParentID 兜底默认值）；Icon/Color/ChartCode/Institution/CreditLimit 与
	// ApplyProfile 重叠但同源幂等（都读 req），安全。
	ApplyCreateDefaults(account, req)

	if err := s.accountRepo.Save(ctx, account); err != nil {
		return nil, fmt.Errorf("save account: %w", err)
	}

	dto := AccountToDTO(account)
	return &dto, nil
}

// GetAccount retrieves an account by ID with tenant isolation.
func (s *Service) GetAccount(ctx context.Context, tenantID, accountID uuid.UUID) (*AccountDTO, error) {
	account, err := s.accountRepo.FindByID(ctx, tenantID, accountID)
	if err != nil {
		return nil, fmt.Errorf("account not found: %w", err)
	}
	dto := AccountToDTO(account)
	return &dto, nil
}

// ListAccounts returns a paginated, filtered list of accounts.
func (s *Service) ListAccounts(ctx context.Context, req ListAccountsRequest) (*ListAccountsResult, error) {
	result, err := s.accountRepo.FindAll(ctx, req.TenantID, req.Filter, req.PageRequest)
	if err != nil {
		return nil, fmt.Errorf("list accounts: %w", err)
	}
	dtos := make([]AccountDTO, len(result.Items))
	for i, a := range result.Items {
		dtos[i] = AccountToDTO(&a)
	}
	return &ListAccountsResult{
		Accounts:      dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// FindByAccountType returns all non-deleted accounts of a given type for the
// tenant. Used by the transaction-form category dropdown (account-as-category).
func (s *Service) FindByAccountType(ctx context.Context, tenantID uuid.UUID, accountType domain.AccountType) ([]AccountDTO, error) {
	accounts, err := s.accountRepo.FindByAccountType(ctx, tenantID, accountType)
	if err != nil {
		return nil, fmt.Errorf("find accounts by type: %w", err)
	}
	dtos := make([]AccountDTO, len(accounts))
	for i, a := range accounts {
		dtos[i] = AccountToDTO(&a)
	}
	return dtos, nil
}

// UpdateAccount updates mutable account fields with optimistic locking.
func (s *Service) UpdateAccount(ctx context.Context, req UpdateAccountRequest) (*AccountDTO, error) {
	account, err := s.accountRepo.FindByID(ctx, req.TenantID, req.AccountID)
	if err != nil {
		return nil, fmt.Errorf("account not found: %w", err)
	}

	if err := ValidateUpdateVersion(account.Version, req.Version); err != nil {
		return nil, err
	}

	account.ApplyProfile(UpdateRequestToProfile(req))
	if req.Status != nil && *req.Status == domain.AccountStatusArchived {
		account.Archive()
	}
	if req.SortOrder != nil {
		account.SetSortOrder(*req.SortOrder)
	}
	if req.ParentID != nil {
		account.ParentID = req.ParentID
	}
	account.IncrementVersion()

	if err := s.accountRepo.Update(ctx, account); err != nil {
		return nil, fmt.Errorf("update account: %w", err)
	}

	dto := AccountToDTO(account)
	return &dto, nil
}

// DeleteAccount soft-deletes an account (only if balance is zero and nothing
// references it — transactions, budgets, debts, holdings, goals, templates;
// R5-E ticket 05 decision 5).
func (s *Service) DeleteAccount(ctx context.Context, tenantID, accountID uuid.UUID) error {
	account, err := s.accountRepo.FindByID(ctx, tenantID, accountID)
	if err != nil {
		return fmt.Errorf("account not found: %w", err)
	}
	if account.CurrentBalanceCents != 0 {
		return fmt.Errorf("cannot delete account with non-zero balance")
	}
	if err := s.rejectIfReferenced(ctx, tenantID, accountID); err != nil {
		return err
	}
	return s.accountRepo.SoftDelete(ctx, tenantID, accountID)
}

// --- Category CRUD (account-as-category model) ---
//
// A category is an Account whose AccountType is Expense or Income. Categories
// back the transaction-form dropdown and the user-facing category manager.
// Preset (is_system=true) categories are created per-tenant at registration and
// may be restyled but not deleted.

// CreateCategory creates an Expense/Income category account for the tenant.
func (s *Service) CreateCategory(ctx context.Context, req CreateCategoryRequest) (*AccountDTO, error) {
	account, err := domain.NewCategoryAccount(req.TenantID, req.Name, req.AccountType)
	if err != nil {
		return nil, fmt.Errorf("create category: %w", err)
	}
	account.Icon = req.Icon
	account.Color = req.Color
	account.ParentID = req.ParentID

	if err := s.accountRepo.Save(ctx, account); err != nil {
		return nil, fmt.Errorf("save category: %w", err)
	}
	dto := AccountToDTO(account)
	return &dto, nil
}

// UpdateCategory edits a category's mutable display fields. System categories
// keep their type; user categories likewise cannot change type via this path
// (type is immutable for all categories — a category's type is part of its
// identity in the dropdown grouping).
func (s *Service) UpdateCategory(ctx context.Context, req UpdateCategoryRequest) (*AccountDTO, error) {
	account, err := s.accountRepo.FindByID(ctx, req.TenantID, req.CategoryID)
	if err != nil {
		return nil, fmt.Errorf("category not found: %w", err)
	}
	if err := ValidateUpdateVersion(account.Version, req.Version); err != nil {
		return nil, err
	}
	if account.AccountType != domain.AccountTypeExpense && account.AccountType != domain.AccountTypeIncome {
		return nil, fmt.Errorf("not a category account: type %s", account.AccountType)
	}
	account.ApplyProfile(&domain.AccountProfile{
		Name:  req.Name,
		Icon:  req.Icon,
		Color: req.Color,
	})
	if req.ParentID != nil {
		account.ParentID = req.ParentID
	}
	account.IncrementVersion()
	if err := s.accountRepo.Update(ctx, account); err != nil {
		return nil, fmt.Errorf("update category: %w", err)
	}
	dto := AccountToDTO(account)
	return &dto, nil
}

// DeleteCategory soft-deletes a category. System (preset) categories are
// non-deletable — the guard is the defining behavior of is_system.
func (s *Service) DeleteCategory(ctx context.Context, tenantID, categoryID uuid.UUID) error {
	account, err := s.accountRepo.FindByID(ctx, tenantID, categoryID)
	if err != nil {
		return fmt.Errorf("category not found: %w", err)
	}
	if account.IsSystem {
		return fmt.Errorf("cannot delete system category %q", account.Name)
	}
	if account.AccountType != domain.AccountTypeExpense && account.AccountType != domain.AccountTypeIncome {
		return fmt.Errorf("not a category account: type %s", account.AccountType)
	}
	// Categories are referenced by transactions like any other account
	// (entries.account_id) — same rejection guard.
	if err := s.rejectIfReferenced(ctx, tenantID, categoryID); err != nil {
		return err
	}
	return s.accountRepo.SoftDelete(ctx, tenantID, categoryID)
}

// ReorderCategories rewrites sort_order for the given category IDs within the
// tenant + account-type group. The slice order defines the new sort order
// (1-indexed). Categories not in the list keep their existing sort_order.
func (s *Service) ReorderCategories(ctx context.Context, req ReorderCategoriesRequest) error {
	if req.AccountType != domain.AccountTypeExpense && req.AccountType != domain.AccountTypeIncome {
		return fmt.Errorf("reorder requires expense or income type, got %s", req.AccountType)
	}
	for i, id := range req.OrderedIDs {
		account, err := s.accountRepo.FindByID(ctx, req.TenantID, id)
		if err != nil {
			return fmt.Errorf("category %s not found: %w", id, err)
		}
		if account.AccountType != req.AccountType {
			return fmt.Errorf("category %s type mismatch: expected %s, got %s", id, req.AccountType, account.AccountType)
		}
		account.SetSortOrder(i + 1)
		account.IncrementVersion()
		if err := s.accountRepo.Update(ctx, account); err != nil {
			return fmt.Errorf("update sort_order for %s: %w", id, err)
		}
	}
	return nil
}

// presetCategories defines the 10 system categories seeded per tenant at
// registration: 6 expense + 4 income. Ordered so sort_order is stable.
var presetCategories = []struct {
	Name        string
	AccountType domain.AccountType
	Icon        string
	Color       string
}{
	// Expense (6)
	{"餐饮", domain.AccountTypeExpense, "utensils", "#FF6B6B"},
	{"交通", domain.AccountTypeExpense, "car", "#4ECDC4"},
	{"购物", domain.AccountTypeExpense, "shopping-bag", "#FFD93D"},
	{"娱乐", domain.AccountTypeExpense, "gamepad", "#6C5CE7"},
	{"居家", domain.AccountTypeExpense, "home", "#A8E6CF"},
	{"医疗", domain.AccountTypeExpense, "heart-pulse", "#FF8B94"},
	// Income (4)
	{"工资", domain.AccountTypeIncome, "banknote", "#00B894"},
	{"兼职", domain.AccountTypeIncome, "briefcase", "#0984E3"},
	{"理财收益", domain.AccountTypeIncome, "trending-up", "#FDCB6E"},
	{"红包", domain.AccountTypeIncome, "gift", "#E17055"},
}

// SeedPresetCategories creates the 10 system categories for a tenant if they
// do not already exist (idempotent — safe to call on every registration retry).
func (s *Service) SeedPresetCategories(ctx context.Context, tenantID uuid.UUID) error {
	existingExpense, err := s.accountRepo.FindByAccountType(ctx, tenantID, domain.AccountTypeExpense)
	if err != nil {
		return fmt.Errorf("check existing expense categories: %w", err)
	}
	existingIncome, err := s.accountRepo.FindByAccountType(ctx, tenantID, domain.AccountTypeIncome)
	if err != nil {
		return fmt.Errorf("check existing income categories: %w", err)
	}
	// If any system category already exists, assume seeding ran — no-op.
	for _, a := range append(append([]domain.Account{}, existingExpense...), existingIncome...) {
		if a.IsSystem {
			return nil
		}
	}

	expenseOrder := 0
	incomeOrder := 0
	for _, p := range presetCategories {
		account, err := domain.NewCategoryAccount(tenantID, p.Name, p.AccountType)
		if err != nil {
			return fmt.Errorf("build preset category %q: %w", p.Name, err)
		}
		account.Icon = p.Icon
		account.Color = p.Color
		account.MarkSystem()
		if p.AccountType == domain.AccountTypeExpense {
			expenseOrder++
			account.SortOrder = expenseOrder
		} else {
			incomeOrder++
			account.SortOrder = incomeOrder
		}
		if err := s.accountRepo.Save(ctx, account); err != nil {
			return fmt.Errorf("save preset category %q: %w", p.Name, err)
		}
	}
	return nil
}

// SumBalancesByCurrency sums the CurrentBalanceCents of every active asset
// account (cash / investment / fixed-asset categories; liability/equity and
// expense/income category-accounts are excluded) for a tenant, grouped by the
// account's CurrencyCode. Implements networth/domain.AccountBalanceSource
// (structural — networth does not import account).
//
// Asset-only: liabilities (borrowed-in only) are tracked separately via the
// debt module's SumRemainingByCurrency; receivables (borrowed-out) are tracked
// as asset account balances via debt double-write; expense/income category
// accounts carry no balance.
// Best-effort per-currency: a zero-currency-code account (should not happen —
// NewAccount defaults to CNY) is bucketed under "".
func (s *Service) SumBalancesByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	assetType := domain.AccountTypeAsset
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.accountRepo.FindAll(ctx, tenantID, domain.AccountFilter{AccountType: &assetType}, page)
		if err != nil {
			return nil, fmt.Errorf("sum balances by currency: list asset accounts: %w", err)
		}
		for _, a := range result.Items {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			byCur[a.CurrencyCode] += a.CurrentBalanceCents
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	slog.Debug("account sum balances by currency",
		slog.String("tenant_id", tenantID.String()),
		slog.Int("currencies", len(byCur)),
		slog.String("operation", "SumBalancesByCurrency"))
	return byCur, nil
}

// GetAccountsBalance returns Σ CurrentBalanceCents of the given accounts
// (Savings goal progress source). Implements goal/domain.AccountBalanceSource
// (structural — goal does not import account).
//
// Best-effort: an account that is missing or fails to load is skipped + logged,
// not fatal — the remaining accounts still contribute (mirrors holding
// GetAccountMarketValue's skip-missing-security pattern). Tenant scoping is
// enforced by the repo's FindByID. Empty accountIDs returns 0.
func (s *Service) GetAccountsBalance(ctx context.Context, tenantID uuid.UUID, accountIDs []uuid.UUID) (int64, error) {
	var sum int64
	for _, id := range accountIDs {
		if err := ctx.Err(); err != nil {
			return sum, err
		}
		a, err := s.accountRepo.FindByID(ctx, tenantID, id)
		if err != nil || a == nil {
			slog.Warn("goal balance: account missing, skip",
				slog.String("account_id", id.String()),
				slog.String("operation", "GetAccountsBalance"))
			continue
		}
		sum += a.CurrentBalanceCents
	}
	return sum, nil
}

// Unimplemented command/query handler stubs (service handles orchestration directly).
// These satisfy the CQRS bus interface requirements.

var _ = command.CreateAccountCommand{}
var _ = command.UpdateAccountCommand{}
var _ = command.DeleteAccountCommand{}
var _ = query.GetAccountQuery{}
var _ = query.ListAccountsQuery{}
