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
			resp, err := svc.CreateDebt(context.Background(), CreateDebtRequest{
				TenantID:            uuid.New(),
				AccountID:           uuid.New(),
				Counterparty:        "Lender " + tc.name,
				InterestRate:        0.05,
				AmortizationMethod:  domain.AmortizationLumpSum,
				StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
				DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
				TotalPrincipalCents: 1000000,
				DebtType:            tc.typ,
			})
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

func TestListDebts_TypeFilter_PassedThroughAndApplied(t *testing.T) {
	tenant := uuid.New()
	repo := newMockDebtRepo()
	// Seed: two borrowed_in, one borrowed_out.
	seed := func(dt domain.DebtType) {
		d, _ := domain.NewDebtDetails(
			tenant, uuid.New(), "C", 0.0, domain.AmortizationLumpSum,
			time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
			100000, dt,
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
