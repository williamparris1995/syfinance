package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	budgetdomain "github.com/yucai/server/internal/budget/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// BudgetRepository is the budget-repo port subset the sync writer consumes
// (type alias, port pattern).
type BudgetRepository = interface {
	UpsertForSync(ctx context.Context, b *budgetdomain.Budget) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
	FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*budgetdomain.Budget, bool, error)
}

// BudgetWriter persists pushed budget changes (entity_type "budget"). Payload
// shape: one Budget domain row with its Items nested.
type BudgetWriter struct {
	repo BudgetRepository
}

// NewBudgetWriter constructs a BudgetWriter.
func NewBudgetWriter(repo BudgetRepository) *BudgetWriter {
	return &BudgetWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *BudgetWriter) Name() string { return "budget" }

// Upsert decodes one budget payload (header + nested items) and upserts it
// under tenantID (authenticated tenant wins, anti injection).
func (w *BudgetWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var b budgetdomain.Budget
	if err := json.Unmarshal(payload, &b); err != nil {
		return fmt.Errorf("unmarshal budget payload: %w", err)
	}
	b.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &b); err != nil {
		return fmt.Errorf("upsert budget %s: %w", b.ID, err)
	}
	return nil
}

// Delete hard-deletes one budget (items cascade in-repo) under tenantID.
func (w *BudgetWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse budget id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete budget %s: %w", id, err)
	}
	return nil
}

// Canonicalize round-trips one payload through the domain entity with the
// tenant stamped — the canonical JSON form the push detection compares
// against CurrentState's payload (see the port doc).
func (w *BudgetWriter) Canonicalize(tenantID uuid.UUID, payload []byte) ([]byte, error) {
	var b budgetdomain.Budget
	if err := json.Unmarshal(payload, &b); err != nil {
		return nil, fmt.Errorf("unmarshal budget payload: %w", err)
	}
	b.TenantID = tenantID
	return json.Marshal(b)
}

// CurrentState returns the server's current budget row (header + nested
// items in the payload) for the push conflict check (F16 ADR-4). See the
// port doc in sync/domain/entity_writer.go for the full contract.
func (w *BudgetWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse budget id %q: %w", entityID, err)
	}
	b, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(b)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal budget %s: %w", id, err)
	}
	return b.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*BudgetWriter)(nil)
