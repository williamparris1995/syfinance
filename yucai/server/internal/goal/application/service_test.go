package application

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// --- D-goal Task 3: SyncInvestmentGoals test doubles ---

// tenantID is a stable tenant used across SyncInvestmentGoals tests.
var tenantID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// acct1 / acct2 are stable investment accounts referenced by seeded goals.
var (
	acct1 = uuid.MustParse("00000000-0000-0000-0000-000000000010")
	acct2 = uuid.MustParse("00000000-0000-0000-0000-000000000020")
)

func ptrUUID(id uuid.UUID) *uuid.UUID { return &id }

// seedGoal describes a goal to seed into the fake repo for a SyncInvestmentGoals
// test. Name is the human key used by currentFor/isCompleted helpers.
type seedGoal struct {
	Name          string // used as lookup key in helpers
	Type          domain.GoalType
	Target        int64
	LinkedAccount *uuid.UUID // single account convenience; converted to []uuid.UUID
	// IsCompleted pre-marks the goal completed (for the skip-completed test).
	IsCompleted bool
}

// fakeAccountMarketValueSource is a test double for domain.AccountMarketValueSource.
type fakeAccountMarketValueSource struct {
	// mv maps accountID → market value cents to return.
	mv map[uuid.UUID]int64
	// errOn maps accountID → error (simulate holding service failure).
	errOn map[uuid.UUID]error
}

func (f *fakeAccountMarketValueSource) GetAccountMarketValue(_ context.Context, _, accountID uuid.UUID) (int64, error) {
	if f.errOn != nil {
		if e, ok := f.errOn[accountID]; ok {
			return 0, e
		}
	}
	return f.mv[accountID], nil
}

// fakeGoalRepo is an in-memory GoalRepository for SyncInvestmentGoals tests.
// FindAll / Update drive the sync path; other methods panic since they are not
// exercised here. Goals are keyed by Name (stable test lookup).
type fakeGoalRepo struct {
	byName map[string]*domain.Goal
	order  []string // stable iteration order
}

func newFakeGoalRepo(seeds []seedGoal) *fakeGoalRepo {
	r := &fakeGoalRepo{byName: map[string]*domain.Goal{}}
	for _, s := range seeds {
		var accs []uuid.UUID
		if s.LinkedAccount != nil {
			accs = []uuid.UUID{*s.LinkedAccount}
		}
		g, err := domain.NewGoal(tenantID, s.Name, s.Type, s.Target, "CNY", nil, accs, nil, "")
		if err != nil {
			panic(err)
		}
		if s.IsCompleted {
			g.MarkCompleted()
		}
		r.byName[s.Name] = g
		r.order = append(r.order, s.Name)
	}
	return r
}

// currentFor returns the current_amount_cents of the goal seeded under name.
func (r *fakeGoalRepo) currentFor(name string) int64 {
	return r.byName[name].CurrentAmountCents
}

// isCompleted reports whether the goal seeded under name is completed.
func (r *fakeGoalRepo) isCompleted(name string) bool {
	return r.byName[name].IsCompleted
}

func (fakeGoalRepo) Save(context.Context, *domain.Goal) error {
	panic("not used in SyncInvestmentGoals test")
}
func (fakeGoalRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*domain.Goal, error) {
	panic("not used in SyncInvestmentGoals test")
}
func (fakeGoalRepo) Delete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("not used in SyncInvestmentGoals test")
}

// FindAll returns seeded goals as a single page, optionally filtered by
// tenantID and goalType (mirrors Task 1 FindAll semantics). completed is ignored
// here since the sync always passes nil for it.
func (r *fakeGoalRepo) FindAll(_ context.Context, tid uuid.UUID, _ *bool, goalType *domain.GoalType, _ domain.PageRequest) (*domain.PaginatedResult[domain.Goal], error) {
	items := make([]domain.Goal, 0, len(r.order))
	for _, name := range r.order {
		g := r.byName[name]
		if tid != uuid.Nil && g.TenantID != tid {
			continue
		}
		if goalType != nil && g.GoalType != *goalType {
			continue
		}
		items = append(items, *g)
	}
	return &domain.PaginatedResult[domain.Goal]{
		Items:         items,
		NextPageToken: "",
		TotalCount:    int32(len(items)),
	}, nil
}

// Update persists the goal back into the fake map (mutates the stored copy).
func (r *fakeGoalRepo) Update(_ context.Context, g *domain.Goal) error {
	// Locate the stored entry by ID and replace it so later currentFor/isCompleted
	// reads reflect SetCurrentAmount/MarkCompleted.
	for name, stored := range r.byName {
		if stored.ID == g.ID {
			cp := *g
			r.byName[name] = &cp
			return nil
		}
	}
	return errors.New("goal not found")
}

// newTestServiceWithGoals builds a Service backed by a fake goal repo seeded
// with the given goals. Returns the repo (for assertions) and the service.
func newTestServiceWithGoals(t *testing.T, seeds []seedGoal) (*fakeGoalRepo, *Service) {
	t.Helper()
	repo := newFakeGoalRepo(seeds)
	svc := NewService(repo)
	return repo, svc
}

// --- tests ---

func TestSyncInvestmentGoalsUpdatesMvAndCompletes(t *testing.T) {
	// seed goals: g1 investment linked_account=acct1 target=100000,
	//             g2 investment linked_account=acct2 target=200000,
	//             g3 savings (not investment, must be skipped).
	// fakeAccountMarketValueSource.mv: acct1=60000, acct2=200000.
	// SyncInvestmentGoals → g1.current=60000 (not completed), g2.current=200000 (auto-completed),
	//                      g3 untouched (savings). returns synced=2.
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "g1", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
		{Name: "g2", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct2), Target: 200000},
		{Name: "g3", Type: domain.GoalTypeSavings, LinkedAccount: ptrUUID(acct1), Target: 50000},
	})
	svc.SetAccountMarketValueSource(&fakeAccountMarketValueSource{
		mv: map[uuid.UUID]int64{acct1: 60000, acct2: 200000},
	})
	count, err := svc.SyncInvestmentGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 2 {
		t.Fatalf("synced = %d, want 2 (g1+g2 investment, g3 savings skipped)", count)
	}
	if got := repo.currentFor("g1"); got != 60000 {
		t.Fatalf("g1 current = %d, want 60000", got)
	}
	if !repo.isCompleted("g2") {
		t.Fatal("g2 should auto-complete at target 200000")
	}
	if got := repo.currentFor("g3"); got != 0 {
		t.Fatalf("g3 (savings) must be untouched, got current %d", got)
	}
}

func TestSyncInvestmentGoalsContinuesPastHoldingError(t *testing.T) {
	// acct1 holding service fails, acct2 ok. g1 skipped (logged), g2 synced. count=1.
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "g1", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
		{Name: "g2", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct2), Target: 200000},
	})
	svc.SetAccountMarketValueSource(&fakeAccountMarketValueSource{
		mv:    map[uuid.UUID]int64{acct1: 60000, acct2: 200000},
		errOn: map[uuid.UUID]error{acct1: errors.New("holding service 500")},
	})
	count, err := svc.SyncInvestmentGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("SyncInvestmentGoals must not abort on per-goal mv error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced = %d, want 1 (g2 ok, g1 errored)", count)
	}
	// g1 errored → untouched at 0; g2 updated to 200000 and auto-completed.
	if got := repo.currentFor("g1"); got != 0 {
		t.Fatalf("g1 should stay 0 after error, got %d", got)
	}
	if got := repo.currentFor("g2"); got != 200000 {
		t.Fatalf("g2 should be updated to 200000, got %d", got)
	}
}

func TestSyncInvestmentGoalsSkipsCompleted(t *testing.T) {
	// g1 already completed (pre-seeded) → skipped, current untouched (not re-set to mv).
	// g2 open investment → synced. count=1.
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "g1", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000, IsCompleted: true},
		{Name: "g2", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct2), Target: 200000},
	})
	svc.SetAccountMarketValueSource(&fakeAccountMarketValueSource{
		mv: map[uuid.UUID]int64{acct1: 99999, acct2: 200000},
	})
	count, err := svc.SyncInvestmentGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced = %d, want 1 (completed g1 skipped, g2 synced)", count)
	}
	// g1 was completed before sync → must NOT be re-touched (current stays 0, not 99999).
	if got := repo.currentFor("g1"); got != 0 {
		t.Fatalf("completed g1 must be skipped, current got %d", got)
	}
	if !repo.isCompleted("g1") {
		t.Fatal("g1 must remain completed")
	}
	if got := repo.currentFor("g2"); got != 200000 {
		t.Fatalf("g2 current = %d, want 200000", got)
	}
}

func TestSyncInvestmentGoalsWithoutSourceErrors(t *testing.T) {
	// Defensive: SetAccountMarketValueSource never called → SyncInvestmentGoals
	// errors clearly instead of nil-dereferencing. Wire always injects.
	_, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "g1", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
	})
	if _, err := svc.SyncInvestmentGoals(context.Background(), tenantID); err == nil {
		t.Fatal("SyncInvestmentGoals without mv source must error")
	}
}
