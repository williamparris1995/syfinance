package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	tagDomain "github.com/yucai/server/internal/tag/domain"
)

// TagRepository is the tag-repo port subset that TagExporter consumes.
// Declared as a type alias so backup does not import the concrete tag repo
// type; any implementer of tag/domain.TagRepository satisfies it (port pattern,
// mirrors the account/transaction/debt/budget/goal/holding/template exporters).
type TagRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]tagDomain.Tag, error)
	Save(ctx context.Context, t *tagDomain.Tag) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// TagExporter 导出/导入/清空 tenant 的 tags (single table, no nested
// children), 实现 backup TenantDataPort。Tag-transaction junction rows
// (transaction_tag) are NOT backed up — they are derivative of transaction
// existence and would be orphaned/lost on restore; users re-apply tags to
// transactions after restore.
type TagExporter struct {
	repo TagRepository
}

// NewTagExporter constructs a TagExporter from a TagRepository.
func NewTagExporter(repo TagRepository) *TagExporter {
	return &TagExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *TagExporter) Name() string { return "tag" }

// Export serializes all tenant tags (non-soft-deleted) to JSON. Single flat
// array (mirrors account/template exporter shape).
func (e *TagExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export tags: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal tags: %w", err)
	}
	return data, nil
}

// Import deserializes tags from JSON and re-saves them under tenantID. Caller
// is expected to have Purged existing data first to avoid ID conflicts. Save
// honors the caller-supplied IDs (create-with-given-id), so Import after Purge
// is safe. Soft-delete state is preserved through DeletedAt roundtrip.
func (e *TagExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []tagDomain.Tag
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal tags: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save tag %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant tags (including soft-deleted rows) and their
// transaction_tag junction rows. The repo handles the junction cleanup (collect
// tag IDs → delete junction rows → delete tags).
func (e *TagExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge tags: %w", err)
	}
	return nil
}

// Compile-time assertion: TagExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*TagExporter)(nil)
