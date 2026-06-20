package application

import (
	"context"
	"fmt"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// --- In-memory mocks (stateful) ---

// mockAccountRepo 存状态：Save 存 map，FindByID/Update/SoftDelete 操作 map。
type mockAccountRepo struct {
	mu       sync.Mutex
	byID     map[uuid.UUID]*domain.Account
	saveErr  error
	updateFn func(*domain.Account) error
}

func newMockAccountRepo() *mockAccountRepo {
	return &mockAccountRepo{byID: make(map[uuid.UUID]*domain.Account)}
}

func (m *mockAccountRepo) Save(_ context.Context, account *domain.Account) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.saveErr != nil {
		return m.saveErr
	}
	// 存一份拷贝，避免外部继续改同一指针
	c := *account
	m.byID[account.ID] = &c
	return nil
}

func (m *mockAccountRepo) FindByID(_ context.Context, tenantID, id uuid.UUID) (*domain.Account, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	a, ok := m.byID[id]
	if !ok || a.TenantID != tenantID {
		return nil, fmt.Errorf("account %s not found", id)
	}
	c := *a
	return &c, nil
}

func (m *mockAccountRepo) FindAll(_ context.Context, tenantID uuid.UUID, _ domain.AccountFilter, _ domain.PageRequest) (*domain.PaginatedResult[domain.Account], error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := &domain.PaginatedResult[domain.Account]{}
	for _, a := range m.byID {
		if a.TenantID == tenantID {
			c := *a
			out.Items = append(out.Items, c)
		}
	}
	out.TotalCount = int32(len(out.Items))
	return out, nil
}

func (m *mockAccountRepo) FindByAccountType(_ context.Context, tenantID uuid.UUID, accountType domain.AccountType) ([]domain.Account, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []domain.Account
	for _, a := range m.byID {
		if a.TenantID == tenantID && a.AccountType == accountType {
			c := *a
			out = append(out, c)
		}
	}
	return out, nil
}

func (m *mockAccountRepo) Update(_ context.Context, account *domain.Account) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.updateFn != nil {
		return m.updateFn(account)
	}
	c := *account
	m.byID[account.ID] = &c
	return nil
}

func (m *mockAccountRepo) SoftDelete(_ context.Context, tenantID, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	a, ok := m.byID[id]
	if !ok || a.TenantID != tenantID {
		return fmt.Errorf("account %s not found", id)
	}
	a.SoftDelete()
	return nil
}

type mockChartRepo struct{}

func newMockChartRepo() *mockChartRepo { return &mockChartRepo{} }

func (mockChartRepo) Save(_ context.Context, _ *domain.ChartOfAccount) error { return nil }
func (mockChartRepo) FindByCode(_ context.Context, _ uuid.UUID, _ string) (*domain.ChartOfAccount, error) {
	return nil, fmt.Errorf("not found")
}
func (mockChartRepo) FindAll(_ context.Context, _ uuid.UUID) ([]domain.ChartOfAccount, error) {
	return nil, nil
}

// --- Tests ---

func TestCreateAccountPersistsTypeSpecificFields(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	rate := 1.9
	tail := "2840"
	req := CreateAccountRequest{
		TenantID: uuid.New(), Name: "招行储蓄", Category: domain.AccountCategorySavings, CurrencyCode: "CNY",
		CardNumberTail: &tail, InterestRate: &rate,
	}
	dto, err := svc.CreateAccount(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if dto.CardNumberTail != "2840" || dto.InterestRate == nil || *dto.InterestRate != 1.9 {
		t.Errorf("type-specific fields not persisted: %+v", dto)
	}
}

// Regression: creating an expense/income account must persist the requested
// AccountType, NOT derive asset/other_asset from the (ignored) Category field.
// Previously CreateAccount always called NewAccountWithCategory, which mapped
// otherAsset→asset and silently miscategorized category-manager creations.
func TestCreateAccount_HonoursExpenseIncomeType(t *testing.T) {
	for _, at := range []domain.AccountType{domain.AccountTypeExpense, domain.AccountTypeIncome} {
		repo := newMockAccountRepo()
		svc := NewService(repo, newMockChartRepo())
		req := CreateAccountRequest{
			TenantID:    uuid.New(),
			Name:        "阿斯顿",
			AccountType: at,
			// Client still sends otherAsset (placeholder); server must ignore it
			// for expense/income and use AccountType.
			Category:    domain.AccountCategoryOtherAsset,
			CurrencyCode: "CNY",
			Icon:        "📦",
			Color:       "#3B82F6",
		}
		dto, err := svc.CreateAccount(context.Background(), req)
		if err != nil {
			t.Fatalf("type %s: %v", at, err)
		}
		if dto.AccountType != at {
			t.Errorf("type %s: expected AccountType %s, got %s (miscategorized as asset?)",
				at, at, dto.AccountType)
		}
	}
}

// Asset-path still derives type from category (unchanged behaviour).
func TestCreateAccount_DerivesAssetTypeFromCategory(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	req := CreateAccountRequest{
		TenantID: uuid.New(), Name: "招行储蓄",
		Category: domain.AccountCategorySavings, CurrencyCode: "CNY",
	}
	dto, err := svc.CreateAccount(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if dto.AccountType != domain.AccountTypeAsset {
		t.Errorf("savings category should derive asset type, got %s", dto.AccountType)
	}
	if dto.Category != domain.AccountCategorySavings {
		t.Errorf("category not persisted: %s", dto.Category)
	}
}

func TestCreateCategory_CreatesExpenseCategoryAccount(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	dto, err := svc.CreateCategory(context.Background(), CreateCategoryRequest{
		TenantID:    tenantID,
		Name:        "餐饮",
		Icon:        "utensils",
		Color:       "#FF6B6B",
		AccountType: domain.AccountTypeExpense,
	})
	if err != nil {
		t.Fatalf("create category: %v", err)
	}
	if dto.AccountType != domain.AccountTypeExpense {
		t.Errorf("expected expense type, got %v", dto.AccountType)
	}
	if dto.IsSystem {
		t.Errorf("user-created category must not be system")
	}
	if dto.Name != "餐饮" || dto.Icon != "utensils" || dto.Color != "#FF6B6B" {
		t.Errorf("category fields not persisted: %+v", dto)
	}
}

func TestCreateCategory_RejectsNonCategoryType(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	_, err := svc.CreateCategory(context.Background(), CreateCategoryRequest{
		TenantID:    uuid.New(),
		Name:        "x",
		AccountType: domain.AccountTypeAsset,
	})
	if err == nil {
		t.Fatal("expected error creating category with asset type")
	}
}

func TestDeleteCategory_RejectsSystemCategory(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	// Seed a system category directly into the repo.
	sys := mustNewAccount(t, tenantID, "餐饮", domain.AccountTypeExpense)
	sys.IsSystem = true
	_ = repo.Save(context.Background(), sys)

	err := svc.DeleteCategory(context.Background(), tenantID, sys.ID)
	if err == nil {
		t.Fatal("expected error deleting system category")
	}
}

func TestDeleteCategory_DeletesUserCategory(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	dto, err := svc.CreateCategory(context.Background(), CreateCategoryRequest{
		TenantID: tenantID, Name: "咖啡", AccountType: domain.AccountTypeExpense,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.DeleteCategory(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("delete user category: %v", err)
	}
}

func TestUpdateCategory_UpdatesNameIconColor(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	created, err := svc.CreateCategory(context.Background(), CreateCategoryRequest{
		TenantID: tenantID, Name: "old", AccountType: domain.AccountTypeIncome,
	})
	if err != nil {
		t.Fatal(err)
	}
	updated, err := svc.UpdateCategory(context.Background(), UpdateCategoryRequest{
		TenantID: tenantID, CategoryID: created.ID, Version: created.Version,
		Name: ptr("new"), Icon: ptr("star"), Color: ptr("#abc"),
	})
	if err != nil {
		t.Fatalf("update category: %v", err)
	}
	if updated.Name != "new" || updated.Icon != "star" || updated.Color != "#abc" {
		t.Errorf("update not applied: %+v", updated)
	}
}

func TestReorderCategories_UpdatesSortOrder(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	a, _ := svc.CreateCategory(context.Background(), CreateCategoryRequest{TenantID: tenantID, Name: "a", AccountType: domain.AccountTypeExpense})
	b, _ := svc.CreateCategory(context.Background(), CreateCategoryRequest{TenantID: tenantID, Name: "b", AccountType: domain.AccountTypeExpense})
	c, _ := svc.CreateCategory(context.Background(), CreateCategoryRequest{TenantID: tenantID, Name: "c", AccountType: domain.AccountTypeExpense})

	// Reverse order: c, b, a
	if err := svc.ReorderCategories(context.Background(), ReorderCategoriesRequest{
		TenantID: tenantID, AccountType: domain.AccountTypeExpense,
		OrderedIDs: []uuid.UUID{c.ID, b.ID, a.ID},
	}); err != nil {
		t.Fatalf("reorder: %v", err)
	}
	got, _ := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	byID := map[uuid.UUID]int{}
	for _, acc := range got {
		byID[acc.ID] = acc.SortOrder
	}
	if byID[c.ID] != 1 || byID[b.ID] != 2 || byID[a.ID] != 3 {
		t.Errorf("sort_order not applied (1,2,3 for c,b,a): %+v", byID)
	}
}

func TestSeedPresetCategories_Creates10SystemCategories(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	if err := svc.SeedPresetCategories(context.Background(), tenantID); err != nil {
		t.Fatalf("seed: %v", err)
	}
	expense, _ := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	income, _ := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeIncome)
	if len(expense) != 6 {
		t.Errorf("expected 6 expense presets, got %d", len(expense))
	}
	if len(income) != 4 {
		t.Errorf("expected 4 income presets, got %d", len(income))
	}
	for _, a := range append(append([]domain.Account{}, expense...), income...) {
		if !a.IsSystem {
			t.Errorf("preset category %s must be is_system=true", a.Name)
		}
	}
}

func TestSeedPresetCategories_Idempotent(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	tenantID := uuid.New()

	_ = svc.SeedPresetCategories(context.Background(), tenantID)
	// Second seed should be a no-op (or at least not double-create).
	_ = svc.SeedPresetCategories(context.Background(), tenantID)
	expense, _ := repo.FindByAccountType(context.Background(), tenantID, domain.AccountTypeExpense)
	if len(expense) != 6 {
		t.Errorf("seed not idempotent: expected 6 expense, got %d", len(expense))
	}
}

func mustNewAccount(t *testing.T, tenantID uuid.UUID, name string, at domain.AccountType) *domain.Account {
	t.Helper()
	a, err := domain.NewAccount(tenantID, name, at, "CNY")
	if err != nil {
		t.Fatalf("new account: %v", err)
	}
	return a
}

func ptr(s string) *string { return &s }

func TestUpdateAccountClosesAccount(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	created, _ := svc.CreateAccount(context.Background(), CreateAccountRequest{
		TenantID: uuid.New(), Name: "x", Category: domain.AccountCategorySavings, CurrencyCode: "CNY",
	})
	archived := domain.AccountStatusArchived
	_, err := svc.UpdateAccount(context.Background(), UpdateAccountRequest{
		TenantID: created.TenantID, AccountID: created.ID, Version: created.Version, Status: &archived,
	})
	if err != nil {
		t.Fatal(err)
	}
	got, _ := svc.GetAccount(context.Background(), created.TenantID, created.ID)
	if got.Status != domain.AccountStatusArchived {
		t.Errorf("close via status=archived failed, got %v", got.Status)
	}
}
