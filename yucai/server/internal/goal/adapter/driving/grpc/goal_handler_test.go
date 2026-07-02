package grpc

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/goal/application"
	"github.com/yucai/server/internal/goal/domain"
	pb "github.com/yucai/server/internal/proto/goal/v1"
	"google.golang.org/grpc/status"
)

// ---------------------------------------------------------------------------
// D-goal Task 7: GoalHandler.SyncInvestmentGoals + ListGoals type filter
//
// The handler is a thin adapter over application.Service. These tests drive the
// full handler with a real Service backed by an in-memory fake repo + fake
// market-value source, asserting:
//   - SyncInvestmentGoals returns the synced count and a non-nil SyncedAt.
//   - ListGoals forwards the proto GoalType filter to the service (UNSPECIFIED
//     → nil/all, INVESTMENT → domain.GoalTypeInvestment by NAME).
// ---------------------------------------------------------------------------

// fakeRepo implements domain.GoalRepository with in-memory slices. FindAll
// records the goalType filter it received so the ListGoals test can assert it.
type fakeRepo struct {
	goals    []*domain.Goal           // working set (mutated by Update)
	listedGT *domain.GoalType         // last GoalType arg passed to FindAll
	updated  []*domain.Goal           // goals persisted by Update
	saved    []*domain.Goal           // goals persisted by Save (CreateGoal/CloneGoal)
}

func (r *fakeRepo) Save(_ context.Context, g *domain.Goal) error {
	r.saved = append(r.saved, g)
	r.goals = append(r.goals, g)
	return nil
}

func (r *fakeRepo) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*domain.Goal, error) {
	// return a deep copy so callers can mutate without touching the stored slice
	for _, g := range r.goals {
		if g.ID == id {
			cp := *g
			return &cp, nil
		}
	}
	return nil, errors.New("goal not found")
}

// FindAll honors the goalType filter (nil = all) and records the arg.
func (r *fakeRepo) FindAll(_ context.Context, _ uuid.UUID, _ *bool, gt *domain.GoalType, _ domain.PageRequest) (*domain.PaginatedResult[domain.Goal], error) {
	r.listedGT = gt
	var items []domain.Goal
	for _, g := range r.goals {
		if gt != nil && g.GoalType != *gt {
			continue
		}
		items = append(items, *g)
	}
	return &domain.PaginatedResult[domain.Goal]{Items: items, TotalCount: int32(len(items))}, nil
}

func (r *fakeRepo) Update(_ context.Context, g *domain.Goal) error {
	r.updated = append(r.updated, g)
	for i, existing := range r.goals {
		if existing.ID == g.ID {
			r.goals[i] = g
			return nil
		}
	}
	r.goals = append(r.goals, g)
	return nil
}

func (r *fakeRepo) Delete(context.Context, uuid.UUID, uuid.UUID) error { return nil }

// WriteSnapshot is a no-op for the handler test (the service calls it after Update).
func (r *fakeRepo) WriteSnapshot(context.Context, *domain.Goal) error { return nil }

// fakeMVSource returns a fixed market value across accounts (multi-account port).
type fakeMVSource struct {
	mv int64
}

func (s *fakeMVSource) GetAccountsMarketValue(context.Context, uuid.UUID, []uuid.UUID) (int64, error) {
	return s.mv, nil
}

// withTenant builds a context carrying both a user id and the given tenant id
// (mirrors what the auth middleware does in production, via authgrpc helpers).
func withTenant(tenantID uuid.UUID) context.Context {
	return authgrpc.WithTenantID(authgrpc.WithUserID(context.Background(), uuid.New()), tenantID)
}

// newInvestmentGoal builds a persisted-style investment goal (we bypass NewGoal
// to avoid validator constraints on test fixtures; fields set explicitly).
func newInvestmentGoal(tenantID uuid.UUID, linkedAccount uuid.UUID) *domain.Goal {
	return &domain.Goal{
		ID:                uuid.New(),
		TenantID:          tenantID,
		Name:              "Retire early",
		GoalType:          domain.GoalTypeInvestment,
		TargetAmountCents: 1_000_000,
		CurrencyCode:      "CNY",
		LinkedAccountIDs:  []uuid.UUID{linkedAccount},
		Version:           1,
	}
}

// TestSyncInvestmentGoalsReturnsCount drives the handler end-to-end and asserts
// the response carries the synced count and a non-nil timestamp.
func TestSyncInvestmentGoalsReturnsCount(t *testing.T) {
	tenantID := uuid.New()
	acct := uuid.New()
	repo := &fakeRepo{goals: []*domain.Goal{
		newInvestmentGoal(tenantID, acct),
		newInvestmentGoal(tenantID, acct),
		newInvestmentGoal(tenantID, acct),
	}}
	svc := application.NewService(repo)
	svc.SetAccountMarketValueSource(&fakeMVSource{mv: 500_000})

	h := NewGoalHandler(svc)
	resp, err := h.SyncInvestmentGoals(withTenant(tenantID), &pb.SyncInvestmentGoalsRequest{})
	if err != nil {
		t.Fatalf("SyncInvestmentGoals returned error: %v", err)
	}
	if resp.SyncedCount != 3 {
		t.Errorf("SyncedCount = %d, want 3", resp.SyncedCount)
	}
	if resp.SyncedAt == nil {
		t.Error("SyncedAt is nil, want a timestamp")
	}
	if len(repo.updated) != 3 {
		t.Errorf("repo.Update calls = %d, want 3", len(repo.updated))
	}
}

// TestSyncInvestmentGoals_Unauthenticated verifies getTenantID → Unauthenticated.
func TestSyncInvestmentGoals_Unauthenticated(t *testing.T) {
	svc := application.NewService(&fakeRepo{})
	h := NewGoalHandler(svc)

	_, err := h.SyncInvestmentGoals(context.Background(), &pb.SyncInvestmentGoalsRequest{})
	if err == nil {
		t.Fatal("expected error for missing tenant, got nil")
	}
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %T", err)
	}
	if st.Code().String() != "Unauthenticated" {
		t.Errorf("error code = %v, want Unauthenticated", st.Code())
	}
}

// TestListGoalsFiltersByType asserts the proto GoalType filter flows through to
// the service: UNSPECIFIED → nil (all), INVESTMENT → *GoalTypeInvestment.
func TestListGoalsFiltersByType(t *testing.T) {
	tenantID := uuid.New()
	repo := &fakeRepo{goals: []*domain.Goal{
		newInvestmentGoal(tenantID, uuid.New()),
	}}
	svc := application.NewService(repo)
	h := NewGoalHandler(svc)

	// UNSPECIFIED → nil (all goals).
	if _, err := h.ListGoals(withTenant(tenantID), &pb.ListGoalsRequest{
		GoalType: pb.GoalType_GOAL_TYPE_UNSPECIFIED,
	}); err != nil {
		t.Fatalf("ListGoals(UNSPECIFIED) error: %v", err)
	}
	if repo.listedGT != nil {
		t.Errorf("UNSPECIFIED: service received GoalType=%v, want nil", *repo.listedGT)
	}

	// INVESTMENT → *GoalTypeInvestment (NAME-based, not numeric coincidence).
	if _, err := h.ListGoals(withTenant(tenantID), &pb.ListGoalsRequest{
		GoalType: pb.GoalType_GOAL_TYPE_INVESTMENT,
	}); err != nil {
		t.Fatalf("ListGoals(INVESTMENT) error: %v", err)
	}
	if repo.listedGT == nil {
		t.Fatal("INVESTMENT: service received nil GoalType, want *GoalTypeInvestment")
	}
	if *repo.listedGT != domain.GoalTypeInvestment {
		t.Errorf("INVESTMENT: service received GoalType=%v, want %v",
			*repo.listedGT, domain.GoalTypeInvestment)
	}
}

// TestProtoGoalTypeMapping verifies the NAME-BASED mapping between proto and
// domain GoalType (paranoid: not relying on numeric coincidence).
func TestProtoGoalTypeMapping(t *testing.T) {
	cases := []struct {
		proto pb.GoalType
		dom   domain.GoalType
	}{
		{pb.GoalType_GOAL_TYPE_SAVINGS, domain.GoalTypeSavings},
		{pb.GoalType_GOAL_TYPE_DEBT_PAYOFF, domain.GoalTypeDebtPayoff},
		{pb.GoalType_GOAL_TYPE_INVESTMENT, domain.GoalTypeInvestment},
		// UNSPECIFIED / unknown resolve to Savings (CreateGoal default; ListGoals
		// filters UNSPECIFIED out at the call site before mapping).
		{pb.GoalType_GOAL_TYPE_UNSPECIFIED, domain.GoalTypeSavings},
	}
	for _, c := range cases {
		if got := protoToGoalType(c.proto); got != c.dom {
			t.Errorf("protoToGoalType(%v) = %v, want %v", c.proto, got, c.dom)
		}
	}
	for _, c := range cases {
		if c.proto == pb.GoalType_GOAL_TYPE_UNSPECIFIED {
			continue
		}
		if got := goalTypeToProto(c.dom); got != c.proto {
			t.Errorf("goalTypeToProto(%v) = %v, want %v", c.dom, got, c.proto)
		}
	}
}

// ---------------------------------------------------------------------------
// D-goal Task 8: GoalHandler.CloneGoal + CreateGoal multi-account mapping
// ---------------------------------------------------------------------------

// TestCloneGoal verifies the handler parses the source_goal_id, drives
// application.CloneGoal, and returns the cloned DTO with a fresh ID and the
// overridden target/name. The source goal's linked accounts are carried over.
func TestCloneGoal(t *testing.T) {
	tenantID := uuid.New()
	src := newInvestmentGoal(tenantID, uuid.New()) // target 1_000_000, 1 linked acct
	repo := &fakeRepo{goals: []*domain.Goal{src}}
	svc := application.NewService(repo)
	h := NewGoalHandler(svc)

	resp, err := h.CloneGoal(withTenant(tenantID), &pb.CloneGoalRequest{
		SourceGoalId:      src.ID.String(),
		TargetAmountCents: 2_000_000,
		Name:              "cloned",
	})
	if err != nil {
		t.Fatalf("CloneGoal error: %v", err)
	}
	g := resp.GetGoal()
	if g.GetId() == src.ID.String() {
		t.Error("clone must have a fresh ID, got source ID")
	}
	if g.GetTargetAmountCents() != 2_000_000 {
		t.Errorf("clone target = %d, want 2000000", g.GetTargetAmountCents())
	}
	if g.GetName() != "cloned" {
		t.Errorf("clone name = %q, want \"cloned\"", g.GetName())
	}
	// Multi-account: linked_account_ids carries the source's account over.
	if len(g.GetLinkedAccountIds()) != 1 {
		t.Errorf("clone linked_account_ids = %v, want 1 id", g.GetLinkedAccountIds())
	}
}

// TestCloneGoal_InvalidSourceID verifies an unparseable source_goal_id surfaces
// InvalidArgument (not Internal).
func TestCloneGoal_InvalidSourceID(t *testing.T) {
	svc := application.NewService(&fakeRepo{})
	h := NewGoalHandler(svc)
	_, err := h.CloneGoal(withTenant(uuid.New()), &pb.CloneGoalRequest{
		SourceGoalId: "not-a-uuid",
	})
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %T", err)
	}
	if st.Code().String() != "InvalidArgument" {
		t.Errorf("error code = %v, want InvalidArgument", st.Code())
	}
}

// TestCreateGoalMultiAccount verifies CreateGoal reads the repeated
// linked_account_ids / linked_debt_ids proto fields (Task 8) and forwards them
// to the service. Both DebtPayoff debts and multiple accounts are exercised.
func TestCreateGoalMultiAccount(t *testing.T) {
	tenantID := uuid.New()
	acct1, acct2, debt1 := uuid.New(), uuid.New(), uuid.New()
	repo := &fakeRepo{}
	svc := application.NewService(repo)
	h := NewGoalHandler(svc)

	resp, err := h.CreateGoal(withTenant(tenantID), &pb.CreateGoalRequest{
		Name:               "payoff",
		GoalType:           pb.GoalType_GOAL_TYPE_DEBT_PAYOFF,
		TargetAmountCents:  500_000,
		CurrencyCode:       "CNY",
		LinkedAccountIds:   []string{acct1.String(), acct2.String()},
		LinkedDebtIds:      []string{debt1.String()},
	})
	if err != nil {
		t.Fatalf("CreateGoal error: %v", err)
	}
	g := resp.GetGoal()
	// Multi-account surfaced on the response DTO.
	if len(g.GetLinkedAccountIds()) != 2 {
		t.Errorf("response linked_account_ids = %v, want 2", g.GetLinkedAccountIds())
	}
	if len(g.GetLinkedDebtIds()) != 1 {
		t.Errorf("response linked_debt_ids = %v, want 1", g.GetLinkedDebtIds())
	}
	// The persisted goal carries the multi-account links too.
	if len(repo.saved) != 1 {
		t.Fatalf("Save calls = %d, want 1", len(repo.saved))
	}
	saved := repo.saved[0]
	if len(saved.LinkedAccountIDs) != 2 || saved.LinkedAccountIDs[0] != acct1 || saved.LinkedAccountIDs[1] != acct2 {
		t.Errorf("saved linked accounts = %v, want [acct1, acct2]", saved.LinkedAccountIDs)
	}
	if len(saved.LinkedDebtIDs) != 1 || saved.LinkedDebtIDs[0] != debt1 {
		t.Errorf("saved linked debts = %v, want [debt1]", saved.LinkedDebtIDs)
	}
}

// TestCreateGoalLegacySingleAccount verifies the legacy single linked_account_id
// field is still honored when the repeated field is empty (back-compat).
func TestCreateGoalLegacySingleAccount(t *testing.T) {
	tenantID := uuid.New()
	acct := uuid.New()
	repo := &fakeRepo{}
	svc := application.NewService(repo)
	h := NewGoalHandler(svc)

	resp, err := h.CreateGoal(withTenant(tenantID), &pb.CreateGoalRequest{
		Name:              "legacy",
		GoalType:          pb.GoalType_GOAL_TYPE_SAVINGS,
		TargetAmountCents: 100_000,
		CurrencyCode:      "CNY",
		LinkedAccountId:   acct.String(), // legacy single field
	})
	if err != nil {
		t.Fatalf("CreateGoal error: %v", err)
	}
	g := resp.GetGoal()
	if len(g.GetLinkedAccountIds()) != 1 || g.GetLinkedAccountIds()[0] != acct.String() {
		t.Errorf("response linked_account_ids = %v, want [%s]", g.GetLinkedAccountIds(), acct)
	}
}
