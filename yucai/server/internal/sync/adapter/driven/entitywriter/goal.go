package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	goaldomain "github.com/yucai/server/internal/goal/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// GoalRepository is the goal-repo port subset the sync writer consumes (type
// alias, port pattern).
type GoalRepository = interface {
	UpsertForSync(ctx context.Context, g *goaldomain.Goal) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
	FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*goaldomain.Goal, bool, error)
}

// GoalWriter persists pushed goal changes (entity_type "goal"). Payload shape:
// one Goal domain row with LinkedAccountIDs/LinkedDebtIDs nested.
type GoalWriter struct {
	repo GoalRepository
}

// NewGoalWriter constructs a GoalWriter.
func NewGoalWriter(repo GoalRepository) *GoalWriter {
	return &GoalWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *GoalWriter) Name() string { return "goal" }

// Upsert decodes one goal payload and upserts it under tenantID (authenticated
// tenant wins, anti injection).
func (w *GoalWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var g goaldomain.Goal
	if err := json.Unmarshal(payload, &g); err != nil {
		return fmt.Errorf("unmarshal goal payload: %w", err)
	}
	g.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &g); err != nil {
		return fmt.Errorf("upsert goal %s: %w", g.ID, err)
	}
	return nil
}

// Delete hard-deletes one goal (account/debt links cascade in-repo) under tenantID.
func (w *GoalWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse goal id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete goal %s: %w", id, err)
	}
	return nil
}

// CurrentState returns the server's current goal row for the push conflict
// check (F16 ADR-4). See the port doc in sync/domain/entity_writer.go for
// the full contract.
func (w *GoalWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse goal id %q: %w", entityID, err)
	}
	g, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(g)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal goal %s: %w", id, err)
	}
	return g.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*GoalWriter)(nil)
