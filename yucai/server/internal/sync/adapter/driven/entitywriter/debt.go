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
	FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*debtdomain.DebtDetails, bool, error)
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

// Canonicalize round-trips one payload through the domain entity with the
// tenant stamped — the canonical JSON form the push detection compares
// against CurrentState's payload (see the port doc).
func (w *DebtWriter) Canonicalize(tenantID uuid.UUID, payload []byte) ([]byte, error) {
	var d debtdomain.DebtDetails
	if err := json.Unmarshal(payload, &d); err != nil {
		return nil, fmt.Errorf("unmarshal debt payload: %w", err)
	}
	d.TenantID = tenantID
	return json.Marshal(d)
}

// CurrentState returns the server's current debt row (header + nested
// schedule in the payload) for the push conflict check (F16 ADR-4). See the
// port doc in sync/domain/entity_writer.go for the full contract.
func (w *DebtWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse debt id %q: %w", entityID, err)
	}
	d, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(d)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal debt %s: %w", id, err)
	}
	return d.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*DebtWriter)(nil)
