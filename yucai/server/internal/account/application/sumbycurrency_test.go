package application

import (
	"context"
	"fmt"
	"sort"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// sortAccounts gives a deterministic order by ID so paging is reproducible.
func sortAccounts(a []domain.Account) {
	sort.Slice(a, func(i, j int) bool { return a[i].ID.String() < a[j].ID.String() })
}

// atoiToken parses the integer-encoded page token. Returns an error on "" or
// non-digit content.
func atoiToken(s string) (int, error) {
	if s == "" {
		return 0, fmt.Errorf("empty token")
	}
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, fmt.Errorf("nan token")
		}
		n = n*10 + int(c-'0')
	}
	return n, nil
}

// --- D-currency Task 5: SumBalancesByCurrency ---

// filterAccountRepo is an in-memory AccountRepository whose FindAll honours the
// AccountFilter's AccountType (so the asset-only path can be verified) and
// paginates by PageSize. The PageToken is an integer offset (string-encoded).
type filterAccountRepo struct {
	byID  map[uuid.UUID]*domain.Account
	calls int
}

func newFilterAccountRepo() *filterAccountRepo {
	return &filterAccountRepo{byID: map[uuid.UUID]*domain.Account{}}
}

func (m *filterAccountRepo) Save(_ context.Context, a *domain.Account) error {
	c := *a
	m.byID[a.ID] = &c
	return nil
}
func (m *filterAccountRepo) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*domain.Account, error) {
	if a, ok := m.byID[id]; ok {
		c := *a
		return &c, nil
	}
	return nil, nil
}
func (m *filterAccountRepo) FindAll(_ context.Context, tenantID uuid.UUID, filter domain.AccountFilter, page domain.PageRequest) (*domain.PaginatedResult[domain.Account], error) {
	m.calls++
	var filtered []domain.Account
	for _, a := range m.byID {
		if a.TenantID != tenantID {
			continue
		}
		if filter.AccountType != nil && a.AccountType != *filter.AccountType {
			continue
		}
		c := *a
		filtered = append(filtered, c)
	}
	// Stable order so paging is deterministic.
	sortAccounts(filtered)

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = len(filtered)
	}
	skip := 0
	if n, err := atoiToken(page.PageToken); err == nil {
		skip = n
	}
	end := skip + ps
	if end > len(filtered) {
		end = len(filtered)
	}
	if skip > len(filtered) {
		skip = len(filtered)
	}
	items := filtered[skip:end]
	res := &domain.PaginatedResult[domain.Account]{
		Items:      items,
		TotalCount: int32(len(filtered)),
	}
	if end < len(filtered) {
		res.NextPageToken = fmt.Sprintf("%d", end)
	}
	return res, nil
}
func (m *filterAccountRepo) FindByAccountType(_ context.Context, tenantID uuid.UUID, accountType domain.AccountType) ([]domain.Account, error) {
	var out []domain.Account
	for _, a := range m.byID {
		if a.TenantID == tenantID && a.AccountType == accountType {
			c := *a
			out = append(out, c)
		}
	}
	return out, nil
}
func (m *filterAccountRepo) Update(_ context.Context, a *domain.Account) error {
	c := *a
	m.byID[a.ID] = &c
	return nil
}
func (m *filterAccountRepo) SoftDelete(_ context.Context, _, id uuid.UUID) error {
	delete(m.byID, id)
	return nil
}

var _ domain.AccountRepository = (*filterAccountRepo)(nil)

// TestSumBalancesByCurrency_AssetOnlyPerCurrency verifies:
//   - only asset-type accounts contribute (liability/equity/expense/income
//     excluded);
//   - balances are summed per CurrencyCode (CNY + USD mixed);
//   - tenant scoping (other tenant's accounts excluded).
func TestSumBalancesByCurrency_AssetOnlyPerCurrency(t *testing.T) {
	tenant := uuid.New()
	repo := newFilterAccountRepo()

	// Seed asset accounts in two currencies.
	// CNY assets: 1000 + 2500 = 3500.
	seed := func(t *testing.T, tenantID uuid.UUID, name string, at domain.AccountType, code string, bal int64) *domain.Account {
		t.Helper()
		a, err := domain.NewAccount(tenantID, name, at, code)
		if err != nil {
			t.Fatalf("new account: %v", err)
		}
		a.CurrentBalanceCents = bal
		_ = repo.Save(context.Background(), a)
		return a
	}
	seed(t, tenant, "CNY savings", domain.AccountTypeAsset, "CNY", 1000)
	seed(t, tenant, "CNY invest", domain.AccountTypeAsset, "CNY", 2500)
	seed(t, tenant, "USD broker", domain.AccountTypeAsset, "USD", 800)
	// Non-asset accounts must be excluded.
	seed(t, tenant, "liability", domain.AccountTypeLiability, "CNY", 999999)
	seed(t, tenant, "expense cat", domain.AccountTypeExpense, "CNY", 999999)
	// Other tenant's asset must be excluded.
	seed(t, uuid.New(), "other tenant asset", domain.AccountTypeAsset, "CNY", 999999)

	svc := NewService(repo, newMockChartRepo())
	got, err := svc.SumBalancesByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumBalancesByCurrency error: %v", err)
	}
	if got["CNY"] != 3500 {
		t.Errorf("CNY sum = %d, want 3500 (liability/expense/other-tenant excluded)", got["CNY"])
	}
	if got["USD"] != 800 {
		t.Errorf("USD sum = %d, want 800", got["USD"])
	}
}

// TestSumBalancesByCurrency_Pagination verifies the service loops across pages
// when the repo returns a NextPageToken. The service uses PageSize=100, so we
// seed 101 accounts to force a second page.
func TestSumBalancesByCurrency_Pagination(t *testing.T) {
	tenant := uuid.New()
	repo := newFilterAccountRepo()

	// 101 asset accounts × 100 cents = 10100 CNY; PageSize 100 → 2 pages.
	seed := func(i int) {
		a, _ := domain.NewAccount(tenant, fmt.Sprintf("acc-%d", i), domain.AccountTypeAsset, "CNY")
		a.CurrentBalanceCents = 100
		_ = repo.Save(context.Background(), a)
	}
	for i := 0; i < 101; i++ {
		seed(i)
	}

	svc := NewService(repo, newMockChartRepo())
	got, err := svc.SumBalancesByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumBalancesByCurrency error: %v", err)
	}
	if got["CNY"] != 10100 {
		t.Errorf("CNY sum across pages = %d, want 10100", got["CNY"])
	}
	if repo.calls < 2 {
		t.Errorf("expected at least 2 FindAll calls (pagination loop), got %d", repo.calls)
	}
}

// TestSumBalancesByCurrency_EmptyTenant returns an empty (non-nil) map.
func TestSumBalancesByCurrency_EmptyTenant(t *testing.T) {
	repo := newFilterAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	got, err := svc.SumBalancesByCurrency(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("SumBalancesByCurrency error: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil map for empty tenant")
	}
	if len(got) != 0 {
		t.Errorf("expected empty map, got %v", got)
	}
}
