package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	templatedomain "github.com/yucai/server/internal/template/domain"
)

// TemplateRepository is the template-repo port subset the sync writer consumes
// (type alias, port pattern).
type TemplateRepository = interface {
	UpsertForSync(ctx context.Context, t *templatedomain.TransactionTemplate) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
}

// TemplateWriter persists pushed template changes (entity_type "template").
type TemplateWriter struct {
	repo TemplateRepository
}

// NewTemplateWriter constructs a TemplateWriter.
func NewTemplateWriter(repo TemplateRepository) *TemplateWriter {
	return &TemplateWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *TemplateWriter) Name() string { return "template" }

// Upsert decodes one template payload and upserts it under tenantID
// (authenticated tenant wins, anti injection).
func (w *TemplateWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var t templatedomain.TransactionTemplate
	if err := json.Unmarshal(payload, &t); err != nil {
		return fmt.Errorf("unmarshal template payload: %w", err)
	}
	t.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &t); err != nil {
		return fmt.Errorf("upsert template %s: %w", t.ID, err)
	}
	return nil
}

// Delete hard-deletes one template under tenantID.
func (w *TemplateWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse template id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete template %s: %w", id, err)
	}
	return nil
}

var _ syncdomain.SyncEntityWriter = (*TemplateWriter)(nil)
