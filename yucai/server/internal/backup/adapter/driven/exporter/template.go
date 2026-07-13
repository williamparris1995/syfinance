package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	templateDomain "github.com/yucai/server/internal/template/domain"
)

// TemplateRepository is the template-repo port subset that TemplateExporter
// consumes. Declared as a type alias so backup does not import the concrete
// template repo type; any implementer of template/domain.TemplateRepository
// satisfies it (port pattern, mirrors the account/transaction/debt/budget/
// goal/holding exporters).
type TemplateRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]templateDomain.TransactionTemplate, error)
	Save(ctx context.Context, t *templateDomain.TransactionTemplate) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// TemplateExporter 导出/导入/清空 tenant 的 transaction templates (single
// table, no nested children), 实现 backup TenantDataPort。
type TemplateExporter struct {
	repo TemplateRepository
}

// NewTemplateExporter constructs a TemplateExporter from a TemplateRepository.
func NewTemplateExporter(repo TemplateRepository) *TemplateExporter {
	return &TemplateExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *TemplateExporter) Name() string { return "template" }

// Export serializes all tenant templates to JSON. Templates have no nested
// children, so this is a flat array (mirrors account exporter shape).
func (e *TemplateExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export templates: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal templates: %w", err)
	}
	return data, nil
}

// Import deserializes templates from JSON and re-saves them under tenantID.
// Caller is expected to have Purged existing data first to avoid ID conflicts.
// Save honors the caller-supplied IDs (create-with-given-id), so Import after
// Purge is safe.
func (e *TemplateExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []templateDomain.TransactionTemplate
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal templates: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save template %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant templates. Templates have no child tables, so
// no ordering concerns.
func (e *TemplateExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge templates: %w", err)
	}
	return nil
}

// Compile-time assertion: TemplateExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*TemplateExporter)(nil)
