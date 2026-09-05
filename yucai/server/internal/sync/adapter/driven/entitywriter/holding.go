package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// HoldingRepository is the holding-repo port subset the sync writer consumes
// (type alias, port pattern).
type HoldingRepository = interface {
	UpsertForSync(ctx context.Context, h *holdingdomain.Holding) error
	HardDeleteForSync(ctx context.Context, tenantID, holdingID uuid.UUID) error
}

// HoldingWriter persists pushed holding changes (entity_type "holding").
//
// Payload shape: ONE Holding position row (per-row serialization, ADR-2) — NOT
// the backup envelope's {holdings, transactions} two-array module shape. The
// trade ledger is append-only and rides the future "holding_ledger" entity
// type (FR-5, ticket 16 line); its writer will register separately.
type HoldingWriter struct {
	repo HoldingRepository
}

// NewHoldingWriter constructs a HoldingWriter.
func NewHoldingWriter(repo HoldingRepository) *HoldingWriter {
	return &HoldingWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *HoldingWriter) Name() string { return "holding" }

// Upsert decodes one holding payload and upserts it under tenantID
// (authenticated tenant wins, anti injection).
func (w *HoldingWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var h holdingdomain.Holding
	if err := json.Unmarshal(payload, &h); err != nil {
		return fmt.Errorf("unmarshal holding payload: %w", err)
	}
	h.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &h); err != nil {
		return fmt.Errorf("upsert holding %s: %w", h.ID, err)
	}
	return nil
}

// Delete hard-deletes one holding position under tenantID. Trade-ledger rows
// are append-only history and survive (in-repo decision, see HardDeleteForSync).
func (w *HoldingWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse holding id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete holding %s: %w", id, err)
	}
	return nil
}

var _ syncdomain.SyncEntityWriter = (*HoldingWriter)(nil)
