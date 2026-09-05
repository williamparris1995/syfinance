package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	debtdomain "github.com/yucai/server/internal/debt/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// DebtRepository is the debt-repo port subset the sync writer consumes (type
// alias, port pattern).
type DebtRepository = interface {
	UpsertForSync(ctx context.Context, d *debtdomain.DebtDetails) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
}

// DebtWriter persists pushed debt changes (entity_type "debt"). Payload shape:
// one DebtDetails domain row with its Schedule nested.
type DebtWriter struct {
	repo DebtRepository
}

// NewDebtWriter constructs a DebtWriter.
func NewDebtWriter(repo DebtRepository) *DebtWriter {
	return &DebtWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *DebtWriter) Name() string { return "debt" }

// Upsert decodes one debt payload (header + nested schedule) and upserts it
// under tenantID (authenticated tenant wins, anti injection).
func (w *DebtWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var d debtdomain.DebtDetails
	if err := json.Unmarshal(payload, &d); err != nil {
		return fmt.Errorf("unmarshal debt payload: %w", err)
	}
	d.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &d); err != nil {
		return fmt.Errorf("upsert debt %s: %w", d.ID, err)
	}
	return nil
}

// Delete hard-deletes one debt (schedule cascades in-repo) under tenantID.
func (w *DebtWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse debt id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete debt %s: %w", id, err)
	}
	return nil
}

var _ syncdomain.SyncEntityWriter = (*DebtWriter)(nil)
