package application

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/debt/domain"
)

// --- D-currency Task 5: SumRemainingByCurrency ---

// pagedDebtRepo is an in-memory DebtRepository whose FindAll honours PageSize
// by returning one page at a time with a NextPageToken until exhausted.
type pagedDebtRepo struct {
	mu   sync.Mutex
	byID map[uuid.UUID]*domain.DebtDetails
}

func newPagedDebtRepo() *pagedDebtRepo {
	return &pagedDebtRepo{byID: map[uuid.UUID]*domain.DebtDetails{}}
}

func (m *pagedDebtRepo) Save(_ context.Context, d *domain.DebtDetails) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *d
	m.byID[d.ID] = &c
	return nil
}
func (m *pagedDebtRepo) FindByID(_ context.Context, tenantID, id uuid.UUID) (*domain.DebtDetails, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	d, ok := m.byID[id]
	if !ok || d.TenantID != tenantID {
		return nil, fmt.Errorf("not found")
	}
	c := *d
	return &c, nil
}
func (m *pagedDebtRepo) FindAll(_ context.Context, tenantID uuid.UUID, page domain.PageRequest, typeFilter *domain.DebtType) (*domain.PaginatedResult[domain.DebtDetails], error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var filtered []domain.DebtDetails
	for _, d := range m.byID {
		if d.TenantID != tenantID {
			continue
		}
		if typeFilter != nil && d.DebtType != *typeFilter {
			continue
		}
		c := *d
		filtered = append(filtered, c)
	}

	// Fixed test page size of 2, regardless of the service's requested
	// PageSize (100): forces the service's pagination loop to iterate with a
	// small seed set.
	const ps = 2
	skip := 0
	if page.PageToken != "" {
		if n, err := atoiDebtToken(page.PageToken); err == nil {
			skip = n
		}
	}
	end := skip + ps
	if end > len(filtered) {
		end = len(filtered)
	}
	if skip > len(filtered) {
		skip = len(filtered)
	}
	items := filtered[skip:end]
	res := &domain.PaginatedResult[domain.DebtDetails]{
		Items:      items,
		TotalCount: int32(len(filtered)),
	}
	if end < len(filtered) {
		res.NextPageToken = fmt.Sprintf("%d", end)
	}
	return res, nil
}
func (m *pagedDebtRepo) ReplaceFutureSchedule(_ context.Context, _ uuid.UUID, _ []domain.PaymentScheduleEntry) error {
	return nil
}

func (m *pagedDebtRepo) Update(_ context.Context, d *domain.DebtDetails) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *d
	m.byID[d.ID] = &c
	return nil
}
func (m *pagedDebtRepo) Delete(_ context.Context, _ uuid.UUID, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.byID, id)
	return nil
}
func (m *pagedDebtRepo) FindUpcomingPayments(context.Context, uuid.UUID, int) ([]domain.PaymentScheduleEntry, error) {
	return nil, nil
}
func (m *pagedDebtRepo) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]domain.DebtDetails, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []domain.DebtDetails{}
	for _, d := range m.byID {
		if d.TenantID == tenantID {
			out = append(out, *d)
		}
	}
	return out, nil
}
func (m *pagedDebtRepo) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, d := range m.byID {
		if d.TenantID == tenantID {
			delete(m.byID, id)
		}
	}
	return nil
}

var _ domain.DebtRepository = (*pagedDebtRepo)(nil)

func atoiDebtToken(s string) (int, error) {
	if s == "" {
		return 0, fmt.Errorf("empty")
	}
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, fmt.Errorf("nan")
		}
		n = n*10 + int(c-'0')
	}
	return n, nil
}

// fakeAccountLookup is an in-memory AccountLookup for debt currency resolution.
type fakeAccountLookup struct {
	byID map[uuid.UUID]*accountdomain.Account
}

func (f *fakeAccountLookup) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*accountdomain.Account, error) {
	if a, ok := f.byID[id]; ok {
		return a, nil
	}
	return nil, fmt.Errorf("account not found")
}

// seedDebt builds a DebtDetails with a 2-entry schedule where entry[0] is paid,
// so RemainingPrincipal = totalPrincipal - entry[0].PrincipalCents.
func seedDebt(t *testing.T, tenantID, accountID uuid.UUID, total, principalPaid int64) *domain.DebtDetails {
	t.Helper()
	d, err := domain.NewDebtDetails(
		tenantID, accountID, "Lender", 0.05, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
		total, domain.BorrowedIn, "",
		"", "", nil,"", "",

	)
	if err != nil {
		t.Fatalf("seed debt: %v", err)
	}
	d.GenerateSchedule()
	if principalPaid > 0 {
		// Mark the first schedule entry paid so RemainingPrincipal reflects it.
		if len(d.Schedule) == 0 {
			t.Fatalf("seed debt: no schedule entries")
		}
		d.Schedule[0].Paid = true
		d.Schedule[0].PrincipalCents = principalPaid
		d.Schedule[0].PaidCents = d.Schedule[0].TotalCents
	}
	return d
}

// TestSumRemainingByCurrency_PerAccountCurrency verifies:
//   - Σ RemainingPrincipal grouped by each debt's parent-account currency;
//   - mixed CNY + USD debts land in separate buckets;
//   - tenant scoping;
//   - when accountLookup is nil, every debt falls back to CNY.
func TestSumRemainingByCurrency_PerAccountCurrency(t *testing.T) {
	tenant := uuid.New()
	cnyAcc, usdAcc := uuid.New(), uuid.New()

	repo := newPagedDebtRepo()
	// CNY debt: total 1000 - paid 200 = 800 remaining.
	_ = repo.Save(context.Background(), seedDebt(t, tenant, cnyAcc, 1000, 200))
	// USD debt: total 5000 - paid 0 = 5000 remaining.
	_ = repo.Save(context.Background(), seedDebt(t, tenant, usdAcc, 5000, 0))

	lookup := &fakeAccountLookup{byID: map[uuid.UUID]*accountdomain.Account{
		cnyAcc: {ID: cnyAcc, CurrencyCode: "CNY"},
		usdAcc: {ID: usdAcc, CurrencyCode: "USD"},
	}}

	svc := NewService(repo)
	svc.SetAccountLookup(lookup)

	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency error: %v", err)
	}
	if got["CNY"] != 800 {
		t.Errorf("CNY remaining = %d, want 800", got["CNY"])
	}
	if got["USD"] != 5000 {
		t.Errorf("USD remaining = %d, want 5000", got["USD"])
	}
}

// seedDebtAsType builds a DebtDetails with explicit DebtType (seedDebt hardcodes BorrowedIn).
func seedDebtAsType(t *testing.T, tenantID, accountID uuid.UUID, total, principalPaid int64, debtType domain.DebtType) *domain.DebtDetails {
	t.Helper()
	d, err := domain.NewDebtDetails(
		tenantID, accountID, "Lender", 0.05, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
		total, debtType, "",
		"", "", nil,"", "",

	)
	if err != nil {
		t.Fatalf("seed debt: %v", err)
	}
	d.GenerateSchedule()
	if principalPaid > 0 {
		if len(d.Schedule) == 0 {
			t.Fatalf("seed debt: no schedule entries")
		}
		d.Schedule[0].Paid = true
		d.Schedule[0].PrincipalCents = principalPaid
		d.Schedule[0].PaidCents = d.Schedule[0].TotalCents
	}
	return d
}

// TestSumRemainingByCurrency_ExcludesBorrowedOut verifies BorrowedOut receivables
// are excluded from networth liabilities (only BorrowedIn counts). Bug root cause:
// original FindAll typeFilter=nil counted both types.
func TestSumRemainingByCurrency_ExcludesBorrowedOut(t *testing.T) {
	tenant := uuid.New()
	acc := uuid.New()
	repo := newPagedDebtRepo()
	// BorrowedIn: total 5000, paid 0 = 5000 remaining.
	_ = repo.Save(context.Background(), seedDebtAsType(t, tenant, acc, 5000, 0, domain.BorrowedIn))
	// BorrowedOut: total 3000, paid 0 = 3000 remaining (EXCLUDED from liab).
	_ = repo.Save(context.Background(), seedDebtAsType(t, tenant, acc, 3000, 0, domain.BorrowedOut))
	lookup := &fakeAccountLookup{byID: map[uuid.UUID]*accountdomain.Account{
		acc: {ID: acc, CurrencyCode: "CNY"},
	}}
	svc := NewService(repo)
	svc.SetAccountLookup(lookup)

	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency: %v", err)
	}
	// only BorrowedIn 5000 (BorrowedOut 3000 excluded).
	if got["CNY"] != 5000 {
		t.Errorf("CNY remaining = %d, want 5000 (BorrowedIn only, BorrowedOut 3000 excluded)", got["CNY"])
	}
}

// TestSumRemainingByCurrency_DefaultCNYWhenNoLookup verifies that without an
// injected accountLookup, every debt is bucketed under CNY (app default).
func TestSumRemainingByCurrency_DefaultCNYWhenNoLookup(t *testing.T) {
	tenant := uuid.New()
	usdAcc := uuid.New()

	repo := newPagedDebtRepo()
	_ = repo.Save(context.Background(), seedDebt(t, tenant, usdAcc, 3000, 0))

	// No SetAccountLookup → falls back to CNY.
	svc := NewService(repo)
	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency error: %v", err)
	}
	if got["CNY"] != 3000 {
		t.Errorf("CNY (default fallback) = %d, want 3000", got["CNY"])
	}
	if _, hasUSD := got["USD"]; hasUSD {
		t.Errorf("USD bucket must not exist without lookup, got %v", got)
	}
}

// TestSumRemainingByCurrency_LookupFailureDefaultsCNY verifies that a failed
// account lookup (missing account) is logged + the debt still contributes under
// CNY rather than being dropped.
func TestSumRemainingByCurrency_LookupFailureDefaultsCNY(t *testing.T) {
	tenant := uuid.New()
	missingAcc := uuid.New() // not seeded in lookup

	repo := newPagedDebtRepo()
	_ = repo.Save(context.Background(), seedDebt(t, tenant, missingAcc, 7000, 0))

	lookup := &fakeAccountLookup{byID: map[uuid.UUID]*accountdomain.Account{}} // empty → FindByID fails

	svc := NewService(repo)
	svc.SetAccountLookup(lookup)

	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency error: %v", err)
	}
	if got["CNY"] != 7000 {
		t.Errorf("CNY (lookup-failure fallback) = %d, want 7000 (debt not dropped)", got["CNY"])
	}
}

// TestSumRemainingByCurrency_Pagination verifies the service loops across pages.
func TestSumRemainingByCurrency_Pagination(t *testing.T) {
	tenant := uuid.New()
	acc := uuid.New()

	repo := newPagedDebtRepo()
	// 3 debts × 1000 remaining; PageSize 2 → 2 pages.
	for i := 0; i < 3; i++ {
		_ = repo.Save(context.Background(), seedDebt(t, tenant, acc, 1000, 0))
	}

	lookup := &fakeAccountLookup{byID: map[uuid.UUID]*accountdomain.Account{
		acc: {ID: acc, CurrencyCode: "CNY"},
	}}

	svc := NewService(repo)
	svc.SetAccountLookup(lookup)

	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency error: %v", err)
	}
	if got["CNY"] != 3000 {
		t.Errorf("CNY remaining across pages = %d, want 3000", got["CNY"])
	}
}

// TestSumRemainingByCurrency_TenantScoping verifies another tenant's debts are
// excluded.
func TestSumRemainingByCurrency_TenantScoping(t *testing.T) {
	tenant := uuid.New()
	otherTenant := uuid.New()
	acc := uuid.New()

	repo := newPagedDebtRepo()
	_ = repo.Save(context.Background(), seedDebt(t, tenant, acc, 1000, 0))
	_ = repo.Save(context.Background(), seedDebt(t, otherTenant, acc, 999999, 0))

	lookup := &fakeAccountLookup{byID: map[uuid.UUID]*accountdomain.Account{
		acc: {ID: acc, CurrencyCode: "CNY"},
	}}

	svc := NewService(repo)
	svc.SetAccountLookup(lookup)

	got, err := svc.SumRemainingByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency error: %v", err)
	}
	if got["CNY"] != 1000 {
		t.Errorf("CNY remaining = %d, want 1000 (other-tenant debt excluded)", got["CNY"])
	}
}
