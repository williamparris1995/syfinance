package application

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/goal/domain"
)

// --- D-goal Task 6: SyncAllGoals test doubles ---

// tenantID is a stable tenant used across SyncAllGoals tests.
var tenantID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// acct1 / acct2 / debt1 are stable investment/savings/debt IDs referenced by seeded goals.
var (
	acct1 = uuid.MustParse("00000000-0000-0000-0000-000000000010")
	acct2 = uuid.MustParse("00000000-0000-0000-0000-000000000020")
	debt1 = uuid.MustParse("00000000-0000-0000-0000-000000000030")
)

func ptrUUID(id uuid.UUID) *uuid.UUID { return &id }

// seedGoal describes a goal to seed into the fake repo for a SyncAllGoals test.
type seedGoal struct {
	Name          string // used as lookup key in helpers
	Type          domain.GoalType
	Target        int64
	LinkedAccount *uuid.UUID // single account convenience; converted to []uuid.UUID
	LinkedDebt    *uuid.UUID // single debt convenience; converted to []uuid.UUID
	// IsCompleted pre-marks the goal completed (for the skip-completed test).
	IsCompleted bool
}

// --- multi-account ports test doubles (Task 6) ---

// stubMV is a test double for domain.AccountMarketValueSource returning a fixed v.
type stubMV struct {
	v   int64
	err error
}

func (s stubMV) GetAccountsMarketValue(context.Context, uuid.UUID, []uuid.UUID) (int64, error) {
	if s.err != nil {
		return 0, s.err
	}
	return s.v, nil
}

// stubBal is a test double for domain.AccountBalanceSource returning a fixed v.
type stubBal struct {
	v   int64
	err error
}

func (s stubBal) GetAccountsBalance(context.Context, uuid.UUID, []uuid.UUID) (int64, error) {
	if s.err != nil {
		return 0, s.err
	}
	return s.v, nil
}

// stubDebt is a test double for domain.DebtProgressSource returning a fixed v.
type stubDebt struct {
	v   int64
	err error
}

func (s stubDebt) GetDebtsPaid(context.Context, uuid.UUID, []uuid.UUID) (int64, error) {
	if s.err != nil {
		return 0, s.err
	}
	return s.v, nil
}

// fakeGoalRepo is an in-memory GoalRepository for SyncAllGoals tests. FindAll /
// Update / WriteSnapshot drive the sync path; other methods panic since they
// are not exercised here. Goals are keyed by Name (stable test lookup).
// progressPoints (Phase 2) is the fixed slice returned by FindSnapshotRange
// for the GetGoalProgressHistory test.
type fakeGoalRepo struct {
	byName         map[string]*domain.Goal
	order          []string               // stable iteration order
	snapshots      []*domain.Goal         // goals passed to WriteSnapshot (in call order)
	progressPoints []domain.ProgressPoint // returned by FindSnapshotRange (Phase 2)
}

func newFakeGoalRepo(seeds []seedGoal) *fakeGoalRepo {
	r := &fakeGoalRepo{byName: map[string]*domain.Goal{}}
	for _, s := range seeds {
		var accs, debts []uuid.UUID
		if s.LinkedAccount != nil {
			accs = []uuid.UUID{*s.LinkedAccount}
		}
		if s.LinkedDebt != nil {
			debts = []uuid.UUID{*s.LinkedDebt}
		}
		g, err := domain.NewGoal(tenantID, s.Name, s.Type, s.Target, "CNY", nil, accs, debts, "")
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

// snapshotCount returns how many WriteSnapshot calls were made for the named goal.
func (r *fakeGoalRepo) snapshotCount() int { return len(r.snapshots) }

func (fakeGoalRepo) Save(context.Context, *domain.Goal) error {
	panic("not used in SyncAllGoals test")
}
func (fakeGoalRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*domain.Goal, error) {
	panic("not used in SyncAllGoals test")
}
func (fakeGoalRepo) Delete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("not used in SyncAllGoals test")
}

// FindAll returns seeded goals as a single page, optionally filtered by
// tenantID and goalType. completed is ignored here since the sync always passes
// nil for it.
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
	for name, stored := range r.byName {
		if stored.ID == g.ID {
			cp := *g
			r.byName[name] = &cp
			return nil
		}
	}
	return errors.New("goal not found")
}

// WriteSnapshot records the goal for snapshot assertion (upsert is the repo's
// concern in prod; here we just track calls).
func (r *fakeGoalRepo) WriteSnapshot(_ context.Context, g *domain.Goal) error {
	r.snapshots = append(r.snapshots, g)
	return nil
}

// FindSnapshotRange returns the seeded progressPoints slice (Phase 2
// GetGoalProgressHistory test). Range/tenant/goal filtering is not exercised
// here — the test seeds exactly the points it expects back.
func (r *fakeGoalRepo) FindSnapshotRange(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ time.Time, _ time.Time) ([]domain.ProgressPoint, error) {
	return r.progressPoints, nil
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

// TestSyncAllGoalsThreeTypeBranches verifies SyncAllGoals fans out across all
// three goal types: Investment→mv(50000), Savings→balance(30000),
// DebtPayoff→paid(20000). Each goal's current_amount is updated + a snapshot is
// written. Returns synced count = 3.
func TestSyncAllGoalsThreeTypeBranches(t *testing.T) {
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "inv", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
		{Name: "sav", Type: domain.GoalTypeSavings, LinkedAccount: ptrUUID(acct2), Target: 100000},
		{Name: "debt", Type: domain.GoalTypeDebtPayoff, LinkedDebt: ptrUUID(debt1), Target: 100000},
	})
	svc.SetAccountMarketValueSource(stubMV{v: 50000}) // Investment → 50000
	svc.SetAccountBalanceSource(stubBal{v: 30000})    // Savings → 30000
	svc.SetDebtProgressSource(stubDebt{v: 20000})     // DebtPayoff → 20000

	n, err := svc.SyncAllGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals unexpected error: %v", err)
	}
	if n != 3 {
		t.Fatalf("synced = %d, want 3 (inv+sav+debt)", n)
	}
	if got := repo.currentFor("inv"); got != 50000 {
		t.Fatalf("investment current = %d, want 50000", got)
	}
	if got := repo.currentFor("sav"); got != 30000 {
		t.Fatalf("savings current = %d, want 30000", got)
	}
	if got := repo.currentFor("debt"); got != 20000 {
		t.Fatalf("debtpayoff current = %d, want 20000", got)
	}
	// snapshot written once per synced goal (3).
	if got := repo.snapshotCount(); got != 3 {
		t.Fatalf("snapshot writes = %d, want 3", got)
	}
}

// TestSyncAllGoalsCompletesAtTarget verifies Investment goal auto-completes when
// mv reaches target.
func TestSyncAllGoalsCompletesAtTarget(t *testing.T) {
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "inv", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
	})
	svc.SetAccountMarketValueSource(stubMV{v: 100000})
	n, err := svc.SyncAllGoals(context.Background(), tenantID)
	if err != nil || n != 1 {
		t.Fatalf("sync: n=%d err=%v", n, err)
	}
	if !repo.isCompleted("inv") {
		t.Fatal("investment should auto-complete at target 100000")
	}
}

// TestSyncAllGoalsSkipsCompleted verifies already-completed goals are skipped
// (mv may fluctuate; we don't un-complete). Their current must NOT be re-set.
func TestSyncAllGoalsSkipsCompleted(t *testing.T) {
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "done", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000, IsCompleted: true},
		{Name: "open", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct2), Target: 200000},
	})
	svc.SetAccountMarketValueSource(stubMV{v: 99999})
	n, err := svc.SyncAllGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if n != 1 {
		t.Fatalf("synced = %d, want 1 (completed skipped)", n)
	}
	if got := repo.currentFor("done"); got != 0 {
		t.Fatalf("completed goal must be skipped, current got %d", got)
	}
	if !repo.isCompleted("done") {
		t.Fatal("done must remain completed")
	}
}

// TestSyncAllGoalsContinuesPastPortError verifies a per-goal port error is
// logged and skipped, not fatal — remaining goals still sync.
func TestSyncAllGoalsContinuesPastPortError(t *testing.T) {
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "inv", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
		{Name: "sav", Type: domain.GoalTypeSavings, LinkedAccount: ptrUUID(acct2), Target: 200000},
	})
	// Investment port errors; savings port ok. inv skipped, sav synced.
	svc.SetAccountMarketValueSource(stubMV{err: errors.New("holding service 500")})
	svc.SetAccountBalanceSource(stubBal{v: 200000})
	n, err := svc.SyncAllGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("per-goal port error must not abort batch: %v", err)
	}
	if n != 1 {
		t.Fatalf("synced = %d, want 1 (inv errored, sav ok)", n)
	}
	if got := repo.currentFor("inv"); got != 0 {
		t.Fatalf("inv should stay 0 after error, got %d", got)
	}
	if got := repo.currentFor("sav"); got != 200000 {
		t.Fatalf("sav should be updated to 200000, got %d", got)
	}
}

// TestSyncAllGoalsNilPortSkipsType verifies a goal whose port is not configured
// (nil) is skipped without error — wire always injects in prod but tests may not.
func TestSyncAllGoalsNilPortSkipsType(t *testing.T) {
	_, svc := newTestServiceWithGoals(t, []seedGoal{
		{Name: "inv", Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
	})
	// No SetAccountMarketValueSource → mvSrc nil → inv skipped, synced=0.
	n, err := svc.SyncAllGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("nil port must not error: %v", err)
	}
	if n != 0 {
		t.Fatalf("synced = %d, want 0 (mv port nil → all skipped)", n)
	}
}

// --- D-goal Task 8: CloneGoal + multi-account CreateGoal ---

// cloneRepo is an in-memory GoalRepository focused on the CloneGoal path
// (FindByID + Save) and the multi-account CreateGoal path (Save). Other methods
// are no-ops; FindAll/Update/WriteSnapshot are intentionally unused here.
type cloneRepo struct {
	byID  map[uuid.UUID]*domain.Goal
	saved []*domain.Goal // goals passed to Save, in call order
}

func newCloneRepo(seed *domain.Goal) *cloneRepo {
	r := &cloneRepo{byID: map[uuid.UUID]*domain.Goal{}}
	if seed != nil {
		cp := *seed
		r.byID[seed.ID] = &cp
	}
	return r
}

func (r *cloneRepo) Save(_ context.Context, g *domain.Goal) error {
	r.saved = append(r.saved, g)
	cp := *g
	r.byID[g.ID] = &cp
	return nil
}
func (r *cloneRepo) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*domain.Goal, error) {
	g, ok := r.byID[id]
	if !ok {
		return nil, errors.New("goal not found")
	}
	cp := *g
	return &cp, nil
}
func (r *cloneRepo) FindAll(context.Context, uuid.UUID, *bool, *domain.GoalType, domain.PageRequest) (*domain.PaginatedResult[domain.Goal], error) {
	panic("not used in CloneGoal/CreateGoal test")
}
func (r *cloneRepo) Update(context.Context, *domain.Goal) error         { panic("not used") }
func (r *cloneRepo) Delete(context.Context, uuid.UUID, uuid.UUID) error { return nil }
func (r *cloneRepo) WriteSnapshot(context.Context, *domain.Goal) error  { return nil }
func (r *cloneRepo) FindSnapshotRange(context.Context, uuid.UUID, uuid.UUID, time.Time, time.Time) ([]domain.ProgressPoint, error) {
	return nil, nil
}

// TestCloneGoal verifies CloneGoal deep-copies the source into a new entity with
// reset progress, an overridden target, and the linked account/debt IDs carried
// over. The clone gets a fresh ID (≠ source) and Save is called exactly once.
func TestCloneGoal(t *testing.T) {
	src, err := domain.NewGoal(tenantID, "orig", domain.GoalTypeInvestment, 100000, "CNY", nil,
		[]uuid.UUID{acct1, acct2}, nil, "notes")
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	repo := newCloneRepo(src)
	svc := NewService(repo)

	dto, err := svc.CloneGoal(context.Background(), tenantID, src.ID, 200000, nil, "cloned")
	if err != nil {
		t.Fatalf("CloneGoal error: %v", err)
	}
	if len(repo.saved) != 1 {
		t.Fatalf("Save calls = %d, want 1", len(repo.saved))
	}
	if dto.ID == src.ID {
		t.Fatal("clone must have a fresh ID, got source ID")
	}
	if dto.TargetAmountCents != 200000 {
		t.Errorf("clone target = %d, want 200000", dto.TargetAmountCents)
	}
	if dto.Name != "cloned" {
		t.Errorf("clone name = %q, want \"cloned\"", dto.Name)
	}
	if dto.CurrentAmountCents != 0 {
		t.Errorf("clone current = %d, want 0 (reset)", dto.CurrentAmountCents)
	}
	if len(dto.LinkedAccountIDs) != 2 || dto.LinkedAccountIDs[0] != acct1 || dto.LinkedAccountIDs[1] != acct2 {
		t.Errorf("clone linked accounts = %v, want [acct1, acct2]", dto.LinkedAccountIDs)
	}
}

// TestCloneGoalSourceNotFound verifies a missing source surfaces a not-found error.
func TestCloneGoalSourceNotFound(t *testing.T) {
	repo := newCloneRepo(nil)
	svc := NewService(repo)
	_, err := svc.CloneGoal(context.Background(), tenantID, uuid.New(), 0, nil, "")
	if err == nil {
		t.Fatal("expected error for missing source, got nil")
	}
}

// TestCreateGoalMultiAccount verifies CreateGoal persists a goal carrying every
// linked account + debt ID supplied (multi-account signature, Task 3/8).
func TestCreateGoalMultiAccount(t *testing.T) {
	repo := newCloneRepo(nil)
	svc := NewService(repo)
	deadline := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)

	dto, err := svc.CreateGoal(context.Background(), CreateGoalRequest{
		TenantID:          tenantID,
		Name:              "retire",
		GoalType:          domain.GoalTypeDebtPayoff,
		TargetAmountCents: 500000,
		CurrencyCode:      "CNY",
		Deadline:          &deadline,
		LinkedAccountIDs:  []uuid.UUID{acct1},
		LinkedDebtIDs:     []uuid.UUID{debt1},
		Notes:             "multi",
	})
	if err != nil {
		t.Fatalf("CreateGoal error: %v", err)
	}
	if len(dto.LinkedAccountIDs) != 1 || dto.LinkedAccountIDs[0] != acct1 {
		t.Errorf("dto linked accounts = %v, want [acct1]", dto.LinkedAccountIDs)
	}
	if len(dto.LinkedDebtIDs) != 1 || dto.LinkedDebtIDs[0] != debt1 {
		t.Errorf("dto linked debts = %v, want [debt1]", dto.LinkedDebtIDs)
	}
	if len(repo.saved) != 1 {
		t.Fatalf("Save calls = %d, want 1", len(repo.saved))
	}
	saved := repo.saved[0]
	if len(saved.LinkedDebtIDs) != 1 || saved.LinkedDebtIDs[0] != debt1 {
		t.Errorf("saved linked debts = %v, want [debt1]", saved.LinkedDebtIDs)
	}
}

// --- Phase 2 Task 1: GetGoalProgressHistory ---

// TestGetGoalProgressHistory verifies the service reads back the progress-point
// range from the repo (FindSnapshotRange) and maps it 1:1 to DTOs. The repo
// double here is the inline closure-style stub returning a fixed slice; the
// shared fakeGoalRepo is exercised by the SyncAllGoals tests above and its
// FindSnapshotRange stub is covered there.
func TestGetGoalProgressHistory(t *testing.T) {
	repo := &fakeGoalRepo{
		progressPoints: []domain.ProgressPoint{
			{Date: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), CurrentAmountCents: 100000},
			{Date: time.Date(2026, 7, 2, 0, 0, 0, 0, time.UTC), CurrentAmountCents: 200000},
		},
	}
	svc := NewService(repo)
	from := time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)
	pts, err := svc.GetGoalProgressHistory(context.Background(), uuid.New(), uuid.New(), from, to)
	if err != nil || len(pts) != 2 || pts[0].CurrentAmountCents != 100000 {
		t.Fatalf("history: pts=%v err=%v", pts, err)
	}
}
