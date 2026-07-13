package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	debtDomain "github.com/yucai/server/internal/debt/domain"
)

// DebtRepository is the debt-repo port subset that DebtExporter consumes.
// Declared as a type alias so backup does not import the concrete debt repo
// type; any implementer of debt/domain.DebtRepository satisfies it (port
// pattern, mirrors AccountExporter/TransactionExporter).
type DebtRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]debtDomain.DebtDetails, error)
	Save(ctx context.Context, d *debtDomain.DebtDetails) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// DebtExporter 导出/导入/清空 tenant 的 debts(含 payment schedule),
// 实现 backup TenantDataPort。Each DebtDetails carries its Schedule nested, so
// Export marshals []DebtDetails directly (schedule rides along as a nested array).
type DebtExporter struct {
	repo DebtRepository
}

// NewDebtExporter constructs a DebtExporter from a DebtRepository.
func NewDebtExporter(repo DebtRepository) *DebtExporter {
	return &DebtExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *DebtExporter) Name() string { return "debt" }

// Export serializes all tenant debts (with payment schedules) to JSON.
func (e *DebtExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export debts: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal debts: %w", err)
	}
	return data, nil
}

// Import deserializes debts (with nested schedules) from JSON and re-saves them
// under tenantID. Caller is expected to have Purged existing data first to avoid
// ID conflicts. Save creates the debt and its schedule in one call, honoring the
// caller-supplied IDs.
func (e *DebtExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []debtDomain.DebtDetails
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal debts: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save debt %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant debts and their payment schedules (schedules
// first, then debts, to respect the FK ordering).
func (e *DebtExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge debts: %w", err)
	}
	return nil
}

// Compile-time assertion: DebtExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*DebtExporter)(nil)
