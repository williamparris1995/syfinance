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
	FindForSync(ctx context.Context, tenantID, holdingID uuid.UUID) (*holdingdomain.Holding, bool, error)
}

// HoldingWriter persists pushed holding changes (entity_type "holding").
//
// Payload shape: ONE Holding position row (per-row serialization, ADR-2) — NOT
// the backup envelope's {holdings, transactions} two-array module shape. The
// trade ledger rides the sibling "holding_ledger" entity type (F17-T2,
// holding_ledger.go — 台账查证裁决=实施).
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

// Canonicalize round-trips one payload through the domain entity with the
// tenant stamped — the canonical JSON form the push detection compares
// against CurrentState's payload (see the port doc).
func (w *HoldingWriter) Canonicalize(tenantID uuid.UUID, payload []byte) ([]byte, error) {
	var h holdingdomain.Holding
	if err := json.Unmarshal(payload, &h); err != nil {
		return nil, fmt.Errorf("unmarshal holding payload: %w", err)
	}
	h.TenantID = tenantID
	return json.Marshal(h)
}

// CurrentState returns the server's current holding position row for the
// push conflict check (F16 ADR-4). See the port doc in
// sync/domain/entity_writer.go for the full contract.
func (w *HoldingWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse holding id %q: %w", entityID, err)
	}
	h, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(h)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal holding %s: %w", id, err)
	}
	return h.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*HoldingWriter)(nil)
