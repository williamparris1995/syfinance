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

func (mockChartRepo) Save(_ context.Context, _ *domain.ChartOfAccount) error             { return nil }
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
