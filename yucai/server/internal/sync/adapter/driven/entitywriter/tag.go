package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	tagdomain "github.com/yucai/server/internal/tag/domain"
)

// TagRepository is the tag-repo port subset the sync writer consumes (type
// alias, port pattern).
type TagRepository = interface {
	UpsertForSync(ctx context.Context, t *tagdomain.Tag) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
	FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*tagdomain.Tag, bool, error)
}

// TagWriter persists pushed tag changes (entity_type "tag"). Tag-transaction
// junction rows are not synced (same scope decision as the backup exporter).
type TagWriter struct {
	repo TagRepository
}

// NewTagWriter constructs a TagWriter.
func NewTagWriter(repo TagRepository) *TagWriter {
	return &TagWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *TagWriter) Name() string { return "tag" }

// Upsert decodes one tag payload and upserts it under tenantID (authenticated
// tenant wins, anti injection).
func (w *TagWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var t tagdomain.Tag
	if err := json.Unmarshal(payload, &t); err != nil {
		return fmt.Errorf("unmarshal tag payload: %w", err)
	}
	t.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &t); err != nil {
		return fmt.Errorf("upsert tag %s: %w", t.ID, err)
	}
	return nil
}

// Delete hard-deletes one tag (junction rows cascade in-repo) under tenantID.
func (w *TagWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse tag id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete tag %s: %w", id, err)
	}
	return nil
}

// CurrentState returns the server's current tag row for the push conflict
// check (F16 ADR-4). See the port doc in sync/domain/entity_writer.go for
// the full contract.
func (w *TagWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse tag id %q: %w", entityID, err)
	}
	t, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(t)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal tag %s: %w", id, err)
	}
	return t.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*TagWriter)(nil)
