package application

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
)

// --- In-memory mock repo (stateful) ---

type mockDebtRepo struct {
	mu           sync.Mutex
	byID         map[uuid.UUID]*domain.DebtDetails
	lastFilter   *domain.DebtType // records the typeFilter passed to the most recent FindAll
	findAllErr   error
	findAllCalls int
}

func newMockDebtRepo() *mockDebtRepo {
	return &mockDebtRepo{byID: make(map[uuid.UUID]*domain.DebtDetails)}
}

func (m *mockDebtRepo) Save(_ context.Context, d *domain.DebtDetails) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *d
	m.byID[d.ID] = &c
	return nil
}

func (m *mockDebtRepo) FindByID(_ context.Context, tenantID, id uuid.UUID) (*domain.DebtDetails, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	d, ok := m.byID[id]
	if !ok || d.TenantID != tenantID {
		return nil, fmt.Errorf("debt %s not found", id)
	}
	c := *d
	return &c, nil
}

func (m *mockDebtRepo) FindAll(_ context.Context, tenantID uuid.UUID, _ domain.PageRequest, typeFilter *domain.DebtType) (*domain.PaginatedResult[domain.DebtDetails], error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.lastFilter = typeFilter
	m.findAllCalls++

	if m.findAllErr != nil {
		return nil, m.findAllErr
	}

	out := &domain.PaginatedResult[domain.DebtDetails]{}
	for _, d := range m.byID {
		if d.TenantID != tenantID {
			continue
		}
		if typeFilter != nil && d.DebtType != *typeFilter {
			continue
		}
		c := *d
		out.Items = append(out.Items, c)
	}
	out.TotalCount = int32(len(out.Items))
	return out, nil
}

func (m *mockDebtRepo) Update(_ context.Context, d *domain.DebtDetails) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *d
	m.byID[d.ID] = &c
	return nil
}

func (m *mockDebtRepo) Delete(_ context.Context, _ uuid.UUID, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.byID, id)
	return nil
}

func (m *mockDebtRepo) FindUpcomingPayments(_ context.Context, _ uuid.UUID, _ int) ([]domain.PaymentScheduleEntry, error) {
	return nil, nil
}

var _ domain.DebtRepository = (*mockDebtRepo)(nil)

// --- Tests ---

func TestCreateDebt_PersistsDebtType(t *testing.T) {
	repo := newMockDebtRepo()
	svc := NewService(repo)

	for _, tc := range []struct {
		name string
		typ  domain.DebtType
	}{
		{"borrowed_in", domain.BorrowedIn},
		{"borrowed_out", domain.BorrowedOut},
		{"unspecified_normalizes_to_borrowed_in", domain.DebtTypeUnspecified},
	} {
		t.Run(tc.name, func(t *testing.T) {
			req := CreateDebtRequest{
				TenantID:            uuid.New(),
				AccountID:           uuid.New(),
				Counterparty:        "Lender " + tc.name,
				InterestRate:        0.05,
				AmortizationMethod:  domain.AmortizationLumpSum,
				StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
				DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
				TotalPrincipalCents: 1000000,
				DebtType:            tc.typ,
			}
			// Receivables (BorrowedOut) require a collection account per the
			// CreateDebt validation rule added in Task 5.
			if tc.typ == domain.BorrowedOut {
				coll := uuid.New()
				req.CollectionAccountID = &coll
			}
			resp, err := svc.CreateDebt(context.Background(), req)
			if err != nil {
				t.Fatalf("CreateDebt failed: %v", err)
			}

			expected := tc.typ
			if expected == domain.DebtTypeUnspecified {
				expected = domain.BorrowedIn
			}
			if resp.DebtType != expected {
				t.Errorf("DTO DebtType = %v, want %v", resp.DebtType, expected)
			}

			saved, ok := repo.byID[resp.ID]
			if !ok {
				t.Fatalf("debt not persisted")
			}
			if saved.DebtType != expected {
				t.Errorf("persisted DebtType = %v, want %v", saved.DebtType, expected)
			}
		})
	}
}

func TestCreateDebt_PersistsSubtype(t *testing.T) {
	// subtype is a plain string; service passes it through verbatim, no mapping.
	repo := newMockDebtRepo()
	svc := NewService(repo)

	for _, tc := range []struct {
		name    string
		subtype string
	}{
		{"empty_default", ""},
		{"mortgage_const", domain.DebtSubtypeMortgage},
		{"credit_card_const", domain.DebtSubtypeCreditCard},
		{"receivable_personal", domain.ReceivableSubtypePersonal},
		{"unknown_custom", "custom_value"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
				TenantID:            uuid.New(),
				AccountID:           uuid.New(),
				Counterparty:        "Lender",
				InterestRate:        0.05,
				AmortizationMethod:  domain.AmortizationLumpSum,
				StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
				DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
				TotalPrincipalCents: 1000000,
				DebtType:            domain.BorrowedIn,
				Subtype:             tc.subtype,
			})
			if err != nil {
				t.Fatalf("CreateDebt failed: %v", err)
			}
			// DTO carries subtype verbatim.
			if resp.Subtype != tc.subtype {
				t.Errorf("DTO Subtype = %q, want %q", resp.Subtype, tc.subtype)
			}
			// Persisted aggregate carries subtype verbatim.
			saved, ok := repo.byID[resp.ID]
			if !ok {
				t.Fatalf("debt not persisted")
			}
			if saved.Subtype != tc.subtype {
				t.Errorf("persisted Subtype = %q, want %q", saved.Subtype, tc.subtype)
			}
		})
	}
}

func TestListDebts_ReturnsSubtype(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	svc := NewService(repo)

	// Seed a debt with a known subtype via CreateDebt so it flows through the
	// full service -> domain -> repo path.
	coll := uuid.New()
	created, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
		TenantID:            tenant,
		AccountID:           uuid.New(),
		Counterparty:        "Bank",
		InterestRate:        0.03,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 500000,
		DebtType:            domain.BorrowedOut,
		Subtype:             domain.ReceivableSubtypeBusiness,
		CollectionAccountID: &coll,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	res, err := svc.ListDebts(context.Background(), ListDebtsRequest{TenantID: tenant})
	if err != nil {
		t.Fatalf("ListDebts failed: %v", err)
	}
	if len(res.Debts) != 1 {
		t.Fatalf("expected 1 debt, got %d", len(res.Debts))
	}
	got := res.Debts[0]
	if got.ID != created.ID {
		t.Errorf("returned ID %v != created %v", got.ID, created.ID)
	}
	if got.Subtype != domain.ReceivableSubtypeBusiness {
		t.Errorf("returned Subtype = %q, want %q", got.Subtype, domain.ReceivableSubtypeBusiness)
	}
}

func TestListDebts_TypeFilter_PassedThroughAndApplied(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	// Seed: two borrowed_in, one borrowed_out.
	seed := func(dt domain.DebtType) {
		d, _ := domain.NewDebtDetails(
			tenant, uuid.New(), "C", 0.0, domain.AmortizationLumpSum,
			time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
			100000, dt, "",
			"", "", nil,
		)
		repo.byID[d.ID] = d
	}
	seed(domain.BorrowedIn)
	seed(domain.BorrowedIn)
	seed(domain.BorrowedOut)

	svc := NewService(repo)

	// Filter for BorrowedOut only.
	out := domain.BorrowedOut
	res, err := svc.ListDebts(context.Background(), ListDebtsRequest{
		TenantID:   tenant,
		TypeFilter: &out,
	})
	if err != nil {
		t.Fatalf("ListDebts failed: %v", err)
	}
	if len(res.Debts) != 1 {
		t.Errorf("expected 1 borrowed_out debt, got %d", len(res.Debts))
	}
	if repo.lastFilter == nil || *repo.lastFilter != domain.BorrowedOut {
		t.Errorf("filter not passed to repo: got %v", repo.lastFilter)
	}

	// No filter -> all 3 returned.
	resAll, err := svc.ListDebts(context.Background(), ListDebtsRequest{
		TenantID: tenant,
	})
	if err != nil {
		t.Fatalf("ListDebts (no filter) failed: %v", err)
	}
	if len(resAll.Debts) != 3 {
		t.Errorf("expected 3 debts with no filter, got %d", len(resAll.Debts))
	}
	if repo.lastFilter != nil {
		t.Errorf("expected nil filter passed to repo, got %v", repo.lastFilter)
	}
}

// --- mockDebtSnapshotRepo for Task 5 tests ---

type mockDebtSnapshotRepo struct {
	mu       sync.Mutex
	saved    []*domain.DebtProgressSnapshot
	saveErr  error
	rangeOut map[uuid.UUID][]domain.DebtProgressSnapshot // debtID -> snapshots returned by FindSnapshotRange
}

func newMockDebtSnapshotRepo() *mockDebtSnapshotRepo {
	return &mockDebtSnapshotRepo{rangeOut: map[uuid.UUID][]domain.DebtProgressSnapshot{}}
}

func (m *mockDebtSnapshotRepo) SaveSnapshot(_ context.Context, snap *domain.DebtProgressSnapshot) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.saveErr != nil {
		return m.saveErr
	}
	c := *snap
	m.saved = append(m.saved, &c)
	return nil
}

func (m *mockDebtSnapshotRepo) FindLatestByDebt(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ time.Time) (*domain.DebtProgressSnapshot, error) {
	return nil, nil
}

func (m *mockDebtSnapshotRepo) FindSnapshotRange(_ context.Context, _ uuid.UUID, debtIDs []uuid.UUID, _, _ time.Time) ([]domain.DebtProgressSnapshot, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []domain.DebtProgressSnapshot
	for _, id := range debtIDs {
		out = append(out, m.rangeOut[id]...)
	}
	return out, nil
}

var _ domain.DebtSnapshotRepository = (*mockDebtSnapshotRepo)(nil)

// helper: build a BorrowedOut debt with a hand-crafted schedule.
func seedReceivable(t *testing.T, tenant uuid.UUID, repo *mockDebtRepo, principal int64, counterparty string, schedule []domain.PaymentScheduleEntry, contact, contractRef string, collectionAcc *uuid.UUID) *domain.DebtDetails {
	t.Helper()
	d, err := domain.NewDebtDetails(
		tenant, uuid.New(), counterparty,
		0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		principal, domain.BorrowedOut, "",
		contact, contractRef, collectionAcc,
	)
	if err != nil {
		t.Fatalf("seed receivable: %v", err)
	}
	d.Schedule = schedule
	for i := range d.Schedule {
		d.Schedule[i].DebtID = d.ID
	}
	repo.byID[d.ID] = d
	return d
}

func mkEntry(date time.Time, principal, interest int64, paid bool) domain.PaymentScheduleEntry {
	return domain.PaymentScheduleEntry{
		ID:             uuid.New(),
		PaymentDate:    date,
		PrincipalCents: principal,
		InterestCents:  interest,
		TotalCents:     principal + interest,
		Paid:           paid,
	}
}

// --- DebtToDTO next_payment ---

func TestDebtToDTOFillsNextPayment(t *testing.T) {
	tenant := uuid.New()
	coll := uuid.New()
	d := &domain.DebtDetails{
		ID:                  uuid.New(),
		TenantID:            tenant,
		AccountID:           uuid.New(),
		Counterparty:        "Alice",
		TotalPrincipalCents: 1_000_00,
		DebtType:            domain.BorrowedOut,
		Contact:             "Bob",
		ContractRef:         "C-001",
		CollectionAccountID: &coll,
		Schedule: []domain.PaymentScheduleEntry{
			mkEntry(time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC), 100_00, 5_00, true),  // paid
			mkEntry(time.Date(2026, 2, 28, 0, 0, 0, 0, time.UTC), 100_00, 4_00, false), // earliest !paid
			mkEntry(time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC), 100_00, 3_00, false),
		},
		Version: 1,
	}

	dto := DebtToDTO(d)

	if dto.NextPaymentDate != "2026-02-28" {
		t.Errorf("NextPaymentDate = %q, want 2026-02-28", dto.NextPaymentDate)
	}
	if dto.NextPaymentAmountCents != 104_00 {
		t.Errorf("NextPaymentAmountCents = %d, want 10400", dto.NextPaymentAmountCents)
	}
	if dto.NextPaymentPeriodNo != 2 {
		t.Errorf("NextPaymentPeriodNo = %d, want 2 (1-based index of earliest unpaid)", dto.NextPaymentPeriodNo)
	}
	if dto.Contact != "Bob" {
		t.Errorf("Contact = %q, want Bob", dto.Contact)
	}
	if dto.ContractRef != "C-001" {
		t.Errorf("ContractRef = %q, want C-001", dto.ContractRef)
	}
	if dto.CollectionAccountID == nil || *dto.CollectionAccountID != coll {
		t.Errorf("CollectionAccountID = %v, want %v", dto.CollectionAccountID, coll)
	}
}

func TestDebtToDTO_AllPaidNoNextPayment(t *testing.T) {
	d := &domain.DebtDetails{
		ID:                  uuid.New(),
		TotalPrincipalCents: 300_00,
		DebtType:            domain.BorrowedOut,
		Schedule: []domain.PaymentScheduleEntry{
			mkEntry(time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC), 100_00, 0, true),
			mkEntry(time.Date(2026, 2, 28, 0, 0, 0, 0, time.UTC), 100_00, 0, true),
			mkEntry(time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC), 100_00, 0, true),
		},
	}
	dto := DebtToDTO(d)
	if dto.NextPaymentDate != "" {
		t.Errorf("NextPaymentDate = %q, want empty when all paid", dto.NextPaymentDate)
	}
	if dto.NextPaymentAmountCents != 0 {
		t.Errorf("NextPaymentAmountCents = %d, want 0 when all paid", dto.NextPaymentAmountCents)
	}
	if dto.NextPaymentPeriodNo != 0 {
		t.Errorf("NextPaymentPeriodNo = %d, want 0 when all paid", dto.NextPaymentPeriodNo)
	}
}

// --- GetReceivablesSummary ---

func TestGetReceivablesSummary(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	snapRepo := newMockDebtSnapshotRepo()

	// Two receivables (borrowed_out) + one borrowed_in (must be excluded).
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)

	// Debt A: principal 1_000_00, schedule entry 1 (Jan) paid principal=200_00,
	// entry 2 (Feb, !paid, overdue since now). RemainingPrincipal = 800_00.
	debtA := &domain.DebtDetails{
		ID:                  uuid.New(),
		TenantID:            tenant,
		AccountID:           uuid.New(),
		Counterparty:        "Alice",
		TotalPrincipalCents: 1_000_00,
		DebtType:            domain.BorrowedOut,
		Contact:             "AliceContact",
		Schedule: []domain.PaymentScheduleEntry{
			mkEntry(time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC), 200_00, 50_00, true),
			mkEntry(time.Date(2026, 2, 28, 0, 0, 0, 0, time.UTC), 200_00, 40_00, false), // overdue (Feb < now)
			mkEntry(time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), 200_00, 30_00, false),
		},
		Version: 1,
	}
	// Debt B: principal 500_00, all unpaid. RemainingPrincipal = 500_00.
	// next unpaid entry in Jul (after debtA's Feb), so global next_payment = debtA Feb.
	debtB := &domain.DebtDetails{
		ID:                  uuid.New(),
		TenantID:            tenant,
		AccountID:           uuid.New(),
		Counterparty:        "Bob",
		TotalPrincipalCents: 500_00,
		DebtType:            domain.BorrowedOut,
		Schedule: []domain.PaymentScheduleEntry{
			mkEntry(time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), 250_00, 10_00, false),
			mkEntry(time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC), 250_00, 5_00, false),
		},
		Version: 1,
	}
	// Debt C: borrowed_in — excluded from receivables summary.
	debtC := &domain.DebtDetails{
		ID:                  uuid.New(),
		TenantID:            tenant,
		AccountID:           uuid.New(),
		Counterparty:        "Bank",
		TotalPrincipalCents: 9_000_00,
		DebtType:            domain.BorrowedIn,
		Version:             1,
	}
	repo.byID[debtA.ID] = debtA
	repo.byID[debtB.ID] = debtB
	repo.byID[debtC.ID] = debtC

	// Snapshots: this month snapshot per debt + last month snapshot per debt.
	monthStart := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	lastMonthStart := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	snapRepo.rangeOut[debtA.ID] = []domain.DebtProgressSnapshot{
		{DebtID: debtA.ID, SnapshotDate: lastMonthStart, TotalPrincipalCents: 1_000_00, RemainingCents: 1_000_00},
		{DebtID: debtA.ID, SnapshotDate: monthStart, TotalPrincipalCents: 1_000_00, RemainingCents: 800_00},
	}
	snapRepo.rangeOut[debtB.ID] = []domain.DebtProgressSnapshot{
		{DebtID: debtB.ID, SnapshotDate: lastMonthStart, TotalPrincipalCents: 500_00, RemainingCents: 500_00},
		// No snapshot this month for B -> only last month counts for remaining_trend.
	}

	svc := NewService(repo)
	svc.SetSnapshotRepo(snapRepo)
	svc.SetNow(func() time.Time { return now })

	summary, err := svc.GetReceivablesSummary(context.Background(), tenant)
	if err != nil {
		t.Fatalf("GetReceivablesSummary failed: %v", err)
	}

	// Aggregates.
	if summary.Count != 2 {
		t.Errorf("Count = %d, want 2 (borrowed_out only)", summary.Count)
	}
	if summary.TotalPrincipalCents != 1_500_00 {
		t.Errorf("TotalPrincipalCents = %d, want 150000", summary.TotalPrincipalCents)
	}
	if summary.TotalRemainingCents != 1_300_00 {
		t.Errorf("TotalRemainingCents = %d, want 1300000 (A:800000+B:500000)", summary.TotalRemainingCents)
	}
	if summary.TotalCollectedCents != 200_00 {
		t.Errorf("TotalCollectedCents = %d, want 20000 (only debtA principal collected)", summary.TotalCollectedCents)
	}
	if summary.PendingInterestCents != 85_00 {
		t.Errorf("PendingInterestCents = %d, want 85000 (A:40+30+ B:10+5 = 85_00)", summary.PendingInterestCents)
	}
	if summary.OverdueCount != 1 {
		t.Errorf("OverdueCount = %d, want 1 (debtA Feb entry)", summary.OverdueCount)
	}
	if summary.OverdueAmountCents != 240_00 {
		t.Errorf("OverdueAmountCents = %d, want 240000 (debtA Feb total 200+40)", summary.OverdueAmountCents)
	}

	// Trend: this month vs last month for receivables.
	// principal_trend = Σ (this_month_principal - last_month_principal) = (1000-1000)+(500-500) = 0
	// remaining_trend = Σ (this_month_remaining - last_month_remaining) = (800-1000)+(no this-month-snapshot for B → skip)
	//                  = -200_00 (debtA reduced = collected)
	if summary.PrincipalTrendCents != 0 {
		t.Errorf("PrincipalTrendCents = %d, want 0", summary.PrincipalTrendCents)
	}
	if summary.RemainingTrendCents != -200_00 {
		t.Errorf("RemainingTrendCents = %d, want -200000", summary.RemainingTrendCents)
	}

	// Global next_payment = earliest unpaid entry across all receivables = debtA Feb 28.
	if summary.NextPaymentDate != "2026-02-28" {
		t.Errorf("NextPaymentDate = %q, want 2026-02-28", summary.NextPaymentDate)
	}
	if summary.NextPaymentCounterparty != "Alice" {
		t.Errorf("NextPaymentCounterparty = %q, want Alice", summary.NextPaymentCounterparty)
	}
	if summary.NextPaymentAmountCents != 240_00 {
		t.Errorf("NextPaymentAmountCents = %d, want 240000", summary.NextPaymentAmountCents)
	}
	if summary.NextPaymentPeriodNo != 2 {
		t.Errorf("NextPaymentPeriodNo = %d, want 2", summary.NextPaymentPeriodNo)
	}

	// Filter was BorrowedOut.
	if repo.lastFilter == nil || *repo.lastFilter != domain.BorrowedOut {
		t.Errorf("repo filter = %v, want BorrowedOut", repo.lastFilter)
	}
}

// --- SyncAllDebts ---

func TestSyncAllDebts(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	snapRepo := newMockDebtSnapshotRepo()

	fixedNow := time.Date(2026, 6, 15, 12, 30, 0, 0, time.UTC)

	// Debt A: borrowed_in, total 1_000_00, hand-built schedule with one paid
	// entry (principal 100_00). RemainingPrincipal = 1_000_00 - 100_00 = 900_00.
	dA, _ := domain.NewDebtDetails(
		tenant, uuid.New(), "A", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		1_000_00, domain.BorrowedIn, "", "", "", nil,
	)
	dA.Schedule = []domain.PaymentScheduleEntry{
		mkEntry(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC), 100_00, 0, true),
		mkEntry(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC), 100_00, 0, false),
		mkEntry(time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), 800_00, 0, false),
	}
	for i := range dA.Schedule {
		dA.Schedule[i].DebtID = dA.ID
	}
	repo.byID[dA.ID] = dA

	// Debt B: borrowed_out, fully unpaid, total 500_00.
	dB, _ := domain.NewDebtDetails(
		tenant, uuid.New(), "B", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		500_00, domain.BorrowedOut, "", "", "", nil,
	)
	dB.GenerateSchedule()
	repo.byID[dB.ID] = dB

	svc := NewService(repo)
	svc.SetSnapshotRepo(snapRepo)
	svc.SetNow(func() time.Time { return fixedNow })

	count, err := svc.SyncAllDebts(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SyncAllDebts failed: %v", err)
	}
	if count != 2 {
		t.Errorf("count = %d, want 2", count)
	}
	if len(snapRepo.saved) != 2 {
		t.Fatalf("snapshots saved = %d, want 2", len(snapRepo.saved))
	}

	// Snapshot for dA: remaining = total - paid principal (100_00).
	snapA := findSnap(t, snapRepo.saved, dA.ID)
	if snapA.RemainingCents != 900_00 {
		t.Errorf("snapA RemainingCents = %d, want 900000", snapA.RemainingCents)
	}
	if snapA.PaidTotalCents != 100_00 {
		t.Errorf("snapA PaidTotalCents = %d, want 100000", snapA.PaidTotalCents)
	}
	if snapA.TotalPrincipalCents != 1_000_00 {
		t.Errorf("snapA TotalPrincipalCents = %d, want 1000000", snapA.TotalPrincipalCents)
	}
	// Truncated to date (no time component).
	wantDate := time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC)
	if !snapA.SnapshotDate.Equal(wantDate) {
		t.Errorf("snapA SnapshotDate = %v, want %v (truncated)", snapA.SnapshotDate, wantDate)
	}

	snapB := findSnap(t, snapRepo.saved, dB.ID)
	if snapB.RemainingCents != 500_00 {
		t.Errorf("snapB RemainingCents = %d, want 500000 (unpaid)", snapB.RemainingCents)
	}
	if snapB.PaidTotalCents != 0 {
		t.Errorf("snapB PaidTotalCents = %d, want 0", snapB.PaidTotalCents)
	}
}

func TestSyncAllDebts_BestEffortSkipOnSaveError(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	snapRepo := newMockDebtSnapshotRepo()
	snapRepo.saveErr = fmt.Errorf("db down")

	dA, _ := domain.NewDebtDetails(
		tenant, uuid.New(), "A", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		1_000_00, domain.BorrowedIn, "", "", "", nil,
	)
	dA.GenerateSchedule()
	repo.byID[dA.ID] = dA

	dB, _ := domain.NewDebtDetails(
		tenant, uuid.New(), "B", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		500_00, domain.BorrowedOut, "", "", "", nil,
	)
	dB.GenerateSchedule()
	repo.byID[dB.ID] = dB

	svc := NewService(repo)
	svc.SetSnapshotRepo(snapRepo)
	svc.SetNow(func() time.Time { return time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC) })

	count, err := svc.SyncAllDebts(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SyncAllDebts should not return error on per-debt save failure, got %v", err)
	}
	if count != 0 {
		t.Errorf("count = %d, want 0 (all saves failed, all skipped)", count)
	}
}

func TestSyncAllDebts_NilSnapshotRepoIsNoop(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	dA, _ := domain.NewDebtDetails(
		tenant, uuid.New(), "A", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		1_000_00, domain.BorrowedIn, "", "", "", nil,
	)
	dA.GenerateSchedule()
	repo.byID[dA.ID] = dA

	svc := NewService(repo) // snapshot repo NOT injected
	svc.SetNow(func() time.Time { return time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC) })

	count, err := svc.SyncAllDebts(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SyncAllDebts nil snapshot repo: %v", err)
	}
	if count != 0 {
		t.Errorf("count = %d, want 0 (noop without snapshot repo)", count)
	}
}

func findSnap(t *testing.T, snaps []*domain.DebtProgressSnapshot, debtID uuid.UUID) *domain.DebtProgressSnapshot {
	t.Helper()
	for _, s := range snaps {
		if s.DebtID == debtID {
			return s
		}
	}
	t.Fatalf("snapshot for debt %s not found", debtID)
	return nil
}

// --- CreateDebt receivable validation ---

func TestCreateDebt_ReceivableRequiresCollectionAccount(t *testing.T) {
	repo := newMockDebtRepo()
	svc := NewService(repo)

	// BorrowedOut + nil CollectionAccountID must error.
	_, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "Alice",
		InterestRate:        0.0,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 1_000_00,
		DebtType:            domain.BorrowedOut,
		CollectionAccountID: nil,
	})
	if err == nil {
		t.Fatal("expected error for receivable without collection account, got nil")
	}
}

func TestCreateDebt_ReceivableWithCollectionAccountOK(t *testing.T) {
	repo := newMockDebtRepo()
	svc := NewService(repo)
	coll := uuid.New()

	resp, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "Alice",
		InterestRate:        0.0,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 1_000_00,
		DebtType:            domain.BorrowedOut,
		Contact:             "Bob",
		ContractRef:         "C-1",
		CollectionAccountID: &coll,
	})
	if err != nil {
		t.Fatalf("CreateDebt receivable with collection account failed: %v", err)
	}
	if resp.Contact != "Bob" {
		t.Errorf("DTO Contact = %q, want Bob", resp.Contact)
	}
	if resp.ContractRef != "C-1" {
		t.Errorf("DTO ContractRef = %q, want C-1", resp.ContractRef)
	}
	if resp.CollectionAccountID == nil || *resp.CollectionAccountID != coll {
		t.Errorf("DTO CollectionAccountID = %v, want %v", resp.CollectionAccountID, coll)
	}
}

func TestCreateDebt_BorrowedInWithoutCollectionAccountOK(t *testing.T) {
	repo := newMockDebtRepo()
	svc := NewService(repo)
	// BorrowedIn + nil CollectionAccountID must succeed (no receivable rule).
	_, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "Bank",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 1_000_00,
		DebtType:            domain.BorrowedIn,
		CollectionAccountID: nil,
	})
	if err != nil {
		t.Fatalf("BorrowedIn without collection account should succeed, got %v", err)
	}
}
