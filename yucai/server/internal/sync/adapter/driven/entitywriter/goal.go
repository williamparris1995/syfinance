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

var _ syncdomain.SyncEntityWriter = (*GoalWriter)(nil)
